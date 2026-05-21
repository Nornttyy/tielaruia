# 饱食度系统 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 teilaruia 加饱食度系统：10 颗鸡腿条 + 10 分钟被动衰减 + 饿坏 -20% 攻击 + 高位回 HP；2 种食物（slime_jelly / apple）+ 右键长按 1s 进食；HUD 红心下方、饿坏抖动；死亡复活回满。

**Architecture:** 新增 `PlayerHunger` 节点（与 `PlayerHealth` 对称结构），单向依赖 `PlayerHealth.heal()`。HUD 加 `HungerHUD` 控件，复用 hearts 的 build / cache 模式（`DrumstickArt` + `ArtCache.drumstick_*`）。进食在 `player_action.gd` 的右键 handler 里插一段状态机，与放置互斥（食物 `placeable_tile_id == -1`）。

**Tech Stack:** Godot 4.3 + GDScript；测试用 GUT（已配 `--editor --quit` 流程）。

**Spec:** `docs/superpowers/specs/2026-05-21-hunger-system-design.md`

**Save 字段持久化暂缓**：项目当前无存档系统（grep `user://` 零结果）。本计划只实现 spec §9 的"死亡复活满鸡腿"（在 `world.gd:174` 现有 `revive_full()` 调用旁加 `refill_full()`），不实现读写文件。等通用 save 系统落地后另起 PR 补 `hunger` 字段。

---

## 文件结构

| 路径 | 操作 | 责任 |
|---|---|---|
| `scripts/player/player_hunger.gd` | 新建 | 饱食度数据 + 衰减/回血计时器 + 信号 |
| `scenes/player/player.tscn` | 改 | 加 `PlayerHunger` 子节点 |
| `scripts/items/item_db.gd` | 改 | 加 `slime_jelly`/`apple` 条目 + 删除 `slime_ball` + 加 `is_food()`/`food_fill()` |
| `scripts/entities/slime.gd:124` | 改 | 掉落字符串 `"slime_ball"` → `"slime_jelly"` |
| `scripts/world/tile_data.gd` | 改 | LEAVES / LEAVES_PINE / LEAVES_AUTUMN drops 各加 `["apple", 5, 1, 1]` |
| `scripts/player/player_action.gd:56-57` | 改 | 右键 handler 改为"食物 → 进食状态机"或"否则 → try_place"；攻击伤害乘 `get_attack_multiplier()` |
| `scripts/world/world.gd:174` 旁 | 改 | `revive_full()` 后加 `refill_full()` |
| `scripts/art/drumstick_art.gd` | 新建 | `build_full()` / `build_half()` / `build_empty()` — 10×10 像素鸡腿 |
| `scripts/art/items_art.gd` | 改 | 加 `_SLIME_JELLY` / `_APPLE` 网格 + 删 `_SLIME_BALL` + 改 `_ICONS` 映射 |
| `scripts/autoload/art_cache.gd` | 改 | 加 `drumstick_*` 字段 + `_build_drumsticks()` + `_build_items()` 列表替换 `slime_ball` → `slime_jelly`, 加 `apple` |
| `scripts/ui/hunger_hud.gd` | 新建 | 镜像 `health_hud.gd`，10 颗鸡腿 + 饿坏抖动 |
| `scenes/ui/hud.tscn` | 改 | 加 `HungerHUD` 节点，位置在 `HealthHUD` 下方 |
| `scripts/ui/hud.gd` | 改 | `bind_player` 加 `hunger_hud.bind(...)` 4 行 |
| `tests/unit/test_player_hunger.gd` | 新建 | 10 个断言（衰减/consume/debuff/回血/refill/信号） |
| `tests/integration/test_eat_food.gd` | 新建 | 4 个断言（吃成功/中断/已满/不放置） |

---

## Task 1: PlayerHunger 数据节点 + 衰减/信号

**Files:**
- Create: `scripts/player/player_hunger.gd`
- Test: `tests/unit/test_player_hunger.gd`

### - [ ] Step 1: 写测试文件（覆盖前 5 项断言）

Create `tests/unit/test_player_hunger.gd`：

```gdscript
extends GutTest

const PlayerHunger = preload("res://scripts/player/player_hunger.gd")

var hunger: Node

func before_each() -> void:
    hunger = PlayerHunger.new()
    # 不挂在 tree 下，_physics_process 手动调
    add_child_autofree(hunger)


func test_initial_full() -> void:
    assert_eq(int(hunger.current), PlayerHunger.MAX)


func test_deplete_one_minute() -> void:
    # 60 步 × 1.0s = 60s；10 分钟掉 100 → 1 分钟掉 ~10
    for _i in 60:
        hunger._physics_process(1.0)
    assert_between(int(hunger.current), 89, 91)


func test_consume_clamps_to_max() -> void:
    hunger.current = 80.0
    hunger.consume(30)
    assert_eq(int(hunger.current), 100)


func test_consume_normal() -> void:
    hunger.current = 50.0
    hunger.consume(30)
    assert_eq(int(hunger.current), 80)


func test_consume_zero_or_negative_noop() -> void:
    hunger.current = 50.0
    hunger.consume(0)
    assert_eq(int(hunger.current), 50)
    hunger.consume(-5)
    assert_eq(int(hunger.current), 50)


func test_attack_multiplier_threshold() -> void:
    hunger.current = 29.0
    assert_eq(hunger.get_attack_multiplier(), 0.8)
    hunger.current = 30.0
    assert_eq(hunger.get_attack_multiplier(), 1.0)
    hunger.current = 100.0
    assert_eq(hunger.get_attack_multiplier(), 1.0)


func test_refill_full_emits_signal() -> void:
    hunger.current = 20.0
    watch_signals(hunger)
    hunger.refill_full()
    assert_eq(int(hunger.current), 100)
    assert_signal_emitted(hunger, "hunger_changed")


func test_is_hungry() -> void:
    hunger.current = 29.0
    assert_true(hunger.is_hungry())
    hunger.current = 30.0
    assert_false(hunger.is_hungry())


func test_signal_only_on_integer_cross() -> void:
    hunger.current = 50.0
    watch_signals(hunger)
    # 很小的 delta，不应跨整数
    hunger._physics_process(0.01)
    assert_signal_emit_count(hunger, "hunger_changed", 0)
```

