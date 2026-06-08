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
signal hello_received(world_seed: int, world_size: int, difficulty: int)  # host → client, seed+大小+难度 (双方一致)
signal remote_name_received(name: String)      # 对方玩家名 (改名后联机也显示真名)
signal chat_received(text: String)              # 对方发来的聊天文字 (联机聊天)
signal remote_pos_received(x: float, y: float, facing: int, anim: String)
signal remote_tile_received(x: int, y: int, tile_id: int)  # 对方挖/放方块
signal remote_time_weather_received(time_val: float, weather_state: String)  # host 广播时间+天气
signal initial_state_received(chunk_deltas: Dictionary)  # host 进游戏后广播现状, client 应用 (Phase G)
signal remote_entity_pos_received(ent_id: int, kind: String, x: float, y: float, hp: int, facing: int, anim: String)  # 实体位置+朝向+动画 (Phase E)
signal remote_entity_die_received(ent_id: int)  # 实体死亡 (Phase E)
signal remote_entity_damage_received(ent_id: int, amount: int, knockback: float, sx: float, sy: float)  # client→host: 对怪造成伤害
signal remote_projectile_received(kind: String, sx: float, sy: float, tx: float, ty: float)  # 投射物(箭/火球)画面同步
signal remote_player_death_received()    # 对方玩家死了
signal remote_player_respawn_received()  # 对方玩家复活了
signal remote_drop_request_received(item_id: String, count: int, x: float, y: float)  # client→host: 请求生成掉落
signal remote_chest_received(x: int, y: int, slots: Array)  # 箱子内容同步 (一人改两人见)
signal remote_drop_pos_received(ent_id: int, item_id: String, count: int, x: float, y: float)  # 掉落物 (item_drop)
signal remote_drop_pickup_received(ent_id: int)  # 对端捡了某个 drop → 本端删
signal remote_tile_batch_received(changes: PackedInt32Array)  # 批量 tile [x,y,id]*N

const POLL_INTERVAL := 0.1  # 每 0.1s 拉一次 status + messages
const POS_SEND_INTERVAL := 0.1  # 玩家位置每 0.1s 发一次 (10Hz)

var status: String = "idle"
var my_room_code: String = ""
var is_host: bool = false
var last_error: String = ""
var shared_world_seed: int = 0  # host 创建房间时生成的种子, client 从 hello 拿
var shared_world_size: int = 1  # host 的世界大小 (0小/1中/2大); client 从 hello 拿. 不传会致两端地形/大小不一致
var shared_world_difficulty: int = 1  # host 难度 (0简/1普/2难); client 从 hello 拿. 不传会致怪 HP/伤害两端不一致
var remote_player_name: String = ""  # 对方玩家名, 收到 name 消息后存; remote_player spawn 时取用
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
		# host 连上 client 后, 立刻发 hello (告诉对方 seed + 世界大小)
		if status == "connected" and is_host and old_status != "connected":
			send_hello(shared_world_seed, shared_world_size, shared_world_difficulty)
		# 双方连上后互发自己的名字 (host + client 都发, 这样两边都显示真名)
		if status == "connected" and old_status != "connected":
			send_player_name(_local_player_name())
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
			var size_val: int = int(data.get("size", 1))  # 缺省 1=中, 向后兼容不带 size 的老 host
			var diff_val: int = int(data.get("diff", 1))  # 缺省 1=普通
			shared_world_seed = seed_val
			shared_world_size = size_val
			shared_world_difficulty = diff_val
			hello_received.emit(seed_val, size_val, diff_val)
		"name":
			var pname: String = String(data.get("n", ""))
			remote_player_name = pname
			remote_name_received.emit(pname)
		"chat":
			# 对方发来的聊天文字. 截断防超长. chat_box 收到 → 头顶气泡 + 左下聊天栏.
			var ctext: String = String(data.get("m", "")).substr(0, 120)
			chat_received.emit(ctext)
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
			var efacing: int = int(data.get("f", 1))
			var eanim: String = String(data.get("a", ""))
			remote_entity_pos_received.emit(eid, ekind, ex, ey, ehp, efacing, eanim)
		"ent_die":
			var did: int = int(data.get("id", 0))
			remote_entity_die_received.emit(did)
		"ent_dmg":
			var dmid: int = int(data.get("id", 0))
			var dmamt: int = int(data.get("dmg", 0))
			var dmkb: float = float(data.get("kb", 0.0))
			var dmsx: float = float(data.get("sx", 0.0))
			var dmsy: float = float(data.get("sy", 0.0))
			remote_entity_damage_received.emit(dmid, dmamt, dmkb, dmsx, dmsy)
		"proj":
			remote_projectile_received.emit(
				String(data.get("k", "fireball")),
				float(data.get("sx", 0.0)), float(data.get("sy", 0.0)),
				float(data.get("tx", 0.0)), float(data.get("ty", 0.0)))
		"pdead":
			remote_player_death_received.emit()
		"pres":
			remote_player_respawn_received.emit()
		"drop_req":
			remote_drop_request_received.emit(
				String(data.get("item", "")), int(data.get("n", 1)),
				float(data.get("x", 0.0)), float(data.get("y", 0.0)))
		"chest":
			var cslots: Variant = data.get("s", [])
			if cslots is Array:
				remote_chest_received.emit(int(data.get("x", 0)), int(data.get("y", 0)), cslots)
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
		"tile_batch":
			var arr_v: Variant = data.get("c", [])
			if arr_v is Array:
				var pia := PackedInt32Array()
				for v in arr_v:
					pia.append(int(v))
				remote_tile_batch_received.emit(pia)
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


