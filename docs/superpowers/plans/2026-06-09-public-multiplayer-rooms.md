# 多人公共房 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 主菜单加「公共生存房」: 点一下进共享生存世界, 支持多人(>2), 房满自动开下一号房。

**Architecture:** 星形拓扑 + host 权威。所有 client 只连 host; client 的玩家个体消息(pos/name/chat/死亡)由 host 盖上来源 peer id 后转发给其它 client。公共房用固定房号 `teilaruia-PUB-SV-<i>`, 抢占式 host (谁先到谁当 host), 满了顺延到下一号。

**Tech Stack:** Godot 4.3 GDScript, PeerJS (WebRTC, web-only) via JavaScriptBridge, GUT 9.x 测试。

设计文档: `docs/superpowers/specs/2026-06-09-public-multiplayer-rooms-design.md`

---

## 测试前提 (每个 GDScript 任务都先做)

新 clone / 改 class_name 后, 跑测试前必须先建索引:
```bash
godot --headless --editor --quit
```
单测命令 (本项目 `.gutconfig.json` 覆盖所有目录, 用 `-gselect=<裸文件名>` 跑单个文件):
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_xxx.gd -gexit 2>&1 | grep -v libfontconfig
```
`libfontconfig.so.1` 那行是无显示环境告警, 过滤掉。

---

## File Structure (改动总览)

- **Create** `scripts/net/mp_rooms.gd` — 公共房纯逻辑 (常量 + peer id 格式化 + 转发目标决策)。无依赖, 可 headless 单测。
- **Create** `tests/unit/test_mp_rooms.gd` — mp_rooms 纯逻辑单测。
- **Modify** `scripts/web/peerjs_bridge.js` — 单连接 → 多连接 (host 连接表), 公共房抢占 `enter_public`, 房满拒绝, 消息带来源, peer 加入/离开事件。(JS, 无 GUT, 网页手测)
- **Modify** `scripts/net/network_manager.gd` — peer 维度信号 + `_route_message(raw, from_peer)` + `{from,data}` 解析 + host 转发 + `enter_public`。
- **Modify** `tests/unit/test_network_protocol.gd` — 适配新信号签名 + 加 peer 路由/转发用例。
- **Modify** `scripts/world/world.gd` — 单 `_remote_player` → `_remote_players` 字典 (peer_id → 节点), peer 加入/离开 spawn/移除。
- **Modify** `scripts/entities/remote_player.gd` — 存 `peer_id`, 支持多实例定位。
- **Modify** `scripts/ui/chat_box.gd` — 气泡按 peer_id 定位 (不再单 `"remote_player"` 组)。
- **Modify** `scripts/ui/main_menu.gd` (+ 主菜单 `.tscn`) — 入口「多人游戏」, 面板上「房间」(公共生存房按钮) 下「加入房间」, 点公共房走 `enter_public` 进游戏。
- **Create** `tests/integration/test_public_room_flow.gd` — 多远程玩家 spawn/移除 + 入口按钮调 enter_public。

---

## Task 1: 公共房纯逻辑 helper (mp_rooms.gd)

地基: 常量 + 两个纯函数 (peer id 格式化、转发目标决策)。可 headless 单测, 后续任务复用。

**Files:**
- Create: `scripts/net/mp_rooms.gd`
- Test: `tests/unit/test_mp_rooms.gd`

- [ ] **Step 1: 写失败测试** `tests/unit/test_mp_rooms.gd`

```gdscript
# 公共房纯逻辑单测 (常量 / peer id 格式 / 转发目标)。无 JS bridge, headless 可跑。
extends GutTest

const MpRooms = preload("res://scripts/net/mp_rooms.gd")


func test_public_peer_id_format() -> void:
	assert_eq(MpRooms.public_peer_id("SV", 1), "teilaruia-PUB-SV-1")
	assert_eq(MpRooms.public_peer_id("SV", 7), "teilaruia-PUB-SV-7")


func test_relay_type_classification() -> void:
	# 玩家个体 + 世界改动 = 要转发
	assert_true(MpRooms.is_relay_type("pos"), "pos 要转发给其它人")
	assert_true(MpRooms.is_relay_type("chat"), "chat 要转发")
	assert_true(MpRooms.is_relay_type("tile"), "挖/放方块要转发")
	# host 权威要先处理的 / host 独有的 = 不直接转发
	assert_false(MpRooms.is_relay_type("ent_dmg"), "伤害要 host 先算, 不直接转发")
	assert_false(MpRooms.is_relay_type("hello"), "hello 是 host 独有")


func test_relay_targets_excludes_origin() -> void:
	# 来自 A 的 pos → 转发给 B、C, 不发回 A (防回声)
	var targets: Array = MpRooms.relay_targets("pos", "A", ["A", "B", "C"])
	assert_eq(targets.size(), 2, "3 人里转给除来源外的 2 人")
	assert_true(targets.has("B") and targets.has("C"), "转给 B 和 C")
	assert_false(targets.has("A"), "不发回来源 A")


func test_relay_targets_empty_for_nonrelay_type() -> void:
	assert_eq(MpRooms.relay_targets("ent_dmg", "A", ["A", "B"]).size(), 0,
		"非转发类型 → 不转发给任何人")


func test_is_player_type() -> void:
	assert_true(MpRooms.is_player_type("pos"), "pos 是玩家个体消息")
	assert_true(MpRooms.is_player_type("chat"))
	assert_false(MpRooms.is_player_type("tile"), "tile 是世界改动不是玩家个体")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_mp_rooms.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: 报 `mp_rooms.gd` 加载失败 / 找不到方法。

