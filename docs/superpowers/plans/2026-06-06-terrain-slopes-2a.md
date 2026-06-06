# 地形斜坡 Phase 2a (地表草斜坡) 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给地表草地的"差 1 格台阶"自动铺 45° 斜砖, 玩家能顺着草斜坡走上去 / 能挖掉它, 跑通整条斜坡链路。

**Architecture:** 斜砖 = 2 个独立 tile id (草·升右◢ / 草·升左◣), 实心单格, **不进 EdgeTemplates.FAMILY_OF** (天然不被 autotile 刷)。三角形碰撞 + 玩家 `move_and_slide` (只需把 `floor_max_angle` 调到 ~51° 让 45° 斜面算地面)。生成器后处理扫相邻列高差铺斜砖。本期只草地 + 只 chunk 内相邻对 (跨 chunk 缝留 2b)。

**Tech Stack:** Godot 4.3 GDScript, TileMapLayer 多边形碰撞, GUT 测试。

设计依据: `docs/superpowers/specs/2026-06-06-terrain-slopes-design.md`

---

## 关键约定 (执行前必读)

- **空闲 tile id**: 当前最大 91 (WATER_L7)。本计划用 **92 = GRASS_SLOPE_R, 93 = GRASS_SLOPE_L**。
  ⚠️ 执行时先 `grep -oE "const [A-Z_0-9]+ := [0-9]+" scripts/world/tile_data.gd | sort -t= -k2 -n | tail` 确认 92/93 仍空闲
  (并发 session 可能已占用); 被占就顺延, 全计划同步改。
- **坐标系**: tile 12×12, 碰撞用 ±6。chunk.tiles 索引 `c.tiles[local_x][y]`, y 越小越高 (地表 y 小)。
- **斜砖朝向定义**:
  - `GRASS_SLOPE_R` ◢ = 实心在**右下**三角 (升向右), 斜边 (-6,6)→(6,-6)。
  - `GRASS_SLOPE_L` ◣ = 实心在**左下**三角 (升向左), 斜边 (6,6)→(-6,-6)。
- 每个新 tile 必须六处登记 (见 spec 登记清单)。本计划逐 task 覆盖。
- 提交只 `git add <精确路径>`, 禁用 `-am`/`-A`/`.` (仓库有并发 WIP, 见 memory)。

---

## Task 1: 加 2 个斜砖 tile id + 属性 + is_slope 助手 (tile_data.gd)

**Files:**
- Modify: `scripts/world/tile_data.gd`
- Test: `tests/unit/test_slope_tiles.gd` (Create)

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_slope_tiles.gd`:
```gdscript
# 斜砖 tile 定义 + 属性 + is_slope 助手.
extends GutTest

func test_slope_ids_defined() -> void:
	assert_eq(Tiles.GRASS_SLOPE_R, 92, "GRASS_SLOPE_R = 92")
	assert_eq(Tiles.GRASS_SLOPE_L, 93, "GRASS_SLOPE_L = 93")

func test_slope_is_solid_and_mineable() -> void:
	for s in [Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L]:
		assert_true(Tiles.is_solid(s), "斜砖实心 (撑住玩家)")
		assert_true(Tiles.is_mineable(s), "斜砖可挖")

func test_is_slope_helper() -> void:
	assert_true(Tiles.is_slope(Tiles.GRASS_SLOPE_R), "◢ 是斜砖")
	assert_true(Tiles.is_slope(Tiles.GRASS_SLOPE_L), "◣ 是斜砖")
	assert_false(Tiles.is_slope(Tiles.GRASS), "普通草不是斜砖")
	assert_false(Tiles.is_slope(Tiles.AIR), "空气不是斜砖")

func test_slope_drops_dirt() -> void:
	# 挖斜砖掉 dirt (跟草地一致), 用石/无所谓徒手可挖
	var props = Tiles.get_props(Tiles.GRASS_SLOPE_R)
	assert_eq(props["drops"][0][0], "dirt", "斜砖掉 dirt")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_slope_tiles.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Failed|Passing"`
