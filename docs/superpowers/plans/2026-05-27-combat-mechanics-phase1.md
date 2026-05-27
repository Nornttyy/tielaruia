# 战斗机制阶段 1 工具差异化 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让剑专精单体输出（戳↔挥交替）、镐成为低伤大范围 AoE 工具（能打怪也能挖矿）、斧只能砍树打怪零伤害；扫击改成弧形避免后方误伤。

**Architecture:** 在 `ItemDef` 加 `damage_mult` 字段统一控制工具能否攻击。`player_action.gd` 拆 `_swing_sword` 为 `_thrust_sword` + `_sweep_sword`，加 `_pickaxe_attack` 和 mode arbitration（鼠标对方块 → 挖矿，否则 → 攻击）。`held_item.gd` 加 `play_thrust` + `play_pickaxe_attack` 两个新动画。所有逻辑通过 GUT integration test 验收（main 场景实例化 + override 测试钩子）。

**Tech Stack:** Godot 4.3 + GDScript, GUT 9.x integration tests, 现有 `primary_override` / `mouse_world_override` / `aim_override` 钩子

参考 spec: `docs/superpowers/specs/2026-05-27-combat-mechanics-design.md`

---

## File Structure

**修改的文件**：
- `scripts/items/item_db.gd` — 加 `damage_mult` 字段 + 每个 tool def 填值
- `scripts/player/player_action.gd` — 拆 `_swing_sword`，加 `_thrust_sword` / `_sweep_sword` / `_pickaxe_attack` / `_reset_combo`，加 mode arbitration
- `scripts/player/held_item.gd` — 加 `play_thrust(target_angle)` + `play_pickaxe_attack()`

**新建的测试文件**：
- `tests/integration/test_combat_phase1.gd` — 7 个测试覆盖戳挥交替、扫弧、镐 AoE、斧零伤害、模式优先级

**不动**：
- `scripts/entities/slime.gd` / `zombie.gd` / `animal_base.gd` — 既有 `take_damage(amount, source_pos)` 接口足够
- `scripts/player/player_inventory.gd` — `hotbar_selection_changed` 信号已存在
- `scripts/world/cursor_manager.gd` — 不动

---

## Task 1: ItemDef 加 damage_mult 字段

**Files:**
- Modify: `scripts/items/item_db.gd`

ItemDef class 加一个属性，所有 tool defs 填充对应倍率。剑 1.0 / 镐 0.5 / 斧 0.0 / 其他 0.0。

- [ ] **Step 1: 看 ItemDef 现有字段定义**

Run: `grep -n "class_name\|var \|placeable_tile_id\|tool_kind\|max_stack" scripts/items/item_db.gd | head -30`
Expected: 看到 `class ItemDef` 或 `class_name ItemDef` 的字段列表（placeable_tile_id / tool_kind / tool_tier / max_stack）

- [ ] **Step 2: 在 ItemDef class 里加 damage_mult 字段**

在其他属性旁边加：

```gdscript
@export var damage_mult: float = 0.0   # 0 = 不能攻击; 1.0 = 满伤; 0.5 = 半伤
```

- [ ] **Step 3: _DEFS 字典每个 tool 加 damage_mult**

把字典构造函数 `ItemDef.from_dict` 或等价位置改造，使读 `damage_mult` 字段。然后在 `_DEFS` 里每个 tool entry 加：

| tool_kind | damage_mult |
|---|---|
| sword (任何 tier) | 1.0 |
| pickaxe (任何 tier) | 0.5 |
| axe (任何 tier) | 0.0 |

例如：
```gdscript
"wood_sword":   {"placeable_tile_id": -1, "tool_kind": "sword",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0},
"wood_pickaxe": {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 1, "max_stack": 1, "damage_mult": 0.5},
"wood_axe":     {"placeable_tile_id": -1, "tool_kind": "axe",     "tool_tier": 1, "max_stack": 1, "damage_mult": 0.0},
```

非 tool（dirt/stone/log/...）不加 damage_mult，由默认 0.0 兜底。

- [ ] **Step 4: 跑现有测试确认没破**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: 所有现有测试 pass，无新失败

- [ ] **Step 5: Commit**

```bash
git add scripts/items/item_db.gd
git commit -m "feat(items): 加 damage_mult 字段 (剑1.0/镐0.5/斧0.0)"
```

---

## Task 2: 加 _tool_damage_mult() helper + 用它改伤害公式

**Files:**
- Modify: `scripts/player/player_action.gd:486-520` (helper 区)

把现有 `_effective_sword_damage()` 改为读 `damage_mult`，统一所有工具的伤害计算。这一步是**纯重构**，剑伤害值不变（damage_mult=1.0 时等价旧公式），但斧的伤害变成 0。

- [ ] **Step 1: 先写测试 — 拿斧打史莱姆零伤害**

新建 `tests/integration/test_combat_phase1.gd`：

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")