### - [ ] Step 2: 运行测试，确认全部失败（文件不存在）

```bash
cd /workspace/teilaruia && godot --headless --path . --editor --quit 2>/dev/null; godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_hunger.gd -gexit
```

Expected: 大量 ERROR "Could not load script ...player_hunger.gd" 或测试全 FAIL。

### - [ ] Step 3: 实现 PlayerHunger（不含回血部分）

Create `scripts/player/player_hunger.gd`：

```gdscript
# 玩家饱食度节点。挂在 Player 下。
# 信号: hunger_changed(cur,max)
# 与 PlayerHealth 对称。
extends Node

signal hunger_changed(current: int, maximum: int)

const MAX := 100
const DEPLETE_PER_SEC := 100.0 / (10.0 * 60.0)  # ≈0.1667，10 分钟掉满
const HUNGRY_THRESHOLD := 30                     # < 30 → 攻击 debuff + HUD 抖动
const HEAL_THRESHOLD := 80                       # ≥ 80 → 自动回 HP
const HEAL_INTERVAL_SEC := 5.0
const HEAL_AMOUNT := 1
const HUNGRY_ATK_MULT := 0.8

var current: float = float(MAX)
var _heal_timer: float = 0.0
var _last_emit_int: int = MAX


func _physics_process(delta: float) -> void:
    current = max(0.0, current - DEPLETE_PER_SEC * delta)
    _tick_heal(delta)
    _maybe_emit()


func consume(amount: int) -> void:
    if amount <= 0:
        return
    current = min(float(MAX), current + float(amount))
    _maybe_emit()


func refill_full() -> void:
    current = float(MAX)
    _heal_timer = 0.0
    _maybe_emit()


func get_attack_multiplier() -> float:
    return HUNGRY_ATK_MULT if int(current) < HUNGRY_THRESHOLD else 1.0


func is_hungry() -> bool:
    return int(current) < HUNGRY_THRESHOLD


func emit_state() -> void:
    # 公共方法：HUD 绑定或加载存档时强制同步一次
    _last_emit_int = -1
    _maybe_emit()


func _tick_heal(_delta: float) -> void:
    # Task 2 接 PlayerHealth；此处先空实现，保持帧逻辑结构。
    pass


func _maybe_emit() -> void:
    var cur_i := int(current)
    if cur_i != _last_emit_int:
        _last_emit_int = cur_i
        hunger_changed.emit(cur_i, MAX)
```

### - [ ] Step 4: 运行测试，确认 9 个全过

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_hunger.gd -gexit
```

Expected: 9 passing, 0 failing。

### - [ ] Step 5: 提交

```bash
git add scripts/player/player_hunger.gd tests/unit/test_player_hunger.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(player): PlayerHunger 节点 (10 分钟衰减 + debuff 阈值 + 信号)"
```

---

## Task 2: 接通 PlayerHealth 自动回血

**Files:**
- Modify: `scripts/player/player_hunger.gd`（`_tick_heal` 内填实现）
- Test: `tests/unit/test_player_hunger.gd`（加 3 个断言）

### - [ ] Step 1: 加测试（用 mock PlayerHealth）

在 `tests/unit/test_player_hunger.gd` 末尾追加：

```gdscript
# --- 回血相关 ---

class MockHealth:
    extends Node
    var current_health: int = 10
    var MAX_HEALTH: int = 20
    var _alive: bool = true

    func is_alive() -> bool:
        return _alive

    func heal(amount: int) -> void:
        current_health = min(MAX_HEALTH, current_health + amount)


func test_heal_when_well_fed() -> void:
    var mh := MockHealth.new()
    add_child_autofree(mh)
    hunger.add_sibling_or_parent_dummy(mh) if false else null
    hunger.set_health_node_for_test(mh)
    hunger.current = 90.0
    mh.current_health = 10
    # 5 秒应触发一次 +1
    hunger._physics_process(5.0)
    assert_eq(mh.current_health, 11)


func test_no_heal_when_hungry() -> void:
    var mh := MockHealth.new()
    add_child_autofree(mh)
    hunger.set_health_node_for_test(mh)
    hunger.current = 70.0
    mh.current_health = 10
    hunger._physics_process(5.0)
    assert_eq(mh.current_health, 10)


