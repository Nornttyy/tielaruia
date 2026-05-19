# 配方重划 + Terraria 风 UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把配方系统对齐 Terraria — 删 stick / 加 4 个物品 + 1 个新 tile / 10 个新配方 / 工具 tier 进阶 / UI 改左上角纵向列表布局。

**Architecture:** 数据层 (TileData / ItemDB / RecipeDB) 先改完跑通,UI 层最后重做。保留 CraftingPanel 内部 `_cells` + `_on_output_clicked` 测试 API 不变,只换 UI 节点;集成测试只需更新 recipe 形状 (planks 代替 stick)。Tier 行为在 `player_action.gd` 集中查表。

**Tech Stack:** Godot 4.3 / GDScript / GUT 测试。

Spec: `docs/superpowers/specs/2026-05-19-recipe-revamp-design.md`

---

## File Structure

**Modify (10 个)**:
- `scripts/world/tile_data.gd` — 加 SLIME_TORCH(13) + 调 LEAVES drops
- `scripts/art/blocks_art.gd` — 加 SLIME_TORCH 调色板/pattern/maps
- `scripts/art/items_art.gd` — 加 3 个石器 16x16 pattern
- `scripts/items/item_db.gd` — 删 stick, 加 4 新物品
- `scripts/autoload/art_cache.gd` — 注册新 tile + 新物品图标
- `scripts/world/tileset_builder.gd` — 加 SLIME_TORCH 到 tile_ids
- `scripts/crafting/recipe_db.gd` — 全量重写 (10 个配方)
- `scripts/player/player_action.gd` — tier 查表 (伤害 + 挖速)
- `scripts/entities/slime.gd` — MAX_HEALTH 6
- `scripts/ui/crafting_panel.gd` — UI 重做 (列表式 + 左上角)
- `scenes/ui/crafting_panel.tscn` — 顶级布局改 PRESET_TOP_LEFT

**Create (1 个)**:
- `tests/unit/test_recipe_db.gd` — 10 个配方各一个命中测

**Update (4 测试)**:
- `tests/unit/test_item_db.gd` — 删 stick, 加 4 新物品检查
- `tests/integration/test_craft_loop.gd` — 删 stick 引用
- `tests/integration/test_workbench_3x3.gd` — wood_pickaxe 改纯 planks
- `tests/integration/test_full_loop.gd` — 整条链不用 stick

---

## Task 1: 新增 SLIME_TORCH tile

**Files:**
- Modify: `scripts/world/tile_data.gd`
- Modify: `scripts/art/blocks_art.gd`
- Modify: `scripts/world/tileset_builder.gd`
- Modify: `scripts/autoload/art_cache.gd`

- [ ] **Step 1: 加 SLIME_TORCH 常量与 _PROPS 到 tile_data.gd**

在文件 `scripts/world/tile_data.gd`,常量定义块末尾追加:
```gdscript
const LEAVES_AUTUMN := 12   # 秋叶 (红橙)
const SLIME_TORCH := 13     # 史莱姆灯 (装饰, 不实心)
```

在 `_PROPS` 字典末尾追加 (在 LEAVES_AUTUMN 之后,字典最后一行 `}` 之前):
```gdscript
	SLIME_TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["slime_torch", 100, 1, 1]],
	},
```

- [ ] **Step 2: 加 SLIME_TORCH 美术到 blocks_art.gd**

在 `scripts/art/blocks_art.gd` 顶部常量区,跟其他 tile id 一起加:
```gdscript
const LEAVES_AUTUMN := 12   # 秋叶 (红橙)
const SLIME_TORCH := 13     # 史莱姆灯
```

