# 空岛群系 · 第 1 步实现计划（地形 + 云块 + 宝藏）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在天空层生成飘着的草地浮岛（云块底 + 草顶 + 小水池 + 树 + 钻石宝箱），数量按世界大小缩放，并新增可挖可放的「云块」方块。

**Architecture:** 完全复用现有金字塔的"选 chunk → 在 chunk 中部盖结构 → 记 treasure_spots"套路。新增一个 `CLOUD` tile（走现有 tile 登记流程）+ `_place_sky_island_chunk` 生成函数，插在 `generate_chunk` 的树木之后、背景墙之前。单岛装进一个 chunk（宽 ≤ 64，居中），不跨 chunk。

**Tech Stack:** Godot 4.3 + GDScript，GUT 单元测试。无 GUI，全靠测试验收。

**对应 spec:** `docs/superpowers/specs/2026-06-02-sky-island-biome-design.md`（第 1 步）。第 2 步（哈比鸟）/第 3 步（云靴）单独出计划。

---

## 文件清单

| 文件 | 改动 |
|---|---|
| `scripts/world/tile_data.gd` | 加 `CLOUD := 75` 常量 + `_PROPS[CLOUD]` 属性 |
| `scripts/art/blocks_art.gd` | 加 `CLOUD := 75` 常量 + `_P_CLOUD` 调色板 + `_CLOUD` 图案 + 注册进 `_PATTERN_MAP` |
| `scripts/autoload/art_cache.gd` | `tile_ids` 列表加 `BlocksArt.CLOUD` + `_ITEM_TO_TILE` 加 `"cloud"` |
| `scripts/world/tileset_builder.gd` | `tile_ids` 数组加 `Tiles.CLOUD` |
| `scripts/items/item_db.gd` | `_DEFS` 加 `"cloud"` |
| `scripts/ui/crafting_panel.gd` | `_ZH_NAMES` 加 `"cloud": "云块"` |
| `scripts/autoload/game_settings.gd` | 加 `skyisland_count_range()` |
| `scripts/world/world_generator.gd` | 加空岛常量 + `_sky_island_chunks` + `_place_sky_island_chunk` + `_stamp_sky_tree` + 在 `generate_chunk` 里调用 |
| `tests/unit/test_cloud_tile.gd` | 新建：CLOUD tile/item 属性测试 |
| `tests/unit/test_sky_island.gd` | 新建：空岛生成测试 |

**⚠️ 跑测试前置（新 clone / 改了 class_name 时）：** 先 `godot --headless --editor --quit` 建 class_name 索引，否则报 `Identifier "GutUtils" not declared`。本计划没新增 class_name，但保险起见第一次跑前执行一次。`libfontconfig.so.1` 警告忽略。

---

## Task 1: 注册「云块」CLOUD tile（属性 + 物品 + 中文名）

**Files:**
- Modify: `scripts/world/tile_data.gd`（常量区尾 line ~74；`_PROPS` 里 `SANDSTONE` 条目附近）
- Modify: `scripts/items/item_db.gd`（`_DEFS` 里 `"sandstone"` 行 ~84 附近）
- Modify: `scripts/ui/crafting_panel.gd`（`_ZH_NAMES` 里 `"sandstone"` 行 ~486 附近）
- Test: `tests/unit/test_cloud_tile.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_cloud_tile.gd`：

```gdscript
extends GutTest

# 云块: 实心可挖, 木镐就能挖, 掉 cloud 物品; cloud 物品能放回 CLOUD tile.
func test_cloud_tile_is_solid_mineable():
	assert_true(Tiles.is_solid(Tiles.CLOUD), "云块实心 (能站上去)")
	assert_true(Tiles.is_mineable(Tiles.CLOUD), "云块可挖")

func test_cloud_drops_cloud_item():
	# drops_for 权重 100 → cloud 必出 (dict: {item_id: count})
	var drops: Dictionary = Tiles.drops_for(Tiles.CLOUD, "")
	assert_true(drops.has("cloud"), "挖云块掉 cloud 物品")

func test_cloud_item_places_cloud_tile():
	var def = ItemDB.get_def("cloud")
	assert_not_null(def, "cloud 物品存在")
	assert_eq(def["placeable_tile_id"], Tiles.CLOUD, "cloud 物品放下去是 CLOUD tile")
```

