# Teilaruia · Demo P2 · Items + Interaction + Crafting · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家从出生开始能砍树 → 2×2 合成木板/木棍/工作台 → 放工作台 → 3×3 合成木镚 → 挖石头，构成完整的"原木到矿石"开局闭环。所有纯逻辑模块走 TDD，整局通过集成测试自动验收。

**Architecture:** Godot 4.3 单进程。两个新 autoload (`ItemDB`、`RecipeDB`) + 两个 RefCounted 数据类 (`Inventory`、`RecipeMatcher`)。Player 场景下挂 `PlayerInventory` (持 Inventory) 和 `PlayerAction` (鼠标瞄准 + 挖放进度)。CraftingPanel CanvasLayer 自持合成 grid (不在 Inventory 内)。

**Tech Stack:** Godot 4.3, GDScript, GUT 9.3.0, P1 的 Tiles/SkyLightGrid/ArtCache。

**前置：** P1 Foundation 完成 (`tag demo-p1-foundation`)，23 个测试通过。

**预计 21 个任务，~110 步。**

---

## File Structure

新建：
- `scripts/items/item_db.gd` (autoload)
- `scripts/items/inventory.gd` (RefCounted)
- `scripts/items/item_drop.gd`
- `scripts/crafting/recipe_db.gd` (autoload)
- `scripts/crafting/recipe_matcher.gd` (RefCounted, static)
- `scripts/player/player_inventory.gd`
- `scripts/player/player_action.gd`
- `scripts/ui/hud.gd`
- `scripts/ui/hotbar_view.gd`
- `scripts/ui/crafting_panel.gd`
- `scenes/items/item_drop.tscn`
- `scenes/ui/hud.tscn`
- `scenes/ui/crafting_panel.tscn`
- `tests/unit/test_item_db.gd`
- `tests/unit/test_inventory.gd`
- `tests/unit/test_recipe_db.gd`
- `tests/unit/test_recipe_matcher.gd`
- `tests/unit/test_player_action.gd`
- `tests/integration/test_mine_drop_pickup.gd`
- `tests/integration/test_place_block.gd`
- `tests/integration/test_craft_loop.gd`
- `tests/integration/test_workbench_3x3.gd`

修改：
- `project.godot` — InputMap (primary/secondary/interact/crafting_2x2/hotbar_1..9) + 新 autoload
- `scenes/player/player.tscn` — 加 PlayerInventory + PlayerAction child
- `scripts/world/world.gd` — terrain_layer 加入 group 供 PlayerAction 访问；CraftingPanel 加到 Main
- `scripts/main.gd` — 实例化 HUD + CraftingPanel

---

## Task 1: InputMap 扩展

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: 在 project.godot `[input]` 段追加新动作**

把现有 `[input]` 段（含 move_left/right/jump/toggle_debug）末尾追加以下行（注意是追加到段内，不要新建段）：

```ini
primary={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":1,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
secondary={
"deadzone": 0.5,
"events": [Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),"factor":1.0,"button_index":2,"canceled":false,"pressed":false,"double_click":false,"script":null)]
}
interact={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":69,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
crafting_2x2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":67,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_1={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":49,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_2={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":50,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_3={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":51,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_4={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":52,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_5={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":53,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_6={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":54,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_7={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":55,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_8={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":56,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
hotbar_9={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":57,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
ui_cancel_crafting={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

Keycode 速查：1=49, 2=50, ..., 9=57, C=67, E=69, ESC=4194305。鼠标 button_index：1=LMB, 2=RMB。

- [ ] **Step 2: 验证项目解析无 error**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error|warn" | grep -v libfontconfig || echo "clean"
```

Expected: `clean`。

- [ ] **Step 3: 提交**

```bash
git add project.godot
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(input): P2 InputMap - primary/secondary/interact/crafting_2x2/hotbar_1..9"
```

---

## Task 2: ItemDB autoload (TDD)

**Files:**
- Create: `scripts/items/item_db.gd`
- Test: `tests/unit/test_item_db.gd`
- Modify: `project.godot`

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_item_db.gd`:

```gdscript
extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
var db


func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)


func test_unknown_item_returns_null():
	assert_null(db.get_def("nonexistent"))


func test_dirt_is_placeable():
	var def = db.get_def("dirt")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, Tiles.DIRT)
	assert_eq(def.max_stack, 64)


func test_stone_placeable():
	var def = db.get_def("stone")
	assert_eq(def.placeable_tile_id, Tiles.STONE)


func test_wood_pickaxe_is_tool_not_placeable():
	var def = db.get_def("wood_pickaxe")
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.tool_kind, "pickaxe")
	assert_eq(def.tool_tier, 1)
	assert_eq(def.max_stack, 1)


func test_stick_is_neither_tool_nor_placeable():
	var def = db.get_def("stick")
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.tool_kind, "")
	assert_eq(def.max_stack, 64)


func test_all_known_items_present():
	for item_id in ["dirt", "grass", "stone", "sand", "log", "leaves",
			"planks", "workbench", "door", "stick",
			"wood_sword", "wood_pickaxe", "wood_axe", "slime_ball"]:
		assert_not_null(db.get_def(item_id), "缺失 item: %s" % item_id)


func test_is_placeable():
	assert_true(db.is_placeable("dirt"))
	assert_false(db.is_placeable("wood_pickaxe"))
	assert_false(db.is_placeable("unknown"))
```

- [ ] **Step 2: 跑测试，确认 FAIL**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: `Preload file "res://scripts/items/item_db.gd" does not exist`。

- [ ] **Step 3: 创建目录 + 写实现**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/items
```

Create `/workspace/teilaruia/scripts/items/item_db.gd`:

```gdscript
# 物品定义表 (autoload)。所有 item_id → 属性查询的单一入口。
extends Node

# 每个条目：
#   placeable_tile_id: int  # 放置时变成的 tile_id；-1 表示非 placeable
#   tool_kind: String       # "pickaxe"/"axe"/"sword"/""
#   tool_tier: int          # 0 = 非工具或徒手等价；1 = 木质
#   max_stack: int          # 堆叠上限
const _DEFS := {
	"dirt":         {"placeable_tile_id": Tiles.DIRT,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"grass":        {"placeable_tile_id": Tiles.GRASS,     "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"stone":        {"placeable_tile_id": Tiles.STONE,     "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"sand":         {"placeable_tile_id": Tiles.SAND,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"log":          {"placeable_tile_id": Tiles.LOG,       "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"leaves":       {"placeable_tile_id": Tiles.LEAVES,    "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"planks":       {"placeable_tile_id": Tiles.PLANKS,    "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"workbench":    {"placeable_tile_id": Tiles.WORKBENCH, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"door":         {"placeable_tile_id": Tiles.DOOR,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"stick":        {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"wood_sword":   {"placeable_tile_id": -1,              "tool_kind": "sword",   "tool_tier": 1, "max_stack": 1},
	"wood_pickaxe": {"placeable_tile_id": -1,              "tool_kind": "pickaxe", "tool_tier": 1, "max_stack": 1},
	"wood_axe":     {"placeable_tile_id": -1,              "tool_kind": "axe",     "tool_tier": 1, "max_stack": 1},
	"slime_ball":   {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64},
}


func get_def(item_id: String) -> Variant:
	return _DEFS.get(item_id, null)


func is_placeable(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.placeable_tile_id != -1


func max_stack(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.max_stack
```

- [ ] **Step 4: 注册 autoload**

修改 `project.godot` 的 `[autoload]` 段，在 ArtCache 之前加 ItemDB：

```ini
[autoload]

Tiles="*res://scripts/world/tile_data.gd"
SkyLightGrid="*res://scripts/world/sky_light_grid.gd"
ItemDB="*res://scripts/items/item_db.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
```

- [ ] **Step 5: 重建 class 索引 + 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | tail -3
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `30 passed, 0 failed`（P1 的 23 + ItemDB 的 7）。

- [ ] **Step 6: 提交**

```bash
git add scripts/items/item_db.gd tests/unit/test_item_db.gd project.godot
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(items): ItemDB autoload + 14 物品定义 (placeable + tool 属性)"
```

---

## Task 3: Inventory RefCounted 数据类 (TDD)

**Files:**
- Create: `scripts/items/inventory.gd`
- Test: `tests/unit/test_inventory.gd`

`Inventory` 是 36 槽数据容器，纯数据无 UI。槽位 0..8 = hotbar；9..35 = main。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_inventory.gd`:

```gdscript
extends GutTest

const InventoryClass = preload("res://scripts/items/inventory.gd")
var inv


func before_each():
	inv = InventoryClass.new()


func test_starts_empty():
	for i in 36:
		assert_null(inv.slots[i])


func test_add_into_first_empty():
	assert_eq(inv.add("dirt", 5), 0)
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[0].count, 5)


func test_add_stacks_onto_same_id():
	inv.add("dirt", 5)
	inv.add("dirt", 3)
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[0].count, 8)


func test_add_overflows_to_next_slot_when_max_stack_hit():
	inv.add("dirt", 60)
	inv.add("dirt", 10)  # 60 + 10 = 70, max=64 → 第一槽 64，第二槽 6
	assert_eq(inv.slots[0].count, 64)
	assert_eq(inv.slots[1].item_id, "dirt")
	assert_eq(inv.slots[1].count, 6)


func test_add_returns_leftover_when_full():
	# 全部 36 槽塞满 dirt → 64 * 36 = 2304
	assert_eq(inv.add("dirt", 2304), 0)
	assert_eq(inv.add("dirt", 5), 5, "全满后剩余 5")


func test_add_tool_does_not_stack_beyond_1():
	inv.add("wood_pickaxe", 1)
	inv.add("wood_pickaxe", 1)
	assert_eq(inv.slots[0].count, 1)
	assert_eq(inv.slots[1].count, 1)


func test_remove_partial():
	inv.add("dirt", 10)
	var took = inv.remove(0, 3)
	assert_eq(took, 3)
	assert_eq(inv.slots[0].count, 7)


func test_remove_more_than_available_returns_available():
	inv.add("dirt", 5)
	var took = inv.remove(0, 10)
	assert_eq(took, 5)
	assert_null(inv.slots[0])


func test_remove_empties_slot_when_zero():
	inv.add("dirt", 1)
	inv.remove(0, 1)
	assert_null(inv.slots[0])


func test_swap():
	inv.add("dirt", 5)
	inv.add("stone", 3)  # 落到 slot 1（不同 id）
	# 先确认布局
	assert_eq(inv.slots[0].item_id, "dirt")
	assert_eq(inv.slots[1].item_id, "stone")
	inv.swap(0, 1)
	assert_eq(inv.slots[0].item_id, "stone")
	assert_eq(inv.slots[1].item_id, "dirt")


func test_split_half_even_count():
	inv.add("dirt", 10)
	var half = inv.split_half(0)
	assert_eq(half.item_id, "dirt")
	assert_eq(half.count, 5)
	assert_eq(inv.slots[0].count, 5)


func test_split_half_odd_count_leaves_larger():
	inv.add("dirt", 7)
	var half = inv.split_half(0)
	assert_eq(half.count, 3)
	assert_eq(inv.slots[0].count, 4)