Expected: FAIL (`Invalid access to 'GRASS_SLOPE_R'` / `is_slope` 未定义)。

注: 若报 `get_props` 不存在, 改用 `Tiles._PROPS[Tiles.GRASS_SLOPE_R]` 或现有等价取属性 API (先 `grep "func get_props\|_PROPS" scripts/world/tile_data.gd` 确认)。

- [ ] **Step 3: 加 const + _PROPS + is_slope**

在 `scripts/world/tile_data.gd` 的 tile id 常量区末尾 (BED_RIGHT/WATER_L7 附近) 加:
```gdscript
const GRASS_SLOPE_R := 92    # 草斜坡·升向右 ◢ (实心右下三角). 地表自动削坡, 玩家走上去
const GRASS_SLOPE_L := 93    # 草斜坡·升向左 ◣ (实心左下三角)
```

在 `_PROPS` 字典里 (BED_RIGHT 条目附近) 加:
```gdscript
	GRASS_SLOPE_R: {
		# 草斜砖: 实心(撑住玩家走斜面) + 可挖. 掉 dirt 跟草地一致. 不可玩家放置 (无 item 映射).
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	GRASS_SLOPE_L: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
```

在文件的助手函数区 (`func is_solid` 附近) 加:
```gdscript
# 是不是斜砖 (45° 斜坡). tileset 加三角碰撞 / 生成器铺坡 / autotile 排除 都用它.
func is_slope(tile_id: int) -> bool:
	return tile_id == GRASS_SLOPE_R or tile_id == GRASS_SLOPE_L
```

- [ ] **Step 4: 跑测试确认通过** (`get_props` 测试若 API 不符已在 Step1 调整)

Run: 同 Step 2。
Expected: PASS (4 测试)。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/tile_data.gd tests/unit/test_slope_tiles.gd
git commit -m "feat(slope): 加草斜砖 tile id 92/93 + 属性 + is_slope 助手"
```

---

## Task 2: 斜砖美术 pattern + 贴图构建 (blocks_art.gd + art_cache.gd)

**Files:**
- Modify: `scripts/art/blocks_art.gd` (加 const + _PATTERN_MAP)
- Modify: `scripts/autoload/art_cache.gd` (加进 _build_blocks 列表)
- Test: `tests/integration/test_slope_art.gd` (Create)

- [ ] **Step 1: 写失败测试** (验证斜砖贴图形状: ◢ 左上透明、右下不透明)

Create `tests/integration/test_slope_art.gd`:
```gdscript
# 斜砖贴图形状: ◢ 左上角透明(被削掉) + 右下角实心; ◣ 镜像.
extends GutTest
const BlocksArt = preload("res://scripts/art/blocks_art.gd")

func test_slope_r_shape() -> void:
	var img: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_R).get_image()
	var w := img.get_width()
	# 左上角 (被削掉的三角) 透明; 右下角 实心
	assert_lt(img.get_pixel(1, 1).a, 0.5, "◢ 左上角该透明")
	assert_gt(img.get_pixel(w - 2, w - 2).a, 0.5, "◢ 右下角该实心")

func test_slope_l_shape() -> void:
	var img: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_L).get_image()
	var w := img.get_width()
	assert_lt(img.get_pixel(w - 2, 1).a, 0.5, "◣ 右上角该透明")
	assert_gt(img.get_pixel(1, w - 2).a, 0.5, "◣ 左下角该实心")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_slope_art.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Failed|Passing|Invalid"`
Expected: FAIL (`GRASS_SLOPE_R` 在 BlocksArt 未定义)。

- [ ] **Step 3: 加 BlocksArt const + pattern + _PATTERN_MAP**