> 已核对方法名：`tile_data.gd` 用 `is_solid` / `is_mineable` / `drops_for(tile_id, tool) -> Dictionary`；`item_db.gd` 用 `get_def(item_id) -> Variant`。

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cloud_tile.gd -gexit`
Expected: FAIL（`Tiles.CLOUD` 未定义 / `ItemDB.get_def("cloud")` 返回 null）

- [ ] **Step 3: 加 CLOUD tile 常量 + 属性**

`scripts/world/tile_data.gd`，在 `const COOKING_POT := 74` 那行后面加：

```gdscript
const CLOUD := 75           # 云块: 空岛岛体. 白软, 实心可站可挖可放, 无重力 (不像 SAND 会塌)
```

在 `_PROPS` 字典里（`SANDSTONE: {...}` 条目后面）加：

```gdscript
	CLOUD: {
		# 云块: 实心 (能站), 木镐就能挖, 掉 cloud 物品. 不是 SAND → 不受沙重力, 挖了上面不塌.
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["cloud", 100, 1, 1]],
	},
```

- [ ] **Step 4: 加 cloud 物品 + 中文名**

`scripts/items/item_db.gd`，在 `"sandstone": {...}` 行后面加：

```gdscript
	"cloud":              {"placeable_tile_id": Tiles.CLOUD,         "tool_kind": "",     "tool_tier": 0, "max_stack": 99},
```

`scripts/ui/crafting_panel.gd` 的 `_ZH_NAMES`，在 `"sandstone": "砂岩",` 行后面加：

```gdscript
	"cloud": "云块",
```

- [ ] **Step 5: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cloud_tile.gd -gexit`
Expected: PASS（3 个 test 全绿）

- [ ] **Step 6: 提交**

```bash
git add scripts/world/tile_data.gd scripts/items/item_db.gd scripts/ui/crafting_panel.gd tests/unit/test_cloud_tile.gd
git commit -m "feat(world): 加云块 CLOUD tile + cloud 物品 (空岛第1步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 云块美术（程序绘制白云块贴图）

**Files:**
- Modify: `scripts/art/blocks_art.gd`（常量镜像区 line ~15-45；调色板/图案区；`_PATTERN_MAP` 注册 dict line ~2100）
- Modify: `scripts/autoload/art_cache.gd`（`tile_ids` 列表 ~line 80-115；`_ITEM_TO_TILE` ~line 300）
- Test: 复用 `tests/unit/test_cloud_tile.gd` 加一条贴图测试

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_cloud_tile.gd` 末尾加：

```gdscript
func test_cloud_has_texture():
	var tex = BlocksArt.get_texture(Tiles.CLOUD)
	assert_not_null(tex, "云块有贴图")
	var img: Image = tex.get_image()
	assert_eq(img.get_width(), 16, "云块贴图 16 宽")
	assert_eq(img.get_height(), 16, "云块贴图 16 高")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cloud_tile.gd -gexit`
Expected: 新增的 `test_cloud_has_texture` FAIL（`get_texture` 拿不到 CLOUD 的图案，返回默认/报 key 缺失）

- [ ] **Step 3: 加 blocks_art 常量 + 调色板 + 图案 + 注册**

`scripts/art/blocks_art.gd` 常量镜像区（`const BED := 65` 附近、跟 Tiles 对齐）加：

```gdscript
const CLOUD := 75           # 云块 (白软, 顶亮底带浅灰蓝阴影)
```

调色板（放在 `_P_SANDSTONE` 附近）：

```gdscript
# 云块: 纯白主体 + 浅灰蓝阴影 (底部更暗), 圆鼓鼓的云团形状 (不是随机散点)
const _P_CLOUD := {
	"c": Color8(248, 250, 255),   # 云白 (主)
	"C": Color8(255, 255, 255),   # 纯白高光
	"s": Color8(212, 222, 240),   # 浅灰蓝阴影
	"d": Color8(186, 198, 222),   # 底部深阴影
}
```

图案（16 行 × 16 列，每行正好 16 字符）：

```gdscript
const _CLOUD := [
	"ccCCccccccCCcccc",
	"cCCCCcccCCCCccCc",
	"CCccccCCccccCCCc",
	"cccccccccccccccc",
	"ccccCcccccccCccc",
	"cccccccccccccccc",
	"sccccccccccccccs",
	"cccccccccccccccc",
	"ccccsccccccccCcc",
	"sccccccccccccccs",
	"ssccccccccccccss",
	"sssccccccccccsss",
	"dsssccccccccsssd",
	"ddsssscccsssssdd",
	"dddsssssssssdddd",
	"ddddssssssssdddd",
]
```