# 通用 setup: spawn main, 等 boot, 拿 player + action
func _setup_game():
    var main = MainScene.instantiate()
    add_child_autofree(main)
    main.boot_to_game()
    await wait_frames(2)
    var world = main.get_node("World")
    var player = world.get_player()
    return {
        "main": main,
        "world": world,
        "player": player,
        "action": player.get_node("PlayerAction"),
        "inv": player.get_node("PlayerInventory"),
    }

# 给玩家 hotbar 0 槽塞工具, 切到 hotbar 0
func _equip_tool(ctx: Dictionary, item_id: String) -> void:
    var inv = ctx["inv"]
    inv.add_item(item_id, 1)
    inv.set_hotbar_index(0)
    # 确保 slot 0 是这个工具 (add_item 可能塞到其他槽)
    for i in range(inv.inventory.slots.size()):
        var s = inv.inventory.slots[i]
        if s != null and s.item_id == item_id:
            inv.set_hotbar_index(i)
            break

# 在 player 旁边 spawn 一只 slime, 返回 slime node
func _spawn_slime_near(ctx: Dictionary, offset: Vector2) -> Node2D:
    var SlimeScene = load("res://scenes/slime.tscn")
    var slime = SlimeScene.instantiate()
    ctx["world"].add_child(slime)
    slime.global_position = ctx["player"].global_position + offset
    return slime


func test_axe_zero_damage_on_enemies():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_axe")
    var slime = _spawn_slime_near(ctx, Vector2(16, 0))   # 右边 1 tile
    var hp_before: int = slime.hp
    # 把鼠标指向 slime, 模拟左键
    ctx["action"].mouse_world_override = slime.global_position
    ctx["action"].primary_override = true
    await wait_frames(20)   # 多帧让 attack tick 触发
    ctx["action"].primary_override = false
    assert_eq(slime.hp, hp_before, "斧打 slime 不应该扣血")
```

- [ ] **Step 2: 跑测试确认 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_axe_zero_damage_on_enemies -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（斧目前没攻击逻辑，但要测试整个 setup 跑通；如果是 setup 报错先修 setup）

> 如果 `_equip_tool` 的 `set_hotbar_index` 或 `add_item` API 不对，先 `grep -n "func add_item\|set_hotbar\|hotbar_index" scripts/player/player_inventory.gd` 找正确 API 名替换。

- [ ] **Step 3: 加 helper `_tool_damage_mult` 和 `_current_tool_def`**

在 `scripts/player/player_action.gd` 第 486 行附近（`_current_tool_kind` 旁边）加：

```gdscript
func _current_tool_def() -> ItemDef:
    var inv: Node = _inventory_node()
    if inv == null:
        return null
    var id: String = inv.current_hotbar_item_id() if inv.has_method("current_hotbar_item_id") else ""
    if id == "":
        return null
    return ItemDB.get_def(id)


func _tool_damage_mult() -> float:
    var def = _current_tool_def()
    return 0.0 if def == null else def.damage_mult
```

> 如果 `current_hotbar_item_id()` 不存在，用 `inv.current_hotbar_slot()` 然后 `.item_id`；先 grep 验证。

- [ ] **Step 4: 改 `_effective_sword_damage` 用 damage_mult**

原来：
```gdscript
func _effective_sword_damage() -> int:
    var base: int = _sword_damage()
    return base
```

改为：
```gdscript
func _effective_sword_damage() -> int:
    var base: int = _sword_damage()
    var mult: float = _tool_damage_mult()
    return int(round(base * mult))
```

注意 `_sword_damage()` 现在只对 tool_kind=="sword" 返回非零，所以镐 / 斧拿在手里会 return 0（因为 `def.tool_kind != "sword"` 触发 return 0）— 这是阶段 1 还没让镐打怪前的暂时状态。Task 7 时镐攻击走自己的伤害公式，不复用 sword_damage。

但**斧**的零伤害已经能通过本测试：拿斧时 _swing_sword 不会被调用（tool_kind != "sword"），slime.hp 不变。

- [ ] **Step 5: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_axe_zero_damage_on_enemies -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 用 damage_mult 算伤害 + 斧零伤害验收"
```

---

## Task 3: 斧拿空 / 拿斧对非树早 return（不播挖矿动画）

**Files:**
- Modify: `scripts/player/player_action.gd:149-200` (`_update_mining`)

防止"拿斧子点空气也在那挥"的傻 bug。

- [ ] **Step 1: 写测试 — 拿斧对石头 tile 不应该播挖矿动画**

加到 `test_combat_phase1.gd`：