在 `scripts/art/blocks_art.gd` 常量区加 (跟 tile_data 同号):
```gdscript
const GRASS_SLOPE_R := 92    # 草斜坡·升向右 ◢
const GRASS_SLOPE_L := 93    # 草斜坡·升向左 ◣
```

加两个 pattern (放在 _PLANT_GRASS 之类装饰 pattern 附近)。用 _P_GRASS 调色板
(g=暖绿基, m=中暖绿, d=暖泥, D=泥阴影, k=小石子):
```gdscript
# 草斜砖 ◢ 升向右: 左上透明(.), 沿对角一条 2px 草带(g 暖绿基/m 中暖绿), 右下泥身(d).
# 每行 = (15-y) 个 '.' + "gm" + 其余 'd' (y=0 行只有 1 格 grass). 泥身先纯 d, 速度斑点留 2c.
const _GRASS_SLOPE_R := [
	"...............g",
	"..............gm",
	".............gmd",
	"............gmdd",
	"...........gmddd",
	"..........gmdddd",
	".........gmddddd",
	"........gmdddddd",
	".......gmddddddd",
	"......gmdddddddd",
	".....gmddddddddd",
	"....gmdddddddddd",
	"...gmddddddddddd",
	"..gmdddddddddddd",
	".gmddddddddddddd",
	"gmdddddddddddddd",
]
# 草斜砖 ◣ 升向左: 右上透明, 对角草带在右, 左下泥身. = _GRASS_SLOPE_R 每行水平镜像.
# 每行 = (y-1) 个 'd' + "mg" + (15-y) 个 '.' (y=0 行只有 1 格 grass).
const _GRASS_SLOPE_L := [
	"g...............",
	"mg..............",
	"dmg.............",
	"ddmg............",
	"dddmg...........",
	"ddddmg..........",
	"dddddmg.........",
	"ddddddmg........",
	"dddddddmg.......",
	"ddddddddmg......",
	"dddddddddmg.....",
	"ddddddddddmg....",
	"dddddddddddmg...",
	"ddddddddddddmg..",
	"dddddddddddddmg.",
	"ddddddddddddddmg",
]
```
(两块都是干净精确的: R 左上空/右下实, L 右上空/左下实, Task2 Step1 的角落断言就是验这个。)

加进 `_PATTERN_MAP` (GRASS 条目附近):
```gdscript
	GRASS_SLOPE_R: [_GRASS_SLOPE_R, _P_GRASS],
	GRASS_SLOPE_L: [_GRASS_SLOPE_L, _P_GRASS],
```

- [ ] **Step 4: 加进 art_cache _build_blocks 列表**

在 `scripts/autoload/art_cache.gd` `_build_blocks()` 的 tile id 列表里 (BED/BED_RIGHT 那行附近) 加:
```gdscript
		BlocksArt.GRASS_SLOPE_R, BlocksArt.GRASS_SLOPE_L,
```

- [ ] **Step 5: 跑测试确认通过 (顺手验左右镜像)**

Run: 同 Step 2。
Expected: PASS (2 测试)。若 ◣ 角落断言失败, 说明 L 不是 R 的正确镜像, 修 `_GRASS_SLOPE_L`。

- [ ] **Step 6: 提交**

```bash
git add scripts/art/blocks_art.gd scripts/autoload/art_cache.gd tests/integration/test_slope_art.gd
git commit -m "feat(slope): 草斜砖美术 pattern ◢◣ + 接入 art_cache 构建"
```

---

## Task 3: tileset 注册斜砖 + 三角形碰撞 (tileset_builder.gd)

**Files:**
- Modify: `scripts/world/tileset_builder.gd`
- Test: `tests/integration/test_slope_collision.gd` (Create)

- [ ] **Step 1: 写失败测试** (斜砖进了 tileset + 碰撞是三角形 3 点不是方形 4 点)

