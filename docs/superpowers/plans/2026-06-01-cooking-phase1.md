# 厨房系统 第 1 步 实现计划（料理 + 超能力 + 自然回血）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家能用「铁锅（叠在炉子上）」做 8 道料理，吃了回血 + 获得短时超能力（跑/跳/挖/回血），并给玩家加自然慢回血；屏幕显示 buff 图标。

**Architecture:** 新增 `PlayerBuffs` 组件（挂玩家下，跟 PlayerHealth/PlayerMana 同级）集中管理临时增益；移动/跳跃/挖矿处乘上 buff 倍数；吃料理在现有 `_update_eat_or_place` 末尾触发 `buffs.apply()`。自然回血加在 `player_health._physics_process`。锅是新 tile（复用火把光源系统发光），料理是带 `buff_kind/buff_secs` 字段的新 food，配方 `requires:"pot"`。Buff HUD 仿 health_hud/mana_hud。

**Tech Stack:** Godot 4.3 + GDScript；GUT 9.x 测试；程序绘制像素美术。

**对应 spec：** `docs/superpowers/specs/2026-06-01-cooking-kitchen-design.md`（第 1 步范围）。

---

## 预备：环境与约定

- 跑测试前若新建了 `class_name` / autoload / 资源，先 `godot --headless --editor --quit` 重建索引（否则报 `Identifier "GutUtils" not declared`）。本计划**不新增 class_name / autoload**（PlayerBuffs 用节点脚本，非 autoload），但新建 .gd 文件后仍建议跑一次 `--editor --quit`。
- 跑全部单测：`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
- 跑全部集成：`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit`
- 跑单个文件：上面命令把 `-gdir=...` 换成 `-gtest=res://tests/unit/test_xxx.gd`。
- `libfontconfig.so.1: cannot open shared object file` 不是 error，忽略。
- 提交规矩：本仓库有并发 session + 用户 WIP。**只 `git add <精确路径>`，禁用 `-am`/`-A`/`.`，禁用 `git commit --amend`**（amend 会顶掉别人的 commit）。每个 Step 5 提交前先 `git log --oneline -3` 看一眼有没有别人新提交。

## 文件结构（本计划涉及）

| 文件 | 动作 | 职责 |
|---|---|---|
| `scripts/player/player_health.gd` | 改 | 加自然慢回血 |
| `scripts/player/player_buffs.gd` | **新建** | 临时增益组件（计时/倍数/regen） |
| `scenes/player/player.tscn` | 改 | 加 PlayerBuffs 子节点 |
| `scripts/player/player_controller.gd` | 改 | 移动/跳跃乘 buff 倍数 |
| `scripts/player/player_action.gd` | 改 | 挖矿乘 buff 倍数；吃料理触发 buff；锅放置约束 |
| `scripts/items/item_db.gd` | 改 | cooking_pot + 7 道料理 def + buff 字段 helper |
| `scripts/crafting/recipe_db.gd` | 改 | cooking_pot + 8 道料理配方；cooked_meat 改 requires pot |
| `scripts/ui/crafting_panel.gd` | 改 | `_has_cooking_pot_nearby` + `requires:"pot"` 过滤 + 中文名 |
| `scripts/world/tile_data.gd` | 改 | `COOKING_POT := 74` 常量 + _PROPS |
| `scripts/world/tileset_builder.gd` | 改 | tile_ids 数组加 COOKING_POT |
| `scripts/world/world_lighting.gd` | 改 | 锅当火把发光 |
| `scripts/art/blocks_art.gd` | 改 | 锅贴图 pattern + palette |
| `scripts/art/items_art.gd` | 改 | 7 道料理图标 |
| `scripts/ui/buff_hud.gd` | **新建** | buff 图标 + 倒计时 |
| `scenes/ui/hud.tscn` + `scripts/ui/hud.gd` | 改 | 接入 BuffHUD |
| `tests/unit/`, `tests/integration/` | 新建多个 | 验收 |

---

## Task 1: 自然慢回血（player_health.gd）

**Files:**
- Modify: `scripts/player/player_health.gd`（const/var 块 9-23；`_physics_process` 26-37；`take_damage` ~140）
- Test: `tests/unit/test_health_regen.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/unit/test_health_regen.gd`:
```gdscript
extends GutTest

const HealthClass = preload("res://scripts/player/player_health.gd")
var hp

func before_each():
	hp = HealthClass.new()
	add_child_autofree(hp)

# 受伤后 REGEN_DELAY 内不回血
func test_no_regen_right_after_hit():
	hp.current_health = 50
	hp.take_damage(1)            # 触发 _since_hit_t = 0
	hp.current_health = 50       # 复位 (排除这 1 点伤害影响)
	# 模拟 2 秒 (< REGEN_DELAY_AFTER_HIT=4)
	for i in 120:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, 50, "刚受击不该回血")

# 久未受击 → 按 REGEN_INTERVAL 回 REGEN_AMOUNT
func test_regen_after_delay():
	hp.current_health = 50
	hp._since_hit_t = 999.0      # 视为很久没被打
	# 模拟 2.1 秒 (> REGEN_INTERVAL=2.0) → 回 1 点
	for i in 126:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, 51, "应回 1 点")

# 满血不回
func test_no_regen_at_full():
	hp.current_health = hp.MAX_HEALTH
	hp._since_hit_t = 999.0
	for i in 200:
		hp._physics_process(1.0 / 60.0)
	assert_eq(hp.current_health, hp.MAX_HEALTH, "满血不该溢出")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_health_regen.gd -gexit`
Expected: FAIL（`_since_hit_t` 未定义 / 不回血）

- [ ] **Step 3: 实现**

在 const/var 块（player_health.gd:9-23 区域）加常量与变量：
```gdscript
const REGEN_INTERVAL := 2.0          # 每 2 秒回一次
const REGEN_AMOUNT := 1              # 每次回 1 点 (~0.5 HP/s, 很慢)
const REGEN_DELAY_AFTER_HIT := 4.0   # 受击后 4 秒内不回 (打架仍紧张)
```
```gdscript
var _regen_t: float = 0.0
var _since_hit_t: float = 999.0      # 初始视为很久没被打
```