```gdscript
func test_axe_on_stone_no_mining_anim():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_axe")
    var pt: Vector2i = ctx["action"].player_tile()
    var target: Vector2i = pt + Vector2i(2, 0)
    var terrain: TileMapLayer = ctx["world"].get_node("TerrainLayer")
    terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
    ctx["world"]._set_tile(target.x, target.y, Tiles.STONE)
    ctx["action"].aim_override = target
    ctx["action"].primary_override = true
    await wait_frames(20)
    # 关键: _mining_swing_t 应该保持初值, 不被 _update_mining 改写
    # 因为斧不该对石头开启挖矿动画循环
    assert_eq(ctx["action"]._mining_progress, 0.0, "斧对非树 tile 不应进入挖矿进度")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_axe_on_stone_no_mining_anim -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（现在斧对石头会触发挖矿进度，因为 required_tool_tier 检查后会 reset，但 _mining_progress 那一帧可能已经累加）

- [ ] **Step 3: 在 `_update_mining` 顶部加斧早 return**

找到 `_update_mining` 函数（约 149 行），在 `pressed` 检查后、`aim_tile_coord` 检查前加：

```gdscript
func _update_mining(delta: float) -> void:
    var pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
    if not pressed:
        _reset_mining()
        return
    var inv: Node = _inventory_node()
    var tool_kind: String = "" if inv == null else inv.current_tool_kind()
    # 斧只能对 LOG, 其他 tile 直接 idle (不播动画)
    if tool_kind == "axe":
        var tile_axe: Vector2i = aim_tile_coord()
        var terrain_axe := _terrain()
        if terrain_axe == null:
            _reset_mining()
            return
        var tid_axe: int = terrain_axe.get_cell_source_id(tile_axe)
        if tid_axe != Tiles.LOG:
            _reset_mining()
            return
    # ... 现有代码继续
```

> 后面已有 tool_kind 计算的行可以保留（变量 shadowing 不影响），或把 inv/tool_kind 计算提到顶部然后下面复用 — 自由发挥但**不要引入新行为**。

- [ ] **Step 4: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_axe_on_stone_no_mining_anim -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS

- [ ] **Step 5: 跑现有挖矿测试确保没破**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_mine_grass_then_pick_up -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS（拿无工具挖 grass 应该仍正常）

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 斧对非树 tile 不播挖矿动画"
```

---

## Task 4: 加 `_attack_combo_step` 状态 + 切工具重置

**Files:**
- Modify: `scripts/player/player_action.gd` (state field + signal handler)

加 combo state，但**不改 `_swing_sword`**（下一个 task 拆）。

- [ ] **Step 1: 写测试 — 切工具重置 combo**

加到 `test_combat_phase1.gd`：

```gdscript
func test_combo_resets_on_hotbar_switch():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_sword")
    ctx["action"]._attack_combo_step = 1   # 人为设到 "下一击是挥"
    # 给玩家加铜镐到 slot 1, 切到 slot 1
    var inv = ctx["inv"]
    inv.add_item("wood_pickaxe", 1)
    # 找到 pickaxe 所在 slot
    for i in range(inv.inventory.slots.size()):
        var s = inv.inventory.slots[i]
        if s != null and s.item_id == "wood_pickaxe":
            inv.set_hotbar_index(i)
            break
    await wait_frames(2)
    assert_eq(ctx["action"]._attack_combo_step, 0, "切工具后 combo_step 应重置为 0")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_combo_resets_on_hotbar_switch -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（_attack_combo_step 字段还不存在 → 报 Invalid set index 或类似）

- [ ] **Step 3: 加状态字段 + signal handler**

在 `player_action.gd` 状态变量区（约 40-60 行附近）加：

```gdscript
var _attack_combo_step: int = 0   # 0 = 下一击戳, 1 = 下一击挥
```

在 `_ready()` 里连 signal（如果 `_ready` 不存在则新建）：

```gdscript
func _ready() -> void:
    var inv: Node = _inventory_node()
    if inv != null and inv.has_signal("hotbar_selection_changed"):
        inv.hotbar_selection_changed.connect(_on_hotbar_changed)


func _on_hotbar_changed(_idx: int) -> void:
    # 切工具时重置 combo (重要: 不要 await, signal handler 同步)
    _attack_combo_step = 0
```

> 注意 [feedback_no_async_signal]: signal handler 不能 await，会跟同步直调路径冲突。

- [ ] **Step 4: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_combo_resets_on_hotbar_switch -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 加 _attack_combo_step + 切工具重置"
```

---

## Task 5: 拆 `_swing_sword` 为 `_thrust_sword` + `_sweep_sword` + 交替逻辑

**Files:**
- Modify: `scripts/player/player_action.gd:79-83` (调度) + `:615-657` (拆函数)

这一步 **保留 `_swing_sword` 的 ` sweep 行为不变**（改名为 `_sweep_sword`），新建 `_thrust_sword`（暂时复用 sweep 逻辑，下一 task 改成矩形判定）。先把分发路径切对。

- [ ] **Step 1: 写测试 — 连按 3 次左键 combo_step 序列 0→1→0**

加到 `test_combat_phase1.gd`：

```gdscript
func test_sword_combo_alternates():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_sword")
    var steps: Array[int] = []
    for i in range(3):
        # 让 cooldown 归零
        ctx["action"]._attack_cooldown = 0.0
        # 戳/挥前的 combo_step (将被消费)
        steps.append(ctx["action"]._attack_combo_step)
        ctx["action"].primary_override = true
        await wait_frames(2)   # 1 帧触发, 多 1 帧保险
        ctx["action"].primary_override = false
        await wait_frames(1)
    # 期望: 第 1 次进函数时是 0 (戳), 然后 step 变 1; 第 2 次是 1 (挥), 然后 step 变 0; 第 3 次又是 0
    assert_eq(steps, [0, 1, 0], "戳挥应该交替")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sword_combo_alternates -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（combo_step 一直 0，因为还没改分发逻辑）

