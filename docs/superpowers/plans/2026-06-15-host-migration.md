# Host 迁移实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 公共生存房房主掉线时，自动让最早进房的幸存客户端接力当新房主，其他人重连，几秒内恢复同一局。

**Architecture:** 房主活着时给每个客户端单独发一个"接班号 rank"（0=最早进的）。房主一掉，每个客户端按 `rank × STAGGER` 错峰后**重跑公共房进房流程到原房号**（复用桥现成的"先试加入、没人就当房主"逻辑）：rank 0 先到→抢到房号当新房主；其余晚到→加入它。rank 0 也掉了→rank 1 到点房号还空→自动顶上（级联）。重连后 world 每帧的 `is_host` 门控让新房主自动开始刷怪+广播，老的状态接管几乎免费。

**Tech Stack:** Godot 4.3 + GDScript；WebRTC P2P（PeerJS）；GUT 9.x 单测；纯逻辑抽到 RefCounted 类可 headless 测，联机时序只能真机测。

**与 spec 的差异（已确认等价）：** spec 写"广播有序名单"，本计划落地为"房主给每个客户端发各自的 rank"（send_to 单播），实现同样的"待最久接班 + 错峰"行为，但不需要客户端在名单里认自己 → 不动 peer-id 身份逻辑，风险更低。

**测试现实：** 沙盒无法跑联机（单机 + 无 GUI）。能单测的只有纯逻辑（接班号维护 / 等待时长计算），抽到 `HostSuccession` 类用 GUT 测。桥接 / world 的联机胶水代码只能：① `godot --headless --editor --quit` 过解析 ② 用户多设备真机测。每个联机任务的"验收"写明真机测步骤。

---

## 文件结构

| 文件 | 动作 | 职责 |
|---|---|---|
| `scripts/net/host_succession.gd` | 新建 | 纯逻辑：房主侧维护"客户端加入顺序"，算每个 pid 的 rank + 等待时长。RefCounted，可单测。 |
| `tests/unit/test_host_succession.gd` | 新建 | HostSuccession 的 GUT 单测。 |
| `scripts/web/peerjs_bridge.js` | 改 | 加 `reenter_public()`：保留当前房号 index 重进公共房（不重置回 1 号房）。 |
| `scripts/net/network_manager.gd` | 改 | 房主侧用 HostSuccession 给每个 client 发 rank；客户端收 rank 存 `my_succession_rank`；加 `reenter_public_for_migration()`。 |
| `scripts/world/world.gd` | 改 | 房主掉线检测 → 启动迁移；错峰重进；「正在换房主…」遮罩；只剩一人转单机兜底。 |

`HostSuccession`（房主用）和"客户端只存自己 rank"分开 → 各自单一职责、互不依赖。

---

## 常量约定（贯穿全计划）

- `STAGGER = 3.0`（秒）：错峰间隔。> 一个客户端"抢房号当上 host"的耗时（约 1~1.5s，含桥的一次 `_flipPublic` 退避），保证 rank 0 先抢到、晚到的人加入而非也去抢。可调。
- 新消息类型 `"succ"`：房主 → 单个客户端，`{"type":"succ","r":<int rank>}`。不转发（host→client 直发）。
- `MIGRATING` 状态标志：防迁移流程里 `disconnected` 信号再次触发迁移（重入）。

---

## Task 1: HostSuccession 纯逻辑类（可单测）

**Files:**
- Create: `scripts/net/host_succession.gd`
- Test: `tests/unit/test_host_succession.gd`

房主侧维护"客户端按加入顺序的列表"，算 rank（第几个进的，0 起）和"该 peer 掉线后该等多久再重进"。纯逻辑、不碰 JavaScriptBridge → headless 可测。

- [ ] **Step 1: 写失败测试**

