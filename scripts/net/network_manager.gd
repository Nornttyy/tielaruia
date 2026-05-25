# 联机管理 autoload. 通过 JavaScriptBridge 调用浏览器端 window.MultiplayerBridge
# (PeerJS WebRTC P2P 信令). 详见 scripts/web/peerjs_bridge.js.
#
# 用法 (UI 调用):
#   NetworkManager.host()          → 启动 host, 等几秒后 NetworkManager.my_room_code 有值
#   NetworkManager.join(code)      → 加入指定房间码
#   NetworkManager.status          → "idle" / "hosting" / "joining" / "connected" / "disconnected" / "error"
#   NetworkManager.connected       → bool (是否已连上)
#
# 信号:
#   status_changed(status: String)        → 状态变化
#   room_code_ready(code: String)         → host 成功后, 房间码可分享
#   message_received(data: String)        → 收到对方发的消息
#   error_occurred(msg: String)           → 出错
#
# 非 HTML5 平台 (桌面 / 测试) 直接禁用, _has_bridge() 返 false, 所有操作 no-op.
extends Node

signal status_changed(s: String)
signal room_code_ready(code: String)
signal message_received(data: String)
signal error_occurred(msg: String)

const POLL_INTERVAL := 0.1  # 每 0.1s 拉一次 status + messages

var status: String = "idle"
var my_room_code: String = ""
var is_host: bool = false
var last_error: String = ""

var _bridge = null   # JavaScriptObject ref, 仅 HTML5 有
var _poll_timer: float = 0.0


func _ready() -> void:
	# 只在 HTML5 export 启用. 桌面 (gut 测试) 直接放着不动.
	if not _has_javascript_bridge():
		print("[NetworkManager] 非 HTML5 平台, 联机功能禁用")
		return
	# 等 JS bridge 加载 (peerjs_bridge.js 是 <script> 加载, 应该 _ready 时已可见)
	_bridge = JavaScriptBridge.get_interface("MultiplayerBridge")
	if _bridge == null:
		# 可能 peerjs_bridge.js 没注入. 不致命, 调用时再 retry.
		push_warning("[NetworkManager] 没找到 window.MultiplayerBridge — 检查 peerjs_bridge.js 是否注入")


func _process(delta: float) -> void:
	if _bridge == null:
		return
	_poll_timer -= delta
	if _poll_timer > 0.0:
		return
	_poll_timer = POLL_INTERVAL
	_poll_bridge()


func _has_javascript_bridge() -> bool:
	return OS.has_feature("web")


# 拉 bridge 状态: 更新 status / my_room_code / 拉消息
func _poll_bridge() -> void:
	var new_status: String = String(_bridge.get_status())
	if new_status != status:
		status = new_status
		status_changed.emit(status)
		if status == "error":
			last_error = String(_bridge.get_last_error())
			error_occurred.emit(last_error)
	# my_room_code (host 模式才有, 异步生成)
	var rc: String = String(_bridge.get_my_id())
	if rc != my_room_code and rc != "":
		my_room_code = rc
		room_code_ready.emit(rc)
	# 拉消息队列
	var msgs_json: String = String(_bridge.pop_messages())
	if msgs_json != "" and msgs_json != "[]":
		var msgs: Variant = JSON.parse_string(msgs_json)
		if msgs is Array:
			for m in msgs:
				message_received.emit(String(m))


func host() -> void:
	if _bridge == null:
		_try_reload_bridge()
	if _bridge == null:
		_emit_no_bridge_error()
		return
	is_host = true
	my_room_code = ""
	_bridge.host()


func join(code: String) -> void:
	if _bridge == null:
		_try_reload_bridge()
	if _bridge == null:
		_emit_no_bridge_error()
		return
	is_host = false
	_bridge.join(code.strip_edges().to_upper())


func send(data: String) -> bool:
	if _bridge == null or not connected():
		return false
	return bool(_bridge.send(data))


func disconnect_room() -> void:
	if _bridge != null:
		_bridge.disconnect()
	status = "idle"
	my_room_code = ""
	is_host = false


func connected() -> bool:
	return status == "connected"


func _try_reload_bridge() -> void:
	if not _has_javascript_bridge():
		return
	_bridge = JavaScriptBridge.get_interface("MultiplayerBridge")


func _emit_no_bridge_error() -> void:
	last_error = "PeerJS bridge 未加载 (这个平台不支持联机, 只在浏览器有效)"
	status = "error"
	status_changed.emit(status)
	error_occurred.emit(last_error)