注册：在 `_PATTERN_MAP`（line ~2100 那个把 `SANDSTONE: [_SANDSTONE, _P_SANDSTONE]` 注册的 dict）里加：

```gdscript
	CLOUD: [_CLOUD, _P_CLOUD],                              # 云块 (白软, 空岛岛体)
```

- [ ] **Step 4: 接入 art_cache（库存图标 + 世界贴图）**

`scripts/autoload/art_cache.gd` 的 `tile_ids` 列表（跟 tileset_builder 并列那个，`BlocksArt.PLANT_GRASS,` 行附近）加：

```gdscript
		BlocksArt.CLOUD,
```

`_ITEM_TO_TILE`（line ~300，`"sandstone": BlocksArt.SANDSTONE,` 附近）加：

```gdscript
	"cloud": BlocksArt.CLOUD,
```

> CLOUD 不在 `EdgeTemplates.FAMILY_OF` 里，会走 art_cache 的 `else` 分支（单张 16×16 贴图，不做 autotile 边缘）—— 跟 SANDSTONE 一样，这是预期行为，云块不需要拼边。

- [ ] **Step 5: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_cloud_tile.gd -gexit`
Expected: PASS（含新 `test_cloud_has_texture`，共 4 个 test 全绿）

- [ ] **Step 6: 提交**

```bash
git add scripts/art/blocks_art.gd scripts/autoload/art_cache.gd tests/unit/test_cloud_tile.gd
git commit -m "feat(art): 云块程序绘制贴图 + 库存图标接入 (空岛第1步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 世界大小 → 空岛数量

**Files:**
- Modify: `scripts/autoload/game_settings.gd`（`mineshaft_count_range()` 行 ~46 后面）
- Test: `tests/unit/test_sky_island.gd`（新建，先放这一条）

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_sky_island.gd`：

```gdscript
extends GutTest

# 空岛数量按世界大小: 小 1 / 中 2-3 / 大 3-5 (跟金字塔同款)
func test_skyisland_count_range_per_size():
	var prev: int = GameSettings.current_world_size
	GameSettings.current_world_size = 0
	assert_eq(GameSettings.skyisland_count_range(), [1, 1], "小世界 1 个")
	GameSettings.current_world_size = 1
	assert_eq(GameSettings.skyisland_count_range(), [2, 3], "中世界 2-3 个")
	GameSettings.current_world_size = 2
	assert_eq(GameSettings.skyisland_count_range(), [3, 5], "大世界 3-5 个")
	GameSettings.current_world_size = prev   # 还原, 不影响后续 test
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_sky_island.gd -gexit`
Expected: FAIL（`skyisland_count_range` 方法不存在）

- [ ] **Step 3: 加方法**

`scripts/autoload/game_settings.gd`，在 `mineshaft_count_range()` 函数后面加：

```gdscript


# 空岛数量: 小 1 / 中 2-3 / 大 3-5 (跟金字塔/废弃矿井同款缩放)
func skyisland_count_range() -> Array:
	match current_world_size:
		0: return [1, 1]
		2: return [3, 5]
		_: return [2, 3]
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_sky_island.gd -gexit`
Expected: PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/autoload/game_settings.gd tests/unit/test_sky_island.gd
git commit -m "feat(world): 空岛数量按世界大小缩放接口 (空岛第1步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 空岛生成（选址 + 盖岛 + 树 + 宝箱）

**Files:**
- Modify: `scripts/world/world_generator.gd`（常量区；`static var` 缓存区 line ~1534；`generate_chunk` 调用区 line ~335；新函数放文件末尾）
- Test: `tests/unit/test_sky_island.gd`（追加）

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_sky_island.gd` 末尾加：

