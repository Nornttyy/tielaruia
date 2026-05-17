# Teilaruia · Demo · P1 Foundation · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家可以在程序生成的 1024×256 tile 世界里跑、跳、撞墙；摄像机平滑跟随；调试 HUD 显示 FPS / 玩家坐标 / 暗格状态。所有纯逻辑模块走 TDD。

**Architecture:** Godot 4.3 单进程。Autoload 注册 `TileData` (tile 属性表) 和 `SkyLightGrid` (天光暗格)。`WorldGenerator` 是 RefCounted 工具，由 `World` 场景调用产生确定性 tile 数据。`TileMapLayer` 渲染 tile，`CharacterBody2D` + `move_and_slide()` 处理玩家物理。

**Tech Stack:** Godot 4.3, GDScript, GUT 9.x (单元测试), 内建 `FastNoiseLite` / `TileMapLayer` / `CharacterBody2D`。

**前置条件：** 已存在 commit `3e16b9d` 的 art 模块（`ArtCache` autoload、`BlocksArt`、`PlayerArt` 等）。本计划复用这些资源。

**预计 12 个任务，~60 步。**

---

## File Structure (P1 涉及)

新建：
- `addons/gut/` — GUT 测试框架 (vendored)
- `tests/unit/test_tile_data.gd`
- `tests/unit/test_world_generator.gd`
- `tests/unit/test_sky_light_grid.gd`
- `tests/integration/test_smoke.gd`
- `tests/.gutconfig.json`
- `scripts/world/tile_data.gd` (autoload)
- `scripts/world/world_generator.gd`
- `scripts/world/sky_light_grid.gd` (autoload)
- `scripts/world/tileset_builder.gd`
- `scripts/world/world.gd`
- `scripts/player/player_controller.gd`
- `scripts/debug/debug_hud.gd`
- `scripts/main.gd`
- `scenes/world/world.tscn`
- `scenes/player/player.tscn`
- `scenes/ui/debug_hud.tscn`
- `scenes/main.tscn`

修改：
- `project.godot` — 注册 autoload + InputMap + 改 main_scene

---

## Task 1: 测试框架 GUT 接入 + 基线烟雾测试

**Files:**
- Create: `addons/gut/` (vendored from upstream)
- Create: `tests/unit/test_sanity.gd`
- Create: `.gutconfig.json`