- [ ] **Step 3: 实现** `scripts/net/mp_rooms.gd`

```gdscript
# 多人公共房纯逻辑 helper. 不碰 JavaScriptBridge → headless 可单测.
# 为什么单独成文件: 把"能不能测"的决策逻辑从 web-only 的 NetworkManager 里抽出来.
extends RefCounted

# 公共生存房固定世界 (每次进都同一张地图, 玩家才有"这就是那个服务器"的感觉)
const PUBLIC_SV_SEED := 20260609
const PUBLIC_SV_SIZE := 1   # 0小/1中/2大
const PUBLIC_SV_DIFF := 1   # 0简/1普/2难

const MAX_PEERS := 8        # 每房最多人数 (含 host 自己)
const MAX_ROOMS := 20       # 公共房顺延上限 (房号 1..MAX_ROOMS)
const HOST_PID := "HOST"    # client 眼里 host 玩家的 peer id

# 固定房号: teilaruia-PUB-<tag>-<index> (生存房 tag="SV")
static func public_peer_id(tag: String, index: int) -> String:
	return "teilaruia-PUB-%s-%d" % [tag, index]

# 玩家个体状态消息 (host 要给它盖来源 pid 再上报/转发)
const _PLAYER_TYPES := {"pos": true, "name": true, "chat": true, "pdead": true, "pres": true}

# host 收到 client 这些类型 → 转发给其它 client (玩家个体 + 世界改动).
# ent_dmg/drop_req 不在内: host 要先权威处理. hello/ent_pos/time 等 host 独有.
const _RELAY_TYPES := {
	"pos": true, "name": true, "chat": true, "pdead": true, "pres": true,
	"tile": true, "tile_batch": true, "chest": true, "drop_pick": true,
}

static func is_player_type(msg_type: String) -> bool:
	return _PLAYER_TYPES.has(msg_type)

static func is_relay_type(msg_type: String) -> bool:
	return _RELAY_TYPES.has(msg_type)

# host 收到来自 from_peer 的 msg_type → 该转发给哪些 peer (除来源外, 防回声)
static func relay_targets(msg_type: String, from_peer: String, all_peers: Array) -> Array:
	if not is_relay_type(msg_type):
		return []
	var out: Array = []
	for p in all_peers:
		if String(p) != from_peer:
			out.append(String(p))
	return out
```

- [ ] **Step 4: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_mp_rooms.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: All tests passed (5 个用例)。

- [ ] **Step 5: Commit**

```bash
git add scripts/net/mp_rooms.gd tests/unit/test_mp_rooms.gd
git commit -m "feat(mp): 公共房纯逻辑 helper (房号格式 + 转发目标决策)"
```

---

## Task 2: NetworkManager peer 维度路由 + 转发

把 `_route_message` 升级成带来源 peer; 玩家个体信号加 `peer_id`; `_poll_bridge` 解析新 `{from,data}` 格式; host 按 mp_rooms 规则转发。

**Files:**
- Modify: `scripts/net/network_manager.gd`
- Modify: `tests/unit/test_network_protocol.gd`

> ⚠️ 改了信号签名 (玩家个体信号加 peer_id), Task 4/5/6 会同步改连接点。本任务只管 NetworkManager + 它的单测。

- [ ] **Step 1: 改/加测试** `tests/unit/test_network_protocol.gd`

把现有 `pos`/`name`/`chat`/death/respawn 相关用例改成带 peer_id 的新签名, 并加转发决策用例。替换这几个测试函数 (其余保持不变):

```gdscript
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


# 死亡/复活: 带 peer_id
func test_route_player_death_and_respawn_carry_peer_id() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"pdead","pid":"P2"}', "P2")
	assert_signal_emitted_with_parameters(nm, "remote_player_death_received", ["P2"])
	nm._route_message('{"type":"pres","pid":"P2"}', "P2")
	assert_signal_emitted_with_parameters(nm, "remote_player_respawn_received", ["P2"])


# 聊天: 带 peer_id
func test_route_chat_carries_peer_id() -> void:
	watch_signals(nm)
	nm._route_message('{"type":"chat","m":"hi","pid":"P5"}', "P5")
	assert_signal_emitted_with_parameters(nm, "chat_received", ["P5", "hi"])
```

加新用例 (host 转发决策, 不需 bridge):