`tests/unit/test_host_succession.gd`:
```gdscript
extends GutTest

const HostSuccession = preload("res://scripts/net/host_succession.gd")

var succ

func before_each() -> void:
	succ = HostSuccession.new()

func test_join_order_preserved() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	assert_eq(succ.ordered(), ["A", "B", "C"], "应按加入顺序")

func test_rank_is_index() -> void:
	succ.on_join("A")
	succ.on_join("B")
	assert_eq(succ.rank_of("A"), 0, "最早进的 rank=0")
	assert_eq(succ.rank_of("B"), 1)
	assert_eq(succ.rank_of("Z"), -1, "没进过的返回 -1")

func test_join_idempotent() -> void:
	succ.on_join("A")
	succ.on_join("A")
	assert_eq(succ.ordered().size(), 1, "重复 join 不重复加")

func test_leave_removes_but_keeps_order() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	succ.on_leave("B")
	assert_eq(succ.ordered(), ["A", "C"], "B 走了, A/C 保持相对顺序")
	assert_eq(succ.rank_of("A"), 0)
	assert_eq(succ.rank_of("C"), 1, "B 走后 C 的 rank 紧凑到 1")

func test_wait_seconds_by_rank() -> void:
	succ.on_join("A")
	succ.on_join("B")
	succ.on_join("C")
	assert_almost_eq(succ.wait_for("A", 3.0), 0.0, 0.001, "rank0 立刻")
	assert_almost_eq(succ.wait_for("B", 3.0), 3.0, 0.001)
	assert_almost_eq(succ.wait_for("C", 3.0), 6.0, 0.001)

func test_wait_for_unknown_waits_after_everyone() -> void:
	succ.on_join("A")
	succ.on_join("B")
	# 不在表里 (名单过期 / 还没分到号) → 排在所有已知接班人之后, 不会 0 秒抢房主
	assert_almost_eq(succ.wait_for("Z", 3.0), 9.0, 0.001, "(size+1)*stagger = 3*3")

func test_clear() -> void:
	succ.on_join("A")
	succ.clear()
	assert_eq(succ.ordered().size(), 0)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_host_succession.gd -gexit`
Expected: FAIL（`host_succession.gd` 不存在 / 方法未定义）。
（若报 `Identifier "GutUtils" not declared`，先跑一次 `godot --headless --editor --quit` 建 class_name 索引，过滤 `libfontconfig` 那行。）

- [ ] **Step 3: 写实现**

`scripts/net/host_succession.gd`:
```gdscript
# 房主侧"接班顺序"纯逻辑. 维护客户端按加入顺序的列表, 算每个 pid 的 rank (第几个进的) +
# 掉线后该等多久再重进 (错峰). 不碰 JavaScriptBridge → headless 可单测.
# 用途: 房主一掉, 各客户端按自己的 rank * STAGGER 错峰重进原房号, rank 小的先抢到当新房主.
extends RefCounted

var _order: Array[String] = []   # 客户端 peer_id, 按加入先后

# 新客户端进房 (host 收到 __peer_join 时调). 已在表里则忽略 (幂等).
func on_join(pid: String) -> void:
	if pid != "" and not _order.has(pid):
		_order.append(pid)

# 客户端离开 (host 收到 __peer_leave 时调).
func on_leave(pid: String) -> void:
	_order.erase(pid)

# 当前加入顺序的副本.
func ordered() -> Array:
	return _order.duplicate()

# 某 pid 是第几个进的 (0 起); 不在表里返回 -1.
func rank_of(pid: String) -> int:
	return _order.find(pid)

# 该 pid 掉线后该等多久再重进 (秒). 在表里 = rank*stagger; 不在表里 = 排到所有人之后 ((size+1)*stagger),
# 防"还没分到接班号的新客户端"0 秒就抢着当房主.
func wait_for(pid: String, stagger: float) -> float:
	var r: int = rank_of(pid)
	if r < 0:
		return float(_order.size() + 1) * stagger
	return float(r) * stagger

func clear() -> void:
	_order.clear()
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_host_succession.gd -gexit`
Expected: PASS（7 passing）。

- [ ] **Step 5: 提交**