func test_no_heal_when_full_hp() -> void:
    var mh := MockHealth.new()
    add_child_autofree(mh)
    hunger.set_health_node_for_test(mh)
    hunger.current = 90.0
    mh.current_health = 20  # 满
    hunger._physics_process(5.0)
    assert_eq(mh.current_health, 20)
```

注：`set_health_node_for_test` 是测试钩子，下一步加。

### - [ ] Step 2: 运行测试，确认 3 个新断言失败

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_hunger.gd -gexit
```

Expected: 之前 9 个仍过；新增 3 个 FAIL（`set_health_node_for_test` 不存在 / 回血未生效）。

### - [ ] Step 3: 实现回血 + 测试钩子

Modify `scripts/player/player_hunger.gd`：

```gdscript
# 在变量区加：
var _health_override: Node = null  # 测试注入用

# 在 _physics_process 之前加：
func set_health_node_for_test(h: Node) -> void:
    _health_override = h

func _get_health() -> Node:
    if _health_override != null:
        return _health_override
    var parent := get_parent()
    return null if parent == null else parent.get_node_or_null("PlayerHealth")
```

并把 `_tick_heal` 替换为：

```gdscript
func _tick_heal(delta: float) -> void:
    var hp: Node = _get_health()
    if hp == null or not hp.is_alive():
        _heal_timer = 0.0
        return
    if int(current) < HEAL_THRESHOLD:
        _heal_timer = 0.0
        return
    if hp.current_health >= hp.MAX_HEALTH:
        _heal_timer = 0.0
        return
    _heal_timer += delta
    if _heal_timer >= HEAL_INTERVAL_SEC:
        _heal_timer -= HEAL_INTERVAL_SEC
        hp.heal(HEAL_AMOUNT)
```

### - [ ] Step 4: 运行测试，确认 12 个全过

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_player_hunger.gd -gexit
```

Expected: 12 passing, 0 failing。

### - [ ] Step 5: 提交

```bash
git add scripts/player/player_hunger.gd tests/unit/test_player_hunger.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(player): 饱食 ≥ 80 时 5s/+1 HP 自动回血"
```

---

## Task 3: 挂到 Player 场景

**Files:**
- Modify: `scenes/player/player.tscn`

### - [ ] Step 1: 检查现有 player.tscn 结构

```bash
cat /workspace/teilaruia/scenes/player/player.tscn | head -30
```

记下 `PlayerHealth` 节点的写法。

### - [ ] Step 2: 加 PlayerHunger 节点

仿照 `PlayerHealth` 子节点的写法，在 `scenes/player/player.tscn` 加：

```
[ext_resource type="Script" path="res://scripts/player/player_hunger.gd" id="N_hunger"]

[node name="PlayerHunger" type="Node" parent="."]
script = ExtResource("N_hunger")
```

（`N_hunger` 取下一个空 id；按 tscn 文件实际格式调整 `load_steps`。）

### - [ ] Step 3: 提交

```bash
git add scenes/player/player.tscn
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(player): 玩家场景挂 PlayerHunger 子节点"
```

---

## Task 4: ItemDB 扩展 + slime_ball → slime_jelly 重命名

**Files:**
- Modify: `scripts/items/item_db.gd`
- Modify: `scripts/entities/slime.gd:124`

### - [ ] Step 1: 改 item_db.gd

把 `_DEFS` 字典里 `"slime_ball": ...` 行删掉，新增两行：

```gdscript
"slime_jelly": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40},
"apple":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
```

在文件末尾追加两个查询函数：

```gdscript
func is_food(item_id: String) -> bool:
    var def = get_def(item_id)
    return def != null and def.get("food_fill", 0) > 0


func food_fill(item_id: String) -> int:
    var def = get_def(item_id)
    return 0 if def == null else def.get("food_fill", 0)
```

注意：现有所有非食物 entries 没 `food_fill` 字段；`.get("food_fill", 0)` 默认 0，等价"不是食物"。

### - [ ] Step 2: 改 slime.gd

在 `scripts/entities/slime.gd:124`，把：

```gdscript
_spawn_drop("slime_ball")
```

改成：

```gdscript
_spawn_drop("slime_jelly")
```

### - [ ] Step 3: grep 确认没遗漏

```bash
cd /workspace/teilaruia && grep -rn "slime_ball" scripts/ tests/ 2>/dev/null
```

Expected: 零结果（不算 `slime_jelly` 子串匹配；用 `grep -w "slime_ball"` 确认）。

```bash
grep -rwn "slime_ball" scripts/ tests/ 2>/dev/null
```

Expected: 零结果。

### - [ ] Step 4: 提交

```bash
git add scripts/items/item_db.gd scripts/entities/slime.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(items): slime_ball → slime_jelly (food_fill 40) + 加 apple (food_fill 25)"
```

---

## Task 5: leaves 5% 掉 apple

**Files:**
- Modify: `scripts/world/tile_data.gd`

### - [ ] Step 1: 改三个 leaves 条目的 drops

在 `scripts/world/tile_data.gd` 找到 `LEAVES`、`LEAVES_PINE`、`LEAVES_AUTUMN` 三个条目，把 `drops` 字段从单元素改为双元素：

```gdscript
LEAVES: {
    "solid": false, "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["leaves", 100, 1, 1], ["apple", 5, 1, 1]],
},
LEAVES_PINE: {
    "solid": false, "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["pine_leaves", 100, 1, 1], ["apple", 5, 1, 1]],
},
LEAVES_AUTUMN: {
    "solid": false, "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["autumn_leaves", 100, 1, 1], ["apple", 5, 1, 1]],
},
```

### - [ ] Step 2: 提交

```bash
git add scripts/world/tile_data.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(world): 3 种 leaves 各 5% 掉 apple"
```

---

## Task 6: 进食状态机（player_action.gd 右键改造）

**Files:**
- Modify: `scripts/player/player_action.gd`
- Test: `tests/integration/test_eat_food.gd`

### - [ ] Step 1: 写集成测试

Create `tests/integration/test_eat_food.gd`：

```gdscript
extends GutTest