在 `_physics_process` 里 `_check_lava_damage()` 那个 if 块**之后**（函数结尾前）追加：
```gdscript
	# 自然慢回血: 离上次受击 >= REGEN_DELAY 且未满血 → 每 REGEN_INTERVAL 回 REGEN_AMOUNT.
	# 直接改 current_health + emit (不走 heal(), 不碰 iframe).
	_since_hit_t += delta
	if is_alive() and current_health < MAX_HEALTH and _since_hit_t >= REGEN_DELAY_AFTER_HIT:
		_regen_t += delta
		if _regen_t >= REGEN_INTERVAL:
			_regen_t -= REGEN_INTERVAL
			current_health = min(MAX_HEALTH, current_health + REGEN_AMOUNT)
			health_changed.emit(current_health, MAX_HEALTH)
	else:
		_regen_t = 0.0
```

在 `take_damage()` 里，紧接设置 `_iframe_timer = IFRAMES_SEC` 的那一行**之后**，加一行：
```gdscript
	_since_hit_t = 0.0   # 受击 → 重置回血延迟计时
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（3 个测试全过）

- [ ] **Step 5: 提交**
```bash
git log --oneline -3
git add scripts/player/player_health.gd tests/unit/test_health_regen.gd
git commit -m "feat(health): 自然慢回血 (每2s回1, 受击4s内暂停)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: PlayerBuffs 组件 + 挂到玩家

**Files:**
- Create: `scripts/player/player_buffs.gd`
- Modify: `scenes/player/player.tscn`（加 PlayerBuffs 子节点）
- Test: `tests/unit/test_player_buffs.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/unit/test_player_buffs.gd`:
```gdscript
extends GutTest

const BuffsClass = preload("res://scripts/player/player_buffs.gd")
var buffs

func before_each():
	buffs = BuffsClass.new()
	add_child_autofree(buffs)

func test_apply_and_active():
	buffs.apply("speed", 5.0)
	assert_true(buffs.is_active("speed"))
	assert_almost_eq(buffs.speed_mul(), buffs.SPEED_MUL, 0.001)

func test_expire():
	buffs.apply("speed", 1.0)
	buffs._process(1.1)        # 超时
	assert_false(buffs.is_active("speed"))
	assert_almost_eq(buffs.speed_mul(), 1.0, 0.001)

func test_refresh_same_kind():
	buffs.apply("jump", 2.0)
	buffs._process(1.5)
	buffs.apply("jump", 2.0)   # 刷新
	buffs._process(1.0)        # 距刷新才 1s, 仍在
	assert_true(buffs.is_active("jump"))

func test_different_kinds_stack():
	buffs.apply("speed", 5.0)
	buffs.apply("mining", 5.0)
	assert_true(buffs.is_active("speed"))
	assert_true(buffs.is_active("mining"))
	assert_almost_eq(buffs.mining_mul(), buffs.MINING_MUL, 0.001)

func test_muls_default_one():
	assert_almost_eq(buffs.speed_mul(), 1.0, 0.001)
	assert_almost_eq(buffs.jump_mul(), 1.0, 0.001)
	assert_almost_eq(buffs.mining_mul(), 1.0, 0.001)

func test_remaining_frac():
	buffs.apply("speed", 4.0)
	buffs._process(1.0)
	assert_almost_eq(buffs.remaining_frac("speed"), 0.75, 0.02)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_buffs.gd -gexit`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 player_buffs.gd**

`scripts/player/player_buffs.gd`:
```gdscript
# 玩家临时增益 (buff) 组件。挂在 Player 下, 与 PlayerHealth/PlayerMana 同级。
# 4 种 kind: speed(跑快) / jump(跳高) / mining(挖快) / regen(慢回血)。
# 同种 buff 再吃刷新时长; 不同种叠加。regen 活跃时每秒帮玩家回血。
extends Node

signal buffs_changed

const SPEED_MUL := 1.4               # 跑快倍数
const JUMP_MUL := 1.3                # 跳高倍数 (乘到负的 JUMP_VELOCITY → 更高)
const MINING_MUL := 1.8              # 挖快倍数
const BUFF_REGEN_INTERVAL := 1.0     # regen buff: 每 1 秒
const BUFF_REGEN_AMOUNT := 2         # 回 2 点 (比自然回血快)

var _active: Dictionary = {}   # kind:String -> remaining_secs:float
var _total: Dictionary = {}    # kind:String -> total_secs:float (给 HUD 算倒计时比例)
var _regen_t: float = 0.0


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var changed: bool = false
	for kind in _active.keys():          # keys() 是副本, 迭代中可 erase
		_active[kind] -= delta
		if _active[kind] <= 0.0:
			_active.erase(kind)
			_total.erase(kind)
			changed = true
	# regen buff: 持续回血
	if _active.has("regen"):
		_regen_t += delta
		if _regen_t >= BUFF_REGEN_INTERVAL:
			_regen_t -= BUFF_REGEN_INTERVAL
			var hp: Node = get_parent().get_node_or_null("PlayerHealth")
			if hp != null and hp.has_method("heal"):
				hp.heal(BUFF_REGEN_AMOUNT)
	else:
		_regen_t = 0.0
	if changed:
		buffs_changed.emit()


func apply(kind: String, secs: float) -> void:
	if kind == "" or secs <= 0.0:
		return
	_active[kind] = secs
	_total[kind] = secs
	buffs_changed.emit()


func is_active(kind: String) -> bool:
	return _active.has(kind)


func remaining(kind: String) -> float:
	return _active.get(kind, 0.0)


func remaining_frac(kind: String) -> float:
	var total: float = _total.get(kind, 1.0)
	return clamp(_active.get(kind, 0.0) / maxf(total, 0.001), 0.0, 1.0)


func active_kinds() -> Array:
	return _active.keys()


func speed_mul() -> float:
	return SPEED_MUL if _active.has("speed") else 1.0


func jump_mul() -> float:
	return JUMP_MUL if _active.has("jump") else 1.0


func mining_mul() -> float:
	return MINING_MUL if _active.has("mining") else 1.0
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（6 个测试全过）

- [ ] **Step 5: 把 PlayerBuffs 挂到 player.tscn**

打开 `scenes/player/player.tscn`，参照已有 `PlayerHealth` 节点的写法：
1. 顶部加一个 `[ext_resource type="Script" path="res://scripts/player/player_buffs.gd" id="<新id>"]`（id 取一个未用过的，如 `id="N_buffs"`）。
2. 在 `[node name="PlayerHealth" ...]` 那一组附近，加：
```
[node name="PlayerBuffs" type="Node" parent="."]
script = ExtResource("<上面的id>")
```
（type 用 `Node`，parent 用 `"."` 表示直接挂在 Player 根下，跟 PlayerHealth 一致。）

- [ ] **Step 6: 重建索引 + 跑单测确认没坏**

Run: `godot --headless --editor --quit` 然后 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 全绿（含新 buff 测试）

- [ ] **Step 7: 提交**
```bash
git log --oneline -3
git add scripts/player/player_buffs.gd scenes/player/player.tscn tests/unit/test_player_buffs.gd
git commit -m "feat(buffs): PlayerBuffs 组件 (speed/jump/mining/regen) + 挂玩家

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 把 buff 接到移动 / 跳跃 / 挖矿