- [ ] **Step 3: 把 `_swing_sword` 改名 `_sweep_sword`（行为不变）**

把第 615 行 `func _swing_sword() -> void:` 改成 `func _sweep_sword() -> void:`，函数体**完全不动**。

- [ ] **Step 4: 加 `_thrust_sword` 占位实现（暂等于 _sweep_sword）**

在 `_sweep_sword` 之前加：

```gdscript
func _thrust_sword() -> void:
    # 占位: 先复用 sweep 逻辑, Task 6 改成矩形判定 + 0.8x 伤害
    _sweep_sword()
```

下一个 task 会替换实现。

- [ ] **Step 5: 改分发逻辑（第 79-83 行）**

把：
```gdscript
if _current_tool_kind() == "sword":
    _reset_mining()
    var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
    if primary_pressed and _attack_cooldown <= 0.0:
        _swing_sword()
```

改成：
```gdscript
if _current_tool_kind() == "sword":
    _reset_mining()
    var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
    if primary_pressed and _attack_cooldown <= 0.0:
        if _attack_combo_step == 0:
            _thrust_sword()
            _attack_combo_step = 1
        else:
            _sweep_sword()
            _attack_combo_step = 0
```

- [ ] **Step 6: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sword_combo_alternates -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 剑分 thrust/sweep 交替分发 (thrust 暂复用 sweep)"
```

---

## Task 6: 戳 `_thrust_sword` 改成矩形判定 + 0.8x 伤害 + 只命中最近

**Files:**
- Modify: `scripts/player/player_action.gd` (`_thrust_sword`)
- Modify: `scripts/player/held_item.gd` (`play_thrust`)

- [ ] **Step 1: 写测试 — 戳前方两只 slime 只有近的扣血**

加到 `test_combat_phase1.gd`：

```gdscript
func test_thrust_hits_only_nearest():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_sword")
    ctx["action"]._attack_combo_step = 0   # 下一击是戳
    var near = _spawn_slime_near(ctx, Vector2(20, 0))   # 玩家右侧 20px
    var far  = _spawn_slime_near(ctx, Vector2(36, 0))   # 玩家右侧 36px (戳范围内但更远)
    var near_hp = near.hp
    var far_hp = far.hp
    ctx["action"].mouse_world_override = near.global_position
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(2)
    ctx["action"].primary_override = false
    assert_lt(near.hp, near_hp, "近的 slime 应该扣血")
    assert_eq(far.hp, far_hp, "远的 slime 不应该扣血 (戳只命中 1 个)")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_thrust_hits_only_nearest -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（目前 thrust 复用 sweep，两只都扣血）

- [ ] **Step 3: 重写 `_thrust_sword`**

替换占位实现：

```gdscript
const THRUST_COOLDOWN := 0.18
const THRUST_LENGTH_MULT := 1.2   # 戳长 = SWORD_RANGE_PX * 1.2
const THRUST_HALF_WIDTH := 6.0    # 戳带半宽 6px (总宽 12)
const THRUST_DAMAGE_MULT := 0.8

func _thrust_sword() -> void:
    _attack_cooldown = THRUST_COOLDOWN
    var player: Node2D = get_parent() as Node2D
    if player == null:
        return
    var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
    var to_mouse: Vector2 = mouse_world - player.global_position
    if to_mouse.length() < 0.001:
        to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
    var swing_dir: Vector2 = to_mouse.normalized()
    last_swing_center = player.global_position + swing_dir * SWORD_RANGE_PX * THRUST_LENGTH_MULT * 0.5
    # 动画
    var held: Node = player.get_node_or_null("HeldItem")
    if held != null and held.has_method("play_thrust"):
        held.play_thrust(swing_dir.angle())
    SfxBank.play("swing", 0.10)
    # 伤害
    var base: int = _sword_damage()
    var damage: int = int(round(base * _tool_damage_mult() * THRUST_DAMAGE_MULT))
    if damage <= 0:
        return
    # 矩形判定: 玩家中心沿 swing_dir 长 SWORD_RANGE_PX*1.2, 半宽 THRUST_HALF_WIDTH; 找最近目标
    var max_len: float = SWORD_RANGE_PX * THRUST_LENGTH_MULT
    var best: Node2D = null
    var best_dist: float = INF
    for group in ["slimes", "animals"]:
        for s in get_tree().get_nodes_in_group(group):
            var sn := s as Node2D
            if sn == null:
                continue
            var local: Vector2 = sn.global_position - player.global_position
            var along: float = local.dot(swing_dir)
            if along < 0.0 or along > max_len:
                continue
            var perp_axis: Vector2 = Vector2(-swing_dir.y, swing_dir.x)
            var perp: float = abs(local.dot(perp_axis))
            if perp > THRUST_HALF_WIDTH:
                continue
            if along < best_dist:
                best_dist = along
                best = sn
    if best != null and best.has_method("take_damage"):
        best.take_damage(damage, player.global_position)
    if player.has_method("shake"):
        player.shake(2.0)
```