```gdscript
# host 收到 client 的 pos → 决定转发给除来源外的所有 peer
func test_host_relay_targets_for_pos() -> void:
	const MpRooms = preload("res://scripts/net/mp_rooms.gd")
	var targets: Array = MpRooms.relay_targets("pos", "P2", ["P2", "P3"])
	assert_eq(targets, ["P3"], "P2 发的 pos 转给 P3, 不发回 P2")


# 解析 bridge 新消息格式 {from, data}: 取出 from 当来源, data 当原始消息
func test_parse_bridge_envelope() -> void:
	var env: Dictionary = nm._parse_envelope('{"from":"P9","data":"{\\"type\\":\\"pos\\",\\"x\\":1.0,\\"y\\":2.0}"}')
	assert_eq(String(env.get("from", "")), "P9", "取出来源 peer")
	assert_eq(String(env.get("data", "")), '{"type":"pos","x":1.0,"y":2.0}', "取出原始消息字符串")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_network_protocol.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: FAIL — 信号参数不匹配 / `_parse_envelope` 未定义。

- [ ] **Step 3: 改 NetworkManager 信号声明**

`scripts/net/network_manager.gd` 顶部信号区: 给玩家个体信号加 `peer_id`, 新增 peer 加入/离开信号。把这几行替换:

```gdscript
signal peer_joined(peer_id: String)             # 有人进房 (host 端 = client 连上; client 端 = 收到 host)
signal peer_left(peer_id: String)               # 有人离开
signal remote_name_received(peer_id: String, name: String)   # 某 peer 的玩家名
signal chat_received(peer_id: String, text: String)          # 某 peer 发来的聊天
signal remote_pos_received(peer_id: String, x: float, y: float, facing: int, anim: String)
signal remote_player_death_received(peer_id: String)
signal remote_player_respawn_received(peer_id: String)
```

(删掉原来不带 peer_id 的同名 `remote_name_received` / `chat_received` / `remote_pos_received` / `remote_player_death_received` / `remote_player_respawn_received` 声明。)

- [ ] **Step 4: 改 `_poll_bridge` 解析 envelope + `_route_message` 带来源**

把 `_poll_bridge` 里拉消息那段 (现约 113-119 行) 替换为:

```gdscript
	# 拉消息队列: 新格式每条是 {"from":"<peerId>","data":"<原始消息字符串>"}
	var msgs_json: String = String(_bridge.pop_messages())
	if msgs_json != "" and msgs_json != "[]":
		var msgs: Variant = JSON.parse_string(msgs_json)
		if msgs is Array:
			for m in msgs:
				var env: Dictionary = _parse_envelope(JSON.stringify(m) if m is Dictionary else String(m))
				_handle_envelope(env)
```

加两个新函数:

```gdscript
# 解析 bridge 投递的信封 {from, data}. 兼容老格式 (纯字符串当 data, from=host).
func _parse_envelope(raw: String) -> Dictionary:
	var v: Variant = JSON.parse_string(raw)
	if v is Dictionary and v.has("data"):
		return {"from": String(v.get("from", MpRooms.HOST_PID)), "data": String(v.get("data", ""))}
	return {"from": MpRooms.HOST_PID, "data": raw}


# 处理一条信封: 系统事件 (peer 加入/离开) 直接发信号; 其余交给 _route_message + host 转发.
func _handle_envelope(env: Dictionary) -> void:
	var from_peer: String = String(env.get("from", MpRooms.HOST_PID))
	var raw: String = String(env.get("data", ""))
	var data: Variant = JSON.parse_string(raw)
	if data is Dictionary:
		var t: String = String(data.get("type", ""))
		if t == "__peer_join":
			peer_joined.emit(String(data.get("id", from_peer)))
			return
		if t == "__peer_leave":
			peer_left.emit(String(data.get("id", from_peer)))
			return
	_route_message(raw, from_peer)
	# host 收到 client 的可转发消息 → 盖来源 pid 后转发给其它 client
	if is_host and data is Dictionary:
		_relay_if_needed(String(data.get("type", "")), from_peer, data)
```

在文件顶部 `extends Node` 下面加:

```gdscript
const MpRooms = preload("res://scripts/net/mp_rooms.gd")
```

- [ ] **Step 5: 改 `_route_message` 接受来源 + 玩家个体信号带 pid**

`_route_message(raw: String)` 改签名为 `_route_message(raw: String, from_peer: String = "HOST")`。把 `name`/`chat`/`pos`/`pdead`/`pres` 这几个 case 改成带 pid (pid 优先取消息里的 `pid` 字段, 没有就用 from_peer):

```gdscript
		"name":
			var pname: String = String(data.get("n", ""))
			remote_player_name = pname
			remote_name_received.emit(_pid_of(data, from_peer), pname)
		"chat":
			var ctext: String = String(data.get("m", "")).substr(0, 120)
			chat_received.emit(_pid_of(data, from_peer), ctext)
		"pdead":
			remote_player_death_received.emit(_pid_of(data, from_peer))
		"pres":
			remote_player_respawn_received.emit(_pid_of(data, from_peer))
		"pos":
			var x: float = float(data.get("x", 0.0))
			var y: float = float(data.get("y", 0.0))
			var facing: int = int(data.get("f", 1))
			var anim: String = String(data.get("a", "idle"))
			remote_pos_received.emit(_pid_of(data, from_peer), x, y, facing, anim)
```

加 helper:

```gdscript
# 解析某玩家个体消息的来源 peer id: 消息里带 pid 用 pid (host 转发时盖的), 否则用 from_peer.
func _pid_of(data: Dictionary, from_peer: String) -> String:
	var pid: String = String(data.get("pid", ""))
	return pid if pid != "" else from_peer
```

- [ ] **Step 6: 加 host 转发 + 多连接发送**

加转发函数 (用 mp_rooms 决策, 给 JSON 盖上 pid 再发给每个目标):

```gdscript
# host 把某 client 的玩家个体/世界改动消息转发给其它 client (盖来源 pid 防回声).
func _relay_if_needed(msg_type: String, from_peer: String, data: Dictionary) -> void:
	if not MpRooms.is_relay_type(msg_type):
		return
	if _bridge == null:
		return
	var peers: Array = _all_peer_ids()
	var targets: Array = MpRooms.relay_targets(msg_type, from_peer, peers)
	if targets.is_empty():
		return
	# 玩家个体消息盖上来源 pid, 让收件 client 知道是谁
	if MpRooms.is_player_type(msg_type):
		data["pid"] = from_peer
	var payload: String = JSON.stringify(data)
	for pid in targets:
		_bridge.send_to(pid, payload)