const PlayerScene = preload("res://scenes/player/player.tscn")

var player: CharacterBody2D
var action: Node
var inv_node: Node
var hunger: Node


func before_each() -> void:
    player = PlayerScene.instantiate()
    add_child_autofree(player)
    action = player.get_node("PlayerAction")
    inv_node = player.get_node("PlayerInventory")
    hunger = player.get_node("PlayerHunger")
    # 不依赖 terrain（吃东西不需要）；如有依赖跳过 _physics_process 别的分支
    action.aim_override = Vector2i(0, 0)  # 测试占位


func _give_food(item_id: String, count: int, slot: int = 0) -> void:
    inv_node.inventory.slots[slot] = {"item_id": item_id, "count": count}
    inv_node.set_hotbar_selection(slot)


func _slot_count(slot: int) -> int:
    var s = inv_node.inventory.slots[slot]
    return 0 if s == null else int(s.count)


func test_eat_slime_jelly_success() -> void:
    _give_food("slime_jelly", 1)
    hunger.current = 50.0
    # 模拟按住右键 1.0s
    action.set_secondary_held_for_test(true)
    action._physics_process(1.0)
    assert_eq(int(hunger.current), 90)
    assert_eq(_slot_count(0), 0)


func test_eat_release_before_1s_cancels() -> void:
    _give_food("slime_jelly", 1)
    hunger.current = 50.0
    action.set_secondary_held_for_test(true)
    action._physics_process(0.5)
    action.set_secondary_held_for_test(false)
    action._physics_process(0.01)
    # 饱食只衰减一点点；jelly 没被吃掉
    assert_between(int(hunger.current), 49, 50)
    assert_eq(_slot_count(0), 1)


func test_eat_no_op_when_full() -> void:
    _give_food("slime_jelly", 1)
    hunger.current = 100.0
    action.set_secondary_held_for_test(true)
    action._physics_process(1.0)
    assert_eq(_slot_count(0), 1)
    # 饱食只是被动衰减少量
    assert_between(int(hunger.current), 99, 100)


func test_eat_does_not_place_block() -> void:
    _give_food("slime_jelly", 1)
    # food 的 placeable_tile_id == -1，try_place 内部 is_placeable 检查会 return false。
    # 上面 success 测试断言了库存只扣 1（来自吃），不是 2（吃 + 放置）。
    # 这里再额外断言：饱食满后再按一次右键，不应触发放置（无 terrain，仅检查无 crash + 库存稳定）
    hunger.current = 100.0
    action.set_secondary_held_for_test(true)
    action._physics_process(0.5)
    assert_eq(_slot_count(0), 1)
```

依赖的接口（已对齐现有代码）：
- `Inventory.slots[i]` —— `null` 或 `{"item_id": String, "count": int}` dict
- `PlayerInventory.set_hotbar_selection(idx)` —— `scripts/player/player_inventory.gd:31`
- `PlayerInventory.consume_current(n)` —— `scripts/player/player_inventory.gd:70`
- `PlayerInventory.current_hotbar_slot() -> Variant` —— 返回 dict 或 null
- `PlayerAction.set_secondary_held_for_test(bool)` —— Task 6 Step 3 内加。

### - [ ] Step 2: 跑一次测试，确认全 FAIL

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_eat_food.gd -gexit
```

Expected: FAIL（接口未实现）。把出错的 missing method 名记下。

### - [ ] Step 3: 改 player_action.gd

在 `scripts/player/player_action.gd` 类变量区（第 21-26 行 `aim_override` 等附近）加：

```gdscript
var secondary_held_override: Variant = null  # null = 真实输入；bool = 强制（测试）

# 进食状态
var _eat_t: float = 0.0
var _eat_item_id: String = ""

const EAT_DURATION_SEC := 1.0


func set_secondary_held_for_test(held: bool) -> void:
    secondary_held_override = held
```

把 `_physics_process` 第 53-57 行：

```gdscript
if place_override:
    try_place()
    place_override = false
if Input.is_action_just_pressed("secondary"):
    try_place()
```

替换为：

```gdscript
_update_eat_or_place(delta)
```

并在文件末尾加新方法：