- [ ] **Step 4: 在 held_item.gd 加 `play_thrust`**

`scripts/player/held_item.gd` 在 `play_swing_directional` 后面加：

```gdscript
const THRUST_DURATION := 0.15
const THRUST_OFFSET_PX := 14.0   # 工具向前突进的距离

func play_thrust(target_angle: float) -> void:
    if not visible:
        return
    if _tween != null and _tween.is_valid():
        _tween.kill()
    var mouse_on_right: bool = cos(target_angle) >= 0.0
    set_facing(mouse_on_right)
    # 工具朝鼠标方向位移再收回, 不旋转
    var dir_vec := Vector2(cos(target_angle), sin(target_angle))
    var base_pos := Vector2(HAND_OFFSET_X if _facing_right else -HAND_OFFSET_X, HAND_OFFSET_Y)
    var thrust_pos := base_pos + dir_vec * THRUST_OFFSET_PX
    rotation = target_angle   # 工具锋朝鼠标
    position = base_pos
    _tween = create_tween()
    _tween.tween_property(self, "position", thrust_pos, THRUST_DURATION * 0.4).set_ease(Tween.EASE_OUT)
    _tween.tween_property(self, "position", base_pos, THRUST_DURATION * 0.6).set_ease(Tween.EASE_IN)
    _tween.tween_callback(func(): rotation = 0.0)
```

> 如果常量 `HAND_OFFSET_X` / `HAND_OFFSET_Y` 名字不同，先 `grep -n "HAND_OFFSET\|const " scripts/player/held_item.gd` 找正确名。

- [ ] **Step 5: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_thrust_hits_only_nearest -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS

- [ ] **Step 6: 跑 alternates 测试也 PASS（回归检查）**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sword_combo_alternates -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: PASS（之前 task 加的测试不该被破坏）

- [ ] **Step 7: Commit**

```bash
git add scripts/player/player_action.gd scripts/player/held_item.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 戳改矩形判定 + 0.8x 伤害 + 只命中最近 + thrust 动画"
```

---

## Task 7: `_sweep_sword` 改用 90° 弧判定（替换圆形）

**Files:**
- Modify: `scripts/player/player_action.gd` (`_sweep_sword` 命中判定段)

把第 651 行的 `center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7` 替换成弧形 helper。

- [ ] **Step 1: 写测试 — 身后 slime 不被挥到**

加到 `test_combat_phase1.gd`：

```gdscript
func test_sweep_misses_behind():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_sword")
    ctx["action"]._attack_combo_step = 1   # 下一击是挥
    var front = _spawn_slime_near(ctx, Vector2(24, 0))    # 前
    var back  = _spawn_slime_near(ctx, Vector2(-24, 0))   # 身后
    var front_hp = front.hp
    var back_hp = back.hp
    ctx["action"].mouse_world_override = front.global_position   # 朝前挥
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(2)
    ctx["action"].primary_override = false
    assert_lt(front.hp, front_hp, "正前 slime 应该扣血")
    assert_eq(back.hp, back_hp, "身后 slime 不该扣血 (90° 弧)")


func test_sweep_hits_all_in_arc():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_sword")
    ctx["action"]._attack_combo_step = 1
    # 三只 slime 朝前 ±30° + 正前
    var center = _spawn_slime_near(ctx, Vector2(24, 0))
    var up = _spawn_slime_near(ctx, Vector2(20, -12))    # 上 ~30°
    var down = _spawn_slime_near(ctx, Vector2(20, 12))   # 下 ~30°
    var hps = [center.hp, up.hp, down.hp]
    ctx["action"].mouse_world_override = center.global_position
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(2)
    ctx["action"].primary_override = false
    assert_lt(center.hp, hps[0])
    assert_lt(up.hp, hps[1], "弧内上方应该扣血")
    assert_lt(down.hp, hps[2], "弧内下方应该扣血")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sweep_misses_behind -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: FAIL（圆形判定 + center 偏向鼠标，身后 slime 距离 center 36+ 超 SWORD_RANGE_PX*0.7=25.2 — 可能已经 fail，但要明确测试通过条件）

> 如果这个测试在改之前其实已经 PASS（圆心已经偏前），仍然要进 Step 3 改成弧判定，因为更紧的几何边界更稳。

- [ ] **Step 3: 加 `_is_in_swing_arc` helper + 替换判定**

在 `_sweep_sword` 之前（或文件底部）加：

```gdscript
const SWEEP_ARC_HALF_DEG := 45.0   # 总弧 90°

func _is_in_swing_arc(target_pos: Vector2, origin: Vector2, dir: Vector2) -> bool:
    var to_target := target_pos - origin
    var dist := to_target.length()
    if dist > SWORD_RANGE_PX:
        return false
    if dist < 4.0:
        return true   # 贴脸总命中
    var diff: float = wrapf(to_target.angle() - dir.angle(), -PI, PI)
    return abs(diff) <= deg_to_rad(SWEEP_ARC_HALF_DEG)