```bash
git add scripts/net/host_succession.gd tests/unit/test_host_succession.gd
git commit -m "feat(mp): HostSuccession 接班顺序纯逻辑 + 单测

房主侧维护客户端加入顺序, 算 rank + 错峰等待时长. 为 host 迁移做地基.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

> ⚠️ 提交只 `git add` 这两个文件 — 仓库有不相关 WIP 不能卷入。**禁用** `-am` / `-A` / `.`。

---

## Task 2: NetworkManager 收发接班号（succ）

**Files:**
- Modify: `scripts/net/network_manager.gd`（加成员/信号、`_route_message` 加 `succ` 分支、房主周期发号、客户端存号）

房主用 HostSuccession 跟踪客户端，周期 + 新人进房时给**每个**客户端单播它的 rank。客户端收到存 `my_succession_rank`。

> 无法单测（要 bridge / 联机）。验收靠解析检查 + 真机日志。

- [ ] **Step 1: 加成员与 HostSuccession 实例**

`scripts/net/network_manager.gd`，在 `var _poll_timer: float = 0.0`（约 88 行）后加：
```gdscript
const HostSuccession = preload("res://scripts/net/host_succession.gd")
var _succession = HostSuccession.new()   # 房主侧: 客户端加入顺序
var my_succession_rank: int = -1          # 客户端侧: 房主分给我的接班号 (-1=还没收到)
var _succ_send_timer: float = 0.0
const _SUCC_SEND_INTERVAL := 4.0          # 房主每 4s 给所有客户端重发一次紧凑 rank
const MIGRATION_STAGGER := 3.0            # 错峰间隔 (秒). 见计划常量说明
```

- [ ] **Step 2: 房主侧在 peer 加入/离开时更新 succession**

在 `_handle_envelope`（约 170-175 行）改两处 emit：
```gdscript
		if t == "__peer_join":
			var jid: String = String(data.get("id", from_peer))
			_succession.on_join(jid)        # 房主: 记加入顺序
			peer_joined.emit(jid)
			return
		if t == "__peer_leave":
			var lid: String = String(data.get("id", from_peer))
			_succession.on_leave(lid)
			peer_left.emit(lid)
			return
```
（`__peer_join/leave` 只有房主端会收到 → `_succession` 只在房主端被填充，客户端那边一直空，无副作用。）

- [ ] **Step 3: 客户端侧 `_route_message` 加 `succ` 分支**

在 `_route_message` 的 `match msg_type:` 里（"time" 分支后，约 298 行）加：
```gdscript
			"succ":
				# 房主告诉我: 我是第几个进的 (接班号). 房主掉线时按它错峰重进.
				my_succession_rank = int(data.get("r", -1))
```

- [ ] **Step 4: 房主周期 + 进房时发号**

加一个发号方法（放在 `_all_peer_ids` 后，约 401 行后）：
```gdscript
# 房主: 给每个客户端单播它的接班号 (rank). 紧凑 (0..N-1, 按加入顺序). 只 host 调.
func broadcast_succession() -> void:
	if _bridge == null or not is_host:
		return
	var order: Array = _succession.ordered()
	for i in range(order.size()):
		_bridge.send_to(String(order[i]), JSON.stringify({"type": "succ", "r": i}))
```

在 `_process`（约 107-114 行）的 poll 之后加周期发号：
```gdscript
func _process(delta: float) -> void:
	if _bridge == null:
		return
	_poll_timer -= delta
	if _poll_timer <= 0.0:
		_poll_timer = POLL_INTERVAL
		_poll_bridge()
	# 房主: 周期给所有客户端重发紧凑接班号
	if is_host and connected():
		_succ_send_timer -= delta
		if _succ_send_timer <= 0.0:
			_succ_send_timer = _SUCC_SEND_INTERVAL
			broadcast_succession()
```
（注意：原 `_process` 用 `if _poll_timer > 0.0: return` 提前返回，会挡住下面的发号。改成上面这种"不提前 return"的写法，poll 和发号都能跑。）

- [ ] **Step 5: 新人进房立刻补发一次号**

让房主在有人进来时立刻发号（不必等 4s）。`peer_joined` 已在 world 的 `_on_peer_joined` 里被房主用来补发 hello 等 —— 在 NetworkManager 这层最稳：在 Step 2 的 `__peer_join` 分支 `peer_joined.emit(jid)` 后加一行：
```gdscript
			_succession.on_join(jid)
			peer_joined.emit(jid)
			broadcast_succession()    # 新人进来 → 立刻给全员发最新紧凑号
			return