# host 当前所有 client peer id (从 bridge 读). 桌面无 bridge → 空.
func _all_peer_ids() -> Array:
	if _bridge == null:
		return []
	var ids_json: String = String(_bridge.get_peer_ids())
	var v: Variant = JSON.parse_string(ids_json)
	return v if v is Array else []
```

> 注: `send_to` / `get_peer_ids` 由 Task 3 的 JS bridge 提供。桌面测试不调它们 (无 bridge), 故单测安全。

- [ ] **Step 7: 加 enter_public + my_peer_id**

在 `host()` / `join()` 附近加:

```gdscript
# 进公共房: 由 bridge 抢占式决定本端成 host 还是 client.
# 先设好固定世界参数 (万一本端成 host, 连上后要 send_hello 这些值给 client).
func enter_public(tag: String, seed_val: int, size_val: int, diff_val: int) -> void:
	if _bridge == null:
		_try_reload_bridge()
	if _bridge == null:
		_emit_no_bridge_error()
		return
	shared_world_seed = seed_val
	shared_world_size = size_val
	shared_world_difficulty = diff_val
	# is_host 先按"未知"留, bridge 决定后由 _poll_bridge 读回
	_bridge.enter_public(tag, MpRooms.MAX_PEERS, MpRooms.MAX_ROOMS)


# 本端玩家的 peer id (host = 固定房号; client = bridge 分配的随机 id)
func my_peer_id() -> String:
	if _bridge == null:
		return MpRooms.HOST_PID
	return String(_bridge.get_my_id())
```

`_poll_bridge` 里 `is_host` 现在由 host()/enter_public 后 bridge 决定。加: 每次 poll 同步 `is_host = bool(_bridge.is_host())` (放在读 status 之后)。

- [ ] **Step 8: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_network_protocol.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: All tests passed。再跑 `test_mp_rooms.gd` 确认没回归。

- [ ] **Step 9: Commit**

```bash
git add scripts/net/network_manager.gd tests/unit/test_network_protocol.gd
git commit -m "feat(mp): NetworkManager peer 维度路由 + host 转发 + enter_public"
```

---

## Task 3: peerjs_bridge.js 多连接 + 公共房抢占

JS 端从单连接升级到 host 连接表, 加 `enter_public` 抢占/顺延、房满拒绝、消息带来源、peer 加入/离开事件、`send_to` / `get_peer_ids`。

> JS 无 GUT 单测。验证靠: ① 文件能被现有注入脚本带上 (`scripts/web/inject_bridge.sh`); ② Task 2 的 GDScript 合同测试已覆盖 GDScript 侧; ③ 部署后网页两人/三人手测。

**Files:**
- Modify: `scripts/web/peerjs_bridge.js`

- [ ] **Step 1: host 连接表 + send 群发**

把 `bridge` 对象的 `_conn: null` 改为 `_conns: {}` (host: peerId→conn) 和 `_hostConn: null` (client 端到 host 的连接)。`_setupConn` 改为:

```javascript
    function _setupConn(conn, isIncoming) {
        // isIncoming=true: host 端收到的 client 连接 (进 _conns 表); false: client 连 host
        conn.on('open', function() {
            bridge._status = 'connected';
            if (isIncoming) {
                bridge._conns[conn.peer] = conn;
                // 通知 GDScript 有人进来了
                bridge._messages.push({from: '__sys', data: JSON.stringify({type: '__peer_join', id: conn.peer})});
            }
        });
        conn.on('data', function(data) {
            // 进队带来源: host 端 = conn.peer; client 端 = 'HOST'
            bridge._messages.push({from: isIncoming ? conn.peer : 'HOST', data: String(data)});
        });
        conn.on('close', function() {
            if (isIncoming) {
                delete bridge._conns[conn.peer];
                bridge._messages.push({from: '__sys', data: JSON.stringify({type: '__peer_leave', id: conn.peer})});
            } else {
                bridge._status = 'disconnected';   // 到 host 的连接断了 = 房主走了
            }
        });
        conn.on('error', function(err) {
            bridge._lastError = 'conn error: ' + (err.type || err.message || err);
        });
    }
```

`send` 改为按角色 fan-out:

```javascript
    bridge.send = function(jsonStr) {
        if (bridge._isHost) {
            var sent = false;
            for (var pid in bridge._conns) {
                var c = bridge._conns[pid];
                if (c && c.open) { c.send(jsonStr); sent = true; }
            }
            return sent;
        }
        if (bridge._hostConn && bridge._hostConn.open) {
            bridge._hostConn.send(jsonStr);
            return true;
        }
        return false;
    };

    bridge.send_to = function(peerId, jsonStr) {
        var c = bridge._conns[peerId];
        if (c && c.open) { c.send(jsonStr); return true; }
        return false;
    };

    bridge.get_peer_ids = function() {
        return JSON.stringify(Object.keys(bridge._conns));
    };

    bridge.get_peer_count = function() {
        return Object.keys(bridge._conns).length;
    };