func host(p_seed: int = 0, p_size: int = 1, p_diff: int = 1) -> void:
	if _bridge == null:
		_try_reload_bridge()
	if _bridge == null:
		_emit_no_bridge_error()
		return
	is_host = true
	my_room_code = ""
	# 共享 seed: 由调用方传 (游戏内 host 用当前世界 seed); 0 = 让 NM 随机生
	shared_world_seed = p_seed if p_seed != 0 else randi_range(1, 999999)
	# 共享世界大小: client 收 hello 后用它生成同样大小的世界 (不传 → 地形/大小不一致 bug)
	shared_world_size = p_size
	shared_world_difficulty = p_diff
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

func _hello_payload(seed_val: int, size_val: int, diff_val: int) -> String:
	return JSON.stringify({"type": "hello", "seed": seed_val, "size": size_val, "diff": diff_val})


func send_hello(seed_val: int, size_val: int, diff_val: int) -> void:
	send(_hello_payload(seed_val, size_val, diff_val))


# 从 GameSettings 安全取本地玩家名 (autoload 缺失时退回 "玩家", 不崩)
func _local_player_name() -> String:
	var gs: Node = get_node_or_null("/root/GameSettings")
	if gs != null and "player_name" in gs:
		return String(gs.player_name)
	return "玩家"


func _name_payload(n: String) -> String:
	return JSON.stringify({"type": "name", "n": n})


func send_player_name(n: String) -> void:
	send(_name_payload(n))


# 联机聊天: 把一句话发给对方 (截断防超长)。
func send_chat(text: String) -> void:
	send(JSON.stringify({"type": "chat", "m": text.substr(0, 120)}))


func _initial_state_payload(chunk_deltas: Dictionary) -> String:
	# chunk_deltas 真实结构: Dict<int cx, Dict<Vector2i pos, int tid>> (见 chunk_manager._deltas)
	# → JSON Dict<str(cx), [lx, y, tid, ...]>  (JSON 不支持 int/Vector2i key: cx 转 str, 内层拍平)
	var stringified: Dictionary = {}
	for cx in chunk_deltas.keys():
		var inner: Dictionary = chunk_deltas[cx]
		var plain: Array = []
		for pos in inner.keys():
			plain.append(pos.x)        # lx (chunk 内局部 x)
			plain.append(pos.y)        # world y
			plain.append(inner[pos])   # tile id
		stringified[str(cx)] = plain
	return JSON.stringify({"type": "init_state", "deltas": stringified})


func send_initial_state(chunk_deltas: Dictionary) -> void:
	# Phase G: host 进游戏后把当前 chunk 改动广播给 client (含挖/放/火把/门).
	# 之前误把内层 Dict 当 PackedInt32Array → 序列化全废, client 看不到 host 的世界改动.
	send(_initial_state_payload(chunk_deltas))


# Phase E: host 广播单个实体当前位置 (slime/cow/zombie). client 用 id 同步.
func send_entity_pos(ent_id: int, kind: String, x: float, y: float, hp: int = 0, facing: int = 1, anim: String = "") -> void:
	send(JSON.stringify({
		"type": "ent_pos", "id": ent_id, "k": kind,
		"x": snappedf(x, 0.1), "y": snappedf(y, 0.1), "hp": hp,
		"f": facing, "a": anim,
	}))


# Phase E: host 广播实体死亡 (移除 id)
func send_entity_die(ent_id: int) -> void:
	send(JSON.stringify({"type": "ent_die", "id": ent_id}))


# client → host: 对 host 权威的怪造成伤害. host 收到后在自己那只真怪上 take_damage.
func send_entity_damage(ent_id: int, amount: int, knockback: float, x: float, y: float) -> void:
	send(JSON.stringify({
		"type": "ent_dmg", "id": ent_id, "dmg": amount,
		"kb": snappedf(knockback, 0.1), "sx": snappedf(x, 0.1), "sy": snappedf(y, 0.1),
	}))


# 广播投射物 spawn (箭/火球), 对端生成纯视觉副本飞同样轨迹 (不造成伤害)
func send_projectile(kind: String, sx: float, sy: float, tx: float, ty: float) -> void:
	send(JSON.stringify({
		"type": "proj", "k": kind,
		"sx": snappedf(sx, 0.1), "sy": snappedf(sy, 0.1),
		"tx": snappedf(tx, 0.1), "ty": snappedf(ty, 0.1),
	}))


func send_player_death() -> void:
	send(JSON.stringify({"type": "pdead"}))


func send_player_respawn() -> void:
	send(JSON.stringify({"type": "pres"}))


# client → host: 请求在 (x,y) 生成掉落. host 权威 spawn 后经 drop_pos 广播给两边.
func send_drop_request(item_id: String, count: int, x: float, y: float) -> void:
	send(JSON.stringify({
		"type": "drop_req", "item": item_id, "n": count,
		"x": snappedf(x, 0.1), "y": snappedf(y, 0.1),
	}))


# 箱子内容改动后广播整箱 (slots = Array[24] of null/{item_id,count})
func send_chest(tile: Vector2i, slots: Array) -> void:
	send(JSON.stringify({"type": "chest", "x": tile.x, "y": tile.y, "s": slots}))


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


# 批量 tile 变化 (水流 tick / 级联砍树): PackedInt32Array [x1,y1,id1,...]
func send_tile_batch(changes: PackedInt32Array) -> void:
	if changes.is_empty():
		return
	var arr: Array = []
	for v in changes:
		arr.append(v)
	send(JSON.stringify({"type": "tile_batch", "c": arr}))


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
	# 清掉本局会话状态, 否则 NetworkManager (autoload) 会把上一局的 chunk deltas / 对方名字
	# 带到下一局, 污染新世界地形 (bug: 返回菜单再开新游戏看到旧改动)
	pending_initial_deltas = {}
	remote_player_name = ""


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