Create `tests/integration/test_slope_collision.gd`:
```gdscript
# 斜砖在 tileset 里有单格 + 三角碰撞 (3 顶点, 区别于方块的 4 顶点).
extends GutTest
const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")

func test_slope_has_triangle_collision() -> void:
	var ts: TileSet = TileSetBuilder.build()
	for sid in [Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L]:
		var src_idx := ts.get_source_id(ts.get_source_count() - 1)  # 占位, 下面用 has_source
		assert_true(_source_for(ts, sid) != null, "斜砖 %d 该有 source" % sid)
		var src: TileSetAtlasSource = _source_for(ts, sid)
		var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
		assert_eq(td.get_collision_polygons_count(0), 1, "斜砖 1 个碰撞多边形")
		assert_eq(td.get_collision_polygon_points(0, 0).size(), 3, "三角碰撞 = 3 顶点")

func _source_for(ts: TileSet, sid: int) -> TileSetAtlasSource:
	# 本项目注册时 source_id == tile_id (见 tileset_builder add_source(source, tile_id))
	if not ts.has_source(sid):
		return null
	return ts.get_source(sid)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_slope_collision.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Failed|Passing"`
Expected: FAIL (斜砖没注册 → has_source false → null)。

- [ ] **Step 3: 把斜砖加进 tile_ids 列表 + 加三角碰撞分支**

在 `scripts/world/tileset_builder.gd` 的 `tile_ids` 数组里 (`Tiles.BED, Tiles.BED_RIGHT,` 那行附近) 加:
```gdscript
		Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L,
```

在非 autotile 单格分支里 (当前 `if Tiles.is_solid(tile_id):` 给方形碰撞 `(-6,-6),(6,-6),(6,6),(-6,6)` 那段, 约 L99-104) 改成先判斜砖给三角:
```gdscript
			else:
				# 非 autotile: 单 cell
				source.create_tile(Vector2i.ZERO)
				if Tiles.is_slope(tile_id):
					# 斜砖: 三角形碰撞 (实心半边). ◢ 右下三角 / ◣ 左下三角.
					var spts: PackedVector2Array
					if tile_id == Tiles.GRASS_SLOPE_R:
						spts = PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(6, -6)])
					else:  # GRASS_SLOPE_L ◣
						spts = PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(-6, -6)])
					var sprops = source.get_tile_data(Vector2i.ZERO, 0)
					sprops.add_collision_polygon(0)
					sprops.set_collision_polygon_points(0, 0, spts)
				elif Tiles.is_solid(tile_id):
					var props = source.get_tile_data(Vector2i.ZERO, 0)
					props.add_collision_polygon(0)
					props.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6),
					]))
				elif is_door:
```
(即: 在原 `if Tiles.is_solid` 前插入 `if Tiles.is_slope ... elif Tiles.is_solid ...`。保持后面 `elif is_door` / `elif WOOD_PLATFORM` / 水动画不变。)

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS (三角碰撞 3 顶点)。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/tileset_builder.gd tests/integration/test_slope_collision.gd
git commit -m "feat(slope): tileset 注册草斜砖 + 三角形碰撞多边形"
```

---

## Task 4: 小地图颜色 (minimap_view.gd)

**Files:**
- Modify: `scripts/ui/minimap_view.gd`

- [ ] **Step 1: 加斜砖小地图色 (跟 GRASS 同色)**

在 `scripts/ui/minimap_view.gd` 的 `_TILE_COLORS` 字典里 (GRASS 附近) 加:
```gdscript
	Tiles.GRASS_SLOPE_R:  Color8(110, 180, 70),   # 草斜坡: 跟草同色
	Tiles.GRASS_SLOPE_L:  Color8(110, 180, 70),
```
(GRASS 实际色值执行时对齐 `_TILE_COLORS[Tiles.GRASS]`, 直接复制那个值。)

- [ ] **Step 2: 冒烟 (无专门测试, 跑现有 minimap/启动测试不崩即可)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_bed_sleep.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Passing|Failing"`
Expected: 2/2 PASS。