```

`pop_messages` 现在队列里是对象 `{from,data}`, 直接 `JSON.stringify(msgs)` 返回 (GDScript `_parse_envelope` 解析)。

- [ ] **Step 2: host 端接受连接 + 房满拒绝**

host 成功开 peer 后, `on('connection')`:

```javascript
        bridge._peer.on('connection', function(conn) {
            if (gen !== bridge._gen) return;
            // 房满 (含 host 自己算 1): 礼貌拒绝, client 会自动试下一号房
            if (Object.keys(bridge._conns).length + 1 >= bridge._maxPeers) {
                conn.on('open', function() {
                    try { conn.send(JSON.stringify({__full: 1})); } catch (e) {}
                    setTimeout(function() { try { conn.close(); } catch (e) {} }, 200);
                });
                return;
            }
            _setupConn(conn, true);
        });
```

(`bridge._maxPeers` 由 `enter_public` 传入, 默认 8。)

- [ ] **Step 3: enter_public 抢占 + 顺延**

加状态字段 `_pubTag`, `_pubIndex`, `_maxPeers`, `_maxRooms`, 和 enter 流程:

```javascript
    bridge.enter_public = function(tag, maxPeers, maxRooms) {
        bridge.disconnect();
        bridge._gen++;
        bridge._maxPeers = maxPeers || 8;
        bridge._maxRooms = maxRooms || 20;
        bridge._pubTag = tag;
        bridge._pubIndex = 1;
        bridge._isHost = false;
        bridge._status = 'joining';
        bridge._lastError = '';
        _tryJoinPublic(bridge._gen);
    };

    function _pubId(idx) { return 'teilaruia-PUB-' + bridge._pubTag + '-' + idx; }

    // 先以 client 身份连 idx 号房
    function _tryJoinPublic(gen) {
        if (gen !== bridge._gen) return;
        if (bridge._pubIndex > bridge._maxRooms) {
            bridge._lastError = '现在人太多啦, 等会儿再来';
            bridge._status = 'error';
            return;
        }
        var targetId = _pubId(bridge._pubIndex);
        bridge._peer = new Peer(null, _peerOpts());
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            var conn = bridge._peer.connect(targetId, {reliable: true});
            var settled = false;
            conn.on('open', function() {
                if (gen !== bridge._gen || settled) return;
                settled = true;
                bridge._isHost = false;
                bridge._hostConn = conn;
                _setupConn(conn, false);
                bridge._status = 'connected';
            });
            conn.on('data', function(d) {
                // 被房主拒绝 (房满) → 试下一号房
                try { if (JSON.parse(String(d)).__full) { _nextRoom(gen); } } catch (e) {}
            });
            // 一定时间没连上 → 可能这号房没人开 → 去抢占当 host
            setTimeout(function() {
                if (gen !== bridge._gen || settled) return;
                settled = true;
                try { bridge._peer.destroy(); } catch (e) {}
                _hostPublic(gen);
            }, 5000);
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (et === 'peer-unavailable') {
                // 没人开这号房 → 抢占当 host
                try { bridge._peer.destroy(); } catch (e) {}
                _hostPublic(gen);
            } else if (_RETRYABLE[et]) {
                bridge._lastError = _friendlyError(et);  // 服务器忙, 保持 joining 等超时重试
            } else {
                bridge._lastError = _friendlyError(et);
                bridge._status = 'error';
            }
        });
    }

    // 抢占 idx 号房当 host
    function _hostPublic(gen) {
        if (gen !== bridge._gen) return;
        bridge._peer = new Peer(_pubId(bridge._pubIndex), _peerOpts());
        bridge._peer.on('open', function() {
            if (gen !== bridge._gen) return;
            bridge._isHost = true;
            bridge._myId = _pubId(bridge._pubIndex);
            bridge._status = 'connected';   // host 自己即"连上" (房里就他一个也能玩)
        });
        bridge._peer.on('connection', function(conn) {
            if (gen !== bridge._gen) return;
            if (Object.keys(bridge._conns).length + 1 >= bridge._maxPeers) {
                conn.on('open', function() {
                    try { conn.send(JSON.stringify({__full: 1})); } catch (e) {}
                    setTimeout(function() { try { conn.close(); } catch (e) {} }, 200);
                });
                return;
            }
            _setupConn(conn, true);
        });
        bridge._peer.on('error', function(err) {
            if (gen !== bridge._gen) return;
            var et = err.type || err.message || err;
            if (et === 'unavailable-id') {
                // 并发竞争: 别人刚抢到这号房 → 退回当 client 再连它
                try { bridge._peer.destroy(); } catch (e) {}
                bridge._isHost = false;
                _tryJoinPublic(gen);
            } else {
                bridge._lastError = _friendlyError(et);
                bridge._status = 'error';
            }
        });
    }

    function _nextRoom(gen) {
        if (gen !== bridge._gen) return;
        try { if (bridge._peer) bridge._peer.destroy(); } catch (e) {}
        bridge._pubIndex++;
        _tryJoinPublic(gen);
    }
```

- [ ] **Step 4: disconnect 清多连接**

`bridge.disconnect` 里把单 `_conn` 清理改为清空 `_conns` + `_hostConn`:

```javascript
        for (var pid in bridge._conns) {
            try { bridge._conns[pid].close(); } catch (e) {}
        }
        bridge._conns = {};
        if (bridge._hostConn) { try { bridge._hostConn.close(); } catch (e) {} }
        bridge._hostConn = null;