```gdscript
const WG = preload("res://scripts/world/world_generator.gd")

func test_sky_island_chunks_nonempty():
	var chunks = WG._sky_island_chunks(777)
	assert_gt(chunks.size(), 0, "至少有一个空岛所在 chunk")

func test_sky_island_has_cloud_grass_chest():
	var chunks = WG._sky_island_chunks(777)
	var cx: int = chunks[0]
	var c = WG.generate_chunk(777, cx, 256)
	var cloud := 0
	var grass_sky := 0
	var chest := 0
	for lx in 64:
		for y in range(8, 60):   # 天空层
			match c.tiles[lx][y]:
				Tiles.CLOUD: cloud += 1
				Tiles.GRASS: grass_sky += 1
				Tiles.DIAMOND_CHEST: chest += 1
	assert_gt(cloud, 20, "空岛云块够多 (岛体)")
	assert_gt(grass_sky, 5, "空岛有草顶")
	assert_eq(chest, 1, "空岛中心一个钻石宝箱")
	assert_gt(c.treasure_spots.size(), 0, "宝箱记进 treasure_spots (chunk_manager 会填战利品)")

func test_sky_island_deterministic():
	var chunks = WG._sky_island_chunks(2024)
	var cx: int = chunks[0]
	var a = WG.generate_chunk(2024, cx, 256)
	var b = WG.generate_chunk(2024, cx, 256)
	for lx in 64:
		assert_eq(a.tiles[lx], b.tiles[lx], "列 %d 两次生成完全一致" % lx)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_sky_island.gd -gexit`
Expected: FAIL（`WG._sky_island_chunks` 方法不存在）

- [ ] **Step 3: 加空岛常量**

`scripts/world/world_generator.gd`，在金字塔常量附近（如 `PYRAMID_*` 常量后）加：

```gdscript
# ===== 空岛 (Sky Island) =====
# 天空层浮岛: 透镜形 (中心厚边缘薄), 云块底 + 2 格土 + 草顶 + 中心小水池 + 树 + 钻石宝箱.
# 单岛装进一个 chunk (宽 ≤ 44, 居中). 数量 GameSettings.skyisland_count_range().
const SKY_ISLAND_WIDTH_MIN := 30        # 岛最窄
const SKY_ISLAND_WIDTH_MAX := 44        # 岛最宽
const SKY_ISLAND_TOP_Y_MIN := 20        # 草顶最高 (y 越小越高, 越远离地表越"飘")
const SKY_ISLAND_TOP_Y_MAX := 36        # 草顶最低
const SKY_ISLAND_CLOUD_DEPTH := 6       # 中心云块最厚层数 (边缘按比例减薄)
const SKY_ISLAND_DIRT_ROWS := 2         # 草下夹土层数
const SKY_ISLAND_POOL_HALF := 3         # 中心水池半宽 (= 7 格宽)
const SKY_ISLAND_TREE_MIN := 2          # 岛上最少树
const SKY_ISLAND_TREE_MAX := 4          # 最多树
const SKY_ISLAND_TREE_TRUNK := 4        # 空岛小树干高 (短, 不戳世界顶)
```

在 `static var` 缓存区（`_pyramid_chunks_cache_valid` 那几行附近）加：

```gdscript
static var _sky_island_chunks_cache_seed: int = 0
static var _sky_island_chunks_cache: Array = []
static var _sky_island_chunks_cache_valid: bool = false
```

- [ ] **Step 4: 加选址 + 生成函数**

`scripts/world/world_generator.gd` 文件末尾加三个函数：