在所有调色板定义之后 (找 `const _P_LEAVES_AUTUMN := {` 块结束),加新调色板:
```gdscript
# 史莱姆灯: 暗木棍 + 顶部黄绿史莱姆胶发光感
const _P_SLIME_TORCH := {
	"b": Color8(74, 52, 41),    # 木棍深
	"r": Color8(110, 80, 67),   # 木棍中
	"g": Color8(120, 200, 100), # 胶体绿
	"G": Color8(76, 175, 80),   # 胶体阴影
	"h": Color8(220, 255, 180), # 高光
}
```

在 pattern 定义区 (找 `const _LEAVES_AUTUMN` 块结束),加新 pattern:
```gdscript
# 史莱姆灯: 顶部 4x3 绿胶 + 中间细木棍
const _SLIME_TORCH := [
	"................",
	"....hgggggggh...",
	"...gggGGGggggg..",
	"...ggGGgGGggGg..",
	"...gGgGGGgGGgg..",
	"....ggGGGgggg...",
	".....gggggg.....",
	".......bb.......",
	".......br.......",
	".......bb.......",
	".......br.......",
	".......bb.......",
	".......br.......",
	".......bb.......",
	"......bbbb......",
	"................",
]
```

在 `_PATTERN_MAP` 字典末尾 (`LEAVES_AUTUMN: [_LEAVES_AUTUMN, _P_LEAVES_AUTUMN],` 之后,`}` 之前):
```gdscript
	LEAVES_AUTUMN: [_LEAVES_AUTUMN, _P_LEAVES_AUTUMN],
	SLIME_TORCH: [_SLIME_TORCH, _P_SLIME_TORCH],
}
```

在 `_PALETTES` 字典末尾追加:
```gdscript
	LEAVES_AUTUMN: [_P_LEAVES_AUTUMN["l"], _P_LEAVES_AUTUMN["L"]],
	SLIME_TORCH:   [_P_SLIME_TORCH["g"],   _P_SLIME_TORCH["G"]],
}
```

- [ ] **Step 3: 注册 SLIME_TORCH 到 TileSetBuilder**

修改 `scripts/world/tileset_builder.gd`,在 `tile_ids` 数组末尾加:
```gdscript
	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
		Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.SLIME_TORCH,
	]
```

- [ ] **Step 4: 注册 SLIME_TORCH 到 ArtCache**

修改 `scripts/autoload/art_cache.gd`,在 `_build_blocks` 函数的 tile_ids 数组末尾加 SLIME_TORCH:
```gdscript
	var tile_ids := [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.STONE, BlocksArt.SAND,
		BlocksArt.LOG, BlocksArt.LEAVES, BlocksArt.PLANKS, BlocksArt.WORKBENCH,
		BlocksArt.DOOR, BlocksArt.BEDROCK,
		BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN, BlocksArt.SLIME_TORCH,
	]
```

- [ ] **Step 5: 验证宽度 + 启动无报错**

```bash
awk '/^const _SLIME_TORCH := \[/,/^]$/' scripts/art/blocks_art.gd | grep -oE '"[^"]+"' | awk '{ n=length($0)-2; if (n!=16) print "BAD", n }'
```
Expected: 无输出 (所有行宽 16)

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
```
Expected: `OK` (无报错)

- [ ] **Step 6: 提交**

```bash
git add scripts/world/tile_data.gd scripts/art/blocks_art.gd scripts/world/tileset_builder.gd scripts/autoload/art_cache.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "feat(tile): 加 SLIME_TORCH tile (13) — 史莱姆灯, 装饰用

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: ItemDB — 删 stick, 加 4 个新物品

**Files:**
- Modify: `scripts/items/item_db.gd`
- Modify: `tests/unit/test_item_db.gd`

- [ ] **Step 1: 改 item_db.gd**

打开 `scripts/items/item_db.gd`,在 `_DEFS` 字典中:
1. 删除这一行 `"stick":        {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64},`
2. 在 `"slime_ball": ...` 之后加 4 行 (在 `}` 之前):