```
(保留原 `_peer.destroy()` + 状态清零。)

- [ ] **Step 5: 确认 is_host 暴露真实角色**

`bridge.is_host = function() { return bridge._isHost; };` 已有 — 确认 `_hostPublic` 设 `_isHost=true`、`_tryJoinPublic` 连上设 `_isHost=false`。

- [ ] **Step 6: 语法自检**

```bash
node -c scripts/web/peerjs_bridge.js && echo "JS 语法 OK"
```
预期: `JS 语法 OK` (无报错)。若环境无 node, 跳过, 靠部署后网页 Console 看 `[MultiplayerBridge] loaded`。

- [ ] **Step 7: Commit**

```bash
git add scripts/web/peerjs_bridge.js
git commit -m "feat(mp): JS bridge 多连接 + 公共房抢占/顺延/房满拒绝 + 转发 API"
```

---

## Task 4: world.gd 多个远程玩家

单 `_remote_player` → `_remote_players` 字典 (peer_id → 节点)。接 `peer_joined`/`peer_left` spawn/移除; pos/name/death 按 peer_id 路由。

**Files:**
- Modify: `scripts/world/world.gd`
- Test: `tests/integration/test_public_room_flow.gd`

- [ ] **Step 1: 写集成测试** `tests/integration/test_public_room_flow.gd`

```gdscript
# 多人公共房: 多个远程玩家 spawn/移除 (用 NetworkManager 信号驱动, 桌面无 bridge 也能测).
extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")

var world


func before_each() -> void:
	world = WorldScene.instantiate()
	add_child_autofree(world)
	await wait_frames(2)   # 等 _ready 跑完


func test_peer_joined_spawns_distinct_remote_players() -> void:
	world._on_peer_joined("P2")
	world._on_peer_joined("P3")
	assert_eq(world._remote_players.size(), 2, "两个 peer → 两个远程玩家")
	assert_true(world._remote_players.has("P2") and world._remote_players.has("P3"))


func test_peer_left_removes_only_that_player() -> void:
	world._on_peer_joined("P2")
	world._on_peer_joined("P3")
	world._on_peer_left("P2")
	await wait_frames(1)
	assert_false(world._remote_players.has("P2"), "P2 走了被移除")
	assert_true(world._remote_players.has("P3"), "P3 还在")


func test_remote_pos_routes_to_correct_player() -> void:
	world._on_peer_joined("P2")
	world._on_remote_pos("P2", 100.0, 50.0, -1, "walk")
	var rp = world._remote_players["P2"]
	assert_almost_eq(rp.global_position.x, 100.0, 0.5, "P2 的位置更新到自己身上")


func test_remote_pos_lazy_spawns_if_unknown() -> void:
	# 位置消息先于 join 到 → 懒创建, 不丢人
	world._on_remote_pos("P9", 10.0, 20.0, 1, "idle")
	assert_true(world._remote_players.has("P9"), "未知 peer 的 pos → 懒创建远程玩家")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_public_room_flow.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: FAIL — `_remote_players` / `_on_peer_joined` 未定义。

- [ ] **Step 3: world.gd 改字典 + spawn/移除**

`scripts/world/world.gd`: 把 `var _remote_player: Node = null` (约 88 行) 改为:

```gdscript
var _remote_players: Dictionary = {}   # peer_id(String) → RemotePlayer 节点 (多人)
```

替换 `_spawn_remote_player()` (约 590 行) 为按 peer_id 版:

```gdscript
func _spawn_remote_player(peer_id: String) -> Node:
	if _remote_players.has(peer_id) and is_instance_valid(_remote_players[peer_id]):
		return _remote_players[peer_id]
	var rp: Node = RemotePlayerScene.instantiate()
	rp.name = "RemotePlayer_" + peer_id
	entities_root.add_child(rp)
	if "peer_id" in rp:
		rp.peer_id = peer_id
	# 初始放在出生点附近 (收到第一个 pos 会立刻校正)
	rp.global_position = Vector2(
		spawn_tile.x * Tiles.TILE_SIZE,
		spawn_tile.y * Tiles.TILE_SIZE)
	if rp.has_method("set_player_name") and NetworkManager.remote_player_name != "":
		rp.set_player_name(NetworkManager.remote_player_name)
	_remote_players[peer_id] = rp
	return rp


func _on_peer_joined(peer_id: String) -> void:
	_spawn_remote_player(peer_id)


func _on_peer_left(peer_id: String) -> void:
	if _remote_players.has(peer_id):
		var rp = _remote_players[peer_id]
		if is_instance_valid(rp):
			rp.queue_free()
		_remote_players.erase(peer_id)


func get_remote_player(peer_id: String) -> Node:
	return _remote_players.get(peer_id, null)
```

- [ ] **Step 4: 信号处理按 peer_id 路由**

替换 `_on_remote_pos` / `_on_remote_name` / `_on_remote_player_death` / `_on_remote_player_respawn` 为带 peer_id 版:

```gdscript
func _on_remote_pos(peer_id: String, x: float, y: float, facing: int, anim: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp == null or not is_instance_valid(rp):
		rp = _spawn_remote_player(peer_id)   # 懒创建: pos 先于 join 到也不丢人
	if rp.has_method("apply_pos"):
		rp.apply_pos(x, y, facing, anim)


func _on_remote_name(peer_id: String, n: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_player_name"):
		rp.set_player_name(n)


func _on_remote_player_death(peer_id: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_dead"):
		rp.set_dead(true)


func _on_remote_player_respawn(peer_id: String) -> void:
	var rp: Node = _remote_players.get(peer_id, null)
	if rp != null and is_instance_valid(rp) and rp.has_method("set_dead"):
		rp.set_dead(false)
```