```

把 `_sweep_sword` 里：
```gdscript
for target in hit_targets.values():
    var sn := target as Node2D
    if sn == null:
        continue
    if center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7:
        if target.has_method("take_damage"):
            target.take_damage(damage, player.global_position)
```

替换为：
```gdscript
for target in hit_targets.values():
    var sn := target as Node2D
    if sn == null:
        continue
    if _is_in_swing_arc(sn.global_position, player.global_position, swing_dir):
        if target.has_method("take_damage"):
            target.take_damage(damage, player.global_position)
```

> `damage` 现在也要乘 damage_mult：把 `var damage: int = _effective_sword_damage()` 保留即可（_effective_sword_damage 已包含 damage_mult，剑时是 1.0 × base）。

- [ ] **Step 4: 跑两个测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sweep_misses_behind -gexit 2>&1 | grep -v libfontconfig | tail -10`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_sweep_hits_all_in_arc -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: 两个都 PASS

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 挥剑改 90° 弧判定 (替换圆形, 避免后方误伤)"
```

---

## Task 8: 镐攻击模式判定（鼠标对方块挖矿 / 否则攻击）

**Files:**
- Modify: `scripts/player/player_action.gd:78-86` (主分发) + 加 `_pickaxe_attack` 占位

只搞**分发路径**，攻击逻辑用 stub（设 cooldown 但不扣血）。下一 task 加伤害。

- [ ] **Step 1: 写测试 — 拿镐对石头优先挖矿**

加到 `test_combat_phase1.gd`：

```gdscript
func test_pickaxe_prefers_mining_over_attack():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_pickaxe")
    var pt: Vector2i = ctx["action"].player_tile()
    var target: Vector2i = pt + Vector2i(2, 0)
    var terrain: TileMapLayer = ctx["world"].get_node("TerrainLayer")
    terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
    ctx["world"]._set_tile(target.x, target.y, Tiles.STONE)
    var slime = _spawn_slime_near(ctx, Vector2(20, 0))
    var slime_hp = slime.hp
    ctx["action"].aim_override = target
    ctx["action"].mouse_world_override = Vector2(target.x * 16 + 8, target.y * 16 + 8)
    ctx["action"].primary_override = true
    await wait_seconds(0.4)
    ctx["action"].primary_override = false
    assert_eq(slime.hp, slime_hp, "镐对石头时不应攻击 slime")
```

- [ ] **Step 2: 跑测试 PASS**（应已 PASS 因镐还没攻击逻辑）

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_prefers_mining_over_attack -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: PASS（确认这条 baseline，下个 task 改完不要破）

- [ ] **Step 3: 写测试 — 拿镐对空有怪触发攻击 mode**

加：
```gdscript
func test_pickaxe_attacks_when_no_block_at_mouse():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_pickaxe")
    # 鼠标位置在 slime 上, 但那 tile 是空气 (没 set_cell)
    var slime = _spawn_slime_near(ctx, Vector2(20, 0))
    ctx["action"].mouse_world_override = slime.global_position
    # 不设 aim_override 让 aim_tile_coord 用鼠标位置算
    ctx["action"].primary_override = true
    await wait_frames(5)
    ctx["action"].primary_override = false
    # 期望: _attack_cooldown 被 _pickaxe_attack 设过, 不再是 0
    assert_gt(ctx["action"]._attack_cooldown, 0.0, "镐对空 + 附近有怪 → 应触发攻击 cooldown")
```

- [ ] **Step 4: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_attacks_when_no_block_at_mouse -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: FAIL（_pickaxe_attack 还没接入）

- [ ] **Step 5: 加 `_pickaxe_attack` stub + 接入分发**

在 `player_action.gd` 加常量和占位函数：

```gdscript
const PICKAXE_ATTACK_COOLDOWN := 0.35
const PICKAXE_AOE_RADIUS_MULT := 1.5
const PICKAXE_MOUSE_NEAR_RADIUS_MULT := 1.5   # 鼠标位置周围多少范围算"附近有怪"

func _pickaxe_attack() -> void:
    _attack_cooldown = PICKAXE_ATTACK_COOLDOWN
    # 伤害逻辑下一 task 加, 这里只设 cooldown

func _mouse_has_enemy_nearby() -> bool:
    var player: Node2D = get_parent() as Node2D
    if player == null:
        return false
    var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
    var radius: float = SWORD_RANGE_PX * PICKAXE_MOUSE_NEAR_RADIUS_MULT
    for group in ["slimes", "animals"]:
        for s in get_tree().get_nodes_in_group(group):
            var sn := s as Node2D
            if sn != null and mouse_world.distance_to(sn.global_position) <= radius:
                return true
    return false


func _mouse_on_mineable_tile() -> bool:
    var tile: Vector2i = aim_tile_coord()
    var terrain := _terrain()
    if terrain == null:
        return false
    var tid: int = terrain.get_cell_source_id(tile)
    return tid != -1 and Tiles.is_mineable(tid)
```

改 `_physics_process` 的分发（第 78-86 行附近），在 sword 分支后加 pickaxe 分支：

```gdscript
if _current_tool_kind() == "sword":
    _reset_mining()
    var primary_pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
    if primary_pressed and _attack_cooldown <= 0.0:
        if _attack_combo_step == 0:
            _thrust_sword()
            _attack_combo_step = 1
        else:
            _sweep_sword()
            _attack_combo_step = 0