- [ ] **Step 1: Vendor GUT 9.x 到 addons/gut/**

Run:
```bash
cd /workspace/teilaruia
git clone --depth 1 --branch v9.3.1 https://github.com/bitwes/Gut.git /tmp/gut-vendor
mkdir -p addons
cp -r /tmp/gut-vendor/addons/gut addons/gut
rm -rf /tmp/gut-vendor
```

Expected: `addons/gut/` 目录存在，里面有 `gut_cmdln.gd`、`gut.gd` 等。

- [ ] **Step 2: 写 .gutconfig.json (项目级测试配置)**

Create `/workspace/teilaruia/.gutconfig.json`:
```json
{
  "dirs": ["res://tests/unit/", "res://tests/integration/"],
  "include_subdirs": true,
  "log_level": 1,
  "should_exit": true,
  "should_maximize": false
}
```

- [ ] **Step 3: 写一个 sanity 测试**

Create `/workspace/teilaruia/tests/unit/test_sanity.gd`:
```gdscript
extends GutTest

func test_one_plus_one_equals_two():
	assert_eq(1 + 1, 2, "数学还活着")

func test_godot_runtime_exists():
	assert_not_null(Engine.get_version_info(), "Godot 引擎可访问")
```

- [ ] **Step 4: 跑 GUT，确认通过**

Run:
```bash
cd /workspace/teilaruia
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -20
```

Expected: 输出含 `2 passed, 0 failed` (或 GUT 等价格式)。

- [ ] **Step 5: 提交**

```bash
git add addons/gut/ tests/unit/test_sanity.gd .gutconfig.json
git commit -m "test: 接入 GUT 9.3.1 测试框架 + sanity 测试"
```

---

## Task 2: InputMap 注册

**Files:**
- Modify: `project.godot`

- [ ] **Step 1: 加 InputMap 块到 project.godot**

在 `project.godot` 末尾追加 (注意是追加，不要覆盖现有 sections)：

```ini
[input]

move_left={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":65,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194319,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
move_right={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":68,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194321,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
jump={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":32,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":87,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null), Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194320,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
toggle_debug={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194334,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

说明 keycode 含义：65=A, 68=D, 32=Space, 87=W, 4194319=Left arrow, 4194321=Right arrow, 4194320=Up arrow, 4194334=F3。

- [ ] **Step 2: 验证 InputMap 加载无错**

Run:
```bash
godot --headless --quit 2>&1 | grep -i "error\|warn" || echo "clean"
```

Expected: `clean` (项目配置解析成功)。

- [ ] **Step 3: 提交**

```bash
git add project.godot
git commit -m "feat(input): 注册 move_left/right/jump/toggle_debug 动作映射"
```

---

## Task 3: TileData autoload (TDD)

**Files:**
- Create: `scripts/world/tile_data.gd`
- Test: `tests/unit/test_tile_data.gd`
- Modify: `project.godot` (注册 autoload)

`TileData` 是全 tile 属性的单一查询入口。返回 "可挖吗 / 所需工具 / 是否实心 / 掉落表"。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_tile_data.gd`:
```gdscript
extends GutTest

# TileData 是 autoload。需要先在 project.godot 注册才能用 TileData 全局名访问。
# 测试里通过 load() 直接拿到类。

const TileDataClass = preload("res://scripts/world/tile_data.gd")
var td: Node

func before_each():
	td = TileDataClass.new()
	add_child_autofree(td)

func test_air_is_not_solid():
	assert_false(td.is_solid(td.AIR), "空气不实心")

func test_stone_is_solid():
	assert_true(td.is_solid(td.STONE), "石头实心")

func test_bedrock_is_unbreakable():
	assert_false(td.is_mineable(td.BEDROCK), "基岩不可挖")

func test_grass_mineable_by_bare_hand():
	assert_true(td.is_mineable(td.GRASS), "草可挖")
	assert_eq(td.required_tool_tier(td.GRASS, "pickaxe"), 0, "草徒手挖")

func test_stone_needs_pickaxe():
	assert_eq(td.required_tool_tier(td.STONE, "pickaxe"), 1, "石头需 1 级镐")
	assert_eq(td.required_tool_tier(td.STONE, "axe"), -1, "斧头挖不了石头")

func test_grass_drops_dirt_or_self():
	var drops = td.drops_for(td.GRASS, "")
	assert_true(drops.has("dirt") or drops.has("grass"), "草掉落含 dirt 或 grass")
```

- [ ] **Step 2: 跑测试，确认 FAIL (脚本不存在)**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: GUT 报错 "Could not preload res://scripts/world/tile_data.gd"。

- [ ] **Step 3: 写实现**

Create `/workspace/teilaruia/scripts/world/tile_data.gd`:
```gdscript
# Tile 属性表 (autoload 单例)。所有 tile 行为查询统一在这里。
extends Node

# Tile ID 常量 (与 BlocksArt 同步)
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const LOG := 5
const LEAVES := 6
const PLANKS := 7
const WORKBENCH := 8
const DOOR := 9
const BEDROCK := 10

# 每 tile 的属性。drops 为 [item_id, weight, count_min, count_max] 数组。
# tool: "pickaxe"/"axe"/"sword"/"" (空 = 徒手)
# tier: -1 = 该工具挖不动；0 = 徒手也行；1 = 需 1 级 (木质)
const _PROPS := {
	AIR: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 80, 1, 1], ["grass", 20, 1, 1]],
	},
	DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	SAND: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["sand", 100, 1, 1]],
	},
	LOG: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LEAVES: {
		"solid": false, "mineable": true,  # 不实心（玩家可穿过）
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 30, 1, 1]],  # 30% 几率掉 1 原木 (代替树苗)
	},
	PLANKS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["planks", 100, 1, 1]],
	},
	WORKBENCH: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["workbench", 100, 1, 1]],
	},
	DOOR: {
		"solid": true, "mineable": true,  # 关时实心；开/关由 Door scene 单独处理碰撞
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["door", 100, 1, 1]],
	},
	BEDROCK: {
		"solid": true, "mineable": false,  # 不可破坏
		"tool_tiers": {},
		"drops": [],
	},
}


func is_solid(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].solid


func is_mineable(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].mineable


# 返回该 tool 挖该 tile 所需的最低 tier。-1 = 不行。0 = 徒手也行。
func required_tool_tier(tile_id: int, tool: String) -> int:
	if not _PROPS.has(tile_id):
		return -1
	var tiers: Dictionary = _PROPS[tile_id].tool_tiers
	if not tiers.has(tool) and not tiers.has(""):
		return -1
	if tiers.has(tool):
		return tiers[tool]
	return tiers.get("", -1)


# 返回挖该 tile 后产生的物品 dict: {item_id: count}。按 drops 表权重抽样。
func drops_for(tile_id: int, _tool: String) -> Dictionary:
	if not _PROPS.has(tile_id):
		return {}
	var result := {}
	for entry in _PROPS[tile_id].drops:
		var item_id: String = entry[0]
		var weight: int = entry[1]
		var roll := randi() % 100
		if roll < weight:
			var n := randi_range(entry[2], entry[3])
			if n > 0:
				result[item_id] = result.get(item_id, 0) + n
	return result
```

- [ ] **Step 4: 注册 autoload**

修改 `project.godot` 的 `[autoload]` 段，加一行 (放在 ArtCache 之前，因为后续 autoload 可能依赖 TileData)：

```ini
[autoload]

TileData="*res://scripts/world/tile_data.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
```

- [ ] **Step 5: 跑测试，确认 PASS**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 输出含 `7+ passed, 0 failed`（之前 sanity 2 个 + tile_data 6 个）。

- [ ] **Step 6: 提交**

```bash
git add scripts/world/tile_data.gd tests/unit/test_tile_data.gd project.godot
git commit -m "feat(world): TileData autoload + 单元测试 (10 种 tile 属性表)"
```

---

## Task 4: WorldGenerator (TDD)

**Files:**
- Create: `scripts/world/world_generator.gd`
- Test: `tests/unit/test_world_generator.gd`

`WorldGenerator` 由种子产生 1024×256 的二维 tile 数组。包含：地表（Perlin 高度）、草层、泥土层、石头层、底部基岩、沙子斑块、出生点。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_world_generator.gd`:
```gdscript
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")

func _gen(seed: int = 42) -> Dictionary:
	return WorldGenerator.generate(seed, 256, 128)  # 小尺寸加速测试

func test_size_matches():
	var w = _gen()
	assert_eq(w.tiles.size(), 256, "宽度匹配")
	assert_eq((w.tiles[0] as Array).size(), 128, "高度匹配")

func test_same_seed_produces_same_world():
	var a = _gen(123)
	var b = _gen(123)
	for x in 256:
		assert_eq(a.tiles[x], b.tiles[x], "列 %d 不一致" % x)

func test_different_seed_produces_different_world():
	var a = _gen(1)
	var b = _gen(2)
	var diff_count := 0
	for x in 256:
		for y in 128:
			if a.tiles[x][y] != b.tiles[x][y]:
				diff_count += 1
	assert_gt(diff_count, 1000, "不同种子至少差 1000 tile")

func test_bedrock_at_bottom():
	var w = _gen()
	for x in 256:
		assert_eq(w.tiles[x][127], TileData.BEDROCK, "最底行全是基岩 (列 %d)" % x)
		assert_eq(w.tiles[x][126], TileData.BEDROCK, "倒数第二行全是基岩 (列 %d)" % x)

func test_air_above_surface():
	var w = _gen()
	# 出生点 y 必然是地表，向上一定有空气
	var spawn: Vector2i = w.spawn_point
	assert_eq(w.tiles[spawn.x][spawn.y - 1], TileData.AIR, "出生点上方是空气")
	assert_eq(w.tiles[spawn.x][spawn.y - 2], TileData.AIR, "出生点上方再上一格也是空气")

func test_spawn_point_on_surface():
	var w = _gen()
	var spawn: Vector2i = w.spawn_point
	assert_true(spawn.x >= 0 and spawn.x < 256, "出生点 x 在范围内")
	assert_true(spawn.y >= 0 and spawn.y < 128, "出生点 y 在范围内")
	# spawn.y 表示"玩家脚底所在 tile"，应是空气
	assert_eq(w.tiles[spawn.x][spawn.y], TileData.AIR, "出生点本格是空气 (脚踏)")

func test_grass_on_surface_dirt_below():
	var w = _gen()
	# 任取 5 列，找到最上层非空气 tile，应是 grass 或 sand
	for x in [10, 50, 100, 150, 200]:
		for y in 128:
			var t = w.tiles[x][y]
			if t != TileData.AIR:
				assert_true(
					t == TileData.GRASS or t == TileData.SAND,
					"列 %d 的地表 tile 应是 grass/sand，实际 %d" % [x, t]
				)
				break
```

- [ ] **Step 2: 跑测试，确认 FAIL**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 7 个 test_world_generator 测试全部失败。

- [ ] **Step 3: 写实现**

Create `/workspace/teilaruia/scripts/world/world_generator.gd`:
```gdscript
# 程序化世界生成。给定种子产生确定性的 2D tile 数组。
# 返回 dict: {"tiles": Array[Array[int]], "spawn_point": Vector2i, "seed": int}
# tiles[x][y] = TileData 常量
extends RefCounted

const SURFACE_BASE := 0.45     # 地表平均高度 (相对世界 0..1)
const SURFACE_AMP := 0.10      # 地表起伏振幅
const DIRT_DEPTH := 6          # 地表下泥土层厚度
const BEDROCK_ROWS := 2        # 基岩占最底几行
const SAND_PATCH_CHANCE := 0.03  # 地表 tile 是 sand 的概率


static func generate(world_seed: int, width: int = 1024, height: int = 256) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3

	# 决定地表高度（每列一个）
	var heights := PackedInt32Array()
	heights.resize(width)
	for x in width:
		var n := noise.get_noise_1d(float(x))  # -1..1
		var h := int(height * (SURFACE_BASE + n * SURFACE_AMP))
		heights[x] = clampi(h, 4, height - BEDROCK_ROWS - 1)

	# 二级噪声决定沙子斑块（由独立种子加 1 派生，避免与高度纠缠）
	var sand_noise := FastNoiseLite.new()
	sand_noise.seed = world_seed + 1
	sand_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	sand_noise.frequency = 0.05

	# 初始化 tiles 数组
	var tiles := []
	tiles.resize(width)
	for x in width:
		var col := []
		col.resize(height)
		var surface_y: int = heights[x]
		var is_sand_column := sand_noise.get_noise_1d(float(x)) > 0.4
		for y in height:
			if y < surface_y:
				col[y] = TileData.AIR
			elif y == surface_y:
				col[y] = TileData.SAND if is_sand_column else TileData.GRASS
			elif y < surface_y + DIRT_DEPTH:
				col[y] = TileData.SAND if is_sand_column else TileData.DIRT
			elif y >= height - BEDROCK_ROWS:
				col[y] = TileData.BEDROCK
			else:
				col[y] = TileData.STONE
		tiles[x] = col

	# 出生点：选地图中央附近第一个非沙地表，玩家脚底在地表上方一格
	var spawn_x := width / 2
	var search_offsets := [0, 4, -4, 8, -8, 12, -12, 16, -16]
	for offset in search_offsets:
		var candidate_x := spawn_x + offset
		if candidate_x < 0 or candidate_x >= width:
			continue
		var surf: int = heights[candidate_x]
		if tiles[candidate_x][surf] == TileData.GRASS:
			spawn_x = candidate_x
			break
	# spawn_y 是脚底所在 tile 的 y (= 地表上方一格 = AIR)
	var spawn_y: int = heights[spawn_x] - 1

	return {
		"tiles": tiles,
		"spawn_point": Vector2i(spawn_x, spawn_y),
		"seed": world_seed,
		"width": width,
		"height": height,
	}
```

- [ ] **Step 4: 跑测试，确认 PASS**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: `15 passed, 0 failed` (sanity 2 + tile_data 6 + world_generator 7)。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/world_generator.gd tests/unit/test_world_generator.gd
git commit -m "feat(world): WorldGenerator perlin 地形 + 出生点 + 沙子斑块"
```

---

## Task 5: SkyLightGrid autoload (TDD)

**Files:**
- Create: `scripts/world/sky_light_grid.gd`
- Test: `tests/unit/test_sky_light_grid.gd`
- Modify: `project.godot`

为后续 (P4) 史莱姆"在暗处刷新"做数据准备。本计划只实现 compute + 查询接口，不做渲染。

- [ ] **Step 1: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_sky_light_grid.gd`:
```gdscript
extends GutTest

const SkyLightGridClass = preload("res://scripts/world/sky_light_grid.gd")
var grid

func before_each():
	grid = SkyLightGridClass.new()
	add_child_autofree(grid)

func _make_tiles(w: int, h: int, default_id: int) -> Array:
	var t := []
	t.resize(w)
	for x in w:
		var col := []
		col.resize(h)
		col.fill(default_id)
		t[x] = col
	return t

func test_pure_air_is_all_lit():
	var tiles = _make_tiles(8, 8, TileData.AIR)
	grid.recompute_from(tiles)
	for x in 8:
		for y in 8:
			assert_true(grid.is_sky_exposed(x, y), "(%d,%d) 应有天光" % [x, y])

func test_solid_blocks_light():
	var tiles = _make_tiles(8, 8, TileData.AIR)
	tiles[3][4] = TileData.STONE
	grid.recompute_from(tiles)
	# (3, 4) 本身实心，不算 sky_exposed
	assert_false(grid.is_sky_exposed(3, 4))
	# (3, 5) 及以下都被遮挡
	assert_false(grid.is_sky_exposed(3, 5))
	assert_false(grid.is_sky_exposed(3, 7))
	# 邻列不受影响
	assert_true(grid.is_sky_exposed(2, 5))

func test_invalidate_column_updates():
	var tiles = _make_tiles(8, 8, TileData.AIR)
	tiles[2][3] = TileData.STONE
	grid.recompute_from(tiles)
	assert_false(grid.is_sky_exposed(2, 5))
	# 移除遮挡
	tiles[2][3] = TileData.AIR
	grid.invalidate_column(2, tiles)
	assert_true(grid.is_sky_exposed(2, 5))

func test_out_of_bounds_returns_false():
	var tiles = _make_tiles(8, 8, TileData.AIR)
	grid.recompute_from(tiles)
	assert_false(grid.is_sky_exposed(-1, 0))
	assert_false(grid.is_sky_exposed(8, 0))
	assert_false(grid.is_sky_exposed(0, -1))
	assert_false(grid.is_sky_exposed(0, 8))

func test_non_solid_tile_does_not_block():
	var tiles = _make_tiles(8, 8, TileData.AIR)
	tiles[1][3] = TileData.LEAVES  # leaves 不实心
	grid.recompute_from(tiles)
	# leaves 上方暗，但下方仍亮 (因为 leaves.solid == false)
	assert_true(grid.is_sky_exposed(1, 5))
```

- [ ] **Step 2: 跑测试，FAIL**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: SkyLightGrid 相关测试报 preload 失败。

- [ ] **Step 3: 写实现**

Create `/workspace/teilaruia/scripts/world/sky_light_grid.gd`:
```gdscript
# 天光暗格：每列从上往下扫描，遇到首个实心 tile 之后下方均标记为"无天光"。
# 用于 P4 史莱姆刷新条件查询。本类不渲染、不影响视觉。
extends Node

var _width: int = 0
var _height: int = 0
# _exposed[x][y] = true 表示 (x,y) 可被天光直射 (本格不实心 + 上方无实心遮挡)
var _exposed: Array = []


func recompute_from(tiles: Array) -> void:
	_width = tiles.size()
	if _width == 0:
		_height = 0
		_exposed = []
		return
	_height = (tiles[0] as Array).size()
	_exposed.resize(_width)
	for x in _width:
		_exposed[x] = _compute_column(tiles[x])


func invalidate_column(x: int, tiles: Array) -> void:
	if x < 0 or x >= _width:
		return
	_exposed[x] = _compute_column(tiles[x])


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
		if TileData.is_solid(tile_id):
			result[y] = false  # 实心本身不算"被天光照"
			blocked = true
		else:
			result[y] = true
	return result
```

- [ ] **Step 4: 注册 autoload**

修改 `project.godot` 的 `[autoload]`：
```ini
[autoload]

TileData="*res://scripts/world/tile_data.gd"
SkyLightGrid="*res://scripts/world/sky_light_grid.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
```

- [ ] **Step 5: 跑测试，PASS**

Run:
```bash
godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: `20 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/world/sky_light_grid.gd tests/unit/test_sky_light_grid.gd project.godot
git commit -m "feat(world): SkyLightGrid autoload + 列扫描算法 (P4 史莱姆刷新支撑)"
```

---

## Task 6: TileSetBuilder (从 ArtCache 程序构建 TileSet)

**Files:**
- Create: `scripts/world/tileset_builder.gd`

为什么用代码而不用 `.tres`：手写 TileSet 文本 30+ 个 atlas region 容易错；ArtCache 已经有现成 16×16 纹理，直接拼装。

- [ ] **Step 1: 写实现**

Create `/workspace/teilaruia/scripts/world/tileset_builder.gd`:
```gdscript
# 从 ArtCache.block_textures 构建一个 TileSet，每个 tile_id 作为独立 source。
# TileMapLayer.set_cell(coord, source_id, atlas_coords=Vector2i.ZERO) 调用时
# source_id 即 TileData 的常量 (1=GRASS, 2=DIRT, ...)。
extends RefCounted


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# 必须先建物理层 (索引 0)，循环里给实心 tile 加碰撞 polygon 才能引用
	ts.add_physics_layer()

	# 给每个 tile_id 创建一个 atlas source。空气不需要 source (set_cell 用 -1 清除)。
	var tile_ids := [
		TileData.GRASS, TileData.DIRT, TileData.STONE, TileData.SAND,
		TileData.LOG, TileData.LEAVES, TileData.PLANKS, TileData.WORKBENCH,
		TileData.DOOR, TileData.BEDROCK,
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(16, 16)
		source.create_tile(Vector2i.ZERO)

		# 给实心 tile 加碰撞 (leaves 不实心)
		if TileData.is_solid(tile_id):
			var tile_props = source.get_tile_data(Vector2i.ZERO, 0)
			tile_props.add_collision_polygon(0)  # physics layer 0
			tile_props.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
			]))

		ts.add_source(source, tile_id)

	return ts
```

⚠️ **命名冲突提示：** Godot 内建的 `TileData` (atlas tile 元数据类型) 与我们的 autoload `TileData` 同名。autoload 会遮蔽内建类型 → 上面 `var tile_props = ...` 故意省略类型注解，避免 `: TileData` 引用错。这是正确写法。

- [ ] **Step 2: 提交（无测试 — 行为通过 World 场景集成验证）**

```bash
git add scripts/world/tileset_builder.gd
git commit -m "feat(world): TileSetBuilder 从 ArtCache 程序构建 TileSet"
```

---

## Task 7: Player scene + 控制器

**Files:**
- Create: `scenes/player/player.tscn`
- Create: `scripts/player/player_controller.gd`

- [ ] **Step 1: 写 player_controller.gd**

Create `/workspace/teilaruia/scripts/player/player_controller.gd`:
```gdscript
# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const SPEED := 140.0           # 像素/秒
const JUMP_VELOCITY := -320.0  # 负值 = 向上
const GRAVITY := 900.0         # 像素/秒²
const COYOTE_TIME := 0.10      # 离地后仍可跳的宽容窗口 (秒)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote_timer: float = 0.0
var _facing_right: bool = true


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# --- 输入 ---
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED

	# --- 重力 ---
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		_coyote_timer = max(0.0, _coyote_timer - delta)
	else:
		_coyote_timer = COYOTE_TIME

	# --- 跳跃 ---
	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0

	move_and_slide()

	# --- 朝向 ---
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right

	# --- 动画状态机 ---
	_update_animation(dir)


func _update_animation(dir: float) -> void:
	var on_floor := is_on_floor()
	var next_anim: String
	if not on_floor:
		next_anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(dir) > 0.01:
		next_anim = "walk"
	else:
		next_anim = "idle"
	if sprite.animation != next_anim:
		sprite.play(next_anim)
```

- [ ] **Step 2: 写 player.tscn**

Create `/workspace/teilaruia/scenes/player/player.tscn`:
```
[gd_scene load_steps=4 format=3 uid="uid://teilaruia_player"]

[ext_resource type="Script" path="res://scripts/player/player_controller.gd" id="1_ctrl"]

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
```

说明：
- CollisionShape2D 是 10×22 矩形，比 sprite (12×24) 略小，让玩家不会卡墙缝
- 玩家"脚底原点" 在 (0,0)，sprite 通过 offset 上移 12 px 让脚踏在原点
- CollisionShape2D 中心位于 (0, -11) → 矩形顶在 -22, 底在 0

- [ ] **Step 3: 冷启动验证 (无运行时错误)**

Run:
```bash
rm -rf .godot && timeout 8 godot --headless 2>&1 | grep -i "error\|warn" || echo "clean"
```

Expected: `clean` 或仅显示 GUT/autoload 的预期 info。

- [ ] **Step 4: 提交**

```bash
git add scripts/player/player_controller.gd scenes/player/player.tscn
git commit -m "feat(player): CharacterBody2D 控制器 + 4 状态动画 + coyote time"
```

---

## Task 8: World scene + bootstrap script

**Files:**
- Create: `scripts/world/world.gd`
- Create: `scenes/world/world.tscn`

- [ ] **Step 1: 写 world.gd**

Create `/workspace/teilaruia/scripts/world/world.gd`:
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
var _tiles: Array  # tiles[x][y] = TileData const


func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
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
			if tile_id == TileData.AIR:
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
	camera.position = Vector2.ZERO  # 跟随玩家


func get_player() -> CharacterBody2D:
	for child in entities_root.get_children():
		if child is CharacterBody2D:
			return child
	return null
```

- [ ] **Step 2: 写 world.tscn**

Create `/workspace/teilaruia/scenes/world/world.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://teilaruia_world"]

[ext_resource type="Script" path="res://scripts/world/world.gd" id="1_world"]

[node name="World" type="Node2D"]
script = ExtResource("1_world")

[node name="TerrainLayer" type="TileMapLayer" parent="."]

[node name="Entities" type="Node2D" parent="."]

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
position_smoothing_enabled = true
position_smoothing_speed = 8.0
```

说明：Camera2D 初始挂在 World 下，运行时通过 `reparent(player)` 挂到玩家身上（这样 `position_smoothing_enabled` 让相机平滑跟随）。zoom 2× 让 16px tile 看起来是 32px，画面更舒服。

- [ ] **Step 3: 验证冷启动 + tiles 生成**

Run:
```bash
rm -rf .godot && timeout 8 godot --headless 2>&1 | grep -i "error\|warn" || echo "clean"
```

Expected: `clean`。

- [ ] **Step 4: 提交**

```bash
git add scripts/world/world.gd scenes/world/world.tscn
git commit -m "feat(world): World 场景 - tile 生成 + 玩家出生 + 相机挂载"
```

---

## Task 9: Debug HUD

**Files:**
- Create: `scripts/debug/debug_hud.gd`
- Create: `scenes/ui/debug_hud.tscn`

- [ ] **Step 1: 写 debug_hud.gd**

Create `/workspace/teilaruia/scripts/debug/debug_hud.gd`:
```gdscript
# F3 切换显示；显示 FPS、玩家世界坐标、玩家所在 tile 坐标、tile 上的暗格状态。
extends CanvasLayer

const TILE_SIZE := 16

@onready var label: Label = $Panel/Label
var _player: Node2D
var _visible: bool = true


func _ready() -> void:
	visible = _visible


func set_player(player: Node2D) -> void:
	_player = player


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		_visible = not _visible
		visible = _visible
	if not _visible or _player == null:
		return
	var pos := _player.global_position
	var tile_x := int(floor(pos.x / TILE_SIZE))
	var tile_y := int(floor(pos.y / TILE_SIZE))
	var dark := not SkyLightGrid.is_sky_exposed(tile_x, tile_y)
	label.text = "FPS: %d\nPos: (%.1f, %.1f)\nTile: (%d, %d)\nDark: %s" % [
		Engine.get_frames_per_second(),
		pos.x, pos.y,
		tile_x, tile_y,
		"YES" if dark else "no",
	]
```

- [ ] **Step 2: 写 debug_hud.tscn**

Create `/workspace/teilaruia/scenes/ui/debug_hud.tscn`:
```
[gd_scene load_steps=3 format=3 uid="uid://teilaruia_debug_hud"]

[ext_resource type="Script" path="res://scripts/debug/debug_hud.gd" id="1_dhud"]

[sub_resource type="StyleBoxFlat" id="StyleBoxFlat_panel"]
bg_color = Color(0, 0, 0, 0.55)
content_margin_left = 8.0
content_margin_top = 6.0
content_margin_right = 8.0
content_margin_bottom = 6.0

[node name="DebugHUD" type="CanvasLayer"]
script = ExtResource("1_dhud")

[node name="Panel" type="PanelContainer" parent="."]
offset_left = 8.0
offset_top = 8.0
offset_right = 220.0
offset_bottom = 96.0
theme_override_styles/panel = SubResource("StyleBoxFlat_panel")

[node name="Label" type="Label" parent="Panel"]
text = "FPS: --
Pos: --
Tile: --
Dark: --"
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0.85, 0.95, 1, 1)
```

- [ ] **Step 3: 提交**

```bash
git add scripts/debug/debug_hud.gd scenes/ui/debug_hud.tscn
git commit -m "feat(ui): Debug HUD - FPS/坐标/暗格 (F3 切换)"
```

---

## Task 10: Main scene + project.godot 主场景切换

**Files:**
- Create: `scripts/main.gd`
- Create: `scenes/main.tscn`
- Modify: `project.godot`

- [ ] **Step 1: 写 main.gd**

Create `/workspace/teilaruia/scripts/main.gd`:
```gdscript
# 游戏根：实例化 World + DebugHUD，串好引用。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")

var world: Node2D
var debug_hud: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	# 等 World 完成 _ready (它在 _ready 里 spawn 玩家)，
	# 再把玩家引用传给 HUD。call_deferred 确保下一帧。
	debug_hud.call_deferred("set_player", world.get_player())
```

- [ ] **Step 2: 写 main.tscn**

Create `/workspace/teilaruia/scenes/main.tscn`:
```
[gd_scene load_steps=2 format=3 uid="uid://teilaruia_main"]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]

[node name="Main" type="Node"]
script = ExtResource("1_main")
```

- [ ] **Step 3: 修改 project.godot 主场景**

把 `[application]` 段里：
```ini
run/main_scene="res://scenes/art_preview.tscn"
```
改成：
```ini
run/main_scene="res://scenes/main.tscn"
```

art_preview 仍保留，未来可临时切回去看美术。

- [ ] **Step 4: 验证冷启动跑得起**

Run:
```bash
rm -rf .godot && timeout 8 godot --headless 2>&1 | tee /tmp/godot.log | head -30
grep -iE "error|crash|stack" /tmp/godot.log || echo "no errors"
```

Expected: 无 error/crash/stack。

- [ ] **Step 5: 提交**

```bash
git add scripts/main.gd scenes/main.tscn project.godot
git commit -m "feat: Main 场景串联 World + DebugHUD，切为默认主场景"
```

---

## Task 11: Smoke integration test

**Files:**
- Create: `tests/integration/test_smoke.gd`

跑一段时间确保不崩溃 + 玩家受重力下落到地表。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_smoke.gd`:
```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_main_scene_loads_without_crash():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	assert_not_null(main, "Main 节点存在")
	var world = main.get_node_or_null("World")
	assert_not_null(world, "World 子节点存在")


func test_player_spawns_and_falls_to_ground():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player, "玩家被实例化")
	var initial_y = player.global_position.y
	# 跑 60 帧 (~1 秒)；玩家应该落地或保持稳定
	await wait_frames(60)
	# 验证：玩家位置仍在合理范围 (不掉出世界)
	assert_lt(player.global_position.y, 256 * 16.0, "玩家未掉出世界底部")
	assert_gt(player.global_position.y, initial_y - 100.0, "玩家未飞天 (排除奇怪动量)")


func test_sky_light_grid_initialized():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	# 顶部 (0,0) 应被天光直射
	assert_true(SkyLightGrid.is_sky_exposed(0, 0), "世界顶部有天光")
	# 底部 (0, 250) 应该被遮挡
	assert_false(SkyLightGrid.is_sky_exposed(0, 250), "世界底部无天光")
```

- [ ] **Step 2: 跑测试**

Run:
```bash
rm -rf .godot && godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -25
```

Expected: 全部测试通过 (≥ 23 个：sanity 2 + tile_data 6 + world_generator 7 + sky_light 5 + smoke 3)。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_smoke.gd
git commit -m "test(integration): Main 场景冷启动 + 玩家下落 + 天光初始化"
```

---

## Task 12: 手动验收 + P1 完成 tag

**Files:** (无新文件)

- [ ] **Step 1: 用户在带显示的 Godot 里手动跑一次**

让用户在自己电脑跑：
```bash
cd /workspace/teilaruia
godot
```

**验收清单（让用户逐项确认）：**
- [ ] 启动 5 秒内进入游戏
- [ ] 看到地表（有草/沙斑块）+ 地下泥土/石头分层 + 底部基岩
- [ ] 按 A/D 或左右键能左右走，玩家朝向跟着翻转
- [ ] 按空格/W/上键能跳
- [ ] 走到地面边缘掉下去会触发重力下落
- [ ] 撞墙能停住，不会穿模
- [ ] 走路时角色播放 walk 动画，停下播放 idle 动画
- [ ] 跳跃中播 jump → 下落中播 fall
- [ ] 摄像机平滑跟随玩家
- [ ] 左上角 Debug HUD 显示 FPS / Pos / Tile / Dark
- [ ] F3 能切换 HUD 显隐
- [ ] 持续游玩 5 分钟无崩溃，FPS 稳定 ≥ 60

- [ ] **Step 2: 打 tag 标记 P1 完成**

Run:
```bash
git tag -a demo-p1-foundation -m "Demo P1 (Foundation) 完成：地形/玩家/相机/HUD/天光数据"
git log --oneline | head -10
```

- [ ] **Step 3: 在 spec 里记录 P1 完成**

修改 `/workspace/teilaruia/docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md` 末尾 §17 加：

```markdown
## 18. 实施进度

- ✅ P1 Foundation — `tag demo-p1-foundation` — 2026-05-XX (实际完成日)
- ⏳ P2 Items & Interaction — 待开始
- ⏳ P3 Crafting & UI — 待开始
- ⏳ P4 Content & Persistence — 待开始
```

Commit:
```bash
git add docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md
git commit -m "docs: 标记 P1 Foundation 完成"
```

---

## Spec Coverage Check (P1 范围内)

对应 spec §3 范围，P1 覆盖：
- §3.1.A 方块 — TileData 注册 + TileSet 生成 ✅
- §3.1.J 暗 — SkyLightGrid 数据层 ✅（渲染推迟）
- §3.1.H 复活 — 出生点字段已有 ✅（死亡逻辑 → P4）
- §13 InputMap — move/jump/toggle_debug 已加 ✅（其他动作 → 各对应 P）

P1 **不**覆盖（按计划推迟）：
- 挖/放（P2）
- 物品/掉落（P2）
- 背包/合成（P3）
- 史莱姆/村民/村庄/门（P4）
- 存档（P4）
- 音效/正式美术（M5）

---

## 验收门禁

每个 task 完成后必须：
1. 跑 GUT 全测试，无 fail
2. 跑 `godot --headless --quit` 无 error log
3. `git status` 干净，所有变更已 commit

P1 完成的最终判定：用户手动跑通 Task 12 验收清单全部 ✅。