- [ ] **Step 3: 提交**

```bash
git add scripts/ui/minimap_view.gd
git commit -m "feat(slope): 草斜砖小地图色 (同草色)"
```

---

## Task 5: 玩家走斜坡 — floor_max_angle (player_controller.gd)

**Files:**
- Modify: `scripts/player/player_controller.gd:81` (`_ready`)

- [ ] **Step 1: 在 _ready 设 floor_max_angle**

在 `scripts/player/player_controller.gd` 的 `func _ready()` 体内加 (默认 0.785=45° 会把 45° 斜面当墙):
```gdscript
	# 斜坡: 默认 floor_max_angle=45° 正好卡边界, 45° 斜砖会被当墙. 调到 ~51° 让斜面算地面能走上去.
	floor_max_angle = 0.90
```

- [ ] **Step 2: 冒烟 (启动不崩 + 平地走路不变)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_player_jump.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Passing|Failing"`
Expected: 跟改前一致 (注: test_player_jump 有 1 个**改前就 fail** 的"站到方块上"用例, 见执行说明; 只要 fail 数不增即可)。

- [ ] **Step 3: 提交**

```bash
git add scripts/player/player_controller.gd
git commit -m "feat(slope): 玩家 floor_max_angle 45°→51° 让 45° 斜面算地面可走"
```

---

## Task 6: 生成器铺草斜坡后处理 (world_generator.gd)

**Files:**
- Modify: `scripts/world/world_generator.gd` (加 `_place_slopes_chunk` + 在 generate_chunk 调用)
- Test: `tests/integration/test_slope_gen.gd` (Create)

- [ ] **Step 1: 写失败测试** (造 1 格台阶 → 后处理在拐角放对朝向斜砖)

Create `tests/integration/test_slope_gen.gd`:
```gdscript
# 生成器后处理: 1 格台阶地表 → 拐角铺对应朝向草斜砖.
extends GutTest
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

class FakeChunk:
	var tiles: Array
	func _init(width: int, height: int):
		tiles = []
		for _x in width:
			var col := []
			for _y in height:
				col.append(Tiles.AIR)
			tiles.append(col)

# 造一列: 顶 (surf) GRASS, 下面 DIRT 填到底
func _fill_col(c, lx: int, surf: int, height: int) -> void:
	c.tiles[lx][surf] = Tiles.GRASS
	for y in range(surf + 1, height):
		c.tiles[lx][y] = Tiles.DIRT

func test_step_up_right_places_slope_r() -> void:
	var H := 40
	var c = FakeChunk.new(4, H)
	var heights := {}
	# 列 0 地表 y=20, 列 1 地表 y=19 (高 1 格 → 向右升) , 列 2/3 同 19
	_fill_col(c, 0, 20, H); heights[0] = 20
	_fill_col(c, 1, 19, H); heights[1] = 19
	_fill_col(c, 2, 19, H); heights[2] = 19
	_fill_col(c, 3, 19, H); heights[3] = 19
	WorldGenerator._place_slopes_chunk(c, heights, 0, 4, H)
	# ◢ 应放在低列(0)地表上方那格 (0, 19)
	assert_eq(c.tiles[0][19], Tiles.GRASS_SLOPE_R, "向右升 → ◢ 放 (0,19)")

func test_step_up_left_places_slope_l() -> void:
	var H := 40
	var c = FakeChunk.new(4, H)
	var heights := {}
	# 列 0/1 地表 y=19, 列 2 地表 y=20 (低 1 格 → 向左升回 19)
	_fill_col(c, 0, 19, H); heights[0] = 19
	_fill_col(c, 1, 19, H); heights[1] = 19
	_fill_col(c, 2, 20, H); heights[2] = 20
	_fill_col(c, 3, 20, H); heights[3] = 20
	WorldGenerator._place_slopes_chunk(c, heights, 0, 4, H)
	# 列1(h=19) vs 列2(h=20): h1=h0+1 → ◣ 放低列(2)地表上方那格 (2,19)
	assert_eq(c.tiles[2][19], Tiles.GRASS_SLOPE_L, "向左升 → ◣ 放 (2,19)")

func test_flat_no_slope() -> void:
	var H := 40
	var c = FakeChunk.new(3, H)
	var heights := {}
	for x in 3:
		_fill_col(c, x, 19, H); heights[x] = 19
	WorldGenerator._place_slopes_chunk(c, heights, 0, 3, H)
	for x in 3:
		assert_ne(c.tiles[x][18], Tiles.GRASS_SLOPE_R, "平地不铺坡")
		assert_ne(c.tiles[x][18], Tiles.GRASS_SLOPE_L, "平地不铺坡")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_slope_gen.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Failed|Passing|Invalid"`