func test_split_half_on_empty_returns_null():
	assert_null(inv.split_half(0))


func test_split_half_on_count_1_returns_null():
	inv.add("wood_pickaxe", 1)
	assert_null(inv.split_half(0))
	assert_eq(inv.slots[0].count, 1)
```

- [ ] **Step 2: 跑测试，FAIL**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: preload 失败。

- [ ] **Step 3: 写实现**

Create `/workspace/teilaruia/scripts/items/inventory.gd`:

```gdscript
# 36 槽物品容器。0..8 = hotbar；9..35 = main。
# 槽位 = null 或 {"item_id": String, "count": int}。
# 合成 grid 不在这里，由 CraftingPanel 自持。
class_name Inventory extends RefCounted

const HOTBAR_SIZE := 9
const MAIN_SIZE := 27
const TOTAL := HOTBAR_SIZE + MAIN_SIZE  # 36

var slots: Array = []


func _init() -> void:
	slots.resize(TOTAL)
	slots.fill(null)


# 把 count 个 item_id 塞入 inventory。返回还没塞下的数量（>= 0）。
func add(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var max_per_slot: int = ItemDB.max_stack(item_id)
	if max_per_slot <= 0:
		return count
	# 先填同 id 已有的槽
	for i in TOTAL:
		if count == 0:
			break
		var s = slots[i]
		if s == null or s.item_id != item_id:
			continue
		var room: int = max_per_slot - s.count
		if room <= 0:
			continue
		var n: int = min(room, count)
		s.count += n
		count -= n
	# 再找空槽
	for i in TOTAL:
		if count == 0:
			break
		if slots[i] != null:
			continue
		var n: int = min(max_per_slot, count)
		slots[i] = {"item_id": item_id, "count": n}
		count -= n
	return count


# 从指定槽拿走至多 count 个。返回实际拿走数。槽空则置 null。
func remove(slot_idx: int, count: int) -> int:
	if slot_idx < 0 or slot_idx >= TOTAL:
		return 0
	var s = slots[slot_idx]
	if s == null:
		return 0
	var n: int = min(s.count, count)
	s.count -= n
	if s.count <= 0:
		slots[slot_idx] = null
	return n


func swap(a: int, b: int) -> void:
	if a < 0 or a >= TOTAL or b < 0 or b >= TOTAL:
		return
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp


# 从指定槽拆走一半 (count / 2)。原槽留下较大的一半 (count - count/2)。
# 拆走 count == 1 或空槽时返回 null。
func split_half(slot_idx: int) -> Variant:
	if slot_idx < 0 or slot_idx >= TOTAL:
		return null
	var s = slots[slot_idx]
	if s == null or s.count <= 1:
		return null
	var half: int = s.count / 2  # 向下取整 → 较小的那半
	s.count -= half
	return {"item_id": s.item_id, "count": half}
```

- [ ] **Step 4: 跑测试，PASS**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `44 passed, 0 failed` (P1 23 + ItemDB 7 + Inventory 14)。

- [ ] **Step 5: 提交**

```bash
git add scripts/items/inventory.gd tests/unit/test_inventory.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(items): Inventory RefCounted - 36 槽 add/remove/swap/split_half + 14 单元测试"
```

---

## Task 4: RecipeDB autoload (TDD)

**Files:**
- Create: `scripts/crafting/recipe_db.gd`
- Test: `tests/unit/test_recipe_db.gd`
- Modify: `project.godot`

`RecipeDB` 存 6 个配方的形状定义。每个 recipe 用 ASCII pattern 描述（"" = 空，"log"/"planks"/"stick" 等 item_id）。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_recipe_db.gd`:

```gdscript
extends GutTest

const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
var db


func before_each():
	db = RecipeDBClass.new()
	add_child_autofree(db)


func test_has_6_recipes():
	assert_eq(db.all_recipes().size(), 6)


func test_planks_recipe():
	var r = db.get_recipe("planks")
	assert_not_null(r)
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "planks")
	assert_eq(r.output_count, 4)
	# 形状里至少有一个 "log"
	var has_log := false
	for row in r.pattern:
		for cell in row:
			if cell == "log":
				has_log = true
	assert_true(has_log)


func test_wood_pickaxe_recipe():
	var r = db.get_recipe("wood_pickaxe")
	assert_eq(r.grid_size, Vector2i(3, 3))
	assert_eq(r.output_id, "wood_pickaxe")
	assert_eq(r.output_count, 1)
	# 顶行 3 planks
	assert_eq(r.pattern[0], ["planks", "planks", "planks"])
	# 中柱 stick
	assert_eq(r.pattern[1][1], "stick")
	assert_eq(r.pattern[2][1], "stick")


func test_workbench_recipe():
	var r = db.get_recipe("workbench")
	assert_eq(r.grid_size, Vector2i(2, 2))
	assert_eq(r.output_id, "workbench")
	for row in r.pattern:
		for cell in row:
			assert_eq(cell, "planks")


func test_unknown_recipe_returns_null():
	assert_null(db.get_recipe("nonexistent"))


func test_all_recipes_have_mirror_flag():
	for r in db.all_recipes():
		assert_true(r.has("mirror_ok"))
```

- [ ] **Step 2: 跑测试 FAIL**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: preload 失败。

- [ ] **Step 3: 写实现**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/crafting
```

Create `/workspace/teilaruia/scripts/crafting/recipe_db.gd`:

```gdscript
# 6 个 Demo 配方。pattern[row][col] = item_id 或 "" (空)。
# grid_size 表 pattern 的形状 (Vector2i(cols, rows))。
# RecipeMatcher 负责把 pattern 平移/镜像后对位匹配玩家的 craft grid。
extends Node

# 每个 recipe 字典：
#   id: String
#   grid_size: Vector2i(cols, rows)
#   pattern: Array[Array[String]]   # rows × cols
#   output_id: String
#   output_count: int
#   mirror_ok: bool
const _RECIPES := [
	{
		"id": "planks",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["log", ""],
			["",    ""],
		],
		"output_id": "planks",
		"output_count": 4,
		"mirror_ok": true,
	},
	{
		"id": "stick",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["planks", ""],
			["planks", ""],
		],
		"output_id": "stick",
		"output_count": 4,
		"mirror_ok": true,
	},
	{
		"id": "workbench",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["planks", "planks"],
			["planks", "planks"],
		],
		"output_id": "workbench",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "planks", ""],
			["", "planks", ""],
			["", "stick",  ""],
		],
		"output_id": "wood_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["planks", "planks", "planks"],
			["",       "stick",  ""],
			["",       "stick",  ""],
		],
		"output_id": "wood_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["planks", "planks", ""],
			["planks", "stick",  ""],
			["",       "stick",  ""],
		],
		"output_id": "wood_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
]


func all_recipes() -> Array:
	return _RECIPES


func get_recipe(recipe_id: String) -> Variant:
	for r in _RECIPES:
		if r.id == recipe_id:
			return r
	return null
```

- [ ] **Step 4: 注册 autoload**

修改 `project.godot` 的 `[autoload]`：

```ini
[autoload]

Tiles="*res://scripts/world/tile_data.gd"
SkyLightGrid="*res://scripts/world/sky_light_grid.gd"
ItemDB="*res://scripts/items/item_db.gd"
RecipeDB="*res://scripts/crafting/recipe_db.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
```

- [ ] **Step 5: 跑测试，PASS**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `50 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/crafting/recipe_db.gd tests/unit/test_recipe_db.gd project.godot
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(crafting): RecipeDB autoload - 6 个配方定义 (ASCII pattern)"
```

---

## Task 5: RecipeMatcher (TDD, 最复杂)

**Files:**
- Create: `scripts/crafting/recipe_matcher.gd`
- Test: `tests/unit/test_recipe_matcher.gd`

形状对位 + 镜像匹配。算法：抽出 craft grid 中所有非空 cell 的最小 bbox，与 recipe pattern 的非空 bbox 对齐，逐 cell 比对。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_recipe_matcher.gd`:

```gdscript
extends GutTest

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")


# 把 ASCII row 列表转 craft grid。"." 视作空，其他词视作 item_id。
func _g(rows: Array) -> Array:
	var grid := []
	for row_str in rows:
		var parts: Array = row_str.split(" ", false)
		var row := []
		for p in parts:
			row.append("" if p == "." else String(p))
		grid.append(row)
	return grid


func test_planks_2x2_basic():
	var grid = _g(["log .", ". ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "planks")


func test_planks_2x2_translated_to_topright():
	var grid = _g([". log", ". ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m, "log 在右上角应仍匹配 planks")
	assert_eq(m.recipe_id, "planks")


func test_planks_2x2_in_3x3_grid():
	# 2x2 配方应在 3x3 grid 里也能匹配（任何位置）
	var grid = _g([". . .", ". log .", ". . ."])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "planks")


func test_workbench_recipe():
	var grid = _g(["planks planks", "planks planks"])
	var m = RecipeMatcher.find_match(grid)
	assert_not_null(m)
	assert_eq(m.recipe_id, "workbench")


func test_stick_recipe():
	var grid = _g(["planks .", "planks ."])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "stick")


func test_stick_recipe_mirrored():
	# 镜像形态：planks 在右列
	var grid = _g([". planks", ". planks"])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "stick")


func test_wood_pickaxe_3x3():
	var grid = _g([
		"planks planks planks",
		". stick .",
		". stick .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_pickaxe")


func test_wood_axe_3x3():
	var grid = _g([
		"planks planks .",
		"planks stick .",
		". stick .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_axe")


func test_wood_axe_mirrored():
	# axe 镜像：planks 在右，stick 立柱不变
	var grid = _g([
		". planks planks",
		". stick  planks",
		". stick  .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_axe")


func test_wood_sword_3x3():
	var grid = _g([
		". planks .",
		". planks .",
		". stick  .",
	])
	var m = RecipeMatcher.find_match(grid)
	assert_eq(m.recipe_id, "wood_sword")


func test_empty_grid_no_match():
	var grid = _g([". . .", ". . .", ". . ."])
	assert_null(RecipeMatcher.find_match(grid))


func test_wrong_item_no_match():
	var grid = _g(["dirt .", ". ."])  # dirt 不在任何 recipe 里
	assert_null(RecipeMatcher.find_match(grid))


func test_partial_pattern_no_match():
	# pickaxe 缺一个 stick → 不应匹配
	var grid = _g([
		"planks planks planks",
		". stick .",
		". . .",
	])
	assert_null(RecipeMatcher.find_match(grid))


func test_extra_item_no_match():
	# planks recipe 是 1 个 log，多放一个 dirt → 不应匹配
	var grid = _g(["log dirt", ". ."])
	assert_null(RecipeMatcher.find_match(grid))
```

- [ ] **Step 2: 跑测试 FAIL**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: preload 失败。

- [ ] **Step 3: 写实现**

Create `/workspace/teilaruia/scripts/crafting/recipe_matcher.gd`:

