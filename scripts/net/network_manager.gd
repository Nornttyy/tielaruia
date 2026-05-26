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

# 高层协议事件 (parse 后):
signal hello_received(world_seed: int)         # host → client, 双方一致的 seed
signal remote_pos_received(x: float, y: float, facing: int, anim: String)
signal remote_tile_received(x: int, y: int, tile_id: int)  # 对方挖/放方块
signal remote_time_weather_received(time_val: float, weather_state: String)  # host 广播时间+天气
signal initial_state_received(chunk_deltas: Dictionary)  # host 进游戏后广播现状, client 应用 (Phase G)
signal remote_entity_pos_received(ent_id: int, kind: String, x: float, y: float, hp: int)  # 实体位置 (Phase E)
signal remote_entity_die_received(ent_id: int)  # 实体死亡 (Phase E)
signal remote_drop_pos_received(ent_id: int, item_id: String, count: int, x: float, y: float)  # 掉落物 (item_drop)
signal remote_drop_pickup_received(ent_id: int)  # 对端捡了某个 drop → 本端删

const POLL_INTERVAL := 0.1  # 每 0.1s 拉一次 status + messages
const POS_SEND_INTERVAL := 0.1  # 玩家位置每 0.1s 发一次 (10Hz)

var status: String = "idle"
var my_room_code: String = ""
var is_host: bool = false
var last_error: String = ""
var shared_world_seed: int = 0  # host 创建房间时生成的种子, client 从 hello 拿
var pending_initial_deltas: Dictionary = {}  # client 收 hello 时存入, world 加载后取走应用
var _pos_send_timer: float = 0.0

var _bridge = null   # JavaScriptObject ref, 仅 HTML5 有
var _poll_timer: float = 0.0


func _ready() -> void:
	# 暂停菜单会 set_tree().paused = true. NetworkManager 是 autoload, 默认会被
	# 暂停影响 (_process 不跑). 设 ALWAYS 让它在暂停时也能 poll JS bridge,
	# 不然 host 在暂停菜单里点"开房间" 永远拿不到 PeerJS 返回的房间码.
	process_mode = Node.PROCESS_MODE_ALWAYS
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
		var old_status: String = status
		status = new_status
		status_changed.emit(status)
		if status == "error":
			last_error = String(_bridge.get_last_error())
			error_occurred.emit(last_error)
		# host 连上 client 后, 立刻发 hello (告诉对方 seed)
		if status == "connected" and is_host and old_status != "connected":
			send_hello(shared_world_seed)
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
				_route_message(String(m))


# 解析收到的 JSON 消息, 分发到具体信号
func _route_message(raw: String) -> void:
	message_received.emit(raw)
	var data: Variant = JSON.parse_string(raw)
	if not (data is Dictionary):
		return
	var msg_type: String = String(data.get("type", ""))
	match msg_type:
		"hello":
			var seed_val: int = int(data.get("seed", 0))
			shared_world_seed = seed_val
			hello_received.emit(seed_val)
		"init_state":
			# host 在自己 world 加载后发的现状. client world 准备好就 emit, world 接收应用.
			var deltas: Dictionary = data.get("deltas", {})
			pending_initial_deltas = deltas
			initial_state_received.emit(deltas)
		"ent_pos":
			var eid: int = int(data.get("id", 0))
			var ekind: String = String(data.get("k", "slime"))
			var ex: float = float(data.get("x", 0.0))
			var ey: float = float(data.get("y", 0.0))
			var ehp: int = int(data.get("hp", 0))
			remote_entity_pos_received.emit(eid, ekind, ex, ey, ehp)
		"ent_die":
			var did: int = int(data.get("id", 0))
			remote_entity_die_received.emit(did)
		"drop_pos":
			var did2: int = int(data.get("id", 0))
			var iid: String = String(data.get("item", ""))
			var cnt: int = int(data.get("n", 1))
			var dx: float = float(data.get("x", 0.0))
			var dy: float = float(data.get("y", 0.0))
			remote_drop_pos_received.emit(did2, iid, cnt, dx, dy)
		"drop_pick":
			# 对端捡了 ent_id, 本端删本地副本
			var pid: int = int(data.get("id", 0))
			remote_drop_pickup_received.emit(pid)
		"pos":
			var x: float = float(data.get("x", 0.0))
			var y: float = float(data.get("y", 0.0))
			var facing: int = int(data.get("f", 1))
			var anim: String = String(data.get("a", "idle"))
			remote_pos_received.emit(x, y, facing, anim)
		"tile":
			var tx: int = int(data.get("x", 0))
			var ty: int = int(data.get("y", 0))
			var tid: int = int(data.get("id", 0))
			remote_tile_received.emit(tx, ty, tid)
		"time":
			var t: float = float(data.get("t", 0.0))
			var w: String = String(data.get("w", "clear"))
			remote_time_weather_received.emit(t, w)