**Files:**
- Modify: `scripts/player/player_controller.gd`（移动 ~277；跳跃 ~313 与 ~301）
- Modify: `scripts/player/player_action.gd`（挖矿进度 ~414）
- Test: `tests/unit/test_buff_wiring.gd`（新建）

- [ ] **Step 1: 写失败测试**

挖矿乘倍数最易单测（直接验证 PlayerBuffs 的 mining_mul 在 0/有 buff 时取值；移动/跳跃接线靠集成手感，单测覆盖 buffs 取值即可，避免实例化整个控制器）。这里加一个"接线点存在"的轻测试：

`tests/unit/test_buff_wiring.gd`:
```gdscript
extends GutTest

const BuffsClass = preload("res://scripts/player/player_buffs.gd")

# mining buff 应把倍数从 1.0 提到 MINING_MUL
func test_mining_mul_changes_with_buff():
	var b = BuffsClass.new()
	add_child_autofree(b)
	assert_almost_eq(b.mining_mul(), 1.0, 0.001)
	b.apply("mining", 5.0)
	assert_almost_eq(b.mining_mul(), b.MINING_MUL, 0.001)

# controller 源码确实乘了 speed_mul (防回归: 接线被删)
func test_controller_multiplies_speed_buff():
	var src: String = FileAccess.get_file_as_string("res://scripts/player/player_controller.gd")
	assert_true(src.find("_buff_speed_mul()") != -1, "移动应乘 _buff_speed_mul()")
	assert_true(src.find("_buff_jump_mul()") != -1, "跳跃应乘 _buff_jump_mul()")

func test_action_multiplies_mining_buff():
	var src: String = FileAccess.get_file_as_string("res://scripts/player/player_action.gd")
	assert_true(src.find("_buff_mining_mul()") != -1, "挖矿应乘 _buff_mining_mul()")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_buff_wiring.gd -gexit`
Expected: FAIL（接线函数不存在）

- [ ] **Step 3: 改 player_controller.gd**

在文件末尾加两个小 helper（读 `$PlayerBuffs`，没有就返回 1.0）：
```gdscript
func _buff_speed_mul() -> float:
	var b: Node = get_node_or_null("PlayerBuffs")
	return 1.0 if b == null else b.speed_mul()


func _buff_jump_mul() -> float:
	var b: Node = get_node_or_null("PlayerBuffs")
	return 1.0 if b == null else b.jump_mul()
```

移动行（~277）：
```gdscript
	velocity.x = dir * SPEED * speed_mul
```
改成：
```gdscript
	velocity.x = dir * SPEED * speed_mul * _buff_speed_mul()
```

陆地跳跃（~313 块 A）：
```gdscript
			velocity.y = JUMP_VELOCITY
```
改成：
```gdscript
			velocity.y = JUMP_VELOCITY * _buff_jump_mul()
```
出水跳跃（~301 块 B）同样把 `velocity.y = JUMP_VELOCITY` 改成 `velocity.y = JUMP_VELOCITY * _buff_jump_mul()`。
（块 C 的 `SWIM_UP_SPEED` 上浮、块 D 的脱钩小跳**不改**——只改真正的"起跳"。）

- [ ] **Step 4: 改 player_action.gd**

文件末尾加 helper：
```gdscript
func _buff_mining_mul() -> float:
	var b: Node = get_parent().get_node_or_null("PlayerBuffs")
	return 1.0 if b == null else b.mining_mul()
```

挖矿进度累加行（~414）：
```gdscript
	_mining_progress += _tool_speed(tool_kind, tid) * delta
```
改成：
```gdscript
	_mining_progress += _tool_speed(tool_kind, tid) * delta * _buff_mining_mul()
```

- [ ] **Step 5: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS（3 个）

- [ ] **Step 6: 提交**
```bash
git log --oneline -3
git add scripts/player/player_controller.gd scripts/player/player_action.gd tests/unit/test_buff_wiring.gd
git commit -m "feat(buffs): 移动/跳跃/挖矿接 buff 倍数

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: ItemDB buff 字段 + 吃料理触发 buff（血满也能吃 buff 料理）

**Files:**
- Modify: `scripts/items/item_db.gd`（helper 区 ~146-189）
- Modify: `scripts/player/player_action.gd`（`_update_eat_or_place` 食物分支）
- Test: `tests/unit/test_item_buff_fields.gd`（新建）

- [ ] **Step 1: 写失败测试**

为测试，先临时往 item_db 加一个**带 buff 的测试食物**？不——直接用 Task 8 会加的真实料理太靠后。改为测 helper 行为 + 一个内联 def 断言。这里测 helper 对"有/无 buff 字段"的判定，用 Task 8 才加的 `bread` 之前会失败，所以本测试只断言 helper 函数存在且对未知 id 返回空：

`tests/unit/test_item_buff_fields.gd`:
```gdscript
extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
var db

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)

func test_buff_helpers_default_empty():
	assert_eq(db.food_buff_kind("apple"), "", "苹果无 buff")
	assert_almost_eq(db.food_buff_secs("apple"), 0.0, 0.001)
	assert_false(db.food_has_buff("apple"))

func test_buff_helpers_unknown():
	assert_eq(db.food_buff_kind("nonexistent"), "")
	assert_false(db.food_has_buff("nonexistent"))
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_item_buff_fields.gd -gexit`
Expected: FAIL（helper 不存在）

- [ ] **Step 3: 加 ItemDB helper**

在 item_db.gd helper 区（`food_fill` 附近）加：
```gdscript
func food_buff_kind(item_id: String) -> String:
	var def = get_def(item_id)
	return "" if def == null else def.get("buff_kind", "")

func food_buff_secs(item_id: String) -> float:
	var def = get_def(item_id)
	return 0.0 if def == null else def.get("buff_secs", 0.0)

func food_has_buff(item_id: String) -> bool:
	return food_buff_kind(item_id) != ""
