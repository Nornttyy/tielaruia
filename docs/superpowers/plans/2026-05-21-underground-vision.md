# 地底视野 + 火把 + 矿洞 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 teilaruia 加"地底变黑 + 火把照明 + 矿洞探索"：全局 CanvasModulate 暗 + Light2D 圆光圈、火把 tile（含火焰/呼吸光/火花粒子）、洞穴/煤矿/铁矿/深石分层，并顺手加铁镐 tier 3。

**Architecture:** 光照走 Godot 原生 Light2D；玩家身上 PlayerAura（永开小光圈）+ SunAura（仅头顶天空时启用，0.3s lerp）。火把 tile 不实心、需相邻支撑；放下时由 `WorldLighting` 在该坐标实例化 TorchFx 节点（火焰 + 光呼吸 + 周期火花），挖掉时 free。地底地形改 `world_generator`：3 个独立 noise 控制洞穴/煤/铁，深度 50% 起石头变 DEEP_STONE。

**Tech Stack:** Godot 4.3 + GDScript；测试 GUT；art 通过 `BlocksArt` (16×16 pattern) + `ArtCache` 缓存。

**Spec:** `docs/superpowers/specs/2026-05-21-underground-vision-design.md`

**测试命令**：
- 全量：`timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15`
- 单文件：`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_X.gd -gexit 2>&1 | tail -8`
- 加新 class_name 后跑测前先：`timeout 30 godot --editor --quit 2>&1 | tail -3`（刷新类索引）

---

## 文件结构

| 路径 | 操作 | 责任 |
|---|---|---|
| `scripts/world/tile_data.gd` | 改 | 加 TORCH/COAL_ORE/IRON_ORE/DEEP_STONE 常量 + _PROPS 条目 |
| `scripts/art/blocks_art.gd` | 改 | 加 4 个调色板 + 4 个 16×16 pattern + get_palette/get_texture 分支 |
| `scripts/autoload/art_cache.gd` | 改 | _build_blocks 加新 tile；_build_items 加 iron_pickaxe；_ITEM_TO_TILE 加 torch；加 `radial_gradient(size, color)` |
| `scripts/world/tileset_builder.gd` | 改 | tile_ids 数组加 4 个新 tile |
| `scripts/items/item_db.gd` | 改 | 加 coal / iron_ore / torch / iron_pickaxe |
| `scripts/art/items_art.gd` | 改 | 加 iron_pickaxe 图标 |
| `scripts/world/world_generator.gd` | 改 | 洞穴/矿石/DEEP_STONE 生成逻辑；3 个新 noise；常量集中 |
| `scripts/crafting/recipe_db.gd` | 改 | 加 torch + iron_pickaxe 配方 |
| `scenes/world/world.tscn` | 改 | 加 CanvasModulate + TorchLights + WorldLighting 子节点 |
| `scenes/player/player.tscn` | 改 | 加 PlayerAura + SunAura（PointLight2D）子节点 |
| `scripts/player/player_controller.gd` | 改 | SunAura energy 每帧 lerp（查 SkyLightGrid） |
| `scripts/world/world.gd` | 改 | _set_tile / _on_chunk_loaded / _on_chunk_unloaded 接 WorldLighting |
| `scripts/world/world_lighting.gd` | 新建 | 火把光源生命周期 + 常量 |
| `scripts/art/particles_art.gd` | 改 | `get_torch_spark(color)` 暖色 2×2 像素纹理 |
| `scripts/fx/torch_fx.gd` | 新建 | 火焰 2 帧 + 光呼吸 + spark timer |
| `scenes/fx/torch_fx.tscn` | 新建 | Flame + Light + SparkTimer 节点结构 |
| `scripts/fx/torch_spark_particle.gd` | 新建 | 单个火花：上升 + 微飘 + alpha 渐隐 |
| `scenes/fx/torch_spark_particle.tscn` | 新建 | Sprite2D 包壳 |
| `tests/unit/test_tile_data.gd` | 改 | 加 4 个新 tile 属性断言 |
| `tests/unit/test_item_db.gd` | 改 | 加 4 个新 item 断言 |
| `tests/unit/test_recipe_db.gd` | 改 | 加 torch + iron_pickaxe 配方断言 |
| `tests/unit/test_world_generator.gd` | 新建 | 确定性生成 + 洞穴/煤/铁存在 + BEDROCK 不被挖空 |
| `tests/integration/test_torch_lifecycle.gd` | 新建 | _set_tile(TORCH) → TorchFx 出现；set_tile(AIR) → free |

---

## Phase A：Tile / Item / Art 基础

### Task A1: 新增 4 个 Tile 常量 + 属性

**Files:**
- Modify: `scripts/world/tile_data.gd`
- Test: `tests/unit/test_tile_data.gd`

- [ ] **Step 1: 写测试断言（覆盖 4 个新 tile 的属性）**

在 `tests/unit/test_tile_data.gd` 末尾追加：

```gdscript
func test_torch_properties() -> void:
	assert_false(Tiles.is_solid(Tiles.TORCH), "TORCH 不实心")
	assert_true(Tiles.is_mineable(Tiles.TORCH), "TORCH 可挖")
	# 徒手即可挖
	assert_eq(Tiles.tool_tier_required(Tiles.TORCH, "pickaxe"), 0)
	var drops = Tiles.drops_for(Tiles.TORCH)
	assert_eq(drops.size(), 1)
	assert_eq(drops[0][0], "torch")


func test_coal_ore_properties() -> void:
	assert_true(Tiles.is_solid(Tiles.COAL_ORE))
	assert_true(Tiles.is_mineable(Tiles.COAL_ORE))
	# 需 pickaxe tier 1
	assert_eq(Tiles.tool_tier_required(Tiles.COAL_ORE, "pickaxe"), 1)
	assert_eq(Tiles.tool_tier_required(Tiles.COAL_ORE, ""), -1)
	assert_eq(Tiles.drops_for(Tiles.COAL_ORE)[0][0], "coal")


func test_iron_ore_properties() -> void:
	assert_true(Tiles.is_solid(Tiles.IRON_ORE))
	# 需 pickaxe tier 2 (石镐+)
	assert_eq(Tiles.tool_tier_required(Tiles.IRON_ORE, "pickaxe"), 2)
	assert_eq(Tiles.drops_for(Tiles.IRON_ORE)[0][0], "iron_ore")


func test_deep_stone_properties() -> void:
	assert_true(Tiles.is_solid(Tiles.DEEP_STONE))
	# 跟 STONE 一样需 pickaxe tier 1，掉普通 stone
	assert_eq(Tiles.tool_tier_required(Tiles.DEEP_STONE, "pickaxe"), 1)
	assert_eq(Tiles.drops_for(Tiles.DEEP_STONE)[0][0], "stone")
```

> 检查现有测试用的 helper 名（`is_solid` / `is_mineable` / `tool_tier_required` / `drops_for`）—— 看 `test_tile_data.gd` 已有用法，按相同 API 调用。若 helper 名不同（项目代码用 `_PROPS[tid].solid` 直接读），把上面断言改为 `assert_eq(Tiles._PROPS[Tiles.TORCH].solid, false)` 等等。