```

- [ ] **Step 6: 进房/断开时重置客户端的 rank + 房主的 succession**

在 `disconnect_room()`（约 606-619 行）末尾加：
```gdscript
	my_succession_rank = -1
	_succession.clear()
```
在 `enter_public()`（约 340 行 `in_public_room = true` 后）加：
```gdscript
	my_succession_rank = -1
	_succession.clear()
```

- [ ] **Step 7: 解析检查**

Run: `godot --headless --editor --quit`（过滤 `libfontconfig`）
Expected: 无 `SCRIPT ERROR` / `Parse Error`。

- [ ] **Step 8: 提交**

```bash
git add scripts/net/network_manager.gd
git commit -m "feat(mp): 房主给每个客户端发接班号 (succ) + 客户端存 rank

房主用 HostSuccession 跟踪加入顺序, 周期(4s)+新人进房时单播各自 rank.
客户端收 succ 存 my_succession_rank. host 迁移错峰用.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 3: 桥接重进原房号 + NetworkManager 包装

**Files:**
- Modify: `scripts/web/peerjs_bridge.js`（加 `reenter_public`）
- Modify: `scripts/net/network_manager.gd`（加 `reenter_public_for_migration`）

`enter_public` 每次把 `_pubIndex` 重置回 1（从 1 号房开始扫）。迁移时**必须重进原来那号房**，否则幸存者各自扫到 1 号房会被打散。`reenter_public` 保留 `_pubTag/_pubIndex` 重进。

> 无法单测（web-only）。验收靠解析检查 + 真机测。

- [ ] **Step 1: 桥加 `reenter_public`**

`scripts/web/peerjs_bridge.js`，在 `enter_public`（约 281-293 行）后加：
```javascript
    // 迁移用: 重进"当前这号"公共房 (保留 _pubTag/_pubIndex, 不重置回 1 号房).
    // 房主掉线后各幸存者调它 → 先试加入原房号, 没人就抢占当新房主 (复用 _tryJoinPublic 现成逻辑).
    bridge.reenter_public = function() {
        var tag = bridge._pubTag, idx = bridge._pubIndex || 1;
        var mp = bridge._maxPeers, mr = bridge._maxRooms;
        bridge.disconnect();            // 清掉旧的到房主的死连接 (会 _gen++)
        bridge._gen++;
        bridge._maxPeers = mp;
        bridge._maxRooms = mr;
        bridge._pubTag = tag;
        bridge._pubIndex = idx;         // 关键: 回到原房号, 不是 1
        bridge._pubFlips = 0;
        bridge._isHost = false;
        bridge._status = 'joining';
        bridge._lastError = '';
        _tryJoinPublic(bridge._gen);
    };
```
（`disconnect()` 清 `_conns/_hostConn/_peer/_status/...` 但**不动** `_pubTag/_pubIndex/_maxPeers/_maxRooms` —— 已确认，见 `disconnect` 实现约 473-490 行。上面先存后设是双保险。）

- [ ] **Step 2: NetworkManager 加包装方法**

`scripts/net/network_manager.gd`，在 `enter_public`（约 362 行）后加：
```gdscript
# host 迁移: 重进当前公共房号 (保留 index). 由 world 检测到房主掉线后错峰调用.
# 角色 (host/client) 由桥的抢占逻辑决定: 先到的抢到房号当新房主, 晚到的加入它.
func reenter_public_for_migration() -> void:
	if _bridge == null:
		return
	status = "joining"
	status_changed.emit(status)   # world 据此显示"正在换房主…"遮罩
	if _bridge.has_method("reenter_public"):
		_bridge.reenter_public()
```

- [ ] **Step 3: 解析检查**

Run: `godot --headless --editor --quit`（过滤 `libfontconfig`）
Expected: 无脚本错误。（JS 文件不参与 Godot 解析，但要肉眼确认 `reenter_public` 语法对、`bridge.` 前缀齐。）

- [ ] **Step 4: 提交**