```

- [ ] **Step 4: 改吃料理逻辑（player_action.gd 食物分支）**

把现有食物分支（`if holding_food and held and hp != null:` 那段，约 966-985）整段替换为：
```gdscript
	# 持食物 + 按住 → 进食. food_fill 当回血量.
	# 普通食物: 满血不让吃 (防误点浪费). 带 buff 的料理: 满血也能吃 (为拿 buff).
	if holding_food and held and hp != null:
		var has_buff: bool = ItemDB.food_has_buff(slot.item_id)
		if hp.current_health >= hp.MAX_HEALTH and not has_buff:
			if _eat_item_id != "":
				_eat_item_id = ""
				_eat_t = 0.0
				_stop_eat_anim()
			return
		if _eat_item_id != slot.item_id:
			_eat_item_id = slot.item_id
			_eat_t = 0.0
			_start_eat_anim()
		_eat_t += delta
		if _eat_t >= EAT_DURATION_SEC:
			_eat_t = 0.0
			hp.heal(ItemDB.food_fill(slot.item_id))
			if has_buff:
				var buffs: Node = get_parent().get_node_or_null("PlayerBuffs")
				if buffs != null:
					buffs.apply(ItemDB.food_buff_kind(slot.item_id), ItemDB.food_buff_secs(slot.item_id))
			SfxBank.play("eat", 0.10)
			inv.consume_current(1)
			_stop_eat_anim()
		return
```

- [ ] **Step 5: 跑确认通过**

Run: 同 Step 2。Expected: PASS

- [ ] **Step 6: 提交**
```bash
git log --oneline -3
git add scripts/items/item_db.gd scripts/player/player_action.gd tests/unit/test_item_buff_fields.gd
git commit -m "feat(food): ItemDB buff 字段 + 吃料理触发 buff (满血也能吃 buff 料理)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 铁锅 tile（COOKING_POT）注册 + item + 中文名 + 美术

**Files:**
- Modify: `scripts/world/tile_data.gd`（常量 + _PROPS）
- Modify: `scripts/world/tileset_builder.gd`（tile_ids 数组）
- Modify: `scripts/items/item_db.gd`（cooking_pot item def）
- Modify: `scripts/ui/crafting_panel.gd`（_ZH_NAMES）
- Modify: `scripts/art/blocks_art.gd`（pattern + palette + 注册）
- Test: `tests/unit/test_cooking_pot_tile.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/unit/test_cooking_pot_tile.gd`:
```gdscript
extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")

func test_cooking_pot_tile_const():
	assert_eq(Tiles.COOKING_POT, 74, "锅 tile id = 74")

func test_cooking_pot_solid_mineable():
	assert_true(Tiles.is_solid(Tiles.COOKING_POT))
	assert_true(Tiles.is_mineable(Tiles.COOKING_POT))

func test_cooking_pot_item_placeable():
	var db = ItemDBClass.new()
	add_child_autofree(db)
	assert_true(db.is_placeable("cooking_pot"))
	assert_eq(db.get_def("cooking_pot").placeable_tile_id, Tiles.COOKING_POT)

func test_cooking_pot_in_tileset_ids():
	var src: String = FileAccess.get_file_as_string("res://scripts/world/tileset_builder.gd")
	assert_true(src.find("Tiles.COOKING_POT") != -1, "tileset_builder 必须注册 COOKING_POT")

func test_cooking_pot_has_art():
	var tex = ArtCache.block_textures.get(Tiles.COOKING_POT)
	assert_not_null(tex, "锅必须有贴图")
```
> 注意：`Tiles` / `ArtCache` 是 autoload，测试里直接可用；但新增 `const COOKING_POT` 与新 block 贴图后**必须先 `godot --headless --editor --quit` 重建索引**，否则 `Tiles.COOKING_POT` 报未定义。

- [ ] **Step 2: 跑确认失败**

先 `godot --headless --editor --quit`，再
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cooking_pot_tile.gd -gexit`
Expected: FAIL

- [ ] **Step 3: tile_data.gd 加常量 + _PROPS**

在 `const LAVA_L3 := 73` 之后加：
```gdscript
const COOKING_POT := 74     # 铁锅: 玩家造, 实心, 只能叠在炉子上. 附近解锁料理配方. 发暖光.
```
在 _PROPS 里（仿 FURNACE）加一项：
```gdscript
	COOKING_POT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["cooking_pot", 100, 1, 1]],
	},
```

- [ ] **Step 4: tileset_builder.gd 注册**

在 `tile_ids` 数组里（`Tiles.FURNACE,` 附近）加一行：
```gdscript
	Tiles.COOKING_POT,