- [ ] **Step 2: 跑测试确认 fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tile_data.gd -gexit 2>&1 | tail -8
```

预期：4 个新测试 FAIL（`Tiles.TORCH` 等常量不存在）

- [ ] **Step 3: 在 `tile_data.gd` 加常量 + 属性**

在 `const SLIME_TORCH := 13` 之后加：

```gdscript
const TORCH := 14
const COAL_ORE := 15
const IRON_ORE := 16
const DEEP_STONE := 17
```

在 `_PROPS` dict 末尾（SLIME_TORCH 之后）加：

```gdscript
	TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["torch", 100, 1, 1]],
	},
	COAL_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["coal", 100, 1, 1]],
	},
	IRON_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
		"drops": [["iron_ore", 100, 1, 1]],
	},
	DEEP_STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
```

- [ ] **Step 4: 跑测试确认 pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_tile_data.gd -gexit 2>&1 | tail -8
```

预期：所有 test_tile_data 通过。

- [ ] **Step 5: 提交**

```
git add scripts/world/tile_data.gd tests/unit/test_tile_data.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(tiles): TORCH / COAL_ORE / IRON_ORE / DEEP_STONE 常量与属性"
```

---

### Task A2: 4 个新 tile 的 16×16 pattern + 调色板

**Files:**
- Modify: `scripts/art/blocks_art.gd`

> 这一节没有自动化测试，验收方式是 art_preview（手动跑或 `art_cache.gd:_build_blocks` 不抛异常）。

- [ ] **Step 1: 加调色板**

在 `_P_SLIME_TORCH` 之后加：

```gdscript
const _P_DEEP_STONE := {
	"s": Color8(102, 88, 78),
	"S": Color8(72, 60, 52),
	"l": Color8(125, 108, 96),
	"k": Color8(48, 36, 28),
	"L": Color8(140, 122, 108),
	"m": Color8(88, 75, 66),
	"b": Color8(60, 50, 42),
	"o": Color8(122, 96, 72),
}

const _P_COAL_ORE := {
	"s": Color8(156, 144, 136),
	"S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158),
	"k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181),
	"m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),
	"o": Color8(184, 154, 130),
	"c": Color8(50, 40, 35),
	"C": Color8(28, 22, 20),
	"h": Color8(80, 65, 55),
}

const _P_IRON_ORE := {
	"s": Color8(156, 144, 136),
	"S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158),
	"k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181),
	"m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),
	"o": Color8(184, 154, 130),
	"r": Color8(168, 100, 60),
	"R": Color8(130, 70, 40),
	"H": Color8(200, 140, 90),
}

const _P_TORCH := {
	"b": Color8(74, 52, 41),    # 木棍深
	"r": Color8(110, 80, 67),   # 木棍中
	"h": Color8(150, 110, 80),  # 木棍高光
	"f": Color8(255, 180, 50),  # 火苗亮
	"F": Color8(220, 100, 30),  # 火苗中
	"d": Color8(170, 60, 20),   # 火苗根
}
```

- [ ] **Step 2: 加 4 个 pattern**

在 `_LEAVES_AUTUMN` 之后（或 `_SLIME_TORCH` 之前，跟着已有顺序）插入：

```gdscript
# 深石：STONE 同构骨架，但暗色 + 更密裂纹 + 更少高光
const _DEEP_STONE := [
	"SbsSsbsSsbsSsbsS",
	"smbbkssssoobbkss",
	"sbbbkssksslbbkss",
	"sslksskkkkksslkk",
	"sombbbsksslkmbss",
	"sobbbbsslbksbbls",
	"ssbbbkssbkssbbbs",
	"sbkkkkbsslkkkkls",
	"sombsbbbsskbbbms",
	"sbbkssolksbbbkbs",
	"sbbslkkbskssbbls",
	"ssssbbbbossolssm",
	"sombsbbbkssbkbbs",
	"sslkkkbsslkbbbss",
	"sombssklllksmsbs",
	"sSsbsSsSsbsSsSss",
]

# 煤矿：STONE 底 + 3 簇煤块 (左上 / 中右 / 左下)
const _COAL_ORE := [
	"SbsSsbsSsbsSsbsS",
	"sccChssssooLLkss",
	"scCCkssksslLLkss",
	"scchkkkkkkksslkk",
	"somLLLsksslcCCss",
	"soLLLLssllkcChls",
	"ssLLLkssbkscCCks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"scCkssolksLLLkbs",
	"cCCslkkbskssLLls",
	"chsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 铁矿：STONE 底 + 3 簇铁锈
const _IRON_ORE := [
	"SbsSsbsSsbsSsbsS",
	"srRHkssssooLLkss",
	"sRRRkssksslLLkss",
	"srhkkskkkkksslkk",
	"somLLLsksslrRHss",
	"soLLLLssllkrRhls",
	"ssLLLkssbkssRRks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sRhkssolksLLLkbs",
	"rRRslkkbskssLLls",
	"sHsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 火把：中央木棍 (b/r/h)，顶部 4×3 火苗 (d→F→f)
const _TORCH := [
	"................",
	"................",
	"......ff........",
	".....fFFf.......",
	"....fFFFFf......",
	"....fFFFFf......",
	".....FdFd.......",
	".....rbhr.......",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"................",
]
```

- [ ] **Step 3: 在 `get_palette` / `get_pattern` / `get_texture` 加分支**

打开 `blocks_art.gd` 找到现有 `get_palette(tile_id)` 函数（如不存在则查 `get_texture` 实际怎么 dispatch；按相同套路加 case）。在 SLIME_TORCH 分支后加：

```gdscript
		DEEP_STONE:
			return _P_DEEP_STONE
		COAL_ORE:
			return _P_COAL_ORE
		IRON_ORE:
			return _P_IRON_ORE
		TORCH:
			return _P_TORCH
```

对应的 `get_pattern`（或者 `get_texture` 里 dispatch tile→pattern array）加：

```gdscript
		DEEP_STONE:
			return _DEEP_STONE
		COAL_ORE:
			return _COAL_ORE
		IRON_ORE:
			return _IRON_ORE
		TORCH:
			return _TORCH
```

加 tile id 常量在文件顶部：

```gdscript
const DEEP_STONE := 17
const COAL_ORE := 15
const IRON_ORE := 16
const TORCH := 14
```

（与 tile_data.gd 同步）

- [ ] **Step 4: 跑 art_preview 或 art_cache 加载冒烟**

```
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

预期：所有现有测试不退化（art_cache 启动加载新 tile 不抛异常）；新 tile 还没接 art_cache，所以加载 list 还没引用——下一 task 才加。

- [ ] **Step 5: 提交**

```
git add scripts/art/blocks_art.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(art): DEEP_STONE / COAL_ORE / IRON_ORE / TORCH 16x16 pattern + palette"
```

---

### Task A3: art_cache + tileset_builder 注册新 tile

**Files:**
- Modify: `scripts/autoload/art_cache.gd`
- Modify: `scripts/world/tileset_builder.gd`

- [ ] **Step 1: art_cache._build_blocks 数组加 4 个 tile**

`scripts/autoload/art_cache.gd:53-58` 改成：

```gdscript
	var tile_ids := [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.STONE, BlocksArt.SAND,
		BlocksArt.LOG, BlocksArt.LEAVES, BlocksArt.PLANKS, BlocksArt.WORKBENCH,
		BlocksArt.DOOR, BlocksArt.BEDROCK,
		BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN, BlocksArt.SLIME_TORCH,
		BlocksArt.DEEP_STONE, BlocksArt.COAL_ORE, BlocksArt.IRON_ORE, BlocksArt.TORCH,
	]