func host(p_seed: int = 0) -> void:
	if _bridge == null:
		_try_reload_bridge()
	if _bridge == null:
		_emit_no_bridge_error()
		return
	is_host = true
	my_room_code = ""
	# 共享 seed: 由调用方传 (游戏内 host 用当前世界 seed); 0 = 让 NM 随机生
	shared_world_seed = p_seed if p_seed != 0 else randi_range(1, 999999)
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


# ===== 高层协议: 发 hello / 位置 =====

func send_hello(seed_val: int) -> void:
	send(JSON.stringify({"type": "hello", "seed": seed_val}))


func send_initial_state(chunk_deltas: Dictionary) -> void:
	# Phase G: host 进游戏后, 把当前 chunk 改动广播给 client.
	# Dict<int, PackedInt32Array> → JSON Dict<str(cx), [lx,y,tid,...]>
	# 转 String key (JSON.stringify 不支持 int key)
	var stringified: Dictionary = {}
	for cx in chunk_deltas.keys():
		var arr: PackedInt32Array = chunk_deltas[cx]
		var plain: Array = []
		for i in arr.size():
			plain.append(arr[i])
		stringified[str(cx)] = plain
	send(JSON.stringify({"type": "init_state", "deltas": stringified}))


# Phase E: host 广播单个实体当前位置 (slime/cow/zombie). client 用 id 同步.
func send_entity_pos(ent_id: int, kind: String, x: float, y: float, hp: int = 0) -> void:
	send(JSON.stringify({
		"type": "ent_pos", "id": ent_id, "k": kind,
		"x": snappedf(x, 0.1), "y": snappedf(y, 0.1), "hp": hp,
	}))


# Phase E: host 广播实体死亡 (移除 id)
func send_entity_die(ent_id: int) -> void:
	send(JSON.stringify({"type": "ent_die", "id": ent_id}))


# 掉落物同步: 跟 ent_pos 类似但带 item_id + count, kind 固定 drop
func send_drop_pos(ent_id: int, item_id: String, count: int, x: float, y: float) -> void:
	send(JSON.stringify({
		"type": "drop_pos", "id": ent_id,
		"item": item_id, "n": count,
		"x": snappedf(x, 0.1), "y": snappedf(y, 0.1),
	}))


# 计算稳定的 entity_id 给某个 Node (host 内唯一就行).
# get_instance_id() 是 int64, 取低 28 位避免 JSON 大数精度问题.
static func entity_id_for(node: Object) -> int:
	return int(node.get_instance_id()) & 0xFFFFFFF


func send_drop_pickup(ent_id: int) -> void:
	send(JSON.stringify({"type": "drop_pick", "id": ent_id}))


func send_tile_change(x: int, y: int, tile_id: int) -> void:
	send(JSON.stringify({"type": "tile", "x": x, "y": y, "id": tile_id}))


# host 调用: 把当前时间 + 天气广播给 client. world 周期触发 (5s 一次)
func send_time_weather(time_val: float, weather_state: String) -> void:
	send(JSON.stringify({"type": "time", "t": snappedf(time_val, 0.001), "w": weather_state}))


# 由 player_controller 每 _physics_process 末尾调.
# 内部限速到 POS_SEND_INTERVAL.
func tick_send_player_pos(delta: float, x: float, y: float, facing: int, anim: String) -> void:
	if not connected():
		return
	_pos_send_timer -= delta
	if _pos_send_timer > 0.0:
		return
	_pos_send_timer = POS_SEND_INTERVAL
	# 紧凑 key (a/f/x/y) 省带宽
	send(JSON.stringify({
		"type": "pos",
		"x": snappedf(x, 0.1),
		"y": snappedf(y, 0.1),
		"f": facing,
		"a": anim,
	}))


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