```gdscript
	"slime_ball":   {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"stone_sword":   {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1},
	"stone_pickaxe": {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1},
	"stone_axe":     {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1},
	"slime_torch":   {"placeable_tile_id": Tiles.SLIME_TORCH,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
}
```

- [ ] **Step 2: 改 test_item_db.gd**

修改 `tests/unit/test_item_db.gd::test_all_known_items_present`,把列表中的 `"stick"` 删除,在末尾加 4 项:

```gdscript
func test_all_known_items_present():
	for item_id in ["dirt", "grass", "stone", "sand", "log", "leaves",
			"planks", "workbench", "door",
			"wood_sword", "wood_pickaxe", "wood_axe", "slime_ball",
			"stone_sword", "stone_pickaxe", "stone_axe", "slime_torch"]:
		assert_not_null(db.get_def(item_id), "缺失 item: %s" % item_id)
```

- [ ] **Step 3: 加一个 test_stick_is_removed 测试**

在 `tests/unit/test_item_db.gd` 末尾加:
```gdscript
func test_stick_removed():
	# Terraria 风格: 没有 stick 中间品
	assert_null(db.get_def("stick"), "stick 已删除")
```

- [ ] **Step 4: 跑 test_item_db 验证**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_item_db.gd -gexit 2>&1 | tail -8
```
Expected: 所有 test_item_db 测试通过 (含新加的 test_stick_removed)

- [ ] **Step 5: 提交**

```bash
git add scripts/items/item_db.gd tests/unit/test_item_db.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "refactor(items): 删 stick + 加 4 新物品 (stone 三件套 + slime_torch)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: ItemsArt — 3 个石器图标 + 删 _STICK pattern

**Files:**
- Modify: `scripts/art/items_art.gd`
- Modify: `scripts/autoload/art_cache.gd`

- [ ] **Step 1: 加 3 个 16×16 石器 pattern (复用现有 PALETTE)**

打开 `scripts/art/items_art.gd`,在 `_STICK` 定义之后,`_PATTERN_MAP` 字典之前,加 3 个新 pattern。