```gdscript
# 给定 world_seed, 返回有空岛的 chunk_x 数组. 仿 _pyramid_chunks 但不限 biome (天上哪都行).
# 数量走 GameSettings.skyisland_count_range(), 从 _scan_chunk_range() 候选里 shuffle 选.
static func _sky_island_chunks(world_seed: int) -> Array:
	if _sky_island_chunks_cache_valid and _sky_island_chunks_cache_seed == world_seed:
		return _sky_island_chunks_cache
	var scan_range: Array = _scan_chunk_range()
	var candidates: Array = []
	for cx in range(scan_range[0], scan_range[1]):
		candidates.append(cx)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 0x5217a1
	# 数量按世界大小 (autoload 在场才读, 不在场默认中世界)
	var count_range: Array = [2, 3]
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null:
		count_range = GameSettings.skyisland_count_range()
	var target_count: int = rng.randi_range(count_range[0], count_range[1])
	var num: int = min(target_count, candidates.size())
	# Fisher-Yates 洗牌, 取前 num 个
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	_sky_island_chunks_cache = candidates.slice(0, num)
	_sky_island_chunks_cache_seed = world_seed
	_sky_island_chunks_cache_valid = true
	return _sky_island_chunks_cache


# 在选中的 chunk 中部盖一块空岛. 透镜形: 中心厚边缘薄.
static func _place_sky_island_chunk(c: Chunk, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	if not _sky_island_chunks(world_seed).has(chunk_x):
		return
	var chunk_start: int = chunk_x * chunk_width
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0x5217a1)
	var width: int = rng.randi_range(SKY_ISLAND_WIDTH_MIN, SKY_ISLAND_WIDTH_MAX)
	var half: int = width / 2
	var top_y: int = rng.randi_range(SKY_ISLAND_TOP_Y_MIN, SKY_ISLAND_TOP_Y_MAX)
	var x_center_local: int = chunk_width / 2

	# 1) 岛体: 每列按到中心比例算云块厚度 (中心 100% → 边缘渐薄), 顶 GRASS / 下 DIRT / 再下 CLOUD
	for dx in range(-half, half + 1):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		var ratio: float = 1.0 - float(absi(dx)) / float(half + 1)   # 1 中心 .. ~0 边缘
		if ratio <= 0.05:
			continue   # 最外缘空着 → 边缘自然收窄成尖
		var cloud_thick: int = int(round(float(SKY_ISLAND_CLOUD_DEPTH) * (0.25 + 0.75 * ratio)))
		if cloud_thick < 1:
			cloud_thick = 1
		# 草顶
		if top_y >= 0 and top_y < height:
			c.tiles[lx][top_y] = Tiles.GRASS
		# 草下夹土
		for d in range(1, SKY_ISLAND_DIRT_ROWS + 1):
			var yy: int = top_y + d
			if yy >= 0 and yy < height:
				c.tiles[lx][yy] = Tiles.DIRT
		# 再下云块到岛底
		var cloud_start: int = top_y + SKY_ISLAND_DIRT_ROWS + 1
		for d2 in range(0, cloud_thick):
			var yy2: int = cloud_start + d2
			if yy2 >= 0 and yy2 < height:
				c.tiles[lx][yy2] = Tiles.CLOUD

	# 2) 中心小水池: 把草顶中间 ±POOL_HALF 列换成 WATER (下面 DIRT 当池底, 水不漏)
	for dxp in range(-SKY_ISLAND_POOL_HALF, SKY_ISLAND_POOL_HALF + 1):
		var lxp: int = x_center_local + dxp
		if lxp < 0 or lxp >= chunk_width:
			continue
		if top_y >= 0 and top_y < height:
			c.tiles[lxp][top_y] = Tiles.WATER

	# 3) 树: 草地上种 2-4 棵小树, 避开水池
	var tree_count: int = rng.randi_range(SKY_ISLAND_TREE_MIN, SKY_ISLAND_TREE_MAX)
	for _i in range(tree_count):
		var tdx: int = rng.randi_range(-half + 2, half - 2)
		# 落在水池上 → 推到池子右边
		if absi(tdx) <= SKY_ISLAND_POOL_HALF + 1:
			tdx = SKY_ISLAND_POOL_HALF + 2
		_stamp_sky_tree(c, x_center_local + tdx, top_y, chunk_width, height)

	# 4) 宝箱: 水池左边一格草地上放钻石宝箱, 记进 treasure_spots
	var chest_lx: int = x_center_local - (SKY_ISLAND_POOL_HALF + 2)
	if chest_lx >= 0 and chest_lx < chunk_width:
		var chest_y: int = top_y - 1   # 草顶上方那格
		if chest_y >= 0 and c.tiles[chest_lx][top_y] == Tiles.GRASS and c.tiles[chest_lx][chest_y] == Tiles.AIR:
			c.tiles[chest_lx][chest_y] = Tiles.DIAMOND_CHEST
			c.treasure_spots.append(Vector2i(chunk_start + chest_lx, chest_y))


# 在草地列 lx 上盖一棵小树 (LOG 树干 + 3×3 LEAVES 团). grass_y = 草顶那行.
static func _stamp_sky_tree(c: Chunk, lx: int, grass_y: int, chunk_width: int, height: int) -> void:
	if lx < 1 or lx >= chunk_width - 1:
		return   # 太靠 chunk 边, 树冠会被裁 → 放弃
	if grass_y < 0 or grass_y >= height or c.tiles[lx][grass_y] != Tiles.GRASS:
		return
	var trunk_top: int = grass_y - SKY_ISLAND_TREE_TRUNK
	if trunk_top < 2:
		return   # 太靠世界顶 → 放弃
	# 树干
	for y in range(trunk_top, grass_y):
		c.tiles[lx][y] = Tiles.LOG
	# 树冠 3×3 LEAVES (只盖 AIR, 不覆盖别的)
	for ddx in range(-1, 2):
		for ddy in range(-1, 2):
			var nx: int = lx + ddx
			var ny: int = trunk_top + ddy
			if nx < 0 or nx >= chunk_width or ny < 0 or ny >= height:
				continue
			if c.tiles[nx][ny] == Tiles.AIR:
				c.tiles[nx][ny] = Tiles.LEAVES
```