```gdscript
# 形状对位 + 镜像配方匹配。静态调用。
# grid: Array[Array[String]]，每个 cell = "" 或 item_id。
# 返回 null 或 {"recipe_id": String, "output_id": String, "output_count": int,
#               "input_cells": Array[Vector2i]}  # 哪些 cell 是被消耗的输入
extends RefCounted


static func find_match(grid: Array) -> Variant:
	for r in RecipeDB.all_recipes():
		var hit = _match_recipe(grid, r, false)
		if hit != null:
			return hit
		if r.mirror_ok:
			hit = _match_recipe(grid, r, true)
			if hit != null:
				return hit
	return null


# 把 pattern (可能 mirrored) 平移到 grid 上所有可能位置，逐 cell 比对。
static func _match_recipe(grid: Array, recipe: Dictionary, mirror: bool) -> Variant:
	var pattern: Array = _maybe_mirror(recipe.pattern, mirror)
	var pat_rows: int = pattern.size()
	var pat_cols: int = (pattern[0] as Array).size()

	# pattern 自身非空 bbox
	var pat_bbox = _bbox_of_nonempty(pattern)
	if pat_bbox == null:
		return null  # pattern 全空 → 不可能匹配
	var pat_min: Vector2i = pat_bbox[0]
	var pat_max: Vector2i = pat_bbox[1]

	var grid_rows: int = grid.size()
	var grid_cols: int = (grid[0] as Array).size()

	# grid 非空 bbox
	var grid_bbox = _bbox_of_nonempty(grid)
	if grid_bbox == null:
		return null
	var grid_min: Vector2i = grid_bbox[0]
	var grid_max: Vector2i = grid_bbox[1]

	# 两个 bbox 尺寸必须一致
	if (grid_max - grid_min) != (pat_max - pat_min):
		return null

	# pattern 的 (pat_min) 应对位到 grid 的 (grid_min)
	# 整张 grid 必须满足：grid[grid_min + d] == pattern[pat_min + d]，其余 grid cell 必须为空
	var dx: int = grid_min.x - pat_min.x
	var dy: int = grid_min.y - pat_min.y
	var input_cells: Array[Vector2i] = []

	for gr in grid_rows:
		for gc in grid_cols:
			var pr: int = gr - dy
			var pc: int = gc - dx
			var grid_cell: String = grid[gr][gc]
			var pat_cell: String = ""
			if pr >= 0 and pr < pat_rows and pc >= 0 and pc < pat_cols:
				pat_cell = pattern[pr][pc]
			if grid_cell != pat_cell:
				return null
			if pat_cell != "":
				input_cells.append(Vector2i(gc, gr))

	return {
		"recipe_id": recipe.id,
		"output_id": recipe.output_id,
		"output_count": recipe.output_count,
		"input_cells": input_cells,
	}


# 返回 [min_coord, max_coord] (Vector2i)，包围所有非空 cell。全空 → null。
static func _bbox_of_nonempty(grid: Array) -> Variant:
	var rows: int = grid.size()
	var cols: int = (grid[0] as Array).size()
	var found := false
	var min_r := rows
	var max_r := -1
	var min_c := cols
	var max_c := -1
	for r in rows:
		for c in cols:
			if grid[r][c] != "":
				found = true
				if r < min_r: min_r = r
				if r > max_r: max_r = r
				if c < min_c: min_c = c
				if c > max_c: max_c = c
	if not found:
		return null
	return [Vector2i(min_c, min_r), Vector2i(max_c, max_r)]


static func _maybe_mirror(pattern: Array, do_mirror: bool) -> Array:
	if not do_mirror:
		return pattern
	var result := []
	for row in pattern:
		var reversed_row: Array = (row as Array).duplicate()
		reversed_row.reverse()
		result.append(reversed_row)
	return result
```

- [ ] **Step 4: 跑测试，PASS**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `64 passed, 0 failed` (加 14 个 matcher 测试)。

- [ ] **Step 5: 提交**

```bash
git add scripts/crafting/recipe_matcher.gd tests/unit/test_recipe_matcher.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(crafting): RecipeMatcher 形状对位 + 镜像 + 14 边界用例"
```

---

## Task 6: ItemDrop 实体

**Files:**
- Create: `scripts/items/item_drop.gd`
- Create: `scenes/items/item_drop.tscn`

ItemDrop 是 Area2D，承载 item_id + count。Sprite 显示物品图标，30 秒后 queue_free。spawn 时有弹跳动量、受重力。

- [ ] **Step 1: 写 item_drop.gd**

Create `/workspace/teilaruia/scripts/items/item_drop.gd`:

```gdscript
# 地上的物品堆。Area2D 检测玩家碰触，触发拾取。
extends Area2D

const GRAVITY := 600.0
const FRICTION := 200.0
const MAX_FALL_SPEED := 400.0
const LIFETIME_SECONDS := 30.0
const PICKUP_DELAY := 0.4  # 刚 spawn 时短暂无法拾取，避免挖完瞬间吸进
const TILE_SIZE := 16

@export var item_id: String = ""
@export var count: int = 1

@onready var sprite: Sprite2D = $Sprite2D
@onready var lifetime: Timer = $Lifetime

var velocity: Vector2 = Vector2.ZERO
var _pickup_ready: bool = false


func _ready() -> void:
	if item_id != "":
		sprite.texture = ArtCache.get_inventory_icon(item_id)
	lifetime.wait_time = LIFETIME_SECONDS
	lifetime.one_shot = true
	lifetime.start()
	lifetime.timeout.connect(queue_free)
	# 初始随机弹跳动量
	velocity = Vector2(randf_range(-30.0, 30.0), -80.0)
	# 短暂延迟才可拾取
	get_tree().create_timer(PICKUP_DELAY).timeout.connect(func(): _pickup_ready = true)
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y = min(velocity.y + GRAVITY * delta, MAX_FALL_SPEED)
	# 水平摩擦
	velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)
	var prev_position := position
	position += velocity * delta
	# 简单地面检测：查脚下 tile 是否实心
	var terrain := get_tree().get_first_node_in_group("terrain_layer")
	if terrain != null:
		var foot_tile: Vector2i = terrain.local_to_map(terrain.to_local(global_position + Vector2(0, 4)))
		var tid: int = terrain.get_cell_source_id(foot_tile)
		if tid != -1 and Tiles.is_solid(tid):
			# 落地：复位到地表 + 反弹一次
			if velocity.y > 0.0:
				position = prev_position
				velocity.y = -velocity.y * 0.25
				velocity.x *= 0.5
				if abs(velocity.y) < 30.0:
					velocity.y = 0.0


func _on_body_entered(body: Node) -> void:
	if not _pickup_ready:
		return
	if not body.has_node("PlayerInventory"):
		return
	var pi: Node = body.get_node("PlayerInventory")
	if not pi.has_method("pickup"):
		return
	var leftover: int = pi.pickup(item_id, count)
	if leftover == 0:
		queue_free()
	else:
		count = leftover
```

- [ ] **Step 2: 写 item_drop.tscn**

Run:
```bash
mkdir -p /workspace/teilaruia/scenes/items
```

Create `/workspace/teilaruia/scenes/items/item_drop.tscn`:

```
[gd_scene load_steps=4 format=3 uid="uid://b5teilaruiadrop"]

[ext_resource type="Script" path="res://scripts/items/item_drop.gd" id="1_drop"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_drop"]
size = Vector2(8, 8)

[sub_resource type="CircleShape2D" id="CircleShape2D_pickup"]
radius = 10.0

[node name="ItemDrop" type="Area2D"]
script = ExtResource("1_drop")
collision_layer = 0
collision_mask = 1

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_pickup")

[node name="Lifetime" type="Timer" parent="."]
```

- [ ] **Step 3: 冷启动验证场景解析**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
```

Expected: `clean`。

- [ ] **Step 4: 提交**

```bash
git add scripts/items/item_drop.gd scenes/items/item_drop.tscn
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(items): ItemDrop Area2D 实体 + 弹跳动量 + 30s 自毁 + 拾取信号"
```

---

## Task 7: PlayerInventory 节点 + pickup 接口

**Files:**
- Create: `scripts/player/player_inventory.gd`
- Modify: `scenes/player/player.tscn` (加 PlayerInventory child)

`PlayerInventory` 节点持有一个 `Inventory` 实例 + 当前热键 index。提供 `pickup(item_id, count)` 让 ItemDrop 调。

- [ ] **Step 1: 写 player_inventory.gd**

Create `/workspace/teilaruia/scripts/player/player_inventory.gd`:

```gdscript
# 玩家库存节点。挂在 Player 下，作为唯一的 Inventory 持有者。
# UI（HotbarView）和 PlayerAction 都通过这里访问 inventory。
extends Node

signal inventory_changed
signal hotbar_selection_changed(index: int)

var inventory: Inventory
var hotbar_selected: int = 0  # 0..8


func _ready() -> void:
	inventory = Inventory.new()


func _unhandled_input(event: InputEvent) -> void:
	# 数字键 1-9 选热键
	for i in 9:
		if Input.is_action_just_pressed("hotbar_%d" % (i + 1)):
			set_hotbar_selection(i)
			return
	# 滚轮切换
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_hotbar_selection((hotbar_selected - 1 + 9) % 9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_hotbar_selection((hotbar_selected + 1) % 9)


func set_hotbar_selection(idx: int) -> void:
	idx = clampi(idx, 0, 8)
	if idx == hotbar_selected:
		return
	hotbar_selected = idx
	hotbar_selection_changed.emit(idx)


# 给 ItemDrop 调。返回还塞不下的数量。
func pickup(item_id: String, count: int) -> int:
	var leftover: int = inventory.add(item_id, count)
	if leftover != count:
		inventory_changed.emit()
	return leftover


func current_hotbar_slot() -> Variant:
	return inventory.slots[hotbar_selected]


func current_tool_kind() -> String:
	var s = current_hotbar_slot()
	if s == null:
		return ""
	var def = ItemDB.get_def(s.item_id)
	if def == null:
		return ""
	return def.tool_kind


func current_tool_tier() -> int:
	var s = current_hotbar_slot()
	if s == null:
		return 0
	var def = ItemDB.get_def(s.item_id)
	return 0 if def == null else def.tool_tier


# 消耗当前 hotbar 槽 1 个
func consume_current(n: int = 1) -> int:
	var taken: int = inventory.remove(hotbar_selected, n)
	if taken > 0:
		inventory_changed.emit()
	return taken
```

- [ ] **Step 2: 修改 player.tscn 加 PlayerInventory child**

修改 `/workspace/teilaruia/scenes/player/player.tscn`，在文件末尾追加（在最后一个节点之后）：

完整新版本：

```
[gd_scene load_steps=4 format=3 uid="uid://b1teilaruiaplayer"]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1_ctrl"]
[ext_resource type="Script" path="res://scripts/player/player_inventory.gd" id="2_inv"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(10, 22)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_ctrl")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -12)
centered = false
offset = Vector2(-6, 0)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -11)
shape = SubResource("RectangleShape2D_player")

[node name="PlayerInventory" type="Node" parent="."]
script = ExtResource("2_inv")
```

- [ ] **Step 3: 冷启动验证**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，64 个测试仍全过。

- [ ] **Step 4: 提交**

```bash
git add scripts/player/player_inventory.gd scenes/player/player.tscn
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): PlayerInventory 节点 + 热键选择 + pickup 接口 + 工具查询"
```

---

## Task 8: PlayerAction 节点 - 鼠标瞄准 + 触达检查

**Files:**
- Create: `scripts/player/player_action.gd`
- Modify: `scenes/player/player.tscn` (加 PlayerAction child)
- Modify: `scripts/world/world.gd` (terrain_layer 加 group)
- Test: `tests/unit/test_player_action.gd`

`PlayerAction` 是 Player 下的 Node2D，负责：
- 鼠标 → tile coord
- 距离检查
- 挖进度状态
- 调 PlayerInventory 消耗物品

本 task 先做瞄准 + 触达。挖放逻辑放后续。

- [ ] **Step 1: 修改 world.gd 让 terrain_layer 加入 group**

修改 `/workspace/teilaruia/scripts/world/world.gd` 的 `_ready` 函数，在 `terrain_layer.tile_set = ...` 之后加一行：

```gdscript
func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
	terrain_layer.add_to_group("terrain_layer")
	_generate_and_apply()
	_spawn_player()
	SkyLightGrid.recompute_from(_tiles)