Expected: FAIL (`_place_slopes_chunk` 未定义)。

- [ ] **Step 3: 写 _place_slopes_chunk + 在 generate_chunk 调用**

在 `scripts/world/world_generator.gd` 加函数 (放 `_place_grass_decor_chunk` 附近):
```gdscript
# 草地表 1 格台阶 → 拐角铺草斜砖 (Phase 2a). 只本 chunk 内相邻对 (跨 chunk 缝留 2b).
# h 越小越高. h1=h0-1 (向右升) → ◢ 放低列(x)上方; h1=h0+1 (向左升) → ◣ 放低列(x+1)上方.
static func _place_slopes_chunk(c, chunk_heights: Dictionary,
		chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start: int = chunk_x * chunk_width
	for local_x in range(chunk_width - 1):
		var wx: int = chunk_start + local_x
		var h0: int = chunk_heights.get(wx, -1)
		var h1: int = chunk_heights.get(wx + 1, -1)
		if h0 < 2 or h1 < 2:
			continue
		# 只草地表削坡 (两列顶都是 GRASS)
		if c.tiles[local_x][h0] != Tiles.GRASS or c.tiles[local_x + 1][h1] != Tiles.GRASS:
			continue
		if h1 == h0 - 1:
			# 向右升: ◢ 放低列 (local_x) 地表上方那格 (y = h1 = h0-1), 仅当是空气
			if c.tiles[local_x][h1] == Tiles.AIR:
				c.tiles[local_x][h1] = Tiles.GRASS_SLOPE_R
		elif h1 == h0 + 1:
			# 向左升: ◣ 放低列 (local_x+1) 地表上方那格 (y = h0 = h1-1)
			if c.tiles[local_x + 1][h0] == Tiles.AIR:
				c.tiles[local_x + 1][h0] = Tiles.GRASS_SLOPE_L
```

在 `generate_chunk` 里, **装饰草之前** (`_place_grass_decor_chunk` 调用行前) 加:
```gdscript
	# 草斜坡: 1 格台阶拐角铺斜砖 (在装饰草前, 装饰草检测 AIR 不会铺到斜砖上)
	_place_slopes_chunk(c, chunk_heights, chunk_x, chunk_width, height)
```

- [ ] **Step 4: 跑测试确认通过**

Run: 同 Step 2。Expected: PASS (3 测试)。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/world_generator.gd tests/integration/test_slope_gen.gd
git commit -m "feat(slope): 生成器后处理 — 草地 1 格台阶拐角铺草斜砖"
```

---

## Task 7: 端到端 — 玩家走上草斜坡 + 挖斜砖掉 dirt (集成)

**Files:**
- Test: `tests/integration/test_slope_walk.gd` (Create)

- [ ] **Step 1: 写测试** (启动游戏, 手搭一段斜坡, 玩家朝坡走 y 上升; 挖斜砖变 AIR)

Create `tests/integration/test_slope_walk.gd`:
```gdscript
# 端到端: 玩家能走上草斜坡 (move_and_slide + floor_max_angle); 挖斜砖掉 dirt 变 AIR.
extends GutTest
const MainScene = preload("res://scenes/main.tscn")
const TILE := 12.0