- [ ] **Step 5: 接入 generate_chunk**

`scripts/world/world_generator.gd` 的 `generate_chunk` 里，在 `_place_grass_decor_chunk(...)` 调用之后、`_fill_walls_chunk(...)` 之前加：

```gdscript
	# 空岛: 天空层浮岛 (云底+草顶+小水池+树+钻石宝箱), 数量按世界大小. 在 walls 前 (天空层不填墙).
	_place_sky_island_chunk(c, world_seed, chunk_x, chunk_width, height)
```

- [ ] **Step 6: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_sky_island.gd -gexit`
Expected: PASS（4 个 test 全绿）

- [ ] **Step 7: 跑全套回归 + 提交**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 全绿（确认空岛没破坏既有 worldgen 测试，如 `test_world_generator.gd`）

```bash
git add scripts/world/world_generator.gd tests/unit/test_sky_island.gd
git commit -m "feat(world): 空岛生成 (云底+草顶+水池+树+钻石宝箱), 数量按世界大小 (空岛第1步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 收尾验收

- [ ] **Step 1: 全套单元测试**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`
Expected: 全绿，无 orphan，记下累计 test/assert 数。

- [ ] **Step 2: 集成冒烟**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_smoke.gd -gexit`
Expected: PASS（游戏能正常起、世界能加载，空岛没让加载崩）。

- [ ] **Step 3: 给用户报告**

3-5 行：做了啥（云块 + 空岛地形/水池/树/宝箱）+ 各 commit SHA + 累计测试数。提醒用户：空岛飘在很高的天上，要拿方块往上垫着爬上去；上面有钻石宝箱。第 2 步（哈比鸟）/第 3 步（云靴）待命。

---

## Self-Review（已核对）

- **Spec 覆盖**：第 1 步要求的「云块（新方块，可挖可放无重力）」「椭圆浮岛云底+土+草顶」「小水池」「2-4 棵树」「中心大宝箱进 treasure_spots」「按世界大小数量缩放」「天空层（地表上方约 70 格）」全部有对应 Task。✅ 羽毛/稀有装备战利品：第 1 步用现成 DIAMOND_CHEST 战利品表（已含宝石+护甲），feather 留到第 2 步（哈比鸟造出 feather 物品后再进战利品），避免做出还用不上的死物品 —— 与 spec「YAGNI」一致。
- **占位符扫描**：无 TBD/TODO，每个 code step 都有完整代码。
- **类型/命名一致**：`_sky_island_chunks` / `_place_sky_island_chunk` / `_stamp_sky_tree` / `skyisland_count_range` / `Tiles.CLOUD` / `"cloud"` 全程一致；缓存 `static var` 三件套命名对齐 pyramid。
- **登记点齐全**（CLAUDE.md 警告"漏一处 tile 不显示也不报错"）：tile_data 常量+属性、blocks_art 常量+图案+palette+`_PATTERN_MAP`、art_cache `tile_ids`+`_ITEM_TO_TILE`、tileset_builder `tile_ids`、item_db `_DEFS`、crafting_panel `_ZH_NAMES` —— 6 处全部列入 Task 1/2。
- **风险点**：①`Tiles.is_solid/is_mineable/get_drops` 方法名以实际 `tile_data.gd` 为准（Step 注里已提示 grep 校验）。②空岛可能落在 spawn 远处 chunk（跟金字塔一样稀有），测试用 `_sky_island_chunks()` 直接定位所在 chunk 再 `generate_chunk`，不依赖 spawn 附近。