```

- [ ] **Step 2: tileset_builder.tile_ids 加 4 个 tile**

`scripts/world/tileset_builder.gd:14-19` 改成：

```gdscript
	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
		Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.SLIME_TORCH,
		Tiles.DEEP_STONE, Tiles.COAL_ORE, Tiles.IRON_ORE, Tiles.TORCH,
	]
```

> 注意：TORCH `solid = false`，会跳过 `add_collision_polygon`（现有 `if Tiles.is_solid(tile_id)` 守卫）。COAL_ORE / IRON_ORE / DEEP_STONE solid = true，会自动加碰撞 polygon。✅

- [ ] **Step 3: 跑全测试冒烟**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

预期：所有现有测试通过，无 art_cache 启动错误。

- [ ] **Step 4: 提交**

```
git add scripts/autoload/art_cache.gd scripts/world/tileset_builder.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(art): 注册 4 个新 tile 到 art_cache + tileset_builder"
```

---

### Task A4: 新增 4 个 Item（coal / iron_ore / torch / iron_pickaxe）

**Files:**
- Modify: `scripts/items/item_db.gd`
- Modify: `scripts/autoload/art_cache.gd` (item_icons + _ITEM_TO_TILE)
- Test: `tests/unit/test_item_db.gd`

- [ ] **Step 1: 写测试**

`tests/unit/test_item_db.gd` 末尾追加：

```gdscript
func test_torch_item() -> void:
	var def = ItemDB.get_def("torch")
	assert_not_null(def, "torch item 应存在")
	assert_eq(def.placeable_tile_id, Tiles.TORCH)
	assert_eq(def.max_stack, 99)
	assert_true(ItemDB.is_placeable("torch"))


func test_coal_item() -> void:
	var def = ItemDB.get_def("coal")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)
	assert_false(ItemDB.is_placeable("coal"))


func test_iron_ore_item() -> void:
	var def = ItemDB.get_def("iron_ore")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)


func test_iron_pickaxe_item() -> void:
	var def = ItemDB.get_def("iron_pickaxe")
	assert_not_null(def)
	assert_eq(def.tool_kind, "pickaxe")
	assert_eq(def.tool_tier, 3)
	assert_eq(def.max_stack, 1)
```

- [ ] **Step 2: 跑测试确认 fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_item_db.gd -gexit 2>&1 | tail -8
```

预期：4 个新测试 FAIL（item 不存在）

- [ ] **Step 3: item_db.gd 加 4 个条目**

`scripts/items/item_db.gd:23` 行（slime_torch 那行）之后追加：

```gdscript
	"coal":         {"placeable_tile_id": -1,                       "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_ore":     {"placeable_tile_id": -1,                       "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"torch":        {"placeable_tile_id": Tiles.TORCH,              "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_pickaxe": {"placeable_tile_id": -1,                       "tool_kind": "pickaxe", "tool_tier": 3, "max_stack": 1},
```

- [ ] **Step 4: art_cache._ITEM_TO_TILE 加 torch（让背包图标走 block_textures）**

`scripts/autoload/art_cache.gd:_ITEM_TO_TILE` dict 加：

```gdscript
	"torch": BlocksArt.TORCH,
```

也加 coal / iron_ore 物品图标（这俩没有对应 tile，走 items_art.gd 渲染）。先扩展 `_build_items` 列表：

```gdscript
func _build_items() -> void:
	for item_id in ["wood_sword", "wood_pickaxe", "wood_axe", "slime_ball",
			"stone_sword", "stone_pickaxe", "stone_axe",
			"coal", "iron_ore", "iron_pickaxe"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)
```

- [ ] **Step 5: items_art.gd 加 3 个图标**

打开 `scripts/art/items_art.gd`，找到现有 `_ICONS` / 类似 dispatch 结构，按现有 pattern 加：

```gdscript
const _COAL := [
	"................",
	"....cCccCc......",
	"...ccCCCCcc.....",
	"..cCCCCCCCCc....",
	"..cCcCcCcCcC....",
	"..ccCCCCCCcc....",
	"...cCcCcCcc.....",
	"....cCccCc......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _IRON_ORE_ICON := [
	"................",
	"....srRsRr......",
	"...srRRRRrs.....",
	"..sRRRrRRRRs....",
	"..sRRRRRRRRs....",
	"..ssRRRRRRss....",
	"...srRrRRrs.....",
	"....srRsRr......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _IRON_PICKAXE := [
	"...rRrrRr.......",
	"..rRRRRRRr......",
	".rRrRRRrRr......",
	"..rRRRRRrR......",
	"....bRb.........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	".....b..........",
	"................",
	"................",
]
```

并加调色板（如 ItemsArt 用法与 BlocksArt 类似）：

```gdscript
const _P_COAL := {
	"c": Color8(50, 40, 35),
	"C": Color8(28, 22, 20),
}

const _P_IRON_ORE_ICON := {
	"s": Color8(156, 144, 136),
	"r": Color8(168, 100, 60),
	"R": Color8(130, 70, 40),
}

const _P_IRON_PICKAXE := {
	"r": Color8(168, 100, 60),
	"R": Color8(130, 70, 40),
	"b": Color8(110, 80, 60),
}
```

并在 `get_icon` 的分发里加：

```gdscript
		"coal":
			return _build(_COAL, _P_COAL)
		"iron_ore":
			return _build(_IRON_ORE_ICON, _P_IRON_ORE_ICON)
		"iron_pickaxe":
			return _build(_IRON_PICKAXE, _P_IRON_PICKAXE)
```

> 上面假定 ItemsArt 用类似 BlocksArt 的 `_build(pattern, palette)` 私有函数 + `get_icon(id)` 分发。**实施前先 grep 一下 `scripts/art/items_art.gd` 确认实际函数名 / 数据结构**，按现有命名对齐。

- [ ] **Step 6: 跑测试确认 pass**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_item_db.gd -gexit 2>&1 | tail -8
```

预期：4 个新 test 通过 + 现有 test 不退化。

- [ ] **Step 7: 提交**

```
git add scripts/items/item_db.gd scripts/autoload/art_cache.gd scripts/art/items_art.gd tests/unit/test_item_db.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(items): coal / iron_ore / torch / iron_pickaxe + 图标"
```

---

## Phase B：世界生成（洞穴 + 矿石 + 深石）

### Task B1: world_generator.gd 加洞穴 + 矿石 + 分层

**Files:**
- Modify: `scripts/world/world_generator.gd`
- Test: `tests/unit/test_world_generator.gd`

- [ ] **Step 1: 写测试**

`tests/unit/test_world_generator.gd`（新建）：

```gdscript
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")