```

- [ ] **Step 2: 写 player_action.gd（先只放瞄准 + 触达，挖放下个 task 加）**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/player
```

Create `/workspace/teilaruia/scripts/player/player_action.gd`:

```gdscript
# 玩家交互：鼠标瞄准、距离检查、挖放进度。
# 持有挖掘状态 (_mining_target, _mining_progress)；放置/拾取由各自方法触发。
extends Node2D

const TILE_SIZE := 16
const REACH_TILES := 4   # 玩家中心到目标 tile 中心的曼哈顿距离限制
const INVALID_TILE := Vector2i(-1, -1)

# 测试可注入瞄准坐标，绕开实际鼠标 (default 时用真实 mouse)
var aim_override: Variant = null

# Mining state
var _mining_target: Vector2i = INVALID_TILE
var _mining_progress: float = 0.0


func aim_tile_coord() -> Vector2i:
	if aim_override != null:
		return aim_override as Vector2i
	var terrain := _terrain()
	if terrain == null:
		return INVALID_TILE
	var mouse_world: Vector2 = terrain.get_global_mouse_position()
	return terrain.local_to_map(terrain.to_local(mouse_world))


func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer


# 玩家中心所在 tile（脚底 +12px / TILE_SIZE 向下取整 ≈ player.position.y / TILE - 1）
func player_tile() -> Vector2i:
	var parent: Node2D = get_parent() as Node2D
	# Player.origin 是脚底，AABB 中心在 y -11px。统一用脚底为参照点。
	var foot: Vector2 = parent.global_position
	return Vector2i(int(floor(foot.x / TILE_SIZE)), int(floor(foot.y / TILE_SIZE)))


func in_reach(tile: Vector2i) -> bool:
	if tile == INVALID_TILE:
		return false
	var pt: Vector2i = player_tile()
	return abs(tile.x - pt.x) <= REACH_TILES and abs(tile.y - pt.y) <= REACH_TILES
```

- [ ] **Step 3: 修改 player.tscn 加 PlayerAction child**

修改 `/workspace/teilaruia/scenes/player/player.tscn` 完整为：

```
[gd_scene load_steps=5 format=3 uid="uid://b1teilaruiaplayer"]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1_ctrl"]
[ext_resource type="Script" path="res://scripts/player/player_inventory.gd" id="2_inv"]
[ext_resource type="Script" path="res://scripts/player/player_action.gd" id="3_act"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(10, 22)

[node name="Player" type="CharacterBody2D"]
script = ExtResource("1_ctrl")

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -12)
centered = false
offset = Vector2(-6, 0)

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -11)
shape = SubResource("RectangleShape2D_player")

[node name="PlayerInventory" type="Node" parent="."]
script = ExtResource("2_inv")

[node name="PlayerAction" type="Node2D" parent="."]
script = ExtResource("3_act")
```

- [ ] **Step 4: 写测试**

Create `/workspace/teilaruia/tests/unit/test_player_action.gd`:

```gdscript
extends GutTest

const PlayerActionScript = preload("res://scripts/player/player_action.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const MainScene = preload("res://scenes/main.tscn")


func test_in_reach_with_aim_override():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var pt: Vector2i = action.player_tile()
	# 玩家自身所在 tile 必在范围
	action.aim_override = pt
	assert_true(action.in_reach(pt))
	# 4 格远 - 仍在
	action.aim_override = pt + Vector2i(4, 0)
	assert_true(action.in_reach(pt + Vector2i(4, 0)))
	# 5 格远 - 超出
	action.aim_override = pt + Vector2i(5, 0)
	assert_false(action.in_reach(pt + Vector2i(5, 0)))


func test_aim_override_returns_set_value():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	action.aim_override = Vector2i(42, 100)
	assert_eq(action.aim_tile_coord(), Vector2i(42, 100))


func test_invalid_tile_not_in_reach():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	assert_false(action.in_reach(Vector2i(-1, -1)))
```

- [ ] **Step 5: 跑测试，PASS**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | tail -3
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `67 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/player/player_action.gd scenes/player/player.tscn scripts/world/world.gd tests/unit/test_player_action.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): PlayerAction 鼠标瞄准 + 4 tile 触达 + aim_override 测试支持"
```

---

## Task 9: PlayerAction.try_mine (hold-progress)

**Files:**
- Modify: `scripts/player/player_action.gd`
- Modify: `tests/unit/test_player_action.gd` (加挖测试)

按住 LMB 累计进度，达到 tile 硬度 + 工具能挖时清除并生成 drops。

- [ ] **Step 1: 让 SkyLightGrid 缓存 tiles 引用，简化 invalidate_column 签名**

完整替换 `/workspace/teilaruia/scripts/world/sky_light_grid.gd`：

```gdscript
# 天光暗格。recompute_from 后内部缓存 tiles 引用；
# invalidate_column(x) 直接从缓存读列 (调用方负责事先 mutate tiles)。
extends Node

var _width: int = 0
var _height: int = 0
var _exposed: Array = []
var _tiles_ref: Array = []  # 引用，不深拷贝


func recompute_from(tiles: Array) -> void:
	_tiles_ref = tiles
	_width = tiles.size()
	if _width == 0:
		_height = 0
		_exposed = []
		return
	_height = (tiles[0] as Array).size()
	_exposed.resize(_width)
	for x in _width:
		_exposed[x] = _compute_column(tiles[x])


# 兼容旧 P1 API：tiles 参数可选，优先用缓存
func invalidate_column(x: int, tiles: Variant = null) -> void:
	if x < 0 or x >= _width:
		return
	var col: Array = (tiles[x] if tiles != null else _tiles_ref[x])
	_exposed[x] = _compute_column(col)


func is_sky_exposed(x: int, y: int) -> bool:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return false
	return _exposed[x][y]


func _compute_column(col: Array) -> Array:
	var result := []
	result.resize(_height)
	var blocked := false
	for y in _height:
		var tile_id: int = col[y]
		if blocked:
			result[y] = false
			continue
		if Tiles.is_solid(tile_id):
			result[y] = false
			blocked = true
		else:
			result[y] = true
	return result
```

- [ ] **Step 2: 让 World 暴露 `_set_tile` + 给 entities_root 加 group**

修改 `/workspace/teilaruia/scripts/world/world.gd`，完整替换：

```gdscript
# 世界根：生成 tile 数据 → 应用到 TileMapLayer → 放置玩家 → 重算天光。
extends Node2D

const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")

const WORLD_WIDTH := 1024
const WORLD_HEIGHT := 256
const TILE_SIZE := 16

@export var world_seed: int = 20260517

@onready var terrain_layer: TileMapLayer = $TerrainLayer
@onready var entities_root: Node2D = $Entities
@onready var camera: Camera2D = $Camera2D

var spawn_point: Vector2i
var _tiles: Array  # tiles[x][y] = Tiles const


func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
	terrain_layer.add_to_group("terrain_layer")
	entities_root.add_to_group("entities_root")
	_generate_and_apply()
	_spawn_player()
	SkyLightGrid.recompute_from(_tiles)


func _generate_and_apply() -> void:
	var data := WorldGenerator.generate(world_seed, WORLD_WIDTH, WORLD_HEIGHT)
	_tiles = data.tiles
	spawn_point = data.spawn_point
	for x in WORLD_WIDTH:
		for y in WORLD_HEIGHT:
			var tile_id: int = _tiles[x][y]
			if tile_id == Tiles.AIR:
				continue
			terrain_layer.set_cell(Vector2i(x, y), tile_id, Vector2i.ZERO)


func _spawn_player() -> void:
	var player := PlayerScene.instantiate()
	player.position = Vector2(
		spawn_point.x * TILE_SIZE + TILE_SIZE / 2.0,
		spawn_point.y * TILE_SIZE + TILE_SIZE
	)
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO


func get_player() -> CharacterBody2D:
	for child in entities_root.get_children():
		if child is CharacterBody2D:
			return child
	return null


# P2: 让 PlayerAction 在挖/放后能同步 _tiles 给 SkyLightGrid
func _set_tile(x: int, y: int, tile_id: int) -> void:
	if x < 0 or x >= WORLD_WIDTH or y < 0 or y >= WORLD_HEIGHT:
		return
	_tiles[x][y] = tile_id
```

- [ ] **Step 3: 写 player_action.gd 加 mining 逻辑（完整最终版）**

完整替换 `/workspace/teilaruia/scripts/player/player_action.gd`：