elif _current_tool_kind() == "pickaxe":
    # 模式: 鼠标对方块 → 挖矿; 否则附近有怪 → 攻击
    if _mouse_on_mineable_tile():
        _update_mining(delta)
    else:
        var primary_pressed_p: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
        if primary_pressed_p and _attack_cooldown <= 0.0 and _mouse_has_enemy_nearby():
            _pickaxe_attack()
        else:
            _reset_mining()
else:
    _update_mining(delta)
```

- [ ] **Step 6: 跑两个测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_attacks_when_no_block_at_mouse -gexit 2>&1 | grep -v libfontconfig | tail -10`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_prefers_mining_over_attack -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: 两个都 PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/player/player_action.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 镐攻击 / 挖矿模式分发 (stub 攻击, 仅设 cooldown)"
```

---

## Task 9: 镐攻击 360° AoE 伤害（玩家中心）+ 转圈动画

**Files:**
- Modify: `scripts/player/player_action.gd` (`_pickaxe_attack` 实现)
- Modify: `scripts/player/held_item.gd` (`play_pickaxe_attack`)

- [ ] **Step 1: 写测试 — 镐 AoE 打四周 4 只 slime**

加到 `test_combat_phase1.gd`：

```gdscript
func test_pickaxe_aoe_360():
    var ctx = await _setup_game()
    _equip_tool(ctx, "wood_pickaxe")
    var r: float = 36.0 * 1.4   # SWORD_RANGE_PX * 1.4 (略小于 AoE 半径 SWORD_RANGE_PX*1.5)
    var slimes: Array = []
    for offset in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
        slimes.append(_spawn_slime_near(ctx, offset))
    var hps_before: Array[int] = []
    for s in slimes:
        hps_before.append(s.hp)
    # 鼠标指向一只 (任意), 触发攻击
    ctx["action"].mouse_world_override = slimes[0].global_position
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(3)
    ctx["action"].primary_override = false
    for i in range(slimes.size()):
        assert_lt(slimes[i].hp, hps_before[i], "方向 %d 的 slime 应扣血 (360° AoE)" % i)


func test_pickaxe_damage_is_half_of_sword():
    var ctx = await _setup_game()
    # 拿铜剑打 slime 一次
    _equip_tool(ctx, "copper_sword")
    var slime_a = _spawn_slime_near(ctx, Vector2(24, 0))
    var hp_a = slime_a.hp
    ctx["action"]._attack_combo_step = 1   # 挥 (100% damage_mult)
    ctx["action"].mouse_world_override = slime_a.global_position
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(2)
    ctx["action"].primary_override = false
    var sword_dmg: int = hp_a - slime_a.hp
    # 换铜镐再打另一只
    var slime_b = _spawn_slime_near(ctx, Vector2(36, 0))   # 在 mouse_near 范围内, 不在 block
    var hp_b = slime_b.hp
    var inv = ctx["inv"]
    inv.add_item("copper_pickaxe", 1)
    for i in range(inv.inventory.slots.size()):
        if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "copper_pickaxe":
            inv.set_hotbar_index(i)
            break
    ctx["action"].mouse_world_override = slime_b.global_position
    ctx["action"]._attack_cooldown = 0.0
    ctx["action"].primary_override = true
    await wait_frames(3)
    ctx["action"].primary_override = false
    var pickaxe_dmg: int = hp_b - slime_b.hp
    # 期望 pickaxe = round(sword * 0.5)
    var expected: int = int(round(float(sword_dmg) * 0.5))
    assert_eq(pickaxe_dmg, expected, "镐伤害应该是剑的 50% (round). sword=%d pickaxe=%d" % [sword_dmg, pickaxe_dmg])
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_aoe_360 -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: FAIL（_pickaxe_attack stub 不扣血）

- [ ] **Step 3: 实现 `_pickaxe_attack`**

替换 stub：

```gdscript
func _pickaxe_attack() -> void:
    _attack_cooldown = PICKAXE_ATTACK_COOLDOWN
    var player: Node2D = get_parent() as Node2D
    if player == null:
        return
    # 动画
    var held: Node = player.get_node_or_null("HeldItem")
    if held != null and held.has_method("play_pickaxe_attack"):
        held.play_pickaxe_attack()
    SfxBank.play("swing", 0.10)
    # 伤害: 玩家中心 360° AoE, 半径 SWORD_RANGE_PX * 1.5
    var base: int = _pickaxe_attack_base_damage()
    var damage: int = int(round(base * _tool_damage_mult()))
    if damage <= 0:
        return
    var radius: float = SWORD_RANGE_PX * PICKAXE_AOE_RADIUS_MULT
    var origin: Vector2 = player.global_position
    var hit_targets: Dictionary = {}
    for group in ["slimes", "animals"]:
        for s in get_tree().get_nodes_in_group(group):
            hit_targets[s.get_instance_id()] = s
    for target in hit_targets.values():
        var sn := target as Node2D
        if sn == null:
            continue
        if origin.distance_to(sn.global_position) <= radius:
            if target.has_method("take_damage"):
                target.take_damage(damage, origin)
    if player.has_method("shake"):
        player.shake(2.0)


# 镐的基础伤害 = 同 tier 剑的伤害 (5 if tier>=2 else 3, 跟 _sword_damage 同公式)
# 这里复制一份避免 _sword_damage 内的 "tool_kind=='sword'" 提前 return.
func _pickaxe_attack_base_damage() -> int:
    var def = _current_tool_def()
    if def == null or def.tool_kind != "pickaxe":
        return 0
    return 5 if def.tool_tier >= 2 else 3
```