func test_deterministic_same_seed() -> void:
	var a = WorldGenerator.generate_chunk(12345, 0)
	var b = WorldGenerator.generate_chunk(12345, 0)
	for x in a.tiles.size():
		for y in a.tiles[x].size():
			assert_eq(a.tiles[x][y], b.tiles[x][y], "(%d,%d) 同 seed 应一致" % [x, y])


func test_underground_has_air_caves() -> void:
	var c = WorldGenerator.generate_chunk(54321, 0)
	var air_count = 0
	for x in c.tiles.size():
		var col = c.tiles[x]
		# 跳过地表上空 (前 N 行) — 简化：从 y = WORLD_HEIGHT/3 起开始数
		for y in range(ChunkConstants.WORLD_HEIGHT / 3, col.size()):
			if col[y] == Tiles.AIR:
				air_count += 1
	assert_gt(air_count, 20, "地下应至少有 20 个洞穴 AIR tile")


func test_has_coal_ore() -> void:
	var c = WorldGenerator.generate_chunk(54321, 0)
	var coal_count = 0
	for x in c.tiles.size():
		for y in c.tiles[x].size():
			if c.tiles[x][y] == Tiles.COAL_ORE:
				coal_count += 1
	assert_gt(coal_count, 0, "应至少有 1 个煤矿")


func test_has_iron_ore() -> void:
	var c = WorldGenerator.generate_chunk(99999, 0)
	var iron_count = 0
	for x in c.tiles.size():
		for y in c.tiles[x].size():
			if c.tiles[x][y] == Tiles.IRON_ORE:
				iron_count += 1
	assert_gt(iron_count, 0, "应至少有 1 个铁矿")


func test_has_deep_stone() -> void:
	var c = WorldGenerator.generate_chunk(11111, 0)
	var has_deep = false
	for x in c.tiles.size():
		for y in c.tiles[x].size():
			if c.tiles[x][y] == Tiles.DEEP_STONE:
				has_deep = true
				break
		if has_deep: break
	assert_true(has_deep, "应有 DEEP_STONE tile")


func test_bedrock_never_air() -> void:
	# 跑 3 个 seed，断言最底 BEDROCK_ROWS 行永远不是 AIR
	for seed_v in [1, 2, 3]:
		var c = WorldGenerator.generate_chunk(seed_v, 0)
		var h = ChunkConstants.WORLD_HEIGHT
		for x in c.tiles.size():
			for y in range(h - 2, h):  # BEDROCK_ROWS = 2
				assert_ne(c.tiles[x][y], Tiles.AIR,
					"seed=%d (%d,%d) BEDROCK 不应被挖空" % [seed_v, x, y])
```

- [ ] **Step 2: 跑测试确认 fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_generator.gd -gexit 2>&1 | tail -10
```

预期：3 个测试 FAIL（无 coal / iron / deep stone）；deterministic 和 bedrock 测试可能 PASS（现有 generator 已确定性 + 永不挖 bedrock）。

- [ ] **Step 3: 改 world_generator.gd**

在文件常量区（`const TREE_CHANCE := 0.45` 之后）加：

```gdscript
const DEEP_STONE_RATIO := 0.5    # 地表往下 50% 起为 DEEP_STONE
const COAL_THRESHOLD := 0.55
const IRON_THRESHOLD := 0.65
const CAVE_THRESHOLD := 0.55
```

`generate_chunk` 函数里，在现有 `sand_noise` 创建之后加 3 个新 noise：

```gdscript
	var cave_noise := FastNoiseLite.new()
	cave_noise.seed = world_seed + 2
	cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cave_noise.frequency = 0.06
	cave_noise.fractal_octaves = 2

	var coal_noise := FastNoiseLite.new()
	coal_noise.seed = world_seed + 3
	coal_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	coal_noise.frequency = 0.12

	var iron_noise := FastNoiseLite.new()
	iron_noise.seed = world_seed + 4
	iron_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	iron_noise.frequency = 0.10
```

然后改填充循环 —— 把现有 `for local_x in chunk_width:` 内层 `for y in height:` 的 tile 决策逻辑替换为：

```gdscript
	for local_x in chunk_width:
		var world_x: int = chunk_start_x + local_x
		var surf: int = chunk_heights[world_x]
		var is_sand_col := sand_noise.get_noise_1d(float(world_x)) > SAND_THRESHOLD
		var deep_threshold: int = surf + int((height - surf) * DEEP_STONE_RATIO)
		for y in height:
			var tid: int
			if y < surf:
				tid = Tiles.AIR
			elif y == surf:
				tid = Tiles.SAND if is_sand_col else Tiles.GRASS
			elif y < surf + DIRT_DEPTH:
				tid = Tiles.SAND if is_sand_col else Tiles.DIRT
			elif y >= height - BEDROCK_ROWS:
				tid = Tiles.BEDROCK
			else:
				tid = Tiles.DEEP_STONE if y >= deep_threshold else Tiles.STONE

			# 矿石覆盖：仅在 STONE / DEEP_STONE 上
			if tid == Tiles.STONE or tid == Tiles.DEEP_STONE:
				var cn: float = coal_noise.get_noise_2d(float(world_x), float(y))
				var inn: float = iron_noise.get_noise_2d(float(world_x), float(y))
				if cn > COAL_THRESHOLD:
					tid = Tiles.COAL_ORE
				elif tid == Tiles.DEEP_STONE and inn > IRON_THRESHOLD:
					tid = Tiles.IRON_ORE

			# 洞穴：除 BEDROCK / AIR 外都可被挖空
			if tid != Tiles.BEDROCK and tid != Tiles.AIR and y > surf:
				var cv: float = abs(cave_noise.get_noise_2d(float(world_x), float(y)))
				if cv > CAVE_THRESHOLD:
					tid = Tiles.AIR

			c.tiles[local_x][y] = tid
```

> 注意：把原本的 `for y in height:` 循环整段替换。保留外层 `_place_trees_chunk` 调用不变。

- [ ] **Step 4: 跑测试确认 pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_generator.gd -gexit 2>&1 | tail -10
```

预期：6 个测试全过。

- [ ] **Step 5: 跑全测试确认无回归**

```
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

预期：现有 test_chunk_streaming / test_sky_light_grid 不退化（生成改了但 chunk 接口未变）。

- [ ] **Step 6: 提交**

```
git add scripts/world/world_generator.gd tests/unit/test_world_generator.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(world): 洞穴 + 煤铁矿 + 深石分层生成"
```

---

## Phase C：合成配方（torch + iron_pickaxe）

### Task C1: torch 配方

**Files:**
- Modify: `scripts/crafting/recipe_db.gd`
- Test: `tests/unit/test_recipe_db.gd`

- [ ] **Step 1: 写测试**

`tests/unit/test_recipe_db.gd` 末尾加：

```gdscript
func test_torch_recipe_exists() -> void:
	var found = false
	for r in RecipeDB.all_recipes():
		if r.id == "torch":
			found = true
			assert_eq(r.output_count, 4)
			assert_eq(r.output_id, "torch")
			# pattern: coal 上, log 下
			assert_eq(r.pattern[0][0], "coal")
			assert_eq(r.pattern[1][0], "log")
			break
	assert_true(found, "torch 配方应存在")
```