```gdscript
# 玩家交互：鼠标瞄准、距离检查、挖放进度。
extends Node2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const TILE_SIZE := 16
const REACH_TILES := 4
const INVALID_TILE := Vector2i(-1, -1)

# Tile 硬度（累计 tool_speed * delta 达此值后挖完，单位"秒"）
const _HARDNESS := {
	Tiles.GRASS: 0.3,
	Tiles.DIRT: 0.3,
	Tiles.SAND: 0.3,
	Tiles.LEAVES: 0.2,
	Tiles.PLANKS: 0.3,
	Tiles.WORKBENCH: 0.5,
	Tiles.DOOR: 0.5,
	Tiles.LOG: 0.6,
	Tiles.STONE: 1.2,
}

# 测试注入
var aim_override: Variant = null         # null = 真实鼠标；Vector2i = 强制
var primary_override: Variant = null     # null = 真实输入；bool = 强制
var place_override: bool = false         # true → try_place 一次

# Mining 状态
var _mining_target: Vector2i = INVALID_TILE
var _mining_progress: float = 0.0


func _physics_process(delta: float) -> void:
	_update_mining(delta)
	if place_override:
		try_place()
		place_override = false


func _update_mining(delta: float) -> void:
	var pressed: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
	if not pressed:
		_mining_target = INVALID_TILE
		_mining_progress = 0.0
		return
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		_mining_target = INVALID_TILE
		_mining_progress = 0.0
		return
	var terrain := _terrain()
	if terrain == null:
		return
	var tid: int = terrain.get_cell_source_id(tile)
	if tid == -1 or not Tiles.is_mineable(tid):
		_mining_target = INVALID_TILE
		_mining_progress = 0.0
		return
	var inv: Node = _inventory_node()
	var tool_kind: String = "" if inv == null else inv.current_tool_kind()
	var required: int = Tiles.required_tool_tier(tid, tool_kind)
	if required == -1:
		# 工具不对 → 永远不能完成
		_mining_target = tile
		_mining_progress = 0.0
		return
	if tile != _mining_target:
		_mining_target = tile
		_mining_progress = 0.0
	_mining_progress += _tool_speed(tool_kind, tid) * delta
	if _mining_progress >= _hardness(tid):
		_finish_mine(tile, tid, tool_kind, terrain)
		_mining_target = INVALID_TILE
		_mining_progress = 0.0


func _finish_mine(tile: Vector2i, tid: int, tool_kind: String, terrain: TileMapLayer) -> void:
	terrain.set_cell(tile, -1)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	SkyLightGrid.invalidate_column(tile.x)
	var drops: Dictionary = Tiles.drops_for(tid, tool_kind)
	for item_id in drops:
		for _i in drops[item_id]:
			_spawn_drop(item_id, tile)


func _spawn_drop(item_id: String, tile: Vector2i) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = Vector2(
		tile.x * TILE_SIZE + TILE_SIZE / 2.0 + randf_range(-3.0, 3.0),
		tile.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent().get_parent()
	entities.add_child(drop)


# Task 10 会替换为真实逻辑
func try_place() -> bool:
	return false


# ---- Helpers ----

func _hardness(tid: int) -> float:
	return _HARDNESS.get(tid, 0.5)


func _tool_speed(tool_kind: String, tid: int) -> float:
	if tool_kind == "axe" and tid == Tiles.LOG:
		return 3.0
	return 1.0


func aim_tile_coord() -> Vector2i:
	if aim_override != null:
		return aim_override as Vector2i
	var terrain := _terrain()
	if terrain == null:
		return INVALID_TILE
	var mouse_world: Vector2 = terrain.get_global_mouse_position()
	return terrain.local_to_map(terrain.to_local(mouse_world))


func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer


func _inventory_node() -> Node:
	var parent: Node = get_parent()
	if parent == null:
		return null
	return parent.get_node_or_null("PlayerInventory")


func player_tile() -> Vector2i:
	var parent: Node2D = get_parent() as Node2D
	var foot: Vector2 = parent.global_position
	return Vector2i(int(floor(foot.x / TILE_SIZE)), int(floor(foot.y / TILE_SIZE)))


func in_reach(tile: Vector2i) -> bool:
	if tile == INVALID_TILE:
		return false
	var pt: Vector2i = player_tile()
	return abs(tile.x - pt.x) <= REACH_TILES and abs(tile.y - pt.y) <= REACH_TILES
```

- [ ] **Step 4: 写挖掘单测**

修改 `/workspace/teilaruia/tests/unit/test_player_action.gd`，**追加**新测试到文件末尾：

```gdscript
func _setup_player_at_tile(tile: Vector2i) -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	# 把玩家瞬移到目标 tile 上方一格 (空气)
	player.global_position = Vector2(tile.x * 16 + 8, (tile.y - 1) * 16)
	await wait_frames(2)
	return {"main": main, "world": world, "player": player, "action": action, "inv": inv}


func test_mine_dirt_with_bare_hands():
	# 在玩家附近放一个 dirt tile，模拟按 LMB 挖完
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 玩家所在 tile 旁的位置放 dirt
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.DIRT, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.DIRT)
	# 模拟按住 LMB 瞄准 target
	action.aim_override = target
	action.primary_override = true
	# 跑足够帧让进度达 hardness=0.3 (60fps → 0.0166s/frame → 0.3/0.0166 ≈ 18 帧)
	await wait_frames(60)
	# 验证 tile 已被移除
	assert_eq(terrain.get_cell_source_id(target), -1, "dirt 应被挖空")


func test_cannot_mine_stone_bare_hand():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	action.primary_override = true
	await wait_frames(60)
	# 徒手挖不动 stone
	assert_eq(terrain.get_cell_source_id(target), Tiles.STONE, "stone 不应被徒手挖空")


func test_can_mine_stone_with_pickaxe():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 给玩家 1 个 wood_pickaxe 选中
	inv.inventory.add("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	action.primary_override = true
	# stone hardness 1.2 → 60fps 需 72 帧
	await wait_frames(90)
	assert_eq(terrain.get_cell_source_id(target), -1, "有镚应能挖空 stone")
```

- [ ] **Step 5: 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | tail -3
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -25
```

Expected: 累计 `70 passed, 0 failed`（加 3 个 mining 测试）。

- [ ] **Step 6: 提交**

```bash
git add scripts/player/player_action.gd scripts/world/world.gd scripts/world/sky_light_grid.gd tests/unit/test_player_action.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): try_mine hold-progress + 工具 tier 拦截 + drops spawn + 3 集成测试"
```

---

## Task 10: PlayerAction.try_place

**Files:**
- Modify: `scripts/player/player_action.gd`
- Modify: `tests/unit/test_player_action.gd`

RMB 在空气 + 触达 + 不重叠玩家的 tile 上，放当前热键的 placeable。

- [ ] **Step 1: 修改 player_action.gd 加 try_place**

修改 `/workspace/teilaruia/scripts/player/player_action.gd`，把 `try_place` 函数 (Task 9 留的 stub) 替换为：

```gdscript
# 返回 true 表示成功放置 (用于测试断言)
func try_place() -> bool:
	var terrain := _terrain()
	var inv: Node = _inventory_node()
	if terrain == null or inv == null:
		return false
	var slot: Variant = inv.current_hotbar_slot()
	if slot == null:
		return false
	if not ItemDB.is_placeable(slot.item_id):
		return false
	var tile: Vector2i = aim_tile_coord()
	if not in_reach(tile):
		return false
	# 目标必须为空气
	if terrain.get_cell_source_id(tile) != -1:
		return false
	# 不与玩家碰撞框重叠（玩家占 2 tile 高：脚底 tile 和上方 tile）
	var pt: Vector2i = player_tile()
	if tile == pt or tile == pt - Vector2i(0, 1):
		return false
	var def = ItemDB.get_def(slot.item_id)
	terrain.set_cell(tile, def.placeable_tile_id, Vector2i.ZERO)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, def.placeable_tile_id)
	inv.consume_current(1)
	SkyLightGrid.invalidate_column(tile.x)
	return true
```

并在 `_physics_process` 末尾增加 secondary 输入处理：

```gdscript
func _physics_process(delta: float) -> void:
	_update_mining(delta)
	if place_override:
		try_place()
		place_override = false
	if Input.is_action_just_pressed("secondary"):
		try_place()
```

- [ ] **Step 2: 写测试**

修改 `/workspace/teilaruia/tests/unit/test_player_action.gd`，追加：

```gdscript
func test_place_dirt_consumes_slot_and_creates_tile():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 给玩家 5 dirt
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	# 目标：玩家头顶上方 2 格（空气 + 触达内 + 不重叠玩家）
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, -2)
	action.aim_override = target
	# 触发 place
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.DIRT, "tile 应出现 dirt")
	assert_eq(inv.inventory.slots[0].count, 4, "槽内 dirt 应减 1")


func test_place_fails_on_occupied_tile():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, -2)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)  # 已占用
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.STONE, "不应覆盖")
	assert_eq(inv.inventory.slots[0].count, 5, "未消耗")


func test_place_fails_when_not_placeable():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	inv.inventory.add("wood_pickaxe", 1)  # 非 placeable
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	action.aim_override = pt + Vector2i(2, -2)
	action.place_override = true
	await wait_frames(3)
	assert_eq(inv.inventory.slots[0].count, 1, "工具不应被消耗")
```

- [ ] **Step 3: 跑测试**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -20
```

Expected: 累计 `73 passed, 0 failed`。

- [ ] **Step 4: 提交**

```bash
git add scripts/player/player_action.gd tests/unit/test_player_action.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): try_place RMB - placeable 检查 + 空气检查 + 不重叠玩家 + 3 测试"
```

---

## Task 11: 整合 ItemDrop pickup 进 player

**Files:**
- (无新文件) — Task 6/7 已写好接口，本 task 加集成测试

- [ ] **Step 1: 写 pickup 集成测试**

Create `/workspace/teilaruia/tests/integration/test_mine_drop_pickup.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_mine_grass_then_pick_up():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 在玩家左侧 2 格放 grass
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.GRASS, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.GRASS)
	action.aim_override = target
	action.primary_override = true
	# 挖完 (hardness 0.3 → ~20 帧)
	await wait_frames(30)
	action.primary_override = false
	# tile 已清，应有 ItemDrop spawn
	assert_eq(terrain.get_cell_source_id(target), -1)
	# 把玩家瞬移到 drop 位置触发 pickup
	player.global_position = Vector2(target.x * 16 + 8, target.y * 16 + 16)
	# 等 pickup_delay (0.4s = 24 帧) + 几帧 area 触发
	await wait_frames(40)
	# 验证 inventory 中有 grass 或 dirt (drops_for grass 是概率)
	var got: int = 0
	for slot in inv.inventory.slots:
		if slot != null and (slot.item_id == "dirt" or slot.item_id == "grass"):
			got += slot.count
	assert_gt(got, 0, "应至少拾到 1 个 dirt/grass")
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `74 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_mine_drop_pickup.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): 挖→掉落→拾取完整闭环"
```

---

## Task 12: Hotbar UI

**Files:**
- Create: `scripts/ui/hud.gd`
- Create: `scripts/ui/hotbar_view.gd`
- Create: `scenes/ui/hud.tscn`
- Modify: `scripts/main.gd` (实例化 HUD)

HUD 是 CanvasLayer，底部居中显示 9 个槽。每个槽 = PanelContainer + TextureRect + Label (count)。当前选中槽边框高亮。

- [ ] **Step 1: 写 hotbar_view.gd**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/ui
```

Create `/workspace/teilaruia/scripts/ui/hotbar_view.gd`:

```gdscript
# 9 格热键栏视图。从 PlayerInventory 读 slots[0..8]，监听 inventory_changed 刷新。
extends HBoxContainer

const SLOT_SIZE := 36

var _player_inv: Node = null
var _slot_nodes: Array = []


func _ready() -> void:
	for i in 9:
		var slot := _make_slot()
		add_child(slot)
		_slot_nodes.append(slot)
	add_theme_constant_override("separation", 4)


func _make_slot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	# Icon
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.add_child(icon)
	# Count label
	var label := Label.new()
	label.name = "Count"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	panel.add_child(label)
	return panel


func bind(player_inv: Node) -> void:
	_player_inv = player_inv
	player_inv.inventory_changed.connect(refresh)
	player_inv.hotbar_selection_changed.connect(func(_i): refresh())
	refresh()


func refresh() -> void:
	if _player_inv == null:
		return
	for i in 9:
		var slot_data = _player_inv.inventory.slots[i]
		var panel: PanelContainer = _slot_nodes[i]
		var icon: TextureRect = panel.get_node("Icon")
		var label: Label = panel.get_node("Count")
		if slot_data == null:
			icon.texture = null
			label.text = ""
		else:
			icon.texture = ArtCache.get_inventory_icon(slot_data.item_id)
			label.text = "" if slot_data.count <= 1 else str(slot_data.count)
		# 高亮选中
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var is_selected: bool = (i == _player_inv.hotbar_selected)
		style.border_color = Color(1, 1, 0.4, 1) if is_selected else Color(0.4, 0.4, 0.4, 1)
		style.border_width_left = 2 if is_selected else 1
		style.border_width_top = 2 if is_selected else 1
		style.border_width_right = 2 if is_selected else 1
		style.border_width_bottom = 2 if is_selected else 1
```