- [ ] **Step 4: 在 held_item.gd 加 `play_pickaxe_attack`**

```gdscript
const PICKAXE_ATTACK_DURATION := 0.4

func play_pickaxe_attack() -> void:
    if not visible:
        return
    if _tween != null and _tween.is_valid():
        _tween.kill()
    rotation = 0.0
    _tween = create_tween()
    var dir: float = 1.0 if _facing_right else -1.0
    _tween.tween_property(self, "rotation", deg_to_rad(360.0 * dir), PICKAXE_ATTACK_DURATION)
    _tween.tween_callback(func(): rotation = 0.0)
```

- [ ] **Step 5: 跑两个测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_aoe_360 -gexit 2>&1 | grep -v libfontconfig | tail -10`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gunit_test_name=test_pickaxe_damage_is_half_of_sword -gexit 2>&1 | grep -v libfontconfig | tail -10`
Expected: 两个都 PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_action.gd scripts/player/held_item.gd tests/integration/test_combat_phase1.gd
git commit -m "feat(combat): 镐 360° AoE 攻击 + 转圈动画"
```

---

## Task 10: 全套测试一次跑 + smoke 不破

**Files:** 仅运行

- [ ] **Step 1: 跑 test_combat_phase1.gd 整个文件**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gtest=res://tests/integration/test_combat_phase1.gd -gexit 2>&1 | grep -v libfontconfig | tail -20`
Expected: 全部 PASS

- [ ] **Step 2: 跑 smoke + 现有挖矿 / 砍树 / hunger 测试**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | grep -v libfontconfig | grep -E "Pass|Fail|Risky|Errors" | tail -10`
Expected: 0 fail，pass count = 现状 + 7 (新加 7 个 phase1 测试)

- [ ] **Step 3: 单元测试不破**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | grep -v libfontconfig | grep -E "Pass|Fail" | tail -5`
Expected: 0 fail

- [ ] **Step 4: 如有失败修复后再 commit**

如果有现有测试因 ItemDef.damage_mult 字段或 `_update_mining` 早 return 破了：
- 报错栈定位文件 + 行
- 修复（通常是 ItemDef 构造方式：dict→ItemDef 转换函数没接 damage_mult key）
- 再跑

如果都 PASS：

```bash
git status   # 应无 unstaged 改动
echo "阶段 1 完成 ✓"
```

---

## Self-Review Notes

**Spec 覆盖检查**：
- F1 剑戳挥交替 → Task 4 (state) + Task 5 (dispatch) + Task 6 (thrust impl) ✓
- F2 弧形判定 → Task 7 ✓
- F3 镐攻击 → Task 8 (mode) + Task 9 (damage + anim) ✓
- F4 斧零伤害 → Task 1 (damage_mult=0) + Task 2 (helper) + Task 3 (no anim) ✓
- damage_mult 字段 → Task 1 ✓
- 信号 reset combo → Task 4 ✓

**8 个 spec 测试 vs 计划里的测试**：

| Spec 测试 | Plan Task |
|---|---|
| test_sword_combo_alternates | Task 5 |
| test_thrust_hits_only_nearest | Task 6 |
| test_sweep_hits_all_in_arc | Task 7 |
| test_sweep_misses_behind | Task 7 |
| test_pickaxe_damages_enemies | Task 9 (test_pickaxe_damage_is_half_of_sword 涵盖) |
| test_pickaxe_aoe_360 | Task 9 |
| test_axe_zero_damage_on_enemies | Task 2 |
| test_combo_resets_on_hotbar_switch | Task 4 |
| test_pickaxe_prefers_mining_over_attack | Task 8 |
| test_axe_on_stone_no_mining_anim | Task 3（新增，spec 风险栏对应）|

**风险**：
- Task 1 改了 `_DEFS` 字典格式，如果 ItemDef.from_dict 之类的构造没接新 key → 报错 Invalid index "damage_mult"。要 grep 构造函数。
- Task 2 改 `_effective_sword_damage`：镐拿在手里时 `_sword_damage` 返回 0（tool_kind check），所以挥剑分支即使被误调也不扣血 — 这是好事（防御性）。
- Task 8 引入 elif pickaxe 分支，没 else 兜底其他工具（axe / 空手）— axe 在 Task 3 已经处理，空手走原 else `_update_mining`。

**没 placeholder**：所有 code block 都填实，所有 task 都引用具体行号。