```bash
git add scripts/web/peerjs_bridge.js scripts/net/network_manager.gd
git commit -m "feat(mp): 桥 reenter_public 重进原房号 + NM 包装

迁移时保留 _pubIndex 重进当前房号 (不重置回 1 号房, 否则幸存者被打散).
复用 _tryJoinPublic 的先加入否则抢占逻辑.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 4: world 迁移触发 + 错峰重进 + 遮罩

**Files:**
- Modify: `scripts/world/world.gd`（`_on_mp_status_changed` 加迁移；新增迁移方法 + 遮罩）

房主掉线（client 端收 `disconnected`）→ 若是公共生存房 → 启动迁移：显示遮罩 → 按 `my_succession_rank × STAGGER` 用 **Timer**（不用 await，遵循"signal handler 不加 async"约定）错峰 → 重进原房号。重连成功撤遮罩。

> 无法单测。验收靠真机：3 台设备进同一公共生存房，关掉房主，看是否一人接力、其余重连、几秒后能继续一起玩。

- [ ] **Step 1: 加迁移状态成员**

`scripts/world/world.gd`，在 `var _remote_players`（约 92 行）附近加：
```gdscript
var _migrating: bool = false            # 正在 host 迁移中 (防 disconnected 重入)
var _migration_overlay: CanvasLayer = null
const _MIGRATION_TIMEOUT := 20.0        # 这么久还没连上 → 放弃, 转单机
```

- [ ] **Step 2: 改 `_on_mp_status_changed` 接入迁移**

替换 `_on_mp_status_changed`（约 324-328 行）：
```gdscript
func _on_mp_status_changed(s: String) -> void:
	if s == "connected":
		# 迁移成功 (重连上新房主 / 自己当上新房主) → 撤遮罩, 收尾
		if _migrating:
			_finish_host_migration()
		_setup_multiplayer_callbacks()
	elif s == "disconnected" or s == "error":
		_cleanup_remote_on_disconnect()
		# 公共生存房的客户端: 房主掉线 → 启动 host 迁移 (而不是干等/散场)
		if _should_attempt_migration():
			_begin_host_migration()
```

- [ ] **Step 3: 加迁移判定 + 启动 + 收尾方法**

在 `_cleanup_remote_on_disconnect`（约 345 行）后加：
```gdscript
# 该不该启动 host 迁移: 必须是"公共生存房 + 之前是客户端 + 没在迁移中".
# 用 in_public_room + room_mode 判定 (不用 connected()/is_host: 断线那刻它们已不可信).
func _should_attempt_migration() -> bool:
	if NetworkManager == null:
		return false
	if _migrating:
		return false                              # 已在迁移, 别重入
	if not NetworkManager.in_public_room:
		return false                              # 私人房本期不迁移
	if NetworkManager.room_mode == "pvp":
		return false                              # 对战房本期不迁移
	if NetworkManager.is_host:
		return false                              # 我本来就是房主, 不是"房主掉线"
	return true

func _begin_host_migration() -> void:
	_migrating = true
	_show_migration_overlay()
	# 我的接班号决定错峰多久. -1 (没收到号) → 排最后兜底.
	var rank: int = NetworkManager.my_succession_rank
	var wait: float = (float(rank) if rank >= 0 else 99.0) * NetworkManager.MIGRATION_STAGGER
	# 用 SceneTreeTimer 的 timeout 回调 (connect, 不是 await) 错峰 → 不把 signal handler async 化.
	var t: SceneTreeTimer = get_tree().create_timer(maxf(wait, 0.05))
	t.timeout.connect(_do_migration_reenter)
	# 兜底超时: 这么久还没连上 → 放弃迁移, 转单机继续玩 (世界还在).
	var giveup: SceneTreeTimer = get_tree().create_timer(_MIGRATION_TIMEOUT)
	giveup.timeout.connect(_migration_timeout_check)

func _do_migration_reenter() -> void:
	if not _migrating:
		return                                    # 期间已收尾/取消
	NetworkManager.reenter_public_for_migration()

func _migration_timeout_check() -> void:
	if not _migrating:
		return
	if NetworkManager != null and NetworkManager.connected():
		return                                    # 已连上, 收尾会处理
	# 超时还没连上 → 当作只剩自己, 转单机继续 (不踢回菜单, 世界保留)
	_finish_host_migration()