- [ ] **Step 2: 确认 fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_db.gd -gexit 2>&1 | tail -8
```

- [ ] **Step 3: 加配方**

`scripts/crafting/recipe_db.gd` 的 `_RECIPES` 数组末尾（在 stone_axe 之后）追加：

```gdscript
	{
		"id": "torch",
		"grid_size": Vector2i(1, 2),
		"pattern": [
			["coal"],
			["log"],
		],
		"output_id": "torch",
		"output_count": 4,
		"mirror_ok": false,
	},
```

- [ ] **Step 4: 确认 pass**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_db.gd -gexit 2>&1 | tail -8
```

- [ ] **Step 5: 提交**

```
git add scripts/crafting/recipe_db.gd tests/unit/test_recipe_db.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(crafting): torch 配方 (1 coal + 1 log → 4 torch)"
```

---

### Task C2: iron_pickaxe 配方

**Files:**
- Modify: `scripts/crafting/recipe_db.gd`
- Test: `tests/unit/test_recipe_db.gd`

- [ ] **Step 1: 写测试**

`tests/unit/test_recipe_db.gd` 末尾加：

```gdscript
func test_iron_pickaxe_recipe_exists() -> void:
	var found = false
	for r in RecipeDB.all_recipes():
		if r.id == "iron_pickaxe":
			found = true
			assert_eq(r.output_id, "iron_pickaxe")
			assert_eq(r.output_count, 1)
			# 顶层三个 iron_ore
			assert_eq(r.pattern[0][0], "iron_ore")
			assert_eq(r.pattern[0][1], "iron_ore")
			assert_eq(r.pattern[0][2], "iron_ore")
			# 中下层 planks 把手
			assert_eq(r.pattern[1][1], "planks")
			assert_eq(r.pattern[2][1], "planks")
			break
	assert_true(found, "iron_pickaxe 配方应存在")
```

- [ ] **Step 2: 确认 fail**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_recipe_db.gd::test_iron_pickaxe_recipe_exists -gexit 2>&1 | tail -8
```

- [ ] **Step 3: 加配方**

`_RECIPES` 数组末尾追加：

```gdscript
	{
		"id": "iron_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ore", "iron_ore", "iron_ore"],
			["",         "planks",   ""],
			["",         "planks",   ""],
		],
		"output_id": "iron_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
```

- [ ] **Step 4: 确认 pass + 全测试**

```
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

- [ ] **Step 5: 提交**

```
git add scripts/crafting/recipe_db.gd tests/unit/test_recipe_db.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(crafting): iron_pickaxe 配方 (tier 3)"
```

---

## Phase D：光照基础（CanvasModulate + PlayerAura + SunAura）

### Task D1: ArtCache 加 radial_gradient helper

**Files:**
- Modify: `scripts/autoload/art_cache.gd`

> 需要一个柔和的径向白光纹理给 PointLight2D 用。Godot 默认 PointLight2D 必须给 texture 才有光。

- [ ] **Step 1: 加函数**

在 `art_cache.gd` 末尾（任意位置）加：

```gdscript
# 生成径向渐变白色纹理，给 Light2D 用。size = 边长 (px)。中心 alpha=1，边缘 alpha=0。
func radial_gradient(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var max_dist := size * 0.5
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(center)
			var a: float = clamp(1.0 - d / max_dist, 0.0, 1.0)
			# 用平方衰减让中心更亮，边缘更平滑
			a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 2: 冒烟（项目能启动）**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
```

预期：无报错。

- [ ] **Step 3: 提交**

```
git add scripts/autoload/art_cache.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(art): ArtCache.radial_gradient(size) helper for Light2D"
```

---

### Task D2: CanvasModulate 加到 world.tscn

**Files:**
- Modify: `scenes/world/world.tscn`

> 直接编辑 .tscn 文本。CanvasModulate 节点在 .tscn 里语法简单。

- [ ] **Step 1: 读 world.tscn 现状**

```
cat scenes/world/world.tscn
```

记下根节点和 Camera2D 节点位置。

- [ ] **Step 2: 在 World 根节点下加 CanvasModulate**

在 `[node name="Camera2D" type="Camera2D" parent="."]` **之前**插入：

```
[node name="CanvasModulate" type="CanvasModulate" parent="."]
color = Color(0.12, 0.08, 0.06, 1)
```

> 完整 patch 示意（用 Edit 工具，old_string 选 Camera2D 那行往前一段 context）：把 `[node name="Camera2D"` 整行替换为 CanvasModulate 块 + Camera2D 块。

- [ ] **Step 3: 启动游戏冒烟**

```
timeout 15 godot --headless 2>&1 | tail -10
```

预期：无错误退出。视觉验证需手动跑：world 进入应整体变暗（暖洞穴色），但 SkyLightGrid 还没接 sun，此时玩家不会有日光 —— 一片黑。下个 task 才接 sun。

- [ ] **Step 4: 提交**

```
git add scenes/world/world.tscn
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(world): CanvasModulate 暖洞穴暗 (0.12, 0.08, 0.06)"
```

---

### Task D3: Player.tscn 加 PlayerAura + SunAura

**Files:**
- Modify: `scenes/player/player.tscn`

- [ ] **Step 1: 读 player.tscn 现状**

```
cat scenes/player/player.tscn
```

确认根节点类型 + 子节点列表。

- [ ] **Step 2: 加 2 个 PointLight2D 子节点**

在 player.tscn 末尾（Camera 等子节点之后）追加：

```
[node name="PlayerAura" type="PointLight2D" parent="."]
energy = 0.5
color = Color(1, 0.95, 0.85, 1)
texture_scale = 1.0
script = null
```

```
[node name="SunAura" type="PointLight2D" parent="."]
energy = 0.0
color = Color(1, 0.95, 0.8, 1)
texture_scale = 1.0
```

> texture 在 player_controller.gd 的 `_ready` 中通过 `ArtCache.radial_gradient(64)` / `radial_gradient(400)` 赋值（避免在 .tscn 里嵌纹理资源）。

- [ ] **Step 3: 启动冒烟**

```
timeout 15 godot --headless 2>&1 | tail -10
```

- [ ] **Step 4: 提交**

```
git add scenes/player/player.tscn
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(player): PlayerAura + SunAura PointLight2D 节点"
```

---

### Task D4: player_controller.gd 每帧 lerp SunAura

**Files:**
- Modify: `scripts/player/player_controller.gd`

- [ ] **Step 1: 在 `player_controller.gd` 顶部加常量 + @onready 引用**

在 `extends CharacterBody2D` 之后加：

```gdscript
const PLAYER_AURA_TEX_SIZE := 64
const SUN_AURA_TEX_SIZE := 400
const SUN_ENERGY_ON := 1.5
const SUN_ENERGY_OFF := 0.0
const SUN_FADE_TIME := 0.3
const TILE_SIZE := 16
```

> 若 TILE_SIZE 已在文件存在，跳过它（不要重复定义）。

在 @onready 区加：

```gdscript
@onready var _player_aura: PointLight2D = $PlayerAura
@onready var _sun_aura: PointLight2D = $SunAura
```

- [ ] **Step 2: `_ready` 里赋纹理**