- [ ] **Step 2: 写 hud.gd**

Create `/workspace/teilaruia/scripts/ui/hud.gd`:

```gdscript
# 游戏 HUD 容器。本 P 只承载 hotbar；后续 (P3) 加血条等。
extends CanvasLayer

@onready var hotbar: HBoxContainer = $HotbarAnchor/Hotbar


func bind_player(player: Node2D) -> void:
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv == null:
		return
	hotbar.bind(inv)
```

- [ ] **Step 3: 写 hud.tscn**

Create `/workspace/teilaruia/scenes/ui/hud.tscn`:

```
[gd_scene load_steps=3 format=3 uid="uid://b6teilaruiahud"]

[ext_resource type="Script" path="res://scripts/ui/hud.gd" id="1_hud"]
[ext_resource type="Script" path="res://scripts/ui/hotbar_view.gd" id="2_hbar"]

[node name="HUD" type="CanvasLayer"]
script = ExtResource("1_hud")

[node name="HotbarAnchor" type="Control" parent="."]
layout_mode = 3
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -180.0
offset_top = -56.0
offset_right = 180.0
offset_bottom = -8.0
grow_horizontal = 2
grow_vertical = 0

[node name="Hotbar" type="HBoxContainer" parent="HotbarAnchor"]
layout_mode = 1
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2
alignment = 1
script = ExtResource("2_hbar")
```

- [ ] **Step 4: 修改 main.gd 实例化 HUD**

修改 `/workspace/teilaruia/scripts/main.gd`，完整替换：

```gdscript
# 游戏根：实例化 World + DebugHUD + HUD，串好引用。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var hud: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	hud = HudScene.instantiate()
	add_child(hud)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	# call_deferred 等 World._ready 跑完玩家被 spawn
	_wire_player.call_deferred()


func _wire_player() -> void:
	var player := world.get_player()
	if player == null:
		return
	debug_hud.set_player(player)
	hud.bind_player(player)
```

- [ ] **Step 5: 冷启动验证 + 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，74 个测试仍全过。

- [ ] **Step 6: 提交**

```bash
git add scripts/ui/hud.gd scripts/ui/hotbar_view.gd scenes/ui/hud.tscn scripts/main.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(ui): Hotbar HUD - 9 格图标+计数+高亮，绑 PlayerInventory 信号"
```

---

## Task 13: CraftingPanel 基础（场景 + cursor 状态）

**Files:**
- Create: `scripts/ui/crafting_panel.gd`
- Create: `scenes/ui/crafting_panel.tscn`
- Modify: `scripts/main.gd` (实例化 + 暴露引用)

CraftingPanel 是一个 CanvasLayer，含可隐藏的 input grid + 输出槽 + 鼠标光标随物品。本 task 先做：弹出/关闭、cursor 状态、点击 input/output 的事件路由。具体的"游标点击" + RecipeMatcher 接通放 Task 14。

- [ ] **Step 1: 写 crafting_panel.gd（含 cursor state，无 recipe 接通）**

Create `/workspace/teilaruia/scripts/ui/crafting_panel.gd`:

```gdscript
# 弹出式合成面板。CanvasLayer，遮住游戏画面顶部。
# - open(2, null) → 2x2 模式 (按 C 触发)
# - open(3, workbench_coord) → 3x3 模式 (E + 靠近工作台)
# - 关闭时残留 input 物品退回 Inventory，塞不下的 spawn ItemDrop
extends CanvasLayer

const GRID_2 := 2
const GRID_3 := 3

signal opened
signal closed

@onready var panel: PanelContainer = $Center/Panel
@onready var grid: GridContainer = $Center/Panel/VBox/Row/InputGrid
@onready var output_slot: PanelContainer = $Center/Panel/VBox/Row/OutputSlot
@onready var cursor: PanelContainer = $Cursor

var _player_inv: Node = null
var _mode: int = 0           # 2 or 3 or 0 (closed)
# _cells[r][c] = null 或 {"item_id", "count"}；3x3 满布；2x2 模式只用 [0..1][0..1]
var _cells: Array = []
# 鼠标游标"拿着的物品" or null
var _cursor_item: Variant = null
var _output_preview: Variant = null  # null or {"output_id", "output_count", "input_cells"}


func _ready() -> void:
	_init_cells()
	_build_grid_cells()
	visible = false
	_update_cursor()


func _init_cells() -> void:
	_cells.resize(3)
	for r in 3:
		var row: Array = []
		row.resize(3)
		row.fill(null)
		_cells[r] = row


func bind_inventory(player_inv: Node) -> void:
	_player_inv = player_inv


func open(grid_n: int) -> void:
	_mode = grid_n
	grid.columns = grid_n
	# 清空 grid 视觉 child，重新生成
	for child in grid.get_children():
		child.queue_free()
	_build_grid_cells()
	_init_cells()
	_output_preview = null
	visible = true
	opened.emit()
	_refresh()


func close() -> void:
	# 残留物品退回 Inventory
	_return_cells_to_inventory()
	_cells_clear()
	_output_preview = null
	# 游标残留也退回
	if _cursor_item != null and _player_inv != null:
		_player_inv.pickup(_cursor_item.item_id, _cursor_item.count)
		_cursor_item = null
	visible = false
	_mode = 0
	closed.emit()


func is_open() -> bool:
	return visible and _mode > 0


func _build_grid_cells() -> void:
	# 在 open() 后调用：根据 _mode 重新建 cell 节点（3x3 时建 9 个，2x2 时建 4 个）
	pass  # Task 14 完善


func _refresh() -> void:
	pass  # Task 14 完善


func _update_cursor() -> void:
	pass  # Task 14 完善


func _return_cells_to_inventory() -> void:
	if _player_inv == null:
		return
	for r in 3:
		for c in 3:
			var v = _cells[r][c]
			if v != null:
				_player_inv.pickup(v.item_id, v.count)


func _cells_clear() -> void:
	for r in 3:
		for c in 3:
			_cells[r][c] = null


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel_crafting"):
		close()
```

- [ ] **Step 2: 写 crafting_panel.tscn**

Create `/workspace/teilaruia/scenes/ui/crafting_panel.tscn`:

```
[gd_scene load_steps=3 format=3 uid="uid://b7teilaruiacraft"]

[ext_resource type="Script" path="res://scripts/ui/crafting_panel.gd" id="1_craft"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_panel"]
bg_color = Color(0.1, 0.1, 0.12, 0.92)
border_color = Color(0.5, 0.5, 0.5, 1)
border_width_left = 2
border_width_top = 2
border_width_right = 2
border_width_bottom = 2
content_margin_left = 12.0
content_margin_top = 12.0
content_margin_right = 12.0
content_margin_bottom = 12.0

[node name="CraftingPanel" type="CanvasLayer"]
script = ExtResource("1_craft")

[node name="Center" type="CenterContainer" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="Panel" type="PanelContainer" parent="Center"]
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="VBox" type="VBoxContainer" parent="Center/Panel"]

[node name="Row" type="HBoxContainer" parent="Center/Panel/VBox"]

[node name="InputGrid" type="GridContainer" parent="Center/Panel/VBox/Row"]
columns = 3

[node name="Arrow" type="Label" parent="Center/Panel/VBox/Row"]
text = " → "
theme_override_font_sizes/font_size = 24

[node name="OutputSlot" type="PanelContainer" parent="Center/Panel/VBox/Row"]
custom_minimum_size = Vector2(40, 40)

[node name="Cursor" type="PanelContainer" parent="."]
custom_minimum_size = Vector2(36, 36)
mouse_filter = 2
visible = false
```

- [ ] **Step 3: 修改 main.gd 实例化 CraftingPanel**

修改 `/workspace/teilaruia/scripts/main.gd`，再次完整替换：

```gdscript
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var hud: CanvasLayer
var crafting_panel: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	hud = HudScene.instantiate()
	add_child(hud)

	crafting_panel = CraftingPanelScene.instantiate()
	add_child(crafting_panel)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	crafting_panel.add_to_group("crafting_panel")
	_wire_player.call_deferred()


func _wire_player() -> void:
	var player := world.get_player()
	if player == null:
		return
	debug_hud.set_player(player)
	hud.bind_player(player)
	crafting_panel.bind_inventory(player.get_node("PlayerInventory"))
```

- [ ] **Step 4: 冷启动 + 测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，74 仍通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/crafting_panel.gd scenes/ui/crafting_panel.tscn scripts/main.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(crafting): CraftingPanel 场景骨架 + open/close + Inventory 退回逻辑"
```

---

## Task 14: CraftingPanel - 游标点击 + RecipeMatcher 集成

**Files:**
- Modify: `scripts/ui/crafting_panel.gd`

完整实现：grid cell 节点动态生成、点击事件路由、cursor item 渲染随鼠标移动、find_match 调用 + output preview、点击 output 消耗 inputs。

- [ ] **Step 1: 完整替换 crafting_panel.gd**

替换 `/workspace/teilaruia/scripts/ui/crafting_panel.gd`：

```gdscript
# 弹出式合成面板。CanvasLayer，遮住游戏画面顶部。
extends CanvasLayer

const CELL_SIZE := 40
const CELL_DISABLED_COLOR := Color(0.05, 0.05, 0.05, 0.6)
const CELL_NORMAL_COLOR := Color(0, 0, 0, 0.4)

signal opened
signal closed

@onready var grid: GridContainer = $Center/Panel/VBox/Row/InputGrid
@onready var output_slot: PanelContainer = $Center/Panel/VBox/Row/OutputSlot
@onready var cursor: PanelContainer = $Cursor

var _player_inv: Node = null
var _mode: int = 0
var _cells: Array = []   # 3x3，2x2 模式只用 [0..1][0..1]
var _cell_nodes: Array = []  # 同形状的 UI 节点
var _output_preview: Variant = null
var _cursor_item: Variant = null


func _ready() -> void:
	_cells.resize(3)
	_cell_nodes.resize(3)
	for r in 3:
		var row_d: Array = []; row_d.resize(3); row_d.fill(null)
		var row_n: Array = []; row_n.resize(3); row_n.fill(null)
		_cells[r] = row_d
		_cell_nodes[r] = row_n
	visible = false


func bind_inventory(player_inv: Node) -> void:
	_player_inv = player_inv


func open(grid_n: int) -> void:
	_mode = grid_n
	# 重建 grid 节点
	for child in grid.get_children():
		child.queue_free()
	_cell_nodes = []
	_cell_nodes.resize(3)
	for r in 3:
		var row_n: Array = []; row_n.resize(3); row_n.fill(null)
		_cell_nodes[r] = row_n
	grid.columns = grid_n
	for r in grid_n:
		for c in grid_n:
			var cell := _make_cell(r, c)
			grid.add_child(cell)
			_cell_nodes[r][c] = cell
	# 清空数据 + 输出
	for r in 3:
		for c in 3:
			_cells[r][c] = null
	_output_preview = null
	_refresh_output()
	_refresh_cells()
	# 同时把 OutputSlot 绑点击
	if not output_slot.gui_input.is_connected(_on_output_clicked):
		output_slot.gui_input.connect(_on_output_clicked)
	visible = true
	opened.emit()