```gdscript
func _update_eat_or_place(delta: float) -> void:
    var held: bool = (secondary_held_override == true) if secondary_held_override != null \
            else Input.is_action_pressed("secondary")
    var just: bool = Input.is_action_just_pressed("secondary") and secondary_held_override == null

    # 测试旁路（保留原有 place_override）
    if place_override:
        try_place()
        place_override = false
        return

    var inv: Node = _inventory_node()
    var slot = null if inv == null else inv.current_hotbar_slot()
    var holding_food: bool = slot != null and ItemDB.is_food(slot.item_id)
    var hunger: Node = get_parent().get_node_or_null("PlayerHunger")

    # 持食物 + 按住 + 没吃饱 → 进入/保持 eating
    if holding_food and held and hunger != null and int(hunger.current) < hunger.MAX:
        if _eat_item_id != slot.item_id:
            _eat_item_id = slot.item_id
            _eat_t = 0.0
        _eat_t += delta
        if _eat_t >= EAT_DURATION_SEC:
            _eat_t = 0.0
            hunger.consume(ItemDB.food_fill(slot.item_id))
            inv.consume_current(1)
        return

    # 取消进食
    if _eat_t > 0.0:
        _eat_t = 0.0
        _eat_item_id = ""

    # 退回放置逻辑（与原行为一致）
    if just:
        try_place()
```

### - [ ] Step 4: 检查 inventory 接口实际名

```bash
grep -n "func " /workspace/teilaruia/scripts/player/player_inventory.gd /workspace/teilaruia/scripts/items/inventory.gd
```

对齐 Step 1 测试和 Step 3 实现里用到的方法名（`set_slot` / `slot_count` / `consume_current` / `current_hotbar_slot` 等），有差异的按实际改测试。

### - [ ] Step 5: 跑测试，期望全过

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_eat_food.gd -gexit
```

Expected: 4 passing。也跑一次完整套件确认没回归：

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

Expected: 全绿。

### - [ ] Step 6: 提交

```bash
git add scripts/player/player_action.gd tests/integration/test_eat_food.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(player): 右键长按 1s 吃食物 (与放置互斥)"
```

---

## Task 7: 攻击伤害乘 hunger multiplier

**Files:**
- Modify: `scripts/player/player_action.gd`（`_swing_sword` / `_sword_damage`）
- Test: `tests/integration/test_eat_food.gd`（追加 1 个断言）

### - [ ] Step 1: 加测试

在 `tests/integration/test_eat_food.gd` 末尾追加：

```gdscript
func test_hungry_attack_damage_reduced() -> void:
    _give_food("wood_sword", 1)
    hunger.current = 29.0
    # 木剑 base 4 → 0.8 → 3.2 → max(1, round(3.2)) = 3
    var dmg := action._effective_sword_damage()
    assert_eq(dmg, 3)

    hunger.current = 30.0
    dmg = action._effective_sword_damage()
    assert_eq(dmg, 4)
```

### - [ ] Step 2: 跑测试，确认 FAIL（`_effective_sword_damage` 不存在）

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_eat_food.gd:test_hungry_attack_damage_reduced -gexit
```

Expected: FAIL。

### - [ ] Step 3: 加 `_effective_sword_damage` + 接到 `_swing_sword`

在 `scripts/player/player_action.gd` `_sword_damage()` 函数下方加：

```gdscript
func _effective_sword_damage() -> int:
    var base: int = _sword_damage()
    if base <= 0:
        return 0
    var hunger: Node = get_parent().get_node_or_null("PlayerHunger")
    var mult: float = 1.0 if hunger == null else hunger.get_attack_multiplier()
    return max(1, int(round(float(base) * mult)))
```

把 `_swing_sword()` 里第 308 行：

```gdscript
var damage: int = _sword_damage()
```

改为：

```gdscript
var damage: int = _effective_sword_damage()
```

### - [ ] Step 4: 跑测试

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_eat_food.gd -gexit
```

Expected: 5 passing。

### - [ ] Step 5: 提交

```bash
git add scripts/player/player_action.gd tests/integration/test_eat_food.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(combat): 饿坏时攻击 ×0.8 (max 1 保底)"
```

---

## Task 8: 鸡腿像素美术 + ArtCache

**Files:**
- Create: `scripts/art/drumstick_art.gd`
- Modify: `scripts/art/items_art.gd`
- Modify: `scripts/autoload/art_cache.gd`

### - [ ] Step 1: 写 DrumstickArt（仿 HeartsArt 结构）

先查现有 `scripts/art/hearts_art.gd` 的接口：

```bash
cat /workspace/teilaruia/scripts/art/hearts_art.gd | head -30
```

Create `scripts/art/drumstick_art.gd`：

```gdscript
# 10×10 像素鸡腿: 棕褐肉身 + 浅黄高光 + 深棕骨。
# 满 / 半 / 空 三态。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
    ".": Color(0, 0, 0, 0),
    "K": Color8(67, 40, 24),       # 深棕轮廓
    "H": Color8(141, 93, 53),      # 棕基
    "h": Color8(168, 116, 69),     # 棕浅
    "y": Color8(212, 160, 90),     # 高光
    "w": Color8(238, 220, 180),    # 骨色
    "g": Color8(80, 80, 80),       # 空态灰
    "G": Color8(50, 50, 50),
}