```

- [ ] **Step 5: item_db.gd 加 item def**

在 `furnace` 那行附近加：
```gdscript
	"cooking_pot":  {"placeable_tile_id": Tiles.COOKING_POT, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
```

- [ ] **Step 6: crafting_panel.gd 加中文名**

在 `_ZH_NAMES` 里加：
```gdscript
	"cooking_pot": "铁锅",
```

- [ ] **Step 7: blocks_art.gd 画锅贴图**

参照 `_P_FURNACE`（blocks_art.gd:571）旁的 FURNACE pattern 写法（同文件里找到 FURNACE 的 pattern 字符串数组与 `BlocksArt.get_texture` 的注册分支，**用相同的网格尺寸**）。加：
1. 调色板 `_P_COOKING_POT`（黑灰锅身 + 橙黄火苗，暖色）：
```gdscript
const _P_COOKING_POT := {
	"k": Color8(35, 30, 28),     # 黑铁描边
	"i": Color8(70, 66, 64),     # 铁锅身灰
	"I": Color8(105, 100, 96),   # 锅身高光
	"R": Color8(220, 90, 40),    # 火焰橙红
	"r": Color8(255, 160, 60),   # 火焰亮黄
	"y": Color8(255, 230, 130),  # 火焰最亮
}
```
2. pattern：画一口**圆肚铁锅**（上沿开口、两侧小耳），**锅底下方一排橙黄火苗**。形状要能一眼认出是"架在火上的锅"。网格尺寸与 FURNACE pattern 一致（多为 16×16，最终缩到 12px）。底部 2-3 行用 `R`/`r`/`y` 画火，锅身用 `i`/`I`，描边 `k`，背景 `.`（透明）。
3. 在 `BlocksArt.get_texture()`（或该文件构建贴图的 match/switch）里，照 FURNACE 的分支加 `COOKING_POT → PixelArt.grid_to_texture(_COOKING_POT, _P_COOKING_POT)`（函数名以文件里 FURNACE 实际用的为准）。

- [ ] **Step 8: 重建索引 + 跑确认通过**

Run: `godot --headless --editor --quit` 然后 `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cooking_pot_tile.gd -gexit`
Expected: PASS（5 个）

- [ ] **Step 9: 提交**
```bash
git log --oneline -3
git add scripts/world/tile_data.gd scripts/world/tileset_builder.gd scripts/items/item_db.gd scripts/ui/crafting_panel.gd scripts/art/blocks_art.gd tests/unit/test_cooking_pot_tile.gd
git commit -m "feat(cook): 铁锅 tile COOKING_POT(74) 注册 + item + 中文名 + 美术

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 锅只能叠炉子上 + 做饭检测 + 配方过滤

**Files:**
- Modify: `scripts/player/player_action.gd`（`try_place()` 加锅约束）
- Modify: `scripts/ui/crafting_panel.gd`（`_has_cooking_pot_nearby` + 过滤）
- Modify: `scripts/crafting/recipe_db.gd`（锅配方 requires furnace）
- Test: `tests/integration/test_cooking_pot_place.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/integration/test_cooking_pot_place.gd`:
```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")

func _boot() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	return {"main": main, "world": world, "player": player}

# 锅放在炉子正上方 → 成功
func test_pot_places_on_furnace():
	var s = await _boot()
	var world = s.world
	var player = s.player
	var pa: Node = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var pt: Vector2i = pa.player_tile()
	# 在玩家旁边铺：下面 furnace, 上面空气
	var fx: int = pt.x + 1
	world._set_tile(fx, pt.y, Tiles.FURNACE)     # 炉子
	world._set_tile(fx, pt.y - 1, Tiles.AIR)     # 上方空
	inv.inventory.add("cooking_pot", 1)
	# 选中锅 + 瞄准炉子上方那格
	inv.select_hotbar(0) if inv.has_method("select_hotbar") else null
	pa.aim_override = Vector2i(fx, pt.y - 1)
	var ok: bool = pa.try_place()
	assert_true(ok, "锅应能叠在炉子上")
	assert_eq(world.get_terrain().get_cell_source_id(Vector2i(fx, pt.y - 1)), Tiles.COOKING_POT)

# 锅放在非炉子上方 → 失败
func test_pot_rejects_non_furnace():
	var s = await _boot()
	var world = s.world
	var player = s.player
	var pa: Node = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var pt: Vector2i = pa.player_tile()
	var sx: int = pt.x + 1
	world._set_tile(sx, pt.y, Tiles.STONE)       # 石头 (不是炉子)
	world._set_tile(sx, pt.y - 1, Tiles.AIR)
	inv.inventory.add("cooking_pot", 1)
	pa.aim_override = Vector2i(sx, pt.y - 1)
	var ok: bool = pa.try_place()
	assert_false(ok, "锅不该放在非炉子上")
```
> 若 `world.get_terrain()` / `get_player()` 名称与现有集成测试不符，照 `tests/integration/test_craft_loop.gd` 里实际用法调整（那里用 `world.get_player()`、`get_tree().get_first_node_in_group("terrain_layer")`）。

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_cooking_pot_place.gd -gexit`
Expected: FAIL（锅能放在任何有支撑处）

- [ ] **Step 3: try_place() 加锅约束**

在 `try_place()` 里，DOOR 分支**之后**、最终通用放置 `if world.has_method("_set_tile"): world._set_tile(tile.x, tile.y, def.placeable_tile_id)` **之前**，插入：
```gdscript
	# 铁锅只能叠在炉子正上方 (用户设计: "锅放在炉子上")
	if slot.item_id == "cooking_pot":
		var below_pot: Vector2i = tile + Vector2i(0, 1)
		if terrain.get_cell_source_id(below_pot) != Tiles.FURNACE:
			SfxBank.play("place", 0.05)   # 轻提示 (放置失败手感, 不卡顿)
			return false
```

- [ ] **Step 4: recipe_db.gd 加锅配方**

在 furnace 配方附近加（U 形开口锅，5 铁锭，熔炉炼）：
```gdscript
	{
		"id": "cooking_pot",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "",           "iron_ingot"],
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["",           "",           ""],
		],
		"output_id": "cooking_pot",
		"output_count": 1,
		"mirror_ok": true,
		"requires": "furnace",
	},
```

- [ ] **Step 5: crafting_panel.gd 加锅检测 + 过滤**

加方法（仿 `_has_furnace_nearby`，只换 tile）：
```gdscript
func _has_cooking_pot_nearby() -> bool:
	if _player_inv == null:
		return false
	var player: Node = _player_inv.get_parent()
	if player == null:
		return false
	var pa: Node = player.get_node_or_null("PlayerAction")
	if pa == null or not pa.has_method("player_tile"):
		return false
	var pt: Vector2i = pa.player_tile()
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return false
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.COOKING_POT:
				return true
	return false
```
在 `_refresh_recipes()` 里、计算 `has_furnace` 那行旁边加：
```gdscript
	var has_cooking_pot: bool = _has_cooking_pot_nearby()
```
在过滤块（`if requires == "furnace" and not has_furnace:` 之后）加：
```gdscript
	if requires == "pot" and not has_cooking_pot:
		btn.visible = false
		continue
```

- [ ] **Step 6: 跑确认通过**

Run: 同 Step 2。Expected: PASS（2 个）

- [ ] **Step 7: 提交**
```bash
git log --oneline -3
git add scripts/player/player_action.gd scripts/ui/crafting_panel.gd scripts/crafting/recipe_db.gd tests/integration/test_cooking_pot_place.gd
git commit -m "feat(cook): 锅只能叠炉子上 + 锅配方 + 做饭检测/过滤

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 锅发光（复用火把光源系统）

**Files:**
- Modify: `scripts/world/world_lighting.gd`（三处 TORCH 判定）
- Test: `tests/integration/test_cooking_pot_light.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/integration/test_cooking_pot_light.gd`:
```gdscript
extends GutTest

# world_lighting: 放下锅 → 在 TorchLights 下生成一盏光 (复用 TorchFx)
func test_pot_spawns_light():
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	var WL = preload("res://scripts/world/world_lighting.gd")
	var wl = WL.new()
	wl.name = "WorldLighting"
	root.add_child(wl)
	await wait_frames(1)
	# 放锅 (世界坐标 5,5)
	wl.on_tile_placed(5, 5, Tiles.COOKING_POT)
	assert_eq(torch_lights.get_child_count(), 1, "锅应生成 1 盏光")
	# 拆锅 → 光消失
	wl.on_tile_removed(5, 5, Tiles.COOKING_POT)
	await wait_frames(1)
	assert_eq(torch_lights.get_child_count(), 0, "拆锅光应消失")
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_cooking_pot_light.gd -gexit`
Expected: FAIL（锅不发光）