在 `_ready()` 函数末尾追加：

```gdscript
	_player_aura.texture = ArtCache.radial_gradient(PLAYER_AURA_TEX_SIZE)
	_sun_aura.texture = ArtCache.radial_gradient(SUN_AURA_TEX_SIZE)
```

- [ ] **Step 3: `_physics_process` 或 `_process` 里 lerp SunAura**

在主循环（建议 `_process(delta)`，若无则加一个）末尾追加：

```gdscript
func _process(delta: float) -> void:
	_update_sun_aura(delta)


func _update_sun_aura(delta: float) -> void:
	var tile_x: int = int(floor(global_position.x / TILE_SIZE))
	var tile_y: int = int(floor(global_position.y / TILE_SIZE))
	var exposed: bool = SkyLightGrid.is_sky_exposed(tile_x, tile_y)
	var target: float = SUN_ENERGY_ON if exposed else SUN_ENERGY_OFF
	# 0.3s lerp：每帧把 energy 朝 target 移动 delta/SUN_FADE_TIME 比例
	var t: float = clamp(delta / SUN_FADE_TIME, 0.0, 1.0)
	_sun_aura.energy = lerp(_sun_aura.energy, target, t)
```

> 若文件已有 `_process` 函数，把 `_update_sun_aura(delta)` 调用插到末尾，**不要重复定义 `_process`**。

- [ ] **Step 4: 启动游戏目检**

```
timeout 30 godot 2>&1 | tail -10
```

> 这一步**应该开图形界面跑**（无 --headless），手动看视觉：玩家在地表应有暖白小光圈 + 一个大日光圈（整个屏幕变亮）；走到地下时大日光圈 0.3s 内淡出，只剩小光圈 + 整体暗洞穴色。

如不能开图形界面，至少跑 headless 看没崩：

```
timeout 15 godot --headless 2>&1 | tail -10
```

- [ ] **Step 5: 提交**

```
git add scripts/player/player_controller.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(player): SunAura 跟随 SkyLightGrid (0.3s lerp)"
```

---

## Phase E：火把 tile + 静态光

### Task E1: world_lighting.gd 火把光生命周期

**Files:**
- Create: `scripts/world/world_lighting.gd`
- Modify: `scenes/world/world.tscn`
- Modify: `scripts/world/world.gd`

- [ ] **Step 1: 创建 world_lighting.gd**

`scripts/world/world_lighting.gd`：

```gdscript
# 火把光源生命周期管理。挂在 World 下。
# - on_tile_placed(x, y, TORCH): 在 TorchLights 下实例化 PointLight2D
# - on_tile_removed(x, y, TORCH): free 对应光源
# Phase F 会把这里的 PointLight2D 换成 TorchFx 节点（含火焰 + 火花）。
extends Node

const TILE_SIZE := 16
const TORCH_LIGHT_RADIUS := 96
const TORCH_LIGHT_ENERGY := 1.2
const TORCH_LIGHT_COLOR := Color(1.0, 0.7, 0.3)

var _torches: Dictionary = {}  # Vector2i tile_coord → Node (光源或 TorchFx)


func on_tile_placed(x: int, y: int, tid: int) -> void:
	if tid != Tiles.TORCH:
		return
	_spawn_torch(x, y)


func on_tile_removed(x: int, y: int, old_tid: int) -> void:
	if old_tid != Tiles.TORCH:
		return
	_despawn_torch(x, y)


func _spawn_torch(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if _torches.has(key):
		return  # 已有，幂等
	var light := PointLight2D.new()
	light.texture = ArtCache.radial_gradient(TORCH_LIGHT_RADIUS * 2)
	light.energy = TORCH_LIGHT_ENERGY
	light.color = TORCH_LIGHT_COLOR
	light.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
	var container: Node = get_node("../TorchLights")
	container.add_child(light)
	_torches[key] = light


func _despawn_torch(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if not _torches.has(key):
		return
	var n: Node = _torches[key]
	if is_instance_valid(n):
		n.queue_free()
	_torches.erase(key)


# Chunk 卸载时清掉该 chunk 内所有火把光
func on_chunk_unloaded(chunk_x: int, chunk_width: int) -> void:
	var x0: int = chunk_x * chunk_width
	var x1: int = x0 + chunk_width
	var keys_to_remove: Array = []
	for k in _torches.keys():
		if k.x >= x0 and k.x < x1:
			keys_to_remove.append(k)
	for k in keys_to_remove:
		_despawn_torch(k.x, k.y)


# Chunk 加载时扫描 tile 数据中所有 TORCH 重建光
func on_chunk_loaded(chunk_x: int, chunk_width: int, tiles_2d: Array) -> void:
	# tiles_2d: Array[Array[int]] (chunk.tiles 风格)
	var x0: int = chunk_x * chunk_width
	for lx in tiles_2d.size():
		var world_x: int = x0 + lx
		var col: Array = tiles_2d[lx]
		for y in col.size():
			if col[y] == Tiles.TORCH:
				_spawn_torch(world_x, y)
```

- [ ] **Step 2: world.tscn 加 TorchLights + WorldLighting 子节点**

在 world.tscn 现有节点末尾追加：

```
[node name="TorchLights" type="Node2D" parent="."]

[node name="WorldLighting" type="Node" parent="."]
script = ExtResource("WL_id")
```

> 顶部 `[ext_resource ...]` 段加：
> `[ext_resource type="Script" path="res://scripts/world/world_lighting.gd" id="WL_id"]`
> （id 用未占用的字符串；参考 .tscn 现有 ext_resource 段命名）

- [ ] **Step 3: world.gd 接 WorldLighting**

`scripts/world/world.gd:24` 附近加 @onready：

```gdscript
@onready var world_lighting: Node = $WorldLighting
```

修改 `_set_tile(x, y, tile_id)`（约 201 行）—— 在 `chunk_manager.set_tile(x, y, tile_id)` 之后加：

```gdscript
	# 通知 lighting：先 remove 旧 → 再 place 新
	var old_tid: int = chunk_manager.get_tile(x, y)  # 注意：此时已被覆盖，所以 old_tid 等于 new tid；改取一手缓存
```

> **修正**：上面 `get_tile` 拿不到旧值。需要在 `_set_tile` 入口缓存 old：

完整改写 `_set_tile`：

```gdscript
func _set_tile(x: int, y: int, tile_id: int) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	var old_tid: int = chunk_manager.get_tile(x, y)
	chunk_manager.set_tile(x, y, tile_id)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(Vector2i(x, y), -1)
	else:
		terrain_layer.set_cell(Vector2i(x, y), tile_id, Vector2i.ZERO)
	SkyLightGrid.invalidate_column(x)
	# 火把光源生命周期
	world_lighting.on_tile_removed(x, y, old_tid)
	world_lighting.on_tile_placed(x, y, tile_id)
```

修改 `_on_chunk_loaded(c: Chunk)` —— 在末尾加：

```gdscript
	world_lighting.on_chunk_loaded(c.chunk_x, ChunkConstants.CHUNK_WIDTH, c.tiles)
```

修改 `_on_chunk_unloaded(cx: int)` —— 在末尾加：