# 完整鸡腿：球状肉头 (右上) + 骨杆 (左下)
const _FULL := [
    "....KKKK..",
    "...KHHHHK.",
    "..KHyyhHHK",
    ".KHyyyhHHK",
    ".KHhhhHHHK",
    "KwHHHHHK..",
    "Kww..KK...",
    ".Kw.......",
    "..K.......",
    "..........",
]

# 左半边鸡腿：只画左侧 5 列
const _HALF := [
    "....K.....",
    "...KH.....",
    "..KHy.....",
    ".KHyy.....",
    ".KHhh.....",
    "KwHHH.....",
    "Kww.......",
    ".Kw.......",
    "..K.......",
    "..........",
]

# 空态：灰色轮廓
const _EMPTY := [
    "....gggg..",
    "...gGGGGg.",
    "..gGggGGGg",
    ".gGgggGGGg",
    ".gGgggGGGg",
    "gGGGGGGg..",
    "Ggg..gg...",
    ".Gg.......",
    "..g.......",
    "..........",
]


static func build_full() -> ImageTexture:
    return PixelArt.grid_to_texture(_FULL, PALETTE)


static func build_half() -> ImageTexture:
    return PixelArt.grid_to_texture(_HALF, PALETTE)


static func build_empty() -> ImageTexture:
    return PixelArt.grid_to_texture(_EMPTY, PALETTE)
```

如果 `hearts_art.gd` 的接口名不是 `build_full/half/empty`，按它的对齐（用 grep 验证：`grep "static func" scripts/art/hearts_art.gd`）。

### - [ ] Step 2: 改 items_art.gd（加 slime_jelly + apple，删 slime_ball）

在 `scripts/art/items_art.gd` PALETTE 里加 apple 用色：

```gdscript
"A": Color8(220, 50, 50),   # 苹果红
"a": Color8(255, 100, 90),  # 苹果高光
"L": Color8(80, 140, 60),   # 叶绿
"S": Color8(110, 70, 30),   # 苹果梗棕
```

把 `_SLIME_BALL` 网格保留（pixels 还是绿色果冻）但改名为 `_SLIME_JELLY`：

```gdscript
# 史莱姆果冻：绿色块状 + 黄高光（比 slime_ball 视觉略立方一点）
const _SLIME_JELLY := [
    "................",
    "...oqqqqqqo.....",
    "..oqqqqqqqqo....",
    "..oqqyyqqqqo....",
    "..oqyyqqqqqo....",
    "..oqqqqqqqqo....",
    "..oqqqqqqqqo....",
    "..oqqqqqqqqo....",
    "..oqqqqqqqqo....",
    "..oqOOOOOOqo....",
    "..oOOOOOOOOo....",
    "...OOOOOOOO.....",
    "................",
    "................",
    "................",
    "................",
]

const _APPLE := [
    "................",
    "........S.......",
    ".......LSL......",
    "......LSLL......",
    ".....AAAaA......",
    "....AaaaaaA.....",
    "...AaaaaaaA.....",
    "...AaaAAaaaA....",
    "...AaaAaaaaA....",
    "...AAaaaaaAA....",
    "....AaaaaaA.....",
    "....AAaaaAA.....",
    ".....AAAAA......",
    "......AAA.......",
    "................",
    "................",
]
```

把 `_ICONS` 字典里 `"slime_ball": _SLIME_BALL` 改为：

```gdscript
"slime_jelly": _SLIME_JELLY,
"apple": _APPLE,
```

删 `_SLIME_BALL` 常量（已不引用）。

### - [ ] Step 3: 改 art_cache.gd

在 `scripts/autoload/art_cache.gd`：

变量区加：

```gdscript
const DrumstickArt = preload("res://scripts/art/drumstick_art.gd")

var drumstick_full: ImageTexture
var drumstick_half: ImageTexture
var drumstick_empty: ImageTexture
```

`_ready()` 内加：

```gdscript
_build_drumsticks()
```

加方法：

```gdscript
func _build_drumsticks() -> void:
    drumstick_full = DrumstickArt.build_full()
    drumstick_half = DrumstickArt.build_half()
    drumstick_empty = DrumstickArt.build_empty()
```

`_build_items()` 列表改：

```gdscript
for item_id in ["wood_sword", "wood_pickaxe", "wood_axe", "slime_jelly", "apple",
        "stone_sword", "stone_pickaxe", "stone_axe"]:
    item_icons[item_id] = ItemsArt.get_icon(item_id)
```

### - [ ] Step 4: 启动游戏一次，确认无加载错误

```bash
cd /workspace/teilaruia && timeout 5 godot --headless --path . 2>&1 | head -40
```

Expected: 不出现 "未知物品 icon" / "Could not load script" 等致命错误。如有 push_warning 关于 slime_ball 没人引用是可以的（因为已经无人用）。

### - [ ] Step 5: 提交

```bash
git add scripts/art/drumstick_art.gd scripts/art/items_art.gd scripts/autoload/art_cache.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "art: 鸡腿 10×10 (满/半/空) + slime_jelly/apple 物品图标"
```

---

## Task 9: HungerHUD 控件

**Files:**
- Create: `scripts/ui/hunger_hud.gd`

### - [ ] Step 1: 写 HungerHUD（镜像 health_hud.gd + 加抖动）

Create `scripts/ui/hunger_hud.gd`：

```gdscript
# 10 颗鸡腿: 每颗 10 点饱食; cur >= (i+1)*10 满, cur == 10i+5..10i+9 半, 否则空。
# 饿坏 (cur < HUNGRY_THRESHOLD) 时左右轻微抖动。
extends Control