func _finish_host_migration() -> void:
	_migrating = false
	_hide_migration_overlay()
```

- [ ] **Step 4: 加遮罩 UI（自带，不依赖 hud）**

继续在上面后面加：
```gdscript
func _show_migration_overlay() -> void:
	if _migration_overlay != null and is_instance_valid(_migration_overlay):
		return
	var layer := CanvasLayer.new()
	layer.layer = 100                             # 盖在最上面
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP    # 迁移期间挡住点击 (别让玩家乱操作)
	layer.add_child(bg)
	var label := Label.new()
	label.text = "正在换房主…"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 32)
	layer.add_child(label)
	add_child(layer)
	_migration_overlay = layer

func _hide_migration_overlay() -> void:
	if _migration_overlay != null and is_instance_valid(_migration_overlay):
		_migration_overlay.queue_free()
	_migration_overlay = null
```

- [ ] **Step 5: 解析检查**

Run: `godot --headless --editor --quit`（过滤 `libfontconfig`）
Expected: 无脚本错误。

- [ ] **Step 6: 提交**

```bash
git add scripts/world/world.gd
git commit -m "feat(mp): 房主掉线触发 host 迁移 + 错峰重进 + 换房主遮罩

公共生存房客户端收 disconnected → 按接班号 rank*STAGGER 用 Timer 错峰
(不 await) 重进原房号; 重连上撤遮罩; 超时转单机. 私人房/对战房不迁移.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 7: 真机验收（用户做）**

3 台设备 A/B/C 进同一公共生存房（A 最先进=房主，B 次之，C 最后）。
- 关掉 A（房主）。预期：弹「正在换房主…」；约 3s 内 B 抢到房号当新房主（B 的怪开始刷），C 自动重连到 B；遮罩消失，三人（剩 B/C）继续在同一世界。
- 再关掉 A 之前先关 B：预期 C 兜底当房主（等久一点）。
- 看 B/C 的世界：房主在的时候搭的方块还在（init_state 接管），怪重新刷了几只（可接受）。

---

## Task 5: 状态接管核验 + 补强

**Files:**
- Modify: `scripts/world/world.gd`（必要时重置实体刷新计时器）

新房主接管"几乎免费"：`_process` 用 `is_host` 门控（约 720、753 行），`is_host` 翻 true 后自动开始刷怪 + 广播；`_setup_multiplayer_callbacks`（"connected" 时调）的 host 分支自动 `_mp_broadcast_initial_state`；`_on_peer_joined` 的 host 分支自动给重连者补发 hello/init_state/实体。本任务只补两个易漏点。

> 无法单测。验收并入 Task 4 Step 7 真机测。

- [ ] **Step 1: 新房主立刻发一次接班号 + 重置刷怪节流**

新房主刚接管时，应尽快给重连者发接班号、并让刷怪/广播不被上一帧的节流计时器卡住。在 `_setup_multiplayer_callbacks` 的 host 分支（约 316-317 行）补：
```gdscript
	# host: 立刻广播 chunk_deltas (新 join 的 client 拿到这份现状)
	if NetworkManager.is_host:
		_mp_broadcast_initial_state.call_deferred()
		_mp_entity_sync_timer = 0.0       # 立刻进入实体广播 (别等节流)
		_mp_entity_full_timer = 0.0
		NetworkManager.broadcast_succession()   # 新房主: 给现有连接发接班号 (有人已先连上时)
```
（`_mp_entity_sync_timer` / `_mp_entity_full_timer` 是 world 已有成员，见约 759-765 行。）

- [ ] **Step 2: 解析检查**

Run: `godot --headless --editor --quit`（过滤 `libfontconfig`）
Expected: 无脚本错误。

- [ ] **Step 3: 提交**