- [ ] **Step 3: world_lighting.gd 三处加 COOKING_POT**

`on_tile_placed`:
```gdscript
	if tile_id == Tiles.TORCH or tile_id == Tiles.COOKING_POT:
		_spawn_torch(x, y)
```
`on_tile_removed`:
```gdscript
	if old_tile_id == Tiles.TORCH or old_tile_id == Tiles.COOKING_POT:
		_despawn_torch(x, y)
```
`on_chunk_loaded`（循环里）：
```gdscript
			if col[y] == Tiles.TORCH or col[y] == Tiles.COOKING_POT:
				_spawn_torch(world_x, y)
```

- [ ] **Step 4: 跑确认通过**

Run: 同 Step 2。Expected: PASS

- [ ] **Step 5: 提交**
```bash
git log --oneline -3
git add scripts/world/world_lighting.gd tests/integration/test_cooking_pot_light.gd
git commit -m "feat(cook): 锅复用火把光源发暖光

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 8 道料理（item def + 配方 + 中文名 + 美术）

**Files:**
- Modify: `scripts/items/item_db.gd`（7 道新 food def）
- Modify: `scripts/crafting/recipe_db.gd`（8 道配方；cooked_meat 改 requires "pot"）
- Modify: `scripts/ui/crafting_panel.gd`（7 道中文名）
- Modify: `scripts/art/items_art.gd`（7 道图标）
- Test: `tests/unit/test_dishes.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/unit/test_dishes.gd`:
```gdscript
extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
var db
var rdb

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)
	rdb = RecipeDBClass.new()
	add_child_autofree(rdb)

# 7 道新料理: food_fill + buff 字段正确
func test_dish_defs():
	var expect := {
		"bread":         {"fill": 30, "kind": "speed"},
		"mushroom_soup": {"fill": 30, "kind": "regen"},
		"apple_pie":     {"fill": 45, "kind": "jump"},
		"meat_skewer":   {"fill": 60, "kind": "mining"},
		"mushroom_stew": {"fill": 65, "kind": "mining"},
		"apple_jam":     {"fill": 35, "kind": "regen"},
		"jelly_pudding": {"fill": 40, "kind": "jump"},
	}
	for id in expect:
		assert_true(db.is_food(id), "%s 应是食物" % id)
		assert_eq(db.food_fill(id), expect[id].fill, "%s food_fill" % id)
		assert_eq(db.food_buff_kind(id), expect[id].kind, "%s buff_kind" % id)
		assert_gt(db.food_buff_secs(id), 0.0, "%s buff_secs>0" % id)

# 熟肉无 buff (基础款)
func test_cooked_meat_no_buff():
	assert_true(db.is_food("cooked_meat"))
	assert_false(db.food_has_buff("cooked_meat"))

# 8 道料理配方都 requires "pot"
func test_dish_recipes_require_pot():
	for id in ["cooked_meat", "bread", "mushroom_soup", "apple_pie", "meat_skewer", "mushroom_stew", "apple_jam", "jelly_pudding"]:
		var r = rdb.get_recipe(id)
		assert_not_null(r, "%s 配方应存在" % id)
		assert_eq(r.get("requires", ""), "pot", "%s 应在锅里做" % id)
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dishes.gd -gexit`
Expected: FAIL

- [ ] **Step 3: item_db.gd 加 7 道 food def**

在食物区（apple/cooked_meat 附近）加：
```gdscript
	"bread":          {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 30, "buff_kind": "speed",  "buff_secs": 60.0},
	"mushroom_soup":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 30, "buff_kind": "regen",  "buff_secs": 30.0},
	"apple_pie":      {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 45, "buff_kind": "jump",   "buff_secs": 60.0},
	"meat_skewer":    {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 60, "buff_kind": "mining", "buff_secs": 60.0},
	"mushroom_stew":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 65, "buff_kind": "mining", "buff_secs": 60.0},
	"apple_jam":      {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 35, "buff_kind": "regen",  "buff_secs": 30.0},
	"jelly_pudding":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40, "buff_kind": "jump",   "buff_secs": 60.0},