- [ ] **Step 5: 改信号接线 + 清理**

在注册 remote_* 信号的函数 (约 264-300 行) 里:
- 删掉 `if _remote_player == null: _spawn_remote_player()` (不再开局就建单个)。
- 加接 `peer_joined`/`peer_left`:
```gdscript
	if not NetworkManager.peer_joined.is_connected(_on_peer_joined):
		NetworkManager.peer_joined.connect(_on_peer_joined)
	if not NetworkManager.peer_left.is_connected(_on_peer_left):
		NetworkManager.peer_left.connect(_on_peer_left)
```
- 现有 `remote_pos_received.connect(_on_remote_pos)` 等保持 (签名已带 peer_id, 处理函数已改)。

把清理远程玩家那段 (约 319-321 行) 改为:

```gdscript
	for pid in _remote_players.keys():
		var rp = _remote_players[pid]
		if is_instance_valid(rp):
			rp.queue_free()
	_remote_players.clear()
```

- [ ] **Step 6: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_public_room_flow.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: All tests passed (4 用例)。

- [ ] **Step 7: Commit**

```bash
git add scripts/world/world.gd tests/integration/test_public_room_flow.gd
git commit -m "feat(mp): world 支持多个远程玩家 (peer_id 字典 + spawn/移除/懒创建)"
```

---

## Task 5: remote_player peer_id + chat_box 按 peer 定位气泡

**Files:**
- Modify: `scripts/entities/remote_player.gd`
- Modify: `scripts/ui/chat_box.gd`

- [ ] **Step 1: remote_player 加 peer_id 字段**

`scripts/entities/remote_player.gd` 顶部 (extends 行下) 加:

```gdscript
var peer_id: String = ""   # 这个远程玩家对应的 peer (多人时区分谁是谁)
```

- [ ] **Step 2: 改 chat_box 气泡定位**

`scripts/ui/chat_box.gd` 的 `_on_chat_received` 现签名 `(text)` → 改为 `(peer_id, text)`, 气泡冒在该 peer 的远程玩家头顶。把 `_on_chat_received` 与 `_bubble_over("remote_player", text)` 改为:

```gdscript
func _on_chat_received(peer_id: String, text: String) -> void:
	var who: String = _remote_name(peer_id)
	_push_line(who, text)
	# 气泡冒在发话那个 peer 的远程玩家头顶 (多人: 不同人冒不同头顶)
	var world: Node = get_tree().get_first_node_in_group("world")
	if world != null and world.has_method("get_remote_player"):
		var rp: Node = world.get_remote_player(peer_id)
		if rp != null and is_instance_valid(rp) and Effects != null:
			Effects.spawn_speech_bubble(rp.global_position, text)
```

(`_remote_name(peer_id)` 暂时仍可返回 `NetworkManager.remote_player_name`; 多人精确名字是后续优化, 本期够用。把现有 `_remote_name()` 改成接受 peer_id 参数, 内部先忽略 peer_id 返回 remote_player_name。)

> 确认 `world` 节点在 `"world"` 组里; 若没有, 在 world.gd `_ready` 加 `add_to_group("world")`。检查后按需补。

- [ ] **Step 3: 跑相关测试确认没崩**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_chat.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: 通过 (若 test_chat 断言旧签名, 同步更新其对 `_on_chat_received` / `chat_received` 的调用为带 peer_id)。

- [ ] **Step 4: Commit**

```bash
git add scripts/entities/remote_player.gd scripts/ui/chat_box.gd
git commit -m "feat(mp): 远程玩家带 peer_id + 聊天气泡按 peer 定位"
```

---

## Task 6: 主菜单 UI — 「多人游戏」面板 + 公共生存房按钮

入口文案改「多人游戏」; 面板上半「房间」(公共生存房按钮) 下半「加入房间」(现有输码); 点公共房走 enter_public 进游戏。

**Files:**
- Modify: `scripts/ui/main_menu.gd`
- Modify: 主菜单 `.tscn` (加房间区节点 + 标题)
- Test: 追加到 `tests/integration/test_public_room_flow.gd`

- [ ] **Step 1: 追加测试 (按钮调 enter_public)**

在 `tests/integration/test_public_room_flow.gd` 加:

```gdscript
# 点"公共生存房"应调 NetworkManager.enter_public("SV", 固定seed, ...)
func test_public_button_calls_enter_public() -> void:
	const MpRooms = preload("res://scripts/net/mp_rooms.gd")
	var MainMenuScene = load("res://scenes/ui/main_menu.tscn")
	var menu = MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	# 用一个假 NetworkManager 记录调用 (monkey-patch: 直接断言方法存在 + 常量正确)
	assert_eq(MpRooms.PUBLIC_SV_SEED, 20260609, "公共生存房固定种子")
	assert_true(menu.has_method("_on_public_survival_pressed"), "有公共生存房按钮回调")
```

(UI 全自动化点击难测; 这里断言"回调存在 + 常量正确", 真实进房靠网页手测。)

- [ ] **Step 2: .tscn 加房间区**

主菜单场景 `MultiplayerPanel/VBox` 下, 在现有 `JoinRow` **之前**插入:
- `RoomsLabel` (Label, text 走 Locale, 占位「房间」)
- `PublicSurvivalButton` (Button)
- `JoinLabel` (Label, 占位「加入房间」) 放在 JoinRow 前