const DRUM_SIZE := 10
const DRUM_SCALE := 2          # 渲染放大倍数 (20px 每颗)
const DRUM_SPACING := 2
const NUM_DRUMS := 10
const PAD := 8
const HUNGRY_THRESHOLD := 30
const SHAKE_INTERVAL := 0.5
const SHAKE_OFFSET_PX := 1

var _cur: int = 100
var _max: int = 100
var _shake_t: float = 0.0
var _shake_x: int = 0


func _ready() -> void:
    custom_minimum_size = Vector2(
        PAD * 2 + (DRUM_SIZE * DRUM_SCALE + DRUM_SPACING) * NUM_DRUMS - DRUM_SPACING,
        PAD * 2 + DRUM_SIZE * DRUM_SCALE
    )
    set_process(true)


func _process(delta: float) -> void:
    if _cur < HUNGRY_THRESHOLD:
        _shake_t += delta
        if _shake_t >= SHAKE_INTERVAL:
            _shake_t -= SHAKE_INTERVAL
            _shake_x = -_shake_x if _shake_x != 0 else SHAKE_OFFSET_PX
            queue_redraw()
    elif _shake_x != 0 or _shake_t != 0.0:
        _shake_x = 0
        _shake_t = 0.0
        queue_redraw()


func bind(hunger_node: Node) -> void:
    if hunger_node == null:
        return
    if hunger_node.has_signal("hunger_changed"):
        hunger_node.hunger_changed.connect(_on_changed)
    if hunger_node.has_method("emit_state"):
        hunger_node.emit_state()
    else:
        _on_changed(int(hunger_node.current), hunger_node.MAX)


func _on_changed(cur: int, maximum: int) -> void:
    _cur = cur
    _max = maximum
    queue_redraw()


func _draw() -> void:
    var drum_px := DRUM_SIZE * DRUM_SCALE
    for i in NUM_DRUMS:
        var x: float = PAD + i * (drum_px + DRUM_SPACING) + _shake_x
        var y: float = PAD
        var tex: ImageTexture
        var threshold: int = (i + 1) * 10  # 这颗鸡腿代表 [10i+1, 10i+10]
        if _cur >= threshold:
            tex = ArtCache.drumstick_full
        elif _cur >= threshold - 5:
            tex = ArtCache.drumstick_half
        else:
            tex = ArtCache.drumstick_empty
        if tex != null:
            draw_texture_rect(tex, Rect2(x, y, drum_px, drum_px), false)
```

注：使用 `_max` 来兼容信号格式，但渲染仅按固定 NUM_DRUMS × 10 = 100 来算（与 MAX 一致）。

### - [ ] Step 2: 启动游戏，确认编译通过（HUD 还没挂，画面不变）

```bash
cd /workspace/teilaruia && timeout 5 godot --headless --path . 2>&1 | head -20
```

Expected: 无脚本错误。

### - [ ] Step 3: 提交

```bash
git add scripts/ui/hunger_hud.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(ui): HungerHUD 10 颗鸡腿 + 饿坏抖动"
```

---

## Task 10: hud.tscn / hud.gd 接入

**Files:**
- Modify: `scenes/ui/hud.tscn`
- Modify: `scripts/ui/hud.gd`

### - [ ] Step 1: 改 hud.tscn

把 `scenes/ui/hud.tscn` 从：

```
[gd_scene load_steps=4 format=3 uid="uid://b6teilaruiahud"]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]
[ext_resource type="Script" path="res://scripts/ui/hotbar_view.gd" id="2_hbar"]
[ext_resource type="Script" path="res://scripts/ui/health_hud.gd" id="3_hp"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="HealthHUD" type="Control" parent="."]
layout_mode = 3
anchors_preset = 0
offset_left = 12.0
offset_top = 12.0
offset_right = 248.0
offset_bottom = 48.0
script = ExtResource("3_hp")

[node name="HotbarAnchor" type="Control" parent="."]
...
```

改为（加 `4_hg` ext_resource，加 `HungerHUD` 节点，位置在 HealthHUD 正下方）：

```
[gd_scene load_steps=5 format=3 uid="uid://b6teilaruiahud"]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]
[ext_resource type="Script" path="res://scripts/ui/hotbar_view.gd" id="2_hbar"]
[ext_resource type="Script" path="res://scripts/ui/health_hud.gd" id="3_hp"]
[ext_resource type="Script" path="res://scripts/ui/hunger_hud.gd" id="4_hg"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="HealthHUD" type="Control" parent="."]
layout_mode = 3
anchors_preset = 0
offset_left = 12.0
offset_top = 12.0
offset_right = 248.0
offset_bottom = 48.0
script = ExtResource("3_hp")