```bash
git add scripts/world/world.gd
git commit -m "feat(mp): 新房主接管即刻广播状态/实体/接班号

接管时立刻重置实体广播节流 + 重发接班号, 让重连者尽快拿到世界和新的接班顺序.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## Task 6: 边界兜底

**Files:**
- Modify: `scripts/world/world.gd`（只剩一人 / 迁移途中新房主又掉）

- [ ] **Step 1: 迁移途中新房主又掉 → 再迁移一次**

新房主接管后若它**也**掉了，对其余人就是又一次"房主掉线"。`_on_mp_status_changed` 的 disconnected 分支已会再调 `_should_attempt_migration()`；但要保证 `_migrating` 已被 `_finish_host_migration` 复位（Task 4 在 "connected" 收尾时复位了）→ 二次掉线能再次进入。**核验**：`_should_attempt_migration` 里 `_migrating` 为 false 时才允许 → 上一轮成功收尾后才会二次触发，正确。无需改码，**确认逻辑**即可（在此打勾表示已核验）。

- [ ] **Step 2: 只剩自己 → 静默转单机（不弹菜单）**

`_migration_timeout_check` 超时已转单机（Task 4 Step 3）。再加一条快速路径：重进后若桥报 `error`（房号扫到头/连不稳），也转单机而非卡遮罩。`_on_mp_status_changed` 的 `error` 分支当前会调 `_cleanup_remote_on_disconnect` + 可能再 `_begin_host_migration`（被 `_migrating` 挡住重入）。补一个：迁移中收到 `error` → 收尾转单机。替换 Task 4 Step 2 里的 error 处理为：
```gdscript
	elif s == "disconnected" or s == "error":
		_cleanup_remote_on_disconnect()
		if _migrating and s == "error":
			_finish_host_migration()              # 迁移中又出错 → 放弃, 转单机继续
		elif _should_attempt_migration():
			_begin_host_migration()
```

- [ ] **Step 3: 解析检查**

Run: `godot --headless --editor --quit`（过滤 `libfontconfig`）
Expected: 无脚本错误。

- [ ] **Step 4: 提交**

```bash
git add scripts/world/world.gd
git commit -m "fix(mp): host 迁移边界 — 二次掉线再迁移 / 失败转单机

迁移中再收 error → 放弃转单机不卡遮罩; 新房主又掉能再触发一轮迁移.

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

- [ ] **Step 5: 全量回归 + 真机终测（用户做）**

- 跑全部单测：`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`，确认 HostSuccession 测试通过、原有测试没被带坏。
- 真机：复测 Task 4 Step 7 的三机场景 + 「连续关两个房主」「只剩一人」「关掉后又有人新进同号房」。

---

## 自查（spec 覆盖 / 占位符 / 类型一致）

**spec 覆盖：**
- 4.1 接班名单 → Task 1（HostSuccession）+ Task 2（发/收 rank）。✅（落地为单播 rank，等价）
- 4.2 检测掉线 → Task 4 Step 2（`_on_mp_status_changed` disconnected）。✅
- 4.3 选举+错峰 → Task 4 Step 3（`_begin_host_migration` 按 rank 错峰）。✅
- 4.4/4.5 重开+重连 → Task 3（`reenter_public` 原房号）+ Task 4。✅
- 4.6 状态接管 → Task 5（自动 + 补强）。✅
- 4.7 遮罩 UI → Task 4 Step 4。✅
- 5 边界（级联/脑裂/二次掉线/只剩一人/PvP 门控）→ 级联=桥的 join-else-host 自动（Task 3）；脑裂=桥的 `_pubFlips` 既有保护；二次掉线/只剩一人=Task 6；PvP 门控=Task 4 `_should_attempt_migration`。✅
- 6 范围（只公共 SV）→ `_should_attempt_migration` 挡掉私人房/PvP。✅
- 7 测试 → Task 1 单测纯逻辑；联机各任务写了真机验收步骤。✅

**占位符扫描：** 无 TBD/TODO；每个改码步骤都给了完整代码。

**类型/命名一致：** `HostSuccession.on_join/on_leave/ordered/rank_of/wait_for/clear`（Task1↔Task2 一致）；`my_succession_rank`（Task2 存↔Task4 读）；`MIGRATION_STAGGER`（Task2 定义↔Task4 用 `NetworkManager.MIGRATION_STAGGER`）；`_migrating`/`_finish_host_migration`/`_show_migration_overlay`（Task4 定义↔Task6 用）一致；桥 `reenter_public`（Task3 定义↔NM `reenter_public_for_migration` 调用）一致。
```