```gdscript
	world_lighting.on_chunk_unloaded(cx, ChunkConstants.CHUNK_WIDTH)
```

- [ ] **Step 4: 写集成测试**

`tests/integration/test_torch_lifecycle.gd`：

```gdscript
extends GutTest

const WorldLighting = preload("res://scripts/world/world_lighting.gd")


func test_spawn_torch_creates_light() -> void:
	var container := Node2D.new()
	container.name = "TorchLights"
	add_child_autofree(container)
	var wl = WorldLighting.new()
	add_child_autofree(wl)
	# 模拟 WorldLighting.get_node("../TorchLights")：把 wl 放到 container 兄弟位置
	# 简化：把 container 改成 wl 的 sibling，root 节点作为父
	# 此处直接调用 _spawn_torch，期望 container 多一个 child
	# 但 _spawn_torch 用 get_node("../TorchLights")，需要兄弟关系
	# 改测试结构：
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	root.add_child(wl)  # 现在 wl 和 torch_lights 是 sibling
	wl.on_tile_placed(5, 10, Tiles.TORCH)
	await get_tree().process_frame
	assert_eq(torch_lights.get_child_count(), 1, "应有 1 个火把光")


func test_despawn_torch_removes_light() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	var wl = WorldLighting.new()
	root.add_child(wl)
	wl.on_tile_placed(3, 7, Tiles.TORCH)
	await get_tree().process_frame
	wl.on_tile_removed(3, 7, Tiles.TORCH)
	await get_tree().process_frame
	await get_tree().process_frame  # queue_free 需要一帧
	assert_eq(torch_lights.get_child_count(), 0, "光应被 free")


func test_non_torch_tile_ignored() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var torch_lights := Node2D.new()
	torch_lights.name = "TorchLights"
	root.add_child(torch_lights)
	var wl = WorldLighting.new()
	root.add_child(wl)
	wl.on_tile_placed(1, 1, Tiles.STONE)
	await get_tree().process_frame
	assert_eq(torch_lights.get_child_count(), 0, "非 TORCH tile 不应建光")
```

- [ ] **Step 5: 跑测试 + 全测试**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_torch_lifecycle.gd -gexit 2>&1 | tail -15
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

- [ ] **Step 6: 提交**

```
git add scripts/world/world_lighting.gd scripts/world/world.gd scenes/world/world.tscn tests/integration/test_torch_lifecycle.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(world): 火把光源生命周期 + chunk 加载/卸载同步"
```

---

## Phase F：火把动效（火焰 + 光呼吸 + 火花粒子）

### Task F1: ParticlesArt.get_torch_spark

**Files:**
- Modify: `scripts/art/particles_art.gd`

- [ ] **Step 1: 加函数**

在 `particles_art.gd` 末尾追加：

```gdscript
# 火花粒子贴图：2×2 暖色像素 + 1 像素 alpha 高光中心
static func get_torch_spark(color: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, color)
	img.set_pixel(1, 0, color)
	img.set_pixel(0, 1, color)
	img.set_pixel(1, 1, color)
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 2: 冒烟**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
```

- [ ] **Step 3: 提交**

```
git add scripts/art/particles_art.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(art): ParticlesArt.get_torch_spark(color)"
```

---

### Task F2: torch_spark_particle 场景 + 脚本

**Files:**
- Create: `scripts/fx/torch_spark_particle.gd`
- Create: `scenes/fx/torch_spark_particle.tscn`

- [ ] **Step 1: 脚本**

`scripts/fx/torch_spark_particle.gd`：

```gdscript
# 单个火花。向上飘 + 微弱重力下拉 + 后半段 alpha 渐隐 + 0.8s 自删。
extends Sprite2D

const GRAVITY := 200.0
const LIFETIME := 0.8

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _base_color: Color = Color.WHITE


func setup(start_pos: Vector2) -> void:
	global_position = start_pos
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	var roll: float = randf()
	if roll < 0.05:
		_base_color = Color(1.0, 0.3, 0.1)  # 5% 红
	else:
		var t: float = randf()
		_base_color = Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.5, 0.2), t)
	texture = ParticlesArt.get_torch_spark(_base_color)
	velocity = Vector2(randf_range(-15.0, 15.0), randf_range(-80.0, -40.0))


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	_age += delta
	if _age > LIFETIME * 0.5:
		var t: float = (_age - LIFETIME * 0.5) / (LIFETIME * 0.5)
		modulate.a = clamp(1.0 - t, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
```

- [ ] **Step 2: 场景**

`scenes/fx/torch_spark_particle.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uid://b_torch_spark"]

[ext_resource type="Script" path="res://scripts/fx/torch_spark_particle.gd" id="1_tsp"]

[node name="TorchSparkParticle" type="Sprite2D"]
script = ExtResource("1_tsp")
```

- [ ] **Step 3: 冒烟**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
```

- [ ] **Step 4: 提交**

```
git add scripts/fx/torch_spark_particle.gd scenes/fx/torch_spark_particle.tscn
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(fx): TorchSparkParticle 单火花"
```

---

### Task F3: torch_fx 场景 + 脚本

**Files:**
- Create: `scripts/fx/torch_fx.gd`
- Create: `scenes/fx/torch_fx.tscn`

- [ ] **Step 1: 脚本**

`scripts/fx/torch_fx.gd`：

```gdscript
# 火把整体特效。挂在 TorchLights 下，跟 tile 坐标绑定。
# - Flame: 2 帧切换 + scale.y 微跳
# - Light: PointLight2D，能量基础 1.2 + sin + 随机抖
# - SparkTimer: 每 0.12-0.20s 触发一次火花粒子
extends Node2D

const TILE_SIZE := 16
const LIGHT_RADIUS := 96
const BASE_ENERGY := 1.2
const ENERGY_OSC := 0.10
const ENERGY_NOISE := 0.05
const FLAME_FRAME_TIME := 0.15
const LIGHT_COLOR := Color(1.0, 0.7, 0.3)

const TorchSparkScene = preload("res://scenes/fx/torch_spark_particle.tscn")

var _time: float = 0.0
var _flame_t: float = 0.0
var _flame_frame: int = 0

@onready var flame: Sprite2D = $Flame
@onready var light: PointLight2D = $Light
@onready var spark_timer: Timer = $SparkTimer


func _ready() -> void:
	light.texture = ArtCache.radial_gradient(LIGHT_RADIUS * 2)
	light.energy = BASE_ENERGY
	light.color = LIGHT_COLOR
	_setup_flame_texture()
	spark_timer.wait_time = randf_range(0.12, 0.20)
	spark_timer.start()
	spark_timer.timeout.connect(_on_spark)


func _setup_flame_texture() -> void:
	# 用 BlocksArt 的 TORCH 纹理整体作为静态备份；Flame 是动态盖在 tile 上的小火苗
	# 简化：直接用 ParticlesArt.get_torch_spark 拿一个 4×4 暖橙色纹理放顶部
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	flame.texture = ParticlesArt.get_torch_spark(Color(1.0, 0.6, 0.2))
	flame.scale = Vector2(2, 3)  # 拉成竖向小火苗
	flame.position = Vector2(0, -6)  # 火把 tile 顶上方


