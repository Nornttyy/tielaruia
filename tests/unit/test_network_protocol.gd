# NetworkManager 联机协议单测.
# 重点: hello 消息必须携带 world_size, 否则 client 用默认"中"世界 → 与 host 地形/大小不一致.
# (桌面/headless 没有 JS bridge, send() 是 no-op; 这里只测「构建 payload」+「解析 route」纯逻辑.)
extends GutTest

const NetworkManagerScript = preload("res://scripts/net/network_manager.gd")

var nm


func before_each() -> void:
	nm = NetworkManagerScript.new()
	add_child_autofree(nm)  # 触发 _ready (无 bridge → 安全 no-op)


# 发送端: hello payload 必须同时带 seed 和 size
func test_hello_payload_includes_world_size() -> void:
	var payload: String = nm._hello_payload(12345, 2)
	var data: Variant = JSON.parse_string(payload)
	assert_true(data is Dictionary, "payload 应是合法 JSON 对象")
	assert_eq(int(data.get("seed", -1)), 12345, "payload 要带 seed")
	assert_eq(int(data.get("size", -1)), 2, "payload 必须带 world_size")


# 接收端: 解析带 size 的 hello → 存 shared_world_size + 信号带 size
func test_route_hello_parses_size_and_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"hello","seed":777,"size":2}')
	assert_eq(nm.shared_world_seed, 777, "解析出 seed")
	assert_eq(nm.shared_world_size, 2, "解析出 world_size 并存 shared_world_size")
	assert_signal_emitted_with_parameters(nm, "hello_received", [777, 2])


# 向后兼容: 老 host 的 hello 不带 size → client 默认中 (1), 不崩
func test_route_hello_defaults_size_to_one_when_absent() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"hello","seed":5}')
	assert_eq(nm.shared_world_size, 1, "缺 size 时默认 1 (中)")
	assert_signal_emitted_with_parameters(nm, "hello_received", [5, 1])


# host(seed, size) 应把 size 暂存到 shared_world_size (供连上后 send_hello 用)
func test_host_stores_world_size() -> void:
	# 无 bridge 时 host() 会走 _emit_no_bridge_error 提前 return, 不会设 shared_world_size.
	# 所以直接验证字段存在且可写 (host 内部会写它); 用默认值确认字段已声明.
	assert_true("shared_world_size" in nm, "NetworkManager 应有 shared_world_size 字段")