func close() -> void:
	if _player_inv != null:
		for r in 3:
			for c in 3:
				var v = _cells[r][c]
				if v != null:
					_player_inv.pickup(v.item_id, v.count)
					_cells[r][c] = null
		if _cursor_item != null:
			_player_inv.pickup(_cursor_item.item_id, _cursor_item.count)
	_cursor_item = null
	_output_preview = null
	cursor.visible = false
	visible = false
	_mode = 0
	closed.emit()


func is_open() -> bool:
	return visible and _mode > 0


func _make_cell(r: int, c: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CELL_SIZE, CELL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = CELL_NORMAL_COLOR
	style.border_color = Color(0.4, 0.4, 0.4, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	panel.add_child(icon)
	var label := Label.new()
	label.name = "Count"
	label.add_theme_font_size_override("font_size", 10)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	panel.add_child(label)
	panel.gui_input.connect(_on_cell_clicked.bind(r, c))
	return panel


func _process(_delta: float) -> void:
	if cursor.visible:
		cursor.position = cursor.get_viewport().get_mouse_position() - Vector2(CELL_SIZE / 2, CELL_SIZE / 2)


func _on_cell_clicked(event: InputEvent, r: int, c: int) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_LEFT:
		_left_click_cell(r, c)
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		_right_click_cell(r, c)
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func _left_click_cell(r: int, c: int) -> void:
	var s = _cells[r][c]
	if _cursor_item == null:
		# 拿起
		if s != null:
			_cursor_item = s
			_cells[r][c] = null
	else:
		if s == null:
			# 放下
			_cells[r][c] = _cursor_item
			_cursor_item = null
		elif s.item_id == _cursor_item.item_id:
			# 合并 (受 max_stack)
			var ms: int = ItemDB.max_stack(s.item_id)
			var room: int = ms - s.count
			if room > 0:
				var n: int = min(room, _cursor_item.count)
				s.count += n
				_cursor_item.count -= n
				if _cursor_item.count <= 0:
					_cursor_item = null
		else:
			# 交换
			var tmp = _cells[r][c]
			_cells[r][c] = _cursor_item
			_cursor_item = tmp
	_update_cursor_visual()


func _right_click_cell(r: int, c: int) -> void:
	var s = _cells[r][c]
	if _cursor_item == null:
		# split half from cell to cursor
		if s != null and s.count > 1:
			var half: int = s.count / 2
			s.count -= half
			_cursor_item = {"item_id": s.item_id, "count": half}
	else:
		# 放 1 个 (相同 id 或空槽)
		if s == null:
			_cells[r][c] = {"item_id": _cursor_item.item_id, "count": 1}
			_cursor_item.count -= 1
		elif s.item_id == _cursor_item.item_id and s.count < ItemDB.max_stack(s.item_id):
			s.count += 1
			_cursor_item.count -= 1
		if _cursor_item != null and _cursor_item.count <= 0:
			_cursor_item = null
	_update_cursor_visual()


func _on_output_clicked(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	if _output_preview == null:
		return
	var output_id: String = _output_preview.output_id
	var output_count: int = _output_preview.output_count
	# 游标必须能装下输出
	if _cursor_item != null and _cursor_item.item_id != output_id:
		return
	var max_stack: int = ItemDB.max_stack(output_id)
	if _cursor_item != null and _cursor_item.count + output_count > max_stack:
		return
	# 消耗 inputs：input_cells 是 grid 坐标 (Vector2i(col, row))
	for cell in _output_preview.input_cells:
		var s = _cells[cell.y][cell.x]
		if s != null:
			s.count -= 1
			if s.count <= 0:
				_cells[cell.y][cell.x] = null
	# 把 output 装到 cursor
	if _cursor_item == null:
		_cursor_item = {"item_id": output_id, "count": output_count}
	else:
		_cursor_item.count += output_count
	_update_cursor_visual()
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func _recompute_output() -> void:
	# 把 _cells (3x3) 切到 _mode x _mode，调 matcher
	var n: int = _mode
	var sub: Array = []
	for r in n:
		var row: Array = []
		for c in n:
			var s = _cells[r][c]
			row.append("" if s == null else String(s.item_id))
		sub.append(row)
	_output_preview = RecipeMatcher.find_match(sub)


func _refresh_cells() -> void:
	for r in _mode:
		for c in _mode:
			var panel: PanelContainer = _cell_nodes[r][c]
			var s = _cells[r][c]
			var icon: TextureRect = panel.get_node("Icon")
			var label: Label = panel.get_node("Count")
			if s == null:
				icon.texture = null
				label.text = ""
			else:
				icon.texture = ArtCache.get_inventory_icon(s.item_id)
				label.text = "" if s.count <= 1 else str(s.count)


func _refresh_output() -> void:
	var icon_node: Node = output_slot.get_node_or_null("Icon")
	if icon_node == null:
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		output_slot.add_child(icon)
		icon_node = icon
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		output_slot.add_child(lbl)
	var icon: TextureRect = output_slot.get_node("Icon")
	var label: Label = output_slot.get_node("Count")
	if _output_preview == null:
		icon.texture = null
		label.text = ""
	else:
		icon.texture = ArtCache.get_inventory_icon(_output_preview.output_id)
		label.text = "" if _output_preview.output_count <= 1 else str(_output_preview.output_count)


func _update_cursor_visual() -> void:
	if _cursor_item == null:
		cursor.visible = false
		return
	cursor.visible = true
	# 重建 cursor 子节点 (一次性即可，每帧只更新内容)
	var icon: TextureRect = cursor.get_node_or_null("Icon")
	if icon == null:
		icon = TextureRect.new()
		icon.name = "Icon"
		icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		cursor.add_child(icon)
		var lbl := Label.new()
		lbl.name = "Count"
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		lbl.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
		cursor.add_child(lbl)
	var label: Label = cursor.get_node("Count")
	icon.texture = ArtCache.get_inventory_icon(_cursor_item.item_id)
	label.text = "" if _cursor_item.count <= 1 else str(_cursor_item.count)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("ui_cancel_crafting"):
		close()
		get_viewport().set_input_as_handled()


# ---- 测试用 API ----
# 测试可调 place_in_cell(r, c, item_id, count) 直接设 _cells 状态
func place_in_cell(r: int, c: int, item_id: String, count: int) -> void:
	_cells[r][c] = {"item_id": item_id, "count": count}
	_recompute_output()
	_refresh_cells()
	_refresh_output()


func get_cursor_item() -> Variant:
	return _cursor_item


func get_output_preview() -> Variant:
	return _output_preview


# 测试用：模拟点击 output slot
func simulate_take_output() -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = true
	_on_output_clicked(e)
```

- [ ] **Step 2: 冷启动验证 + 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，74 仍通过。

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/crafting_panel.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(crafting): CraftingPanel 完整 - 游标点击/合并/拆半/输出/RecipeMatcher 集成"
```

---

## Task 15: 触发 2×2 (C 键) 与 3×3 (E + 工作台靠近)

**Files:**
- Modify: `scripts/player/player_action.gd`

按 C 弹 2×2；按 E + 范围内有 workbench → 弹 3×3；面板已开则 E/C 关闭。

- [ ] **Step 1: 修改 player_action.gd 加触发逻辑**

在 `/workspace/teilaruia/scripts/player/player_action.gd` 的 `_physics_process` 末尾追加 + 加新方法：

```gdscript
func _physics_process(delta: float) -> void:
	_update_mining(delta)
	if place_override:
		try_place()
		place_override = false
	if Input.is_action_just_pressed("secondary"):
		try_place()
	if Input.is_action_just_pressed("crafting_2x2"):
		_toggle_crafting(2)
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()


func _toggle_crafting(n: int) -> void:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
	else:
		cp.open(n)


func _try_open_workbench_or_close() -> void:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	if cp == null:
		return
	if cp.is_open():
		cp.close()
		return
	if _has_workbench_nearby():
		cp.open(3)


func _has_workbench_nearby() -> bool:
	var terrain := _terrain()
	if terrain == null:
		return false
	var pt: Vector2i = player_tile()
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var tid: int = terrain.get_cell_source_id(pt + Vector2i(dx, dy))
			if tid == Tiles.WORKBENCH:
				return true
	return false
```

- [ ] **Step 2: 跑测试（应仍通过）**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 74 通过。

- [ ] **Step 3: 提交**

```bash
git add scripts/player/player_action.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): C 切 2x2 合成 / E + 工作台 chebyshev≤2 开 3x3"
```

---

## Task 16: 集成测试 - 2×2 合成闭环

**Files:**
- Create: `tests/integration/test_craft_loop.gd`

完整跑通：玩家有 1 log → 用 2x2 合成 4 planks → 再用 4 planks 合 1 workbench。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_craft_loop.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_craft_planks_from_log():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	# 玩家持 1 log
	inv.inventory.add("log", 1)
	# 开 2x2
	cp.open(2)
	# 把 log 放到 (0,0)
	cp.place_in_cell(0, 0, "log", 1)
	# 现在 output_preview 应为 planks x 4
	var preview = cp.get_output_preview()
	assert_not_null(preview, "log 应触发 planks 配方")
	assert_eq(preview.output_id, "planks")
	assert_eq(preview.output_count, 4)
	# 点击 output → cursor 拿 4 planks
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_not_null(ci)
	assert_eq(ci.item_id, "planks")
	assert_eq(ci.count, 4)
	# 关闭面板 → cursor + cells 退回 inventory
	cp.close()
	# 检查 inventory 中有 4 planks
	var total_planks: int = 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "planks":
			total_planks += slot.count
	assert_eq(total_planks, 4)


func test_craft_workbench_from_planks():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	inv.inventory.add("planks", 4)
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	var preview = cp.get_output_preview()
	assert_eq(preview.output_id, "workbench")
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_eq(ci.item_id, "workbench")
	assert_eq(ci.count, 1)
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `76 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_craft_loop.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): 2x2 合成闭环 (log→planks, planks→workbench)"
```

---

## Task 17: 集成测试 - 3×3 工作台

**Files:**
- Create: `tests/integration/test_workbench_3x3.gd`

放工作台 → 靠近 + E → 3×3 弹 → 合 wood_pickaxe → 关。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_workbench_3x3.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_place_workbench_and_craft_pickaxe():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	# 玩家持 1 workbench + 3 planks + 2 sticks
	inv.inventory.add("workbench", 1)
	inv.inventory.add("planks", 3)
	inv.inventory.add("stick", 2)
	# 选中 workbench 放置
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	# 把 target 上方原本可能存在的 tile 清掉
	terrain.set_cell(target, -1)
	world._set_tile(target.x, target.y, Tiles.AIR)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.WORKBENCH, "workbench 应被放下")
	# 现在 chebyshev ≤ 2，触发 3x3
	# 直接调 cp.open(3) 模拟（实际靠 E 键，单测路径覆盖更可靠）
	cp.open(3)
	# 摆 wood_pickaxe 形状
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "stick", 1)
	cp.place_in_cell(2, 1, "stick", 1)
	var preview = cp.get_output_preview()
	assert_not_null(preview, "应匹配 wood_pickaxe")
	assert_eq(preview.output_id, "wood_pickaxe")
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_eq(ci.item_id, "wood_pickaxe")
	cp.close()
	var has_pickaxe := false
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "wood_pickaxe":
			has_pickaxe = true
	assert_true(has_pickaxe, "wood_pickaxe 应入库")


func test_workbench_proximity_check():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 玩家面前 1 格放 workbench
	var pt: Vector2i = action.player_tile()
	terrain.set_cell(pt + Vector2i(1, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	assert_true(action._has_workbench_nearby(), "1 格邻居应识别")
	terrain.set_cell(pt + Vector2i(1, 0), -1)
	# 3 格远 - 超 chebyshev=2
	terrain.set_cell(pt + Vector2i(3, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	assert_false(action._has_workbench_nearby(), "3 格远应被拒")
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `78 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_workbench_3x3.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): 放工作台 + 3x3 合 wood_pickaxe + chebyshev 距离"
```

---

## Task 18: 整局闭环 smoke 测试

**Files:**
- Create: `tests/integration/test_full_loop.gd`

最大集成：砍木 → 拾 → 合 planks → 合 stick → 合 workbench → 放 → 合 pickaxe → 挖 stone。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_full_loop.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


# 走全闭环。每一步都 assert，定位失败点。
func test_full_survival_loop():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	var pt: Vector2i = action.player_tile()

	# 1. 在玩家右侧放 4 个 log（模拟一棵树），逐个挖完
	for i in 4:
		var t: Vector2i = pt + Vector2i(2 + i, 0)
		terrain.set_cell(t, Tiles.LOG, Vector2i.ZERO)
		world._set_tile(t.x, t.y, Tiles.LOG)
	# 直接给玩家 4 log（绕开拾取的随机概率，集中测合成 + 后续）
	inv.inventory.add("log", 4)

	# 2. 2x2 合成 1 log → 4 planks
	cp.open(2)
	cp.place_in_cell(0, 0, "log", 1)
	var p1 = cp.get_output_preview()
	assert_eq(p1.output_id, "planks")
	cp.simulate_take_output()
	assert_eq(cp.get_cursor_item().count, 4)
	cp.close()
	# 重复 3 次 → 16 planks
	for i in 3:
		cp.open(2)
		cp.place_in_cell(0, 0, "log", 1)
		cp.simulate_take_output()
		cp.close()
	# 库存 planks 至少 16
	var total_planks := 0
	for s in inv.inventory.slots:
		if s != null and s.item_id == "planks":
			total_planks += s.count
	assert_gte(total_planks, 16)

	# 3. 2x2 合 4 planks → 4 sticks
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	var p2 = cp.get_output_preview()
	assert_eq(p2.output_id, "stick")
	cp.simulate_take_output()
	cp.close()

	# 4. 2x2 合 4 planks → 1 workbench
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	var p3 = cp.get_output_preview()
	assert_eq(p3.output_id, "workbench")
	cp.simulate_take_output()
	cp.close()
	# 把 workbench 移到 hotbar 0
	var wb_idx := -1
	for i in 36:
		if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "workbench":
			wb_idx = i
			break
	assert_gte(wb_idx, 0)
	inv.inventory.swap(0, wb_idx)
	inv.set_hotbar_selection(0)

	# 5. 放工作台
	var wb_target: Vector2i = pt + Vector2i(2, -1)
	terrain.set_cell(wb_target, -1)
	world._set_tile(wb_target.x, wb_target.y, Tiles.AIR)
	action.aim_override = wb_target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(wb_target), Tiles.WORKBENCH)

	# 6. 3x3 合 wood_pickaxe (需要 3 planks + 2 sticks)
	cp.open(3)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "stick", 1)
	cp.place_in_cell(2, 1, "stick", 1)
	var p4 = cp.get_output_preview()
	assert_eq(p4.output_id, "wood_pickaxe")
	cp.simulate_take_output()
	cp.close()

	# 7. 挖石头
	# 找到 wood_pickaxe 槽并选中
	var pk_idx := -1
	for i in 36:
		if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "wood_pickaxe":
			pk_idx = i
			break
	assert_gte(pk_idx, 0)
	if pk_idx > 8:
		inv.inventory.swap(0, pk_idx)
		inv.set_hotbar_selection(0)
	else:
		inv.set_hotbar_selection(pk_idx)
	# 在玩家旁放 stone
	var stone_target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(stone_target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(stone_target.x, stone_target.y, Tiles.STONE)
	action.aim_override = stone_target
	action.primary_override = true
	await wait_frames(90)
	assert_eq(terrain.get_cell_source_id(stone_target), -1, "stone 应被挖空")
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 240 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -20
```

Expected: 累计 `79 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_full_loop.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): 整局闭环 - 砍木→2x2合成→放工作台→3x3合镚→挖石"
```

---

## Task 19: 鼠标输入 → CraftingPanel 阻断 game input

**Files:**
- Modify: `scripts/ui/crafting_panel.gd`
- Modify: `scripts/player/player_action.gd`

CraftingPanel 打开时，PlayerAction 的 primary/secondary/crafting_2x2 应该被忽略（避免点 UI 同时挖地）。

- [ ] **Step 1: 修改 player_action.gd `_physics_process` 在动作前加 guard**

把 `_physics_process` 改成：

```gdscript
func _physics_process(delta: float) -> void:
	if _crafting_open():
		return
	_update_mining(delta)
	if place_override:
		try_place()
		place_override = false
	if Input.is_action_just_pressed("secondary"):
		try_place()
	if Input.is_action_just_pressed("crafting_2x2"):
		_toggle_crafting(2)
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()


func _crafting_open() -> bool:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	return cp != null and cp.is_open()
```

但 C/E 关闭面板的逻辑被 `_crafting_open()` 提前 return 拦了。需要让 C/E 即使面板开也能触发。改为：

```gdscript
func _physics_process(delta: float) -> void:
	# C/E 不管面板开关都响应
	if Input.is_action_just_pressed("crafting_2x2"):
		_toggle_crafting(2)
	if Input.is_action_just_pressed("interact"):
		_try_open_workbench_or_close()
	# 其余动作面板开则跳过
	if _crafting_open():
		return
	_update_mining(delta)
	if place_override:
		try_place()
		place_override = false
	if Input.is_action_just_pressed("secondary"):
		try_place()


func _crafting_open() -> bool:
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	return cp != null and cp.is_open()
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 240 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 79 仍通过。

- [ ] **Step 3: 提交**

```bash
git add scripts/player/player_action.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "fix(player): CraftingPanel 打开时禁挖/放，C/E 仍可关闭面板"
```

---

## Task 20: 60 秒无 crash 长跑测试

**Files:**
- Create: `tests/integration/test_smoke_60s.gd`

跑 main scene 模拟 3600 帧 (~60s) 无 error / crash，验证 P2 不引入泄漏。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_smoke_60s.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_main_runs_60_seconds_no_crash():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	# 注：actually 3600 帧 ≈ 60s @ 60fps；GUT 模拟通常更快，按帧数走
	await wait_frames(3600)
	# 还在场景里 = 没崩
	assert_not_null(main.get_node_or_null("World"))
	var player = main.get_node("World").get_player()
	assert_not_null(player)
	# 玩家位置仍在世界范围内
	assert_lt(player.global_position.y, 256 * 16.0)
```

- [ ] **Step 2: 跑测试（长，注意 timeout）**

Run:
```bash
timeout 300 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `80 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_smoke_60s.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): 60 秒长跑 smoke - 无 crash/泄漏"
```

---

## Task 21: spec 进度 + tag P2

**Files:**
- Modify: `docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md`

- [ ] **Step 1: 更新顶层 spec 的实施进度**

修改 `/workspace/teilaruia/docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md` §18 段，把 P2 行从 `⏳` 改为 `✅`：

把：

```markdown
- ⏳ **P2 Items & Interaction** — 待开始（挖/放/掉落/拾取/工具）
- ⏳ **P3 Crafting & UI** — 待开始（背包/合成台/6 配方）
- ⏳ **P4 Content & Persistence** — 待开始（史莱姆/村民/村庄/门/存档）
```

替换为：

```markdown
- ✅ **P2 Items + Interaction + Crafting** — tag `demo-p2-items` — 2026-05-18
  - 挖/放/掉落/拾取/热键栏 UI (9 格)
  - Inventory (36 槽) + ItemDB (14 物品) + RecipeDB (6 配方) + RecipeMatcher (镜像 + 平移)
  - 2×2 内置合成 (C) + 3×3 工作台合成 (E + chebyshev ≤ 2)
  - 工具 tier 强制 (徒手不挖石、木斧砍 LOG ×3)
  - 80 个自动化测试全过
  - 范围说明：把原 spec 的 P3 合成前移到本 P，P3 重定义为"主背包 UI + 内容 + 存档"
- ⏳ **P3 Inventory UI + Content + Persistence** — 待开始（主背包 4×9 UI + 拖拽 + 史莱姆 + 村民 + 门 + 存档）
```

- [ ] **Step 2: 提交 + tag**

```bash
git add docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "docs: 标记 P2 Items+Interaction+Crafting 完成"
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" tag -a demo-p2-items -m "Demo P2 完成: 完整生存开局闭环 + 80 测试通过"
git log --oneline | head -25
```

---

## Spec Coverage Check

对应 spec `2026-05-18-teilaruia-demo-p2-design.md`：
- §2.1 鼠标瞄准 + 距离 → Task 8 ✅
- §2.1 挖 / 放 → Task 9, 10 ✅
- §2.1 ItemDrop / 拾取 → Task 6, 7, 11 ✅
- §2.1 Inventory → Task 3 ✅
- §2.1 热键栏 UI → Task 12 ✅
- §2.1 2×2 / 3×3 UI → Task 13, 14, 15 ✅
- §2.1 6 配方 / 形状匹配 / 镜像 → Task 4, 5 ✅
- §2.1 工具行为 → Task 9 (tier + axe-on-log ×3) ✅
- §2.1 游标式移动 → Task 14 ✅
- §3 InputMap → Task 1 ✅
- §4 数据流（挖/放/拾/合）→ Task 9, 10, 11, 14 ✅
- §5 6 配方表 → Task 4 ✅
- §6 ItemDB → Task 2 ✅
- §7 InputMap → Task 1 ✅
- §8 测试矩阵 → Task 2, 3, 4, 5, 8, 9, 10, 11, 16, 17, 18, 20 ✅
- §9 验收门禁 → Task 18 (整局闭环) + Task 20 (60s) + Task 21 (tag) ✅
- §10 P3 重定义 → Task 21 (spec 更新) ✅

---

## 验收门禁

每 task：
1. 涉及 .gd 时跑全 GUT 测试，无 fail
2. 涉及 .tscn 或 autoload 时跑 `rm -rf .godot && godot --headless --editor --quit` 无 error
3. git status 干净

P2 整体：tag `demo-p2-items` + 80 个测试通过 + spec §18 更新。