func _process(delta: float) -> void:
	_time += delta
	# 光呼吸
	light.energy = BASE_ENERGY + sin(_time * 8.0) * ENERGY_OSC + randf_range(-ENERGY_NOISE, ENERGY_NOISE)
	# 火焰 2 帧切换
	_flame_t += delta
	if _flame_t >= FLAME_FRAME_TIME:
		_flame_t = 0.0
		_flame_frame = 1 - _flame_frame
		flame.scale.y = 3.0 if _flame_frame == 0 else 2.6  # 跳一下


func _on_spark() -> void:
	var s = TorchSparkScene.instantiate()
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	if root == null:
		root = get_tree().current_scene
	root.add_child(s)
	s.setup(global_position + Vector2(randf_range(-1, 1), -7))
	# 重置下次 timer
	spark_timer.wait_time = randf_range(0.12, 0.20)
	spark_timer.start()
```

- [ ] **Step 2: 场景**

`scenes/fx/torch_fx.tscn`：

```
[gd_scene load_steps=2 format=3 uid="uid://b_torch_fx"]

[ext_resource type="Script" path="res://scripts/fx/torch_fx.gd" id="1_tfx"]

[node name="TorchFx" type="Node2D"]
script = ExtResource("1_tfx")

[node name="Flame" type="Sprite2D" parent="."]

[node name="Light" type="PointLight2D" parent="."]

[node name="SparkTimer" type="Timer" parent="."]
wait_time = 0.15
one_shot = false
```

- [ ] **Step 3: 冒烟**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
```

- [ ] **Step 4: 提交**

```
git add scripts/fx/torch_fx.gd scenes/fx/torch_fx.tscn
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(fx): TorchFx 节点 (火焰 + 光呼吸 + 火花 timer)"
```

---

### Task F4: world_lighting.gd 切换到 TorchFx 节点

**Files:**
- Modify: `scripts/world/world_lighting.gd`

- [ ] **Step 1: 改 `_spawn_torch` 用 TorchFx 场景**

把 `_spawn_torch` 整段替换为：

```gdscript
const TorchFxScene = preload("res://scenes/fx/torch_fx.tscn")


func _spawn_torch(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if _torches.has(key):
		return
	var fx = TorchFxScene.instantiate()
	fx.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
	var container: Node = get_node("../TorchLights")
	container.add_child(fx)
	_torches[key] = fx
```

> 删掉旧的 PointLight2D-only 实现（TORCH_LIGHT_* 常量也可以删，因为它们在 TorchFx 里）。但保留也无害；按 YAGNI，删掉。

- [ ] **Step 2: 跑 test_torch_lifecycle 看是否还过**

```
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_torch_lifecycle.gd -gexit 2>&1 | tail -10
```

> 测试断言的是 `torch_lights.get_child_count()` —— TorchFx 也是 child，仍然 1 个。✅

- [ ] **Step 3: 全测试**

```
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

- [ ] **Step 4: 手动目检（如有图形界面）**

```
timeout 30 godot 2>&1 | tail -10
```

预期：进游戏→挖矿→合成火把→放下时该位置出现火苗 + 光圈 + 随机飘起火花。

- [ ] **Step 5: 提交**

```
git add scripts/world/world_lighting.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(world): 火把光改用 TorchFx 场景 (含火焰 + 火花)"
```

---

## Phase G：最终集成 + 全测

### Task G1: 全测试 + 视觉冒烟

**Files:** 无新增

- [ ] **Step 1: 跑全测试**

```
timeout 30 godot --editor --quit 2>&1 | tail -3
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -25
```

预期：所有 test 通过，无回归。

- [ ] **Step 2: 视觉冒烟清单**

如有图形界面（`timeout 60 godot 2>&1`）：
1. 主菜单 → 开新游戏（确认主菜单 UI 未变黑，因 UI 在 CanvasLayer 之外）
2. 进入世界 → 地表玩家有暖白小光圈 + 大日光（屏幕亮）
3. 向下挖（用 wood_pickaxe）→ 钻入地下时大日光 0.3s 内淡出，屏幕变暖暗色
4. 找洞穴 → 应该能看到不规则空腔；找煤矿（深色斑块）/铁矿（红橙斑块）/ DEEP_STONE（暗色岩石）
5. 挖煤 → 背包有 coal
6. 工作台合成（1 coal + 1 log 竖直）→ 拿到 4 torch
7. 切到 torch 物品，右键放置 → 当前格出现火苗 + 暖光晕 + 周期火花飞起
8. 挖掉火把 → 光消失 + 回收 1 torch
9. 走出洞穴回到地表 → 大日光淡入

记下任何视觉异常（光圈大小不合适？颜色太暗？火花太密？）→ 调整 `lighting_constants` 区域常量。

- [ ] **Step 3: （如有视觉异常）调整常量**

常用调整点：
- `world.tscn` 的 `CanvasModulate.color` —— 暗度
- `player_controller.gd: SUN_ENERGY_ON` —— 日光强度
- `world_lighting.gd: TORCH_LIGHT_RADIUS / BASE_ENERGY` —— 火把光强
- `torch_fx.gd: ENERGY_OSC / ENERGY_NOISE` —— 呼吸幅度
- `torch_fx.gd: SparkTimer wait_time` 范围 —— 火花密度

- [ ] **Step 4: 提交（如有调整）**

```
git add -p
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "tune(lighting): 视觉调优 (常量微调)"
```

---

## 自检（写完计划后）

- **Spec 覆盖**:
  - 光照系统（spec §4） → Phase D（D1-D4）
  - 火把 + 火焰（spec §5） → Phase A（tile/item）+ Phase C（recipe）+ Phase E（lifecycle）+ Phase F（fx）
  - 地底地形（spec §6） → Phase A（tile/item/art）+ Phase B（generator）
  - 铁镐（spec §7） → Phase A（item）+ Phase C（recipe）
  - 配置常量（spec §8） → 散布在 player_controller.gd / world_lighting.gd / torch_fx.gd 顶部
  - 测试（spec §9） → Phase A1/A4 (test_tile_data, test_item_db), Phase C (test_recipe_db), Phase B (test_world_generator), Phase E (test_torch_lifecycle)
  - 变更清单（spec §10） → 见本计划"文件结构"表

- **未自动化测试**：spec §11 风险 #2 (cloud_layer 被压暗) —— 实施 D2 时若发现云层变黑，调整 cloud_layer.tscn 放到独立 CanvasLayer。**实施时关注**。

- **placeholder 扫描**：无 TBD / TODO（生成时已避免）。

- **类型一致性**：`Tiles.TORCH` (=14) / `BlocksArt.TORCH` (=14) / WorldLighting 中所有引用一致；ItemDB "torch" 的 `placeable_tile_id = Tiles.TORCH` 一致。

---

## 执行选择

**Plan complete and saved to `docs/superpowers/plans/2026-05-21-underground-vision.md`. Two execution options:**

**1. Subagent-Driven (推荐)** —— 每个 Task 单独 dispatch fresh subagent，主线 review 后再发下一个

**2. Inline Execution** —— 在当前 session 顺序执行所有 Task，断点处停下让你 review

**选哪个？**
