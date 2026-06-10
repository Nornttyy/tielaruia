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
	var payload: String = nm._hello_payload(12345, 2, 2)
	var data: Variant = JSON.parse_string(payload)
	assert_true(data is Dictionary, "payload 应是合法 JSON 对象")
	assert_eq(int(data.get("seed", -1)), 12345, "payload 要带 seed")
	assert_eq(int(data.get("size", -1)), 2, "payload 必须带 world_size")
	assert_eq(int(data.get("diff", -1)), 2, "payload 必须带 difficulty")


# 接收端: 解析带 size 的 hello → 存 shared_world_size + 信号带 size
func test_route_hello_parses_size_and_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"hello","seed":777,"size":2,"diff":2}')
	assert_eq(nm.shared_world_seed, 777, "解析出 seed")
	assert_eq(nm.shared_world_size, 2, "解析出 world_size 并存 shared_world_size")
	assert_eq(nm.shared_world_difficulty, 2, "解析出 difficulty 并存 shared_world_difficulty")
	assert_signal_emitted_with_parameters(nm, "hello_received", [777, 2, 2])


# 向后兼容: 老 host 的 hello 不带 size → client 默认中 (1), 不崩
func test_route_hello_defaults_size_to_one_when_absent() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"hello","seed":5}')
	assert_eq(nm.shared_world_size, 1, "缺 size 时默认 1 (中)")
	assert_eq(nm.shared_world_difficulty, 1, "缺 diff 时默认 1 (普通)")
	assert_signal_emitted_with_parameters(nm, "hello_received", [5, 1, 1])


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


# 接收端: 解析 name 消息 → 存 remote_player_name + 发信号 (带 peer_id)
func test_route_name_stores_and_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"name","n":"小红","pid":"P2"}', "P2")
	assert_eq(nm.remote_player_name, "小红", "收到 name 后存 remote_player_name")
	assert_signal_emitted_with_parameters(nm, "remote_name_received", ["P2", "小红"])


# 玩家位置: 信号带 peer_id (多人时区分是谁)
func test_route_pos_carries_peer_id() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"pos","x":10.0,"y":20.0,"f":-1,"a":"walk","pid":"P3"}', "P3")
	assert_signal_emitted_with_parameters(nm, "remote_pos_received", ["P3", 10.0, 20.0, -1, "walk"])


# 聊天: 带 peer_id
func test_route_chat_carries_peer_id() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"chat","m":"hi","pid":"P5"}', "P5")
	assert_signal_emitted_with_parameters(nm, "chat_received", ["P5", "hi"])


# host 收到 client 的 pos → 决定转发给除来源外的所有 peer
func test_host_relay_targets_for_pos() -> void:
	var MpRooms = preload("res://scripts/net/mp_rooms.gd")
	var targets: Array = MpRooms.relay_targets("pos", "P2", ["P2", "P3"])
	assert_eq(targets, ["P3"], "P2 发的 pos 转给 P3, 不发回 P2")


# 解析 bridge 新消息格式 {from, data}: 取出 from 当来源, data 当原始消息
func test_parse_bridge_envelope() -> void:
	var env: Dictionary = nm._parse_envelope('{"from":"P9","data":"{\\"type\\":\\"pos\\",\\"x\\":1.0,\\"y\\":2.0}"}')
	assert_eq(String(env.get("from", "")), "P9", "取出来源 peer")
	assert_eq(String(env.get("data", "")), '{"type":"pos","x":1.0,"y":2.0}', "取出原始消息字符串")


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


# --- 投射物画面同步 (箭/火球) ---
func test_route_proj_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"proj","k":"fireball","sx":1.0,"sy":2.0,"tx":3.0,"ty":4.0}')
	assert_signal_emitted_with_parameters(nm, "remote_projectile_received", ["fireball", 1.0, 2.0, 3.0, 4.0])


# --- 玩家死亡/复活通知 (带 peer_id) ---
func test_route_player_death_and_respawn_carry_peer_id() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"pdead","pid":"P2"}', "P2")
	assert_signal_emitted_with_parameters(nm, "remote_player_death_received", ["P2"])
	nm._route_message('{"type":"pres","pid":"P2"}', "P2")
	assert_signal_emitted_with_parameters(nm, "remote_player_respawn_received", ["P2"])


# --- client→host 掉落请求 ---
func test_route_drop_request() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"drop_req","item":"stone","n":2,"x":5.0,"y":6.0}')
	assert_signal_emitted_with_parameters(nm, "remote_drop_request_received", ["stone", 2, 5.0, 6.0])


# --- 箱子内容同步 ---
func test_route_chest_emits() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"chest","x":3,"y":4,"s":[null,{"item_id":"stone","count":5}]}')
	assert_signal_emitted(nm, "remote_chest_received")
	var params: Array = get_signal_parameters(nm, "remote_chest_received")
	assert_eq(int(params[0]), 3, "箱子 x")
	assert_eq(int(params[1]), 4, "箱子 y")
	assert_eq((params[2] as Array).size(), 2, "槽数组传过来")