```

- [ ] **Step 4: recipe_db.gd 加 8 道配方 + 改 cooked_meat**

把现有 `cooked_meat` 配方的 `"requires": "furnace"` 改成 `"requires": "pot"`。
新增 7 道（都 `requires:"pot"`）：
```gdscript
	{ "id": "bread", "grid_size": Vector2i(3, 1),
	  "pattern": [["wheat", "wheat", "wheat"]],
	  "output_id": "bread", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "mushroom_soup", "grid_size": Vector2i(2, 1),
	  "pattern": [["mushroom", "mushroom"]],
	  "output_id": "mushroom_soup", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "apple_pie", "grid_size": Vector2i(3, 1),
	  "pattern": [["apple", "apple", "wheat"]],
	  "output_id": "apple_pie", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "meat_skewer", "grid_size": Vector2i(3, 1),
	  "pattern": [["raw_meat", "raw_meat", "mushroom"]],
	  "output_id": "meat_skewer", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "mushroom_stew", "grid_size": Vector2i(3, 1),
	  "pattern": [["mushroom", "raw_meat", "mushroom"]],
	  "output_id": "mushroom_stew", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "apple_jam", "grid_size": Vector2i(3, 1),
	  "pattern": [["apple", "apple", "apple"]],
	  "output_id": "apple_jam", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "jelly_pudding", "grid_size": Vector2i(3, 1),
	  "pattern": [["slime_jelly", "slime_jelly", "apple"]],
	  "output_id": "jelly_pudding", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
```
> 用到的材料 id 都已存在：`wheat`、`mushroom`、`apple`、`raw_meat`、`slime_jelly`。

- [ ] **Step 5: crafting_panel.gd 加 7 道中文名**

`_ZH_NAMES` 加：
```gdscript
	"bread": "面包",
	"mushroom_soup": "蘑菇汤",
	"apple_pie": "苹果派",
	"meat_skewer": "烤肉串",
	"mushroom_stew": "蘑菇炖肉",
	"apple_jam": "苹果酱",
	"jelly_pudding": "果冻布丁",
```

- [ ] **Step 6: items_art.gd 画 7 道图标**

仿 `_APPLE`(items_art.gd:559) / `_COOKED_MEAT`(1281) 的 16×16 字符网格 + PALETTE 字母键写法，加 7 个 pattern 常量并在该文件的图标注册分支（`ItemsArt.get_icon` / item id→pattern 的 match）里注册。形状要可识别、暖色：
- `_BREAD` 面包：棕黄椭圆面包，顶部 3 道斜划痕。
- `_MUSHROOM_SOUP` 蘑菇汤：碗 + 汤面 + 露出的蘑菇块 + 热气点。
- `_APPLE_PIE` 苹果派：金棕派皮三角块 + 格纹。
- `_MEAT_SKEWER` 烤肉串：一根棕签串 3 块烤肉。
- `_MUSHROOM_STEW` 蘑菇炖肉：深碗 + 肉块 + 蘑菇 + 热气。
- `_APPLE_JAM` 苹果酱：玻璃罐 + 红酱 + 布盖。
- `_JELLY_PUDDING` 果冻布丁：粉橙半透明布丁 + 顶部高光（弹弹的）。
可复用 PALETTE 已有键（A/a 苹果红、M/m 肉粉、L 叶绿、S 棕、k 暖深灰等）；如缺色（如玻璃蓝、布丁粉）在 PALETTE 加 1-2 个暖色键。每个图标 16×16，用 `PixelArt.grid_to_texture(pattern, PALETTE)`。

- [ ] **Step 7: 重建索引 + 跑确认通过**

Run: `godot --headless --editor --quit` 然后 `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_dishes.gd -gexit`
Expected: PASS（3 个）

- [ ] **Step 8: 提交**
```bash
git log --oneline -3
git add scripts/items/item_db.gd scripts/crafting/recipe_db.gd scripts/ui/crafting_panel.gd scripts/art/items_art.gd tests/unit/test_dishes.gd
git commit -m "feat(cook): 8 道料理 (def+配方+中文名+美术), cooked_meat 改在锅做

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Buff HUD（屏幕显示 buff 图标 + 倒计时）

**Files:**
- Create: `scripts/ui/buff_hud.gd`
- Modify: `scenes/ui/hud.tscn`（加 BuffHUD 节点）
- Modify: `scripts/ui/hud.gd`（bind_player 里绑 buffs）
- Test: `tests/integration/test_buff_hud.gd`（新建）

- [ ] **Step 1: 写失败测试**

`tests/integration/test_buff_hud.gd`:
```gdscript
extends GutTest

const BuffHudClass = preload("res://scripts/ui/buff_hud.gd")
const BuffsClass = preload("res://scripts/player/player_buffs.gd")

func test_hud_reads_active_kinds():
	var buffs = BuffsClass.new()
	add_child_autofree(buffs)
	var hud = BuffHudClass.new()
	add_child_autofree(hud)
	hud.bind(buffs)
	buffs.apply("speed", 10.0)
	buffs.apply("mining", 10.0)
	# HUD 应能从 buffs 读到 2 个活跃 kind
	assert_eq(hud._active_kinds().size(), 2)
	buffs.apply("speed", 0.0)   # secs<=0 不生效, 仍是 2? apply 对 secs<=0 直接 return
	assert_eq(hud._active_kinds().size(), 2)
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_buff_hud.gd -gexit`
Expected: FAIL（脚本不存在）

- [ ] **Step 3: 实现 buff_hud.gd**

`scripts/ui/buff_hud.gd`:
```gdscript
# Buff HUD: 屏幕上一排 buff 图标 + 倒计时条. 绑 PlayerBuffs, 每帧重画 (有 buff 时).
# 图标 ≥ 20px (用户要求特效够明显). 4 种: speed/jump/mining/regen.
extends Control

const ICON_PX := 22
const ICON_GAP := 6
const PAD := 6
const BAR_H := 4

# 每种 buff 的底色 (暖色, 一眼区分)
const KIND_COLOR := {
	"speed":  Color8(90, 200, 120),    # 绿: 跑快
	"jump":   Color8(120, 170, 255),   # 蓝: 跳高
	"mining": Color8(230, 180, 70),    # 橙黄: 挖快
	"regen":  Color8(230, 90, 110),    # 红: 回血
}
# 8x8 像素字形 (X=画, .=透明)
const KIND_GLYPH := {
	"speed":  ["........","..XX.X..",".XXXXX..","XXXX.X..",".XXXXX..","..XX.X..","........","........"],
	"jump":   ["...XX...","..XXXX..",".XX..XX.","X.X..X.X","...XX...","...XX...","..XXXX..","........"],
	"mining": [".....XX.","....XXX.","...XXX..","..XXX.X.",".XXX..X.","XXX.....","X.......","........"],
	"regen":  [".XX..XX.","XXXXXXXX","XXXXXXXX",".XXXXXX.","..XXXX..","...XX...","........","........"],
}

var _buffs: Node = null


func bind(buffs_node: Node) -> void:
	_buffs = buffs_node
	if _buffs != null and _buffs.has_signal("buffs_changed"):
		_buffs.buffs_changed.connect(func(): queue_redraw())
	queue_redraw()


func _active_kinds() -> Array:
	if _buffs == null:
		return []
	return _buffs.active_kinds()


func _process(_delta: float) -> void:
	# 有 buff 时每帧重画 (倒计时条平滑). 没 buff 不画, 省开销.
	if _buffs != null and not _buffs.active_kinds().is_empty():
		queue_redraw()


func _draw() -> void:
	if _buffs == null:
		return
	var kinds: Array = _buffs.active_kinds()
	var x: float = PAD
	for kind in kinds:
		var col: Color = KIND_COLOR.get(kind, Color.WHITE)
		# 圆角底块
		draw_rect(Rect2(x, PAD, ICON_PX, ICON_PX), col)
		draw_rect(Rect2(x, PAD, ICON_PX, ICON_PX), Color(0, 0, 0, 0.6), false, 2.0)
		# 像素字形
		var glyph: Array = KIND_GLYPH.get(kind, [])
		if glyph.size() == 8:
			var cell: float = ICON_PX / 8.0
			for row in 8:
				var s: String = glyph[row]
				for c in 8:
					if s[c] == "X":
						draw_rect(Rect2(x + c * cell, PAD + row * cell, cell + 0.5, cell + 0.5), Color(0.1, 0.1, 0.1))
		# 倒计时条 (底部, 随剩余缩短)
		var frac: float = _buffs.remaining_frac(kind)
		draw_rect(Rect2(x, PAD + ICON_PX + 1, ICON_PX, BAR_H), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(x, PAD + ICON_PX + 1, ICON_PX * frac, BAR_H), col)
		x += ICON_PX + ICON_GAP
```

- [ ] **Step 4: hud.tscn 加 BuffHUD 节点**

打开 `scenes/ui/hud.tscn`，仿 `HealthHUD`（Control, 锚右上）加：
1. 顶部 `[ext_resource type="Script" path="res://scripts/ui/buff_hud.gd" id="<新id>"]`。
2. 一个 Control 节点（放在血条下方，左上角即可，避免和血条重叠）：
```
[node name="BuffHUD" type="Control" parent="."]
anchors_preset = 0
offset_left = 12.0
offset_top = 12.0
offset_right = 320.0
offset_bottom = 50.0
script = ExtResource("<上面的id>")
```
（左上角横排；若与小地图/hotbar 冲突，挪到 offset_top 更大处。）

- [ ] **Step 5: hud.gd bind_player 里绑 buffs**

在 `hud.gd` 顶部加 `@onready var buff_hud: Control = $BuffHUD`（节点名与 tscn 一致）。
在 `bind_player()` 里、绑 mana 之后加：
```gdscript
	var buffs: Node = player.get_node_or_null("PlayerBuffs")
	if buffs != null and buff_hud != null and buff_hud.has_method("bind"):
		buff_hud.bind(buffs)
```

- [ ] **Step 6: 跑确认通过**

Run: `godot --headless --editor --quit` 然后 `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_buff_hud.gd -gexit`
Expected: PASS

- [ ] **Step 7: 提交**
```bash
git log --oneline -3
git add scripts/ui/buff_hud.gd scenes/ui/hud.tscn scripts/ui/hud.gd tests/integration/test_buff_hud.gd
git commit -m "feat(buffs): Buff HUD 图标 + 倒计时条, 接入 HUD

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 端到端集成 + 全测试回归

**Files:**
- Test: `tests/integration/test_cooking_end_to_end.gd`（新建）

- [ ] **Step 1: 写端到端测试**

`tests/integration/test_cooking_end_to_end.gd`:
```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")

# 吃带 buff 的料理 → 回血 + buff 生效 + 消耗 1
func test_eat_dish_applies_buff():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var hp: Node = player.get_node("PlayerHealth")
	var buffs: Node = player.get_node("PlayerBuffs")
	var pa: Node = player.get_node("PlayerAction")
	# 掉点血, 拿一份面包 (speed buff)
	hp.current_health = 50
	inv.inventory.add("bread", 2)
	inv.select_hotbar(0) if inv.has_method("select_hotbar") else null
	# 模拟"按住吃" 2.1 秒
	pa.secondary_held_override = true
	for i in 130:
		pa._update_eat_or_place(1.0 / 60.0)
	assert_gt(hp.current_health, 50, "面包应回血")
	assert_true(buffs.is_active("speed"), "面包应给 speed buff")
	# 至少消耗了 1 个面包
	var total: int = 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "bread":
			total += slot.count
	assert_lt(total, 2, "应消耗 1 个面包")
```
> 若 `select_hotbar` / `inventory.slots` / `secondary_held_override` 名称与现有代码不符，照 `tests/integration/test_craft_loop.gd` 与 player_action.gd 里实际 API 调整。

- [ ] **Step 2: 跑确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_cooking_end_to_end.gd -gexit`
Expected: PASS

- [ ] **Step 3: 全套回归**

Run:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 全绿（统计累计测试数，写进给用户的报告）。
若有红：用 systematic-debugging 排查；常见坑——新 class/tile 没重建索引、tscn 节点名拼错、material id 不存在。

- [ ] **Step 4: 提交**
```bash
git log --oneline -3
git add tests/integration/test_cooking_end_to_end.gd
git commit -m "test(cook): 厨房端到端 (吃料理→回血+buff+消耗)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## 计划自查（spec 覆盖 / 一致性）

- **自然回血** → Task 1 ✅
- **Buff 系统（4 种 + 刷新/叠加 + regen 回血）** → Task 2 ✅
- **跑/跳/挖接线** → Task 3 ✅
- **吃料理触发 buff + 血满能吃 buff 料理** → Task 4 ✅
- **锅 tile + 注册 + item + 中文名 + 美术** → Task 5 ✅
- **锅只能叠炉子上 + 做饭检测 + 配方过滤 + 锅配方** → Task 6 ✅
- **锅发光** → Task 7 ✅
- **8 道料理（含 cooked_meat 改锅做）+ 中文名 + 美术** → Task 8 ✅
- **Buff HUD** → Task 9 ✅
- **端到端 + 回归** → Task 10 ✅

**命名一致性自查：** buff kind 字符串全程用 `"speed"/"jump"/"mining"/"regen"`；ItemDB 字段 `buff_kind`/`buff_secs`；helper `food_buff_kind`/`food_buff_secs`/`food_has_buff`；controller `_buff_speed_mul`/`_buff_jump_mul`，action `_buff_mining_mul`；PlayerBuffs API `apply/is_active/remaining/remaining_frac/active_kinds/speed_mul/jump_mul/mining_mul`；tile `Tiles.COOKING_POT`(74)，item `"cooking_pot"`，配方 `requires:"pot"`。已核对前后一致。

## 实现期需现场确认（非阻塞）

1. blocks_art.gd 里 FURNACE pattern 的实际网格尺寸（16×16 还是别的）+ 贴图注册函数名 —— 照文件实际写法，别硬套。
2. items_art.gd 图标注册分支的实际函数/match 形式 —— 照 `_APPLE`/`_COOKED_MEAT` 实际注册处加。
3. player.tscn / hud.tscn 的 ext_resource id 取未占用值；节点名与 hud.gd 的 `$BuffHUD` 对齐。
4. 集成测试里 `world.get_player()`/`get_terrain()`/`inv.select_hotbar`/`inv.inventory.slots`/`pa.secondary_held_override`/`pa.aim_override` 等 API 名以现有测试 + 源码为准（本计划按 `test_craft_loop.gd` 与抽取到的源码命名，若有出入就地对齐）。
5. recipe `rotate_ok` 字段：横排料理加了 `rotate_ok:true` 方便竖摆也能合；若 RecipeMatcher 不支持 rotate_ok 则去掉，仅靠 mirror_ok。