[node name="HungerHUD" type="Control" parent="."]
layout_mode = 3
anchors_preset = 0
offset_left = 12.0
offset_top = 48.0
offset_right = 248.0
offset_bottom = 84.0
script = ExtResource("4_hg")

[node name="HotbarAnchor" type="Control" parent="."]
...
```

（HealthHUD `offset_bottom=48` → HungerHUD `offset_top=48` 紧贴。如果觉得太挤，留 +4 → 52，PAD 内置 8 实际间隔会再多。）

### - [ ] Step 2: 改 hud.gd

`scripts/ui/hud.gd` 现状：

```gdscript
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar
@onready var health_hud: Control = $HealthHUD


func bind_player(player: Node2D) -> void:
    var inv: Node = player.get_node_or_null("PlayerInventory")
    if inv != null:
        hotbar.bind(inv)
    var hp: Node = player.get_node_or_null("PlayerHealth")
    if hp != null:
        health_hud.bind(hp)
```

改为：

```gdscript
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar
@onready var health_hud: Control = $HealthHUD
@onready var hunger_hud: Control = $HungerHUD


func bind_player(player: Node2D) -> void:
    var inv: Node = player.get_node_or_null("PlayerInventory")
    if inv != null:
        hotbar.bind(inv)
    var hp: Node = player.get_node_or_null("PlayerHealth")
    if hp != null:
        health_hud.bind(hp)
    var hg: Node = player.get_node_or_null("PlayerHunger")
    if hg != null:
        hunger_hud.bind(hg)
```

### - [ ] Step 3: 启动游戏，看 HUD 显示

```bash
cd /workspace/teilaruia && timeout 5 godot --headless --path . 2>&1 | head -20
```

Expected: 无错误（headless 看不到画面但能验证场景加载和 HUD 绑定无报错）。

### - [ ] Step 4: 提交

```bash
git add scenes/ui/hud.tscn scripts/ui/hud.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(ui): HUD 加鸡腿条 (红心下方)"
```

---

## Task 11: 死亡复活回满鸡腿

**Files:**
- Modify: `scripts/world/world.gd:173-175`

### - [ ] Step 1: 改 respawn_player

在 `scripts/world/world.gd` 第 173-175 行：

```gdscript
var hp: Node = player.get_node_or_null("PlayerHealth")
if hp != null and hp.has_method("revive_full"):
    hp.revive_full()
```

改为：

```gdscript
var hp: Node = player.get_node_or_null("PlayerHealth")
if hp != null and hp.has_method("revive_full"):
    hp.revive_full()
var hg: Node = player.get_node_or_null("PlayerHunger")
if hg != null and hg.has_method("refill_full"):
    hg.refill_full()
```

### - [ ] Step 2: 跑全测试，确认没回归

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -30
```

Expected: 全绿，包括之前的 unit + integration + 新增的 hunger 14 个。

### - [ ] Step 3: 提交

```bash
git add scripts/world/world.gd
git -c user.email="Duke_Aguirredlz@greenmail.net" -c user.name="Duke" commit -m "feat(world): 死亡复活时回满鸡腿"
```

---

## Task 12: 手工验收（启动游戏看效果）

### - [ ] Step 1: 启动游戏，对照 spec §11 验收清单

```bash
cd /workspace/teilaruia && godot --path . 2>&1 | head -10
```

按 spec §11 清单逐条手测：

- [ ] 新游戏开局鸡腿条满（10 颗），位于红心正下方
- [ ] 砍 leaves 多次看是否会偶尔掉 apple（5% 频率，预期约 20 次有 1 次）
- [ ] 杀史莱姆掉 slime_jelly（替代旧 slime_ball），物品图标为新的果冻造型
- [ ] 手拿 slime_jelly 长按右键 ~1s → 进度感觉 + 鸡腿涨 4 颗（+40）
- [ ] 手拿 apple 长按右键 ~1s → 鸡腿涨 ~2.5 颗（+25）
- [ ] 饱食 100% 时右键食物 → 不消耗
- [ ] 命令行调试或自然衰减至 < 30%（耗 7 分钟）→ 鸡腿条左右抖动
- [ ] 饿坏期间用木剑打史莱姆 → 需要 3 击死（满血 6 / 伤害 3）而非 2 击
- [ ] 饱食 ≥ 80% + 受伤 → 等 ~5s 回 1 HP
- [ ] 死亡复活后 → 鸡腿满 + HP 满

如有失败项，列出来再补 task；都通过就收尾。

### - [ ] Step 2: 收尾 commit / 关闭

测试若全过，最后跑一次完整套件：

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit
```

确认全绿（含 14 个新增断言）。无需再 commit。

---

## 完成判据

- [ ] 12 个 task 全部勾完
- [ ] `tests/unit/test_player_hunger.gd` 12 个断言全过
- [ ] `tests/integration/test_eat_food.gd` 5 个断言全过
- [ ] 既有测试全绿（无回归）
- [ ] spec §11 验收清单 10 项手测全过

---

## 关联

- Spec: `docs/superpowers/specs/2026-05-21-hunger-system-design.md`
- Memory: [[project-demo-spec]] / [[feedback-warm-detailed-textures]] / [[feedback-respawn-minecraft]]