**重要**: 复用现有 PALETTE 字符 (`b`=#BDBDBD金属高/石头亮, `B`=#757575金属中/石头基, `K`=#424242金属暗/石头描边, `h`=#A87445木, `H`=#8D5D35木深, `g`=#8D8D8D护手, `G`=#616161护手深, `r`=#A55F3C 木柄红棕)。无需加新调色板键。

```gdscript
# 石剑: bBKb 描灰刀身 + h/H 木柄
const _STONE_SWORD := [
	"................",
	"...........bBB..",
	"..........bBKB..",
	".........bBKBB..",
	"........bBKBB...",
	".......bBKBB....",
	"......bBKBB.....",
	".....bBKBB......",
	"....bBKBB.......",
	"...gggGG........",
	"..gggGGGG.......",
	"....hh..........",
	"....hH..........",
	"....hH..........",
	"....KK..........",
	"................",
]

# 石镐: 横 T 石头头 + 木柄
const _STONE_PICKAXE := [
	"................",
	"....BBBBBBBB....",
	"...BbbbbbbbbB...",
	"...BbBKKKKBbB...",
	"....BbbBBbbB....",
	"......BbbB......",
	"......hHrh......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......KK.......",
	"................",
	"................",
]

# 石斧: 半月石头头 + 木柄
const _STONE_AXE := [
	"................",
	"....BBBBB.......",
	"...BbbbbbB......",
	"..BbbbbbbbB.....",
	".BbbbbBBKB......",
	"BbbBBBKK........",
	"BbBBKKr.........",
	"BBKKKhrh........",
	".....hHr........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....KK.........",
	"................",
]
```

- [ ] **Step 2: 注册到 _ICONS (items_art.gd 末尾的映射字典)**

修改 `_ICONS` 字典:
- 删除 `"stick": _STICK,` 这一行
- 在 `"slime_ball": _SLIME_BALL,` 之后加 3 个新映射:

```gdscript
	"slime_ball": _SLIME_BALL,
	"stone_sword": _STONE_SWORD,
	"stone_pickaxe": _STONE_PICKAXE,
	"stone_axe": _STONE_AXE,
}
```

`_STICK` 常量定义保留无害,但不再被引用。

- [ ] **Step 3: 注册到 ArtCache._build_items**

修改 `scripts/autoload/art_cache.gd::_build_items`:
```gdscript
func _build_items() -> void:
	for item_id in ["wood_sword", "wood_pickaxe", "wood_axe", "slime_ball",
			"stone_sword", "stone_pickaxe", "stone_axe"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)
```

(删除 "stick", 加 3 个石器 id)

- [ ] **Step 4: 注册 slime_torch 到 _ITEM_TO_TILE**

修改 `scripts/autoload/art_cache.gd::_ITEM_TO_TILE`,在 `door` 之后加:
```gdscript
	"door": BlocksArt.DOOR,
	"slime_torch": BlocksArt.SLIME_TORCH,
}
```

- [ ] **Step 5: 验证宽度**

```bash
awk '/^const _STONE_/,/^]$/' scripts/art/items_art.gd | grep -oE '"[^"]+"' | awk '{ n=length($0)-2; if (n!=16) print "BAD", n }'
```
Expected: 无输出

- [ ] **Step 6: 启动验证**

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
```
Expected: `OK`

- [ ] **Step 7: 提交**

```bash
git add scripts/art/items_art.gd scripts/autoload/art_cache.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "art(items): 3 个 16x16 石器图标 + 注册 slime_torch tile 图标

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: LEAVES drops 去掉 stick

**Files:**
- Modify: `scripts/world/tile_data.gd`

- [ ] **Step 1: 改 LEAVES drops**

在 `scripts/world/tile_data.gd` 找到 LEAVES / LEAVES_PINE / LEAVES_AUTUMN 三个 _PROPS 条目, drops 改成只掉自己:

LEAVES:
```gdscript
	LEAVES: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["leaves", 100, 1, 1]],
	},
```

LEAVES_PINE:
```gdscript
	LEAVES_PINE: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["pine_leaves", 100, 1, 1]],
	},
```

LEAVES_AUTUMN:
```gdscript
	LEAVES_AUTUMN: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["autumn_leaves", 100, 1, 1]],
	},
```

- [ ] **Step 2: 跑 tile_data 测试**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tile_data.gd -gexit 2>&1 | tail -5
```
Expected: 所有通过

- [ ] **Step 3: 提交**

```bash
git add scripts/world/tile_data.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "fix(tiles): leaves drops 去掉 stick (Terraria 风)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Slime HP 4→6

**Files:**
- Modify: `scripts/entities/slime.gd`

- [ ] **Step 1: 改 MAX_HEALTH**

`scripts/entities/slime.gd` 顶部常量:
```gdscript
const MAX_HEALTH := 6   # 木剑 4 dmg × 2 击, 石剑 7 dmg × 1 击
```

- [ ] **Step 2: 启动验证**

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
```
Expected: `OK`

- [ ] **Step 3: 提交**

```bash
git add scripts/entities/slime.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "balance(slime): HP 4 → 6, 配合 tier 工具进阶

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Player attack/mining — tier 查表

**Files:**
- Modify: `scripts/player/player_action.gd`

- [ ] **Step 1: SWORD_DAMAGE 改 tier-aware**

`scripts/player/player_action.gd`,删除常量 `const SWORD_DAMAGE := 5`,新增函数:

在 `_swing_sword` 之前加:
```gdscript
func _sword_damage() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null or def.tool_kind != "sword":
		return 0
	# wood tier 1 → 4; stone tier 2 → 7
	return 7 if def.tool_tier >= 2 else 4
```

修改 `_swing_sword` 的伤害参数:
```gdscript
func _swing_sword() -> void:
	_attack_cooldown = SWORD_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	var damage: int = _sword_damage()
	if damage <= 0:
		return
	var facing: int = 1
	if player.has_method("facing_dir"):
		facing = player.facing_dir()
	var center: Vector2 = player.global_position + Vector2(facing * SWORD_RANGE_PX * 0.5, -8.0)
	for s in get_tree().get_nodes_in_group("slimes"):
		var sn := s as Node2D
		if sn == null:
			continue
		if center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7:
			if s.has_method("take_damage"):
				s.take_damage(damage, player.global_position)
```

- [ ] **Step 2: _tool_speed 改 tier-aware**

替换 `scripts/player/player_action.gd::_tool_speed`:
```gdscript
func _tool_speed(tool_kind: String, tid: int) -> float:
	# axe 砍 LOG: wood ×3, stone ×4
	if tool_kind == "axe" and tid == Tiles.LOG:
		var tier := _current_tool_tier()
		return 4.0 if tier >= 2 else 3.0
	# pickaxe 挖 STONE: wood ×1, stone ×1.5
	if tool_kind == "pickaxe" and tid == Tiles.STONE:
		var tier := _current_tool_tier()
		return 1.5 if tier >= 2 else 1.0
	return 1.0


func _current_tool_tier() -> int:
	var inv: Node = _inventory_node()
	if inv == null:
		return 0
	var slot = inv.current_hotbar_slot()
	if slot == null:
		return 0
	var def = ItemDB.get_def(slot.item_id)
	if def == null:
		return 0
	return def.tool_tier
```

- [ ] **Step 3: 启动验证**

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
```
Expected: `OK`

- [ ] **Step 4: 提交**

```bash
git add scripts/player/player_action.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "feat(player): 剑伤害/挖速按工具 tier 查 (wood vs stone)

- 剑: wood 4 / stone 7
- 斧砍 LOG: wood ×3 / stone ×4
- 镐挖 STONE: wood ×1 / stone ×1.5

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 重写 RecipeDB (10 个配方)

**Files:**
- Modify: `scripts/crafting/recipe_db.gd`

- [ ] **Step 1: 全量替换 _RECIPES 数组**

打开 `scripts/crafting/recipe_db.gd`,把整个 `_RECIPES` 数组替换为:

```gdscript
const _RECIPES := [
	# === 2×2 (徒手) ===
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
		"id": "slime_torch",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["slime_ball", ""],
			["planks",     ""],
		],
		"output_id": "slime_torch",
		"output_count": 3,
		"mirror_ok": true,
	},
	# === 3×3 (工作台) ===
	{
		"id": "door",
		"grid_size": Vector2i(2, 3),
		"pattern": [
			["planks", "planks"],
			["planks", "planks"],
			["planks", "planks"],
		],
		"output_id": "door",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "planks", ""],
			["", "planks", ""],
			["", "planks", ""],
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
			["",       "planks", ""],
			["",       "planks", ""],
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
			["planks", "planks", ""],
			["",       "planks", ""],
		],
		"output_id": "wood_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "stone",  ""],
			["", "stone",  ""],
			["", "planks", ""],
		],
		"output_id": "stone_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["stone", "stone",  "stone"],
			["",      "planks", ""],
			["",      "planks", ""],
		],
		"output_id": "stone_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["stone", "stone",  ""],
			["stone", "planks", ""],
			["",      "planks", ""],
		],
		"output_id": "stone_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
]
```

- [ ] **Step 2: 启动验证 (recipe 字段都齐全)**

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
```
Expected: `OK`

- [ ] **Step 3: 提交**

```bash
git add scripts/crafting/recipe_db.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "feat(crafting): 10 个 Terraria 风配方 (3 个 2×2 + 7 个 3×3)

去 stick: 工具配方用纯 planks 或 planks+stone
新增: door / stone 三件套 / slime_torch

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 新增 test_recipe_db 单元测试

**Files:**
- Create: `tests/unit/test_recipe_db.gd`

- [ ] **Step 1: 写测试文件**

新建 `tests/unit/test_recipe_db.gd`:

```gdscript
extends GutTest

const RecipeMatcher = preload("res://scripts/crafting/recipe_matcher.gd")


func _grid_2x2() -> Array:
	return [["", ""], ["", ""]]


func _grid_3x3() -> Array:
	return [["", "", ""], ["", "", ""], ["", "", ""]]


func test_planks_recipe_matches():
	var g = _grid_2x2()
	g[0][0] = "log"
	var hit = RecipeMatcher.find_match(g)
	assert_not_null(hit, "log 应触发 planks 配方")
	assert_eq(hit.output_id, "planks")
	assert_eq(hit.output_count, 4)


func test_workbench_recipe_matches():
	var g = [["planks", "planks"], ["planks", "planks"]]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "workbench")


func test_slime_torch_recipe_matches():
	var g = [["slime_ball", ""], ["planks", ""]]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "slime_torch")
	assert_eq(hit.output_count, 3)


func test_door_recipe_matches():
	# 2 宽 3 高 planks 列 — 必须在 3×3 grid 才装得下
	var g = [
		["planks", "planks", ""],
		["planks", "planks", ""],
		["planks", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "door")


func test_wood_sword_no_stick():
	# 工具配方全是 planks, 不再要 stick
	var g = [
		["", "planks", ""],
		["", "planks", ""],
		["", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_sword")


func test_wood_pickaxe_planks_only():
	var g = [
		["planks", "planks", "planks"],
		["",       "planks", ""],
		["",       "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_pickaxe")


func test_wood_axe_planks_only():
	var g = [
		["planks", "planks", ""],
		["planks", "planks", ""],
		["",       "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "wood_axe")


func test_stone_sword_recipe():
	var g = [
		["", "stone",  ""],
		["", "stone",  ""],
		["", "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_sword")


func test_stone_pickaxe_recipe():
	var g = [
		["stone", "stone",  "stone"],
		["",      "planks", ""],
		["",      "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_pickaxe")


func test_stone_axe_recipe():
	var g = [
		["stone", "stone",  ""],
		["stone", "planks", ""],
		["",      "planks", ""],
	]
	var hit = RecipeMatcher.find_match(g)
	assert_eq(hit.output_id, "stone_axe")
```

- [ ] **Step 2: 跑测试**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_db.gd -gexit 2>&1 | tail -8
```
Expected: 10/10 通过

- [ ] **Step 3: 提交**

```bash
git add tests/unit/test_recipe_db.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "test(recipe): 10 个新配方各一个 RecipeMatcher 命中测

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: 更新集成测试 (去掉 stick 用法)

**Files:**
- Modify: `tests/integration/test_workbench_3x3.gd`
- Modify: `tests/integration/test_full_loop.gd`
- Modify: `tests/integration/test_craft_loop.gd`

- [ ] **Step 1: 改 test_workbench_3x3.gd**

打开,找 `test_place_workbench_and_craft_pickaxe` 函数,把 wood_pickaxe 摆 stick 改成摆 planks:

```gdscript
	# 玩家持 1 workbench + 5 planks (不再要 stick)
	inv.inventory.add("workbench", 1)
	inv.inventory.add("planks", 5)
	# 选中 workbench 放置
	inv.set_hotbar_selection(0)
```

把 wood_pickaxe 形状改成纯 planks:
```gdscript
	# 摆 wood_pickaxe 形状 (T 形, 全 planks)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	cp.place_in_cell(2, 1, "planks", 1)
```

(注: 我们原文摆的是 row 0 col 0-2 一列 planks, 然后 col 1, 2 row 1 两个 stick → 这跟 RecipeMatcher 的 pattern 是 (cols=3, rows=3) 还是反? 看 pattern: [["planks","planks","planks"],["","planks",""],["","planks",""]] — row 0 是上排 3 个 planks; row 1, 2 中间一格 planks)

正确摆法:
```gdscript
	# wood_pickaxe pattern: row 0 顶排 3 planks + col 1 (rows 1-2) 两个 planks
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	cp.place_in_cell(2, 1, "planks", 1)
```

(注: `place_in_cell(r, c, ...)` — r 是 row, c 是 col. row 0 col 0,1,2 = 顶排; row 1 col 1; row 2 col 1)

- [ ] **Step 2: 改 test_full_loop.gd**

找 "3. 2x2 合 4 planks → 4 sticks" 块, 整段删除 (5-10 行):
```gdscript
	# 3. 2x2 合 4 planks → 4 sticks
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	var p2 = cp.get_output_preview()
	assert_eq(p2.output_id, "stick")
	cp.simulate_take_output()
	cp.close()
```

修改第 6 步 wood_pickaxe 合成 stick → planks:
```gdscript
	# 6. 3x3 合 wood_pickaxe (5 planks, 不要 stick)
	cp.open(3)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	cp.place_in_cell(2, 1, "planks", 1)
	var p4 = cp.get_output_preview()
	assert_eq(p4.output_id, "wood_pickaxe")
	cp.simulate_take_output()
	cp.close()
```

- [ ] **Step 3: 改 test_craft_loop.gd**

如果文件里有 test_craft_stick_from_planks 或类似测试, 删掉它 (不需要再造 stick)。

```bash
grep -n "stick" tests/integration/test_craft_loop.gd
```
看哪几行用到 stick,删除对应测试函数。

如果该文件只有 planks/workbench 测试,无需改。

- [ ] **Step 4: 跑全部测试**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -8
```
Expected: 所有测试通过 (123 → 130+ 含新加的 11 个)

- [ ] **Step 5: 提交**

```bash
git add tests/integration/
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "test(integration): 合成集成测试改用 planks (删 stick)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: CraftingPanel UI 改纵向列表 + 左上角锚定

**Files:**
- Modify: `scenes/ui/crafting_panel.tscn`
- Modify: `scripts/ui/crafting_panel.gd`

- [ ] **Step 1: 改 .tscn 顶级布局为 PRESET_TOP_LEFT**

打开 `scenes/ui/crafting_panel.tscn`, 把 `[node name="Center" type="CenterContainer" ...]` 改成:

```
[node name="TopLeft" type="Control" parent="."]
layout_mode = 3
anchors_preset = 0
offset_left = 16.0
offset_top = 16.0
offset_right = 460.0
offset_bottom = 720.0
```

把 `[node name="Panel" ... parent="Center"]` 的 parent 改成 `TopLeft`。

panel bg_color 改透明些 `Color(0.1, 0.1, 0.12, 0.78)`:

```
bg_color = Color(0.1, 0.1, 0.12, 0.78)
```

- [ ] **Step 2: 大改 crafting_panel.gd 的 _build_ui — 改成纵向 list**

打开 `scripts/ui/crafting_panel.gd`, 找 `_build_recipe_buttons` 函数,整个替换为纵向列表行 (每行一个 Button):

```gdscript
func _build_recipe_buttons() -> void:
	for r in RecipeDB.all_recipes():
		var entry := _make_recipe_row(r)
		_recipe_buttons.append(entry)
		_recipe_container.add_child(entry.button)


func _make_recipe_row(recipe: Dictionary) -> Dictionary:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(380, 44)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.tooltip_text = _recipe_tooltip(recipe)

	# HBox 容器
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.set_anchors_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 8.0
	hb.offset_right = -8.0
	btn.add_child(hb)

	# 输出图标
	var icon := TextureRect.new()
	icon.texture = ArtCache.get_inventory_icon(recipe.output_id)
	icon.custom_minimum_size = Vector2(36, 36)
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(icon)

	# 名字 + 材料 (竖向 2 行)
	var vb := VBoxContainer.new()
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = "%s × %d" % [recipe.output_id, recipe.output_count]
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var cost_lbl := Label.new()
	cost_lbl.text = _short_cost_text(recipe)
	cost_lbl.add_theme_font_size_override("font_size", 10)
	cost_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(cost_lbl)

	btn.pressed.connect(_on_recipe_pressed.bind(recipe.id))
	return {"recipe": recipe, "button": btn, "cost_label": cost_lbl}
```

- [ ] **Step 3: 更新 _short_name 加石头/史莱姆球简写**

```gdscript
func _short_name(item_id: String) -> String:
	const SHORT := {
		"log": "原木", "planks": "板", "stick": "棍",
		"workbench": "台", "leaves": "叶",
		"stone": "石", "slime_ball": "胶",
	}
	return SHORT.get(item_id, item_id)
```

- [ ] **Step 4: 删掉旧的"工作台/徒手"状态 emoji (Unicode 字体可能不支持)**

`scripts/ui/crafting_panel.gd::_refresh_wb_label`:
```gdscript
func _refresh_wb_label() -> void:
	if _wb_label == null:
		return
	if _mode == 3:
		_wb_label.text = "[ 工作台旁 — 全部配方可用 ]"
		_wb_label.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6))
	else:
		_wb_label.text = "[ 徒手 — 仅 2×2 配方可用 ]"
		_wb_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.5))
```

(删 🛠/✋ emoji 避免显示问题)

- [ ] **Step 5: 启动 + 跑全测试**

```bash
timeout 5 godot --headless --main-scene res://scenes/main.tscn 2>&1 | grep -iE "error|assert" || echo "OK"
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -8
```
Expected: 无错 + 所有测试过

- [ ] **Step 6: 导出 web 并提交**

```bash
godot --headless --export-release "Web" build/web/index.html 2>&1 | tail -2
python3 -c "
import zipfile, os
files = ['index.html','index.js','index.pck','index.wasm','index.audio.worklet.js','index.png','index.icon.png','index.apple-touch-icon.png']
with zipfile.ZipFile('build/teilaruia-web.zip','w',zipfile.ZIP_DEFLATED) as z:
    for f in files: z.write(os.path.join('build/web', f), f)
"

git add scenes/ui/crafting_panel.tscn scripts/ui/crafting_panel.gd
git -c user.name="Claude" -c user.email="$(git log -1 --format='%ae' HEAD)" commit -m "feat(ui): 合成面板改纵向列表 + 左上角锚定 (Terraria 风)

- 面板锚 PRESET_TOP_LEFT, 不再居中遮世界
- 半透明 bg (0.78 alpha)
- 配方按钮改成横排 list-item: [icon] [名字×数量] [材料简写]
- 删除 emoji (字体兼容)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

## 验收 (10 个 task 全部完成后)

- [ ] 合成面板锚在左上角, 世界仍可见
- [ ] 配方为纵向列表 (10 行)
- [ ] 工作台不在身边: 3 行 2×2 配方亮 (planks / workbench / slime_torch); 7 行 3×3 灰
- [ ] 工作台旁: 全部 10 行亮 (若素材够)
- [ ] 木剑攻击 2 次杀史莱姆 (HP 6 / dmg 4)
- [ ] 石剑攻击 1 次杀史莱姆 (HP 6 / dmg 7)
- [ ] 砍树: 木斧 ×3, 石斧 ×4 (明显石斧快)
- [ ] 挖石: 木镐 1.0, 石镐 1.5 (明显石镐快)
- [ ] door 在 3×3 模式下可造 (6 planks 摆 2×3 列)
- [ ] slime_torch 放下 → tile 13 显示绿色顶+木棍 sprite
- [ ] 所有 GUT 测试通过