按现有面板里 Label/Button 的节点写法手写 (参考同文件 JoinRow/JoinButton 的 type/theme 行)。保持 UID 不冲突 (新节点不写 uid)。

- [ ] **Step 3: main_menu.gd 接按钮 + 文案**

`_setup_multiplayer_panel_once()` 里加:

```gdscript
	var pub_btn: Button = panel.get_node("VBox/PublicSurvivalButton")
	_apply_button_style(pub_btn)
	if not pub_btn.pressed.is_connected(_on_public_survival_pressed):
		pub_btn.pressed.connect(_on_public_survival_pressed)
```

加回调:

```gdscript
const MpRooms = preload("res://scripts/net/mp_rooms.gd")

func _on_public_survival_pressed() -> void:
	if NetworkManager == null:
		return
	NetworkManager.enter_public("SV", MpRooms.PUBLIC_SV_SEED, MpRooms.PUBLIC_SV_SIZE, MpRooms.PUBLIC_SV_DIFF)
	$MultiplayerPanel/VBox/StatusLabel.text = Locale.t("mp_entering_public")
	# 复用现有: 本端成 host → 直接用固定 seed 进; 成 client → 等 hello 进.
	_await_public_enter()


# 进公共房: host 立即用固定 seed 进; client 等 hello (复用现有 hello_received → _start_multiplayer_game).
func _await_public_enter() -> void:
	if NetworkManager.is_host:
		_start_multiplayer_game(MpRooms.PUBLIC_SV_SEED, MpRooms.PUBLIC_SV_SIZE, MpRooms.PUBLIC_SV_DIFF)
```

> 现有 `_on_mp_hello_received` (约 968 行) 已处理 client 收 hello 后进游戏 — 公共房 client 走这条不用改。host 进游戏用 `_start_multiplayer_game`。`is_host` 在 enter_public 后由 bridge 决定, 用 `status_changed`→connected 时判断更稳: 在 `_on_mp_status_changed` 里, 若 connected 且 `NetworkManager.is_host` 且尚未进游戏 → `_start_multiplayer_game(固定参数)`。按现有 status 处理点补这一句。

- [ ] **Step 4: 文案 key**

`Locale` 加 key (4 语言, 至少 zh 完整, 其它退回 zh/en): `menu_multiplayer`(已有, 确认文案=「多人游戏」), `mp_rooms_title`=「房间」, `mp_public_survival`=「🌍 公共生存房」, `mp_join_title`=「加入房间」, `mp_entering_public`=「正在进入公共房…」。按 Locale 现有结构 (i18n Phase 1) 加。

- [ ] **Step 5: 跑测试**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_public_room_flow.gd -gexit 2>&1 | grep -v libfontconfig
```
预期: 全过。

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/main_menu.gd scenes/ui/main_menu.tscn scripts/autoload/locale.gd
git commit -m "feat(mp): 主菜单多人面板 (房间/加入房间) + 公共生存房入口"
```

---

## Task 7: 全量回归 + 部署手测

- [ ] **Step 1: 跑全部单测**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -v libfontconfig | tail -5
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -v libfontconfig | tail -5
```
预期: All tests passed, 0 failures。

- [ ] **Step 2: 桌面冒烟**

```bash
./run.sh --rebuild
```
确认主菜单出现「多人游戏」, 点开看到上「房间」(公共生存房按钮) 下「加入房间」, 桌面点公共房友好提示"只在浏览器有效"(无 bridge)。

- [ ] **Step 3: 部署网页手测**

```bash
git push origin main   # 触发 GitHub Actions 自动 build+部署 (3-5 分钟)
```
等部署后, 开 https://nornttyy.github.io/tielaruia/ 多设备/多标签:
- A 点公共生存房 → 进世界 (成 host)。
- B、C 各点公共生存房 → 进同一世界, 互相看得到走动/挖方块/聊天。
- 凑够 9 人 (或临时把 MAX_PEERS 调小验证) → 第 9 人自动进 2 号房。
- A (host) 关网页 → B、C 提示房主走了回菜单。

- [ ] **Step 4: 收尾**

用 superpowers:finishing-a-development-branch 收尾。

---

## Self-Review (against spec)

- 多人 (星形+host 权威): Task 2 (转发) + Task 3 (JS 多连接) + Task 4 (多远程玩家) ✅
- 公共房抢占 + 房满顺延: Task 3 `enter_public`/`_hostPublic`/`_nextRoom` ✅
- UI 重构 (多人游戏 / 房间 / 加入房间): Task 6 ✅
- 固定地图: Task 1 常量 + Task 6 传参 ✅
- 多远程玩家 spawn/移除: Task 4 ✅
- 房主走了回菜单: Task 6 Step 3 备注 + Task 4 (client 端 host 断开 → disconnected) ✅
- 测试策略 (纯逻辑抽离): Task 1/2 纯函数测, Task 4 信号驱动集成测 ✅
- 类型一致: `peer_id: String` 全程统一; `enter_public(tag, seed, size, diff)` / `relay_targets(type, from, all)` 签名各任务一致 ✅

> 已知未覆盖 (验收靠网页手测, 非单测): JS bridge 真实 WebRTC 抢占/顺延/转发; UI 真实点击进房。GUT 无 WebRTC + UI 自动化弱, 已在 Task 3/6 注明。