func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main

# 手搭: 在玩家脚下造一段 "平地 → ◢ → 高 1 格平地", 放玩家在低平地, 按右, 看 y 是否上升.
func test_player_walks_up_slope() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var pt: Vector2i = player.get_node("PlayerAction").player_tile()
	var bx: int = pt.x
	var gy: int = pt.y + 1   # 玩家脚下那行作地面
	# 低平地 (bx..bx+1) 地面 gy; 斜砖 ◢ 在 (bx+2, gy-1); 高平地 (bx+3..) 地面 gy-1
	for dx in range(0, 2):
		world._set_tile(bx + dx, gy, Tiles.GRASS)
		world._set_tile(bx + dx, gy - 1, Tiles.AIR)
	world._set_tile(bx + 2, gy - 1, Tiles.GRASS_SLOPE_R)
	world._set_tile(bx + 2, gy, Tiles.GRASS)
	for dx in range(3, 7):
		world._set_tile(bx + dx, gy - 1, Tiles.GRASS)
		world._set_tile(bx + dx, gy - 2, Tiles.AIR)
	# 玩家落到低平地站稳
	player.global_position = Vector2((bx + 0.5) * TILE, (gy - 1) * TILE)
	await wait_frames(10)
	var y_before: float = player.global_position.y
	# 持续按右 ~40 帧 (用输入注入; action 名执行时按工程实际确认)
	for _i in range(40):
		Input.action_press("move_right")
		await wait_frames(1)
	Input.action_release("move_right")
	var y_after: float = player.global_position.y
	assert_lt(y_after, y_before - TILE * 0.5, "玩家该顺斜坡走上去 (y 上升至少半格)")

func test_mine_slope_drops_dirt_and_clears() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var player = world.get_player()
	var action = player.get_node("PlayerAction")
	var inv = player.get_node("PlayerInventory")
	inv.pickup("wood_pickaxe", 1); inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var sx: int = pt.x + 2
	var sy: int = pt.y
	world._set_tile(sx, sy, Tiles.GRASS_SLOPE_R)
	world._set_tile(sx, sy + 1, Tiles.DIRT)
	action.aim_override = Vector2i(sx, sy)
	action.primary_override = true
	for _i in range(60):
		await wait_frames(1)
		if terrain.get_cell_source_id(Vector2i(sx, sy)) == -1:
			break
	action.primary_override = false
	assert_eq(terrain.get_cell_source_id(Vector2i(sx, sy)), -1, "斜砖挖掉变 AIR")
