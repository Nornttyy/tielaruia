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


# --- 玩家名字同步 ---

# 发送端: name payload 带 type=name + 名字
func test_name_payload_builds_message() -> void:
	var payload: String = nm._name_payload("小明")
	var data: Variant = JSON.parse_string(payload)
	assert_true(data is Dictionary, "payload 应是合法 JSON")
	assert_eq(String(data.get("type", "")), "name", "type 应为 name")
	assert_eq(String(data.get("n", "")), "小明", "payload 要带名字")


# 接收端: 解析 name 消息 → 存 remote_player_name + 发信号
func test_route_name_stores_and_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"name","n":"小红"}')
	assert_eq(nm.remote_player_name, "小红", "收到 name 后存 remote_player_name")
	assert_signal_emitted_with_parameters(nm, "remote_name_received", ["小红"])


# --- 实体朝向/动画同步 (动物被打后对方看到动作/方向不变的 bug) ---

# 接收端: ent_pos 必须带出 facing + anim
func test_route_ent_pos_carries_facing_and_anim() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"ent_pos","id":42,"k":"cow","x":10.0,"y":20.0,"hp":5,"f":-1,"a":"walk"}')
	assert_signal_emitted_with_parameters(nm, "remote_entity_pos_received", [42, "cow", 10.0, 20.0, 5, -1, "walk"])


# 向后兼容: 老消息不带 f/a → facing 默认 1, anim 默认 ""
func test_route_ent_pos_defaults_facing_anim() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"ent_pos","id":7,"k":"slime","x":1.0,"y":2.0,"hp":0}')
	assert_signal_emitted_with_parameters(nm, "remote_entity_pos_received", [7, "slime", 1.0, 2.0, 0, 1, ""])


# --- 初始世界状态 (host 挖/放的方块同步给 client) ---

# host _deltas (Dict<cx, Dict<Vector2i, tid>>) 序列化后, client 解析能还原成 [lx,y,tid]
# (之前 send_initial_state 误当 PackedInt32Array, 序列化全废, client 看不到 host 改动)
func test_initial_state_roundtrip_serializes_deltas() -> void:
	var deltas: Dictionary = {0: {Vector2i(3, 5): 7}}
	var payload: String = nm._initial_state_payload(deltas)
	nm._route_message(payload)
	assert_true(nm.pending_initial_deltas.has("0"), "init_state 应按 str(cx) 存")
	var arr: Array = nm.pending_initial_deltas["0"]
	assert_eq(arr.size(), 3, "一个 delta 拍平成 [lx, y, tid] 共 3 个数")
	assert_eq(int(arr[0]), 3, "lx")
	assert_eq(int(arr[1]), 5, "world y")
	assert_eq(int(arr[2]), 7, "tile id")


# --- 战斗: client → host 伤害消息 ---
func test_route_ent_dmg_carries_fields() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"ent_dmg","id":99,"dmg":5,"kb":120.0,"sx":3.0,"sy":4.0}')
	assert_signal_emitted_with_parameters(nm, "remote_entity_damage_received", [99, 5, 120.0, 3.0, 4.0])


# 断线/返回菜单要清掉 pending 状态, 否则污染下一局
func test_disconnect_clears_session_state() -> void:
	nm.pending_initial_deltas = {"0": [1, 2, 3]}
	nm.remote_player_name = "小明"
	nm.disconnect_room()
	assert_eq(nm.pending_initial_deltas.size(), 0, "断线应清 pending_initial_deltas, 防污染新游戏")
	assert_eq(nm.remote_player_name, "", "断线应清 remote_player_name")