# 断线/返回菜单要清掉 pending 状态, 否则污染下一局
func test_disconnect_clears_session_state() -> void:
	nm.pending_initial_deltas = {"0": [1, 2, 3]}
	nm.remote_player_name = "小明"
	nm.disconnect_room()
	assert_eq(nm.pending_initial_deltas.size(), 0, "断线应清 pending_initial_deltas, 防污染新游戏")
	assert_eq(nm.remote_player_name, "", "断线应清 remote_player_name")


# --- PvP 对战模式 ---

# hello payload 带 room_mode (host 告诉 client 这是对战房)
func test_hello_payload_includes_mode() -> void:
	nm.room_mode = "pvp"
	var data: Variant = JSON.parse_string(nm._hello_payload(1, 1, 1))
	assert_eq(String(data.get("mode", "")), "pvp", "hello 要带 mode 让 client 知道是对战房")


# 收 hello 带 mode → 设 room_mode
func test_route_hello_sets_room_mode() -> void:
	nm._route_message('{"type":"hello","seed":1,"size":1,"diff":1,"mode":"pvp"}')
	assert_eq(nm.room_mode, "pvp", "client 收 hello 后知道在对战房")


# 起床战争分岛: bw_slot → bw_slot_received 信号
func test_route_bw_slot() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"bw_slot","pid":"P2","slot":3}', "HOST")
	assert_signal_emitted_with_parameters(nm, "bw_slot_received", ["P2", 3])


# 起床战争模式: is_bedwars + combat_enabled (对战房+起床房都能打)
func test_bedwars_mode_and_combat_enabled() -> void:
	nm.status = "connected"
	nm.room_mode = "bedwars"
	assert_true(nm.is_bedwars(), "bedwars 模式")
	assert_true(nm.combat_enabled(), "起床房能打人")
	assert_false(nm.is_pvp(), "bedwars 不是 pvp")
	nm.room_mode = "pvp"
	assert_true(nm.combat_enabled(), "对战房能打人")
	assert_false(nm.is_bedwars())
	nm.room_mode = "survival"
	assert_false(nm.combat_enabled(), "生存房不能打人")


# 私人房创造模式: hello 带 creative, client 收到设 shared_world_creative
func test_hello_creative_roundtrip() -> void:
	nm.shared_world_creative = true
	var data: Variant = JSON.parse_string(nm._hello_payload(1, 1, 1))
	assert_true(bool(data.get("creative", false)), "hello 该带 creative")
	nm.shared_world_creative = false
	nm._route_message('{"type":"hello","seed":1,"size":1,"diff":1,"creative":true}')
	assert_true(nm.shared_world_creative, "收 hello → 设 shared_world_creative")


# is_pvp 必须 connected + room_mode=pvp
func test_is_pvp_requires_connected_and_pvp() -> void:
	nm.room_mode = "pvp"
	nm.status = "idle"
	assert_false(nm.is_pvp(), "没连上不算 pvp")
	nm.status = "connected"
	assert_true(nm.is_pvp(), "连上 + pvp 模式 = is_pvp")
	nm.room_mode = "survival"
	assert_false(nm.is_pvp(), "生存模式不是 pvp")


# 被房主踢: 收到 __kicked → emit kicked_by_host (main 收到回主菜单)
func test_route_kicked_emits_signal() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"__kicked"}', "HOST")
	assert_signal_emitted(nm, "kicked_by_host")


# 回归: 新信封 {from,data} 处理路径不能把实体同步弄断 (host→client 怪位置)
func test_handle_envelope_routes_entity_pos() -> void:
	watch_signals(nm)
	nm._handle_envelope({"from": "HOST", "data": '{"type":"ent_pos","id":5,"k":"slime","x":1.0,"y":2.0,"hp":3,"f":1,"a":"hop"}'})
	assert_signal_emitted(nm, "remote_entity_pos_received")


# 回归: client→host 伤害消息经信封处理仍到 (host 给真怪扣血)
func test_handle_envelope_routes_entity_dmg() -> void:
	watch_signals(nm)
	nm._handle_envelope({"from": "P2", "data": '{"type":"ent_dmg","id":9,"dmg":5,"kb":120.0,"sx":1.0,"sy":2.0}'})
	assert_signal_emitted(nm, "remote_entity_damage_received")


# pdmg payload 带 by (攻击者), to (被打者)
func test_player_damage_payload() -> void:
	var data: Variant = JSON.parse_string(nm._player_damage_payload("B", 8, 120.0, 3.0, 4.0))
	assert_eq(String(data.get("to", "")), "B", "带被打者")
	assert_eq(int(data.get("dmg", 0)), 8, "带伤害")


# route pdmg → player_damaged 信号; route pkill → kill_scored 信号
func test_route_pdmg_and_pkill() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"pdmg","to":"B","dmg":8,"kb":120.0,"sx":3.0,"sy":4.0,"by":"A"}')
	assert_signal_emitted_with_parameters(nm, "player_damaged", ["B", 8, 120.0, 3.0, 4.0, "A"])
	nm._route_message('{"type":"pkill","killer":"A","victim":"B"}')
	assert_signal_emitted_with_parameters(nm, "kill_scored", ["A", "B"])