```

注: `move_override` / 输入注入方式执行时按 player_controller 实际接口对齐 (先 `grep "move_override\|Input.is_action\|move_right" scripts/player/player_controller.gd`)。优先用 `Input.action_press("move_right")` (上面已用); 若工程用别的 action 名, 换成实际名。`aim_override`/`primary_override` 已被 test_bed_2tile 验证可用。

- [ ] **Step 2: 跑测试**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_slope_walk.gd -gexit 2>&1 | grep -v libfontconfig | grep -E "Failed|Passing|Failing"`
Expected: 起初可能 FAIL (走路手感 / 输入名)。调到 PASS:
- 若玩家没走上去: 确认 floor_max_angle 已设 (Task 5); 试 `floor_snap_length` 加大 (player_controller 里) 让贴坡不弹起。
- 若输入名不对: 用实际 move action 名。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_slope_walk.gd
git commit -m "test(slope): 端到端 — 玩家走上草斜坡 + 挖斜砖掉 dirt"
```

---

## Task 8: 视觉验收 (截图)

**Files:**
- Create (临时): `tools/dump_slope.gd` (验收后删)

- [ ] **Step 1: 写截图脚本** (合成一段台阶地形 + 斜砖, 放大存 PNG)

Create `tools/dump_slope.gd`:
```gdscript
# 一次性: 合成 "平地→上坡→平地" 一段, 看草斜砖接得顺不顺. 看完删.
extends SceneTree
func _initialize() -> void:
	const BlocksArt = preload("res://scripts/art/blocks_art.gd")
	var grass: Image = BlocksArt.get_texture(BlocksArt.GRASS).get_image()
	var dirt: Image = BlocksArt.get_texture(BlocksArt.DIRT).get_image()
	var sr: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_R).get_image()
	var sl: Image = BlocksArt.get_texture(BlocksArt.GRASS_SLOPE_L).get_image()
	var T := 16; var cols := 12; var rows := 5
	var canvas := Image.create(cols * T, rows * T, false, Image.FORMAT_RGBA8)
	canvas.fill(Color8(135, 180, 215))
	# 地表行: 列0-3 在 row2; ◢ 在(4,row1); 列5-7 在 row1(高1); ◣ 在(8,row2); 列9-11 row2
	var surf := [2,2,2,2, 1,1,1,1, 2,2,2,2]   # 每列地表 row
	for cx in cols:
		var sy = surf[cx]
		_blit(canvas, grass, cx*T, sy*T)
		for ry in range(sy+1, rows): _blit(canvas, dirt, cx*T, ry*T)
	_blit(canvas, sr, 4*T, 1*T)   # 上坡口
	_blit(canvas, sl, 8*T, 1*T)   # 下坡口
	var s := 6
	var out := Image.create(cols*T*s, rows*T*s, false, Image.FORMAT_RGBA8)
	for y in canvas.get_height():
		for x in canvas.get_width():
			var col := canvas.get_pixel(x,y)
			for dy in s:
				for dx in s: out.set_pixel(x*s+dx, y*s+dy, col)
	out.save_png("/tmp/slope_preview.png")
	print(">>> /tmp/slope_preview.png")
	quit()
func _blit(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x,y)
			if c.a > 0.01: dst.set_pixel(ox+x, oy+y, c)
```

- [ ] **Step 2: 渲染 + 人眼看**

Run: `godot --headless -s tools/dump_slope.gd 2>&1 | grep -v libfontconfig | grep ">>>"`
然后 Read `/tmp/slope_preview.png`。检查: 上坡口 ◢ 草面从低平地顺接到高平地、下坡口 ◣ 顺接, 没有悬空/缺口/朝向反。若朝向反, 对调 Task6 的 ◢/◣ 或 Task3 碰撞三角。

- [ ] **Step 3: 删临时脚本**

```bash
rm -f tools/dump_slope.gd; rmdir tools 2>/dev/null
```
(不提交 tools/ 临时脚本。)

---

## 收尾验收 (全 Task 完成后)

- [ ] 跑全 `tests/unit` + `tests/integration` 一遍, 确认新增全绿 + 没把别的测试搞红 (除已知 pre-existing: 牛爬台阶 / 地表悬空水 / 玩家站方块, 这 3 个跟斜坡无关)。
- [ ] `git push origin main` (先 `git fetch` 看 origin 有没有新 commit, 有就 `git merge origin/main --no-edit` 再 push; 别动工作树里别人的 WIP 文件)。
- [ ] 给用户 3-5 行大白话报告 + 截图描述 + 累计测试数。
- [ ] 网页部署后让用户试: 找个小山坡看是不是斜的、走上去顺不顺。

## 不在 2a 范围 (留 2b/2c)
跨 chunk 缝斜坡 / 泥沙石深石斜砖 / 洞顶 CEIL 斜砖 / 地下洞穴削坡 / 陡坎(差≥2)多段坡 / 斜边高光精修 / 程序遮罩生成贴图 (2a 手画 2 块够了)。
