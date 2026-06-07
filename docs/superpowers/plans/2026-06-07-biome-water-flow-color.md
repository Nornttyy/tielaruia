# 群系水流动保色 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让沙漠/丛林/沼泽的水流动后保持本群系颜色, 颜色 = 水当前所在群系。

**Architecture:** 彩色水只活在画面层 (`terrain_layer` TileMapLayer)。数据/存档/联机永远只存普通水 (`WATER` + `WATER_L1..L7`)。画水那一刻按列查群系 (`WorldGenerator._biome_at`), 把 cell 换成对应颜色的薄水 tile。`water_sim.gd` 一行不改。

**Tech Stack:** Godot 4.3 + GDScript, GUT 测试。

**Spec:** `docs/superpowers/specs/2026-06-07-biome-water-flow-color-design.md`

**关键事实 (实现前已核实):**
- 所有水 (含 3 个群系满水) 都**不**走 autotile (`FAMILY_OF` 里没有水) → 全部经 `terrain_layer.set_cell(pos, id, Vector2i.ZERO)` 单格绘制。
- `tileset_builder.gd:78` 用 `ArtCache.block_textures[tile_id]` 取贴图 → 新 id 必须在 ArtCache 注册, 否则 KeyError。
- `tileset_builder.gd:133` 用 `Tiles.is_water(tile_id)` 决定是否加 4 帧动画。新彩色 id 不进 `is_water`, 改用新判定 `Tiles.is_biome_water_visual` 让它们也动画。
- 现有 `WorldGenerator._biome_water_tile(biome_id)` 已把 biome → `WATER/WATER_DESERT/WATER_JUNGLE/WATER_SWAMP`, 复用它解耦 `Tiles` 与 biome 编号。
- tile id 空号: 两文件均连续占用 0–93, 新增用 94–114。
- 自动加载顺序 `Tiles` 先于 `ArtCache` (见 project.godot) → ArtCache 可安全调 `Tiles.*`。

**测试前置 (每次跑 GUT 前):**
```bash
godot --headless --editor --quit    # 建 class_name 索引 (新 clone / 改 class_name 后必跑)
```
`libfontconfig.so.1` 警告无视。

---

## 文件结构

| 文件 | 责任 | 改动 |
|---|---|---|
| `scripts/world/tile_data.gd` (`Tiles`) | tile id 常量 + 纯映射函数 | 加 21 常量 + `water_level` / `is_biome_water_visual` / `display_water_tile` |
| `scripts/art/blocks_art.gd` (`BlocksArt`) | 程序绘图 + 平行 id 常量 | 加 21 常量 + `get_water_level_atlas_p` + 扩 `water_palette_for` |
| `scripts/autoload/art_cache.gd` (`ArtCache`) | tile id → 贴图 | 生成 21 张彩色薄水贴图 |
| `scripts/world/tileset_builder.gd` | 建 TileSet | tile_ids 加 21 个 + 动画门改用 `is_biome_water_visual` |
| `scripts/world/world.gd` | 画水到 terrain_layer | 加 `_display_water_tile` + 两处调用 |
| `tests/unit/test_biome_water_flow_color.gd` | 单测纯函数 + 注册 | 新建 |
| `tests/integration/test_biome_water_flow_color.gd` | 集成: world_seed → 颜色 | 新建 |

---

## Task 1: `Tiles.water_level()` — tile id 反查水位

**Files:**
- Modify: `scripts/world/tile_data.gd` (在 `is_water` 附近, 约 `tile_data.gd:669`)
- Test: `tests/unit/test_biome_water_flow_color.gd` (新建)

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_biome_water_flow_color.gd`:

```gdscript
# 群系水流动保色: 纯映射函数 + 贴图注册 验收.
extends GutTest


func test_water_level_generic() -> void:
	assert_eq(Tiles.water_level(Tiles.WATER), 8, "满水 = 8")
	assert_eq(Tiles.water_level(Tiles.WATER_L1), 1)
	assert_eq(Tiles.water_level(Tiles.WATER_L3), 3)
	assert_eq(Tiles.water_level(Tiles.WATER_L4), 4)
	assert_eq(Tiles.water_level(Tiles.WATER_L7), 7)


func test_water_level_biome_full() -> void:
	assert_eq(Tiles.water_level(Tiles.WATER_DESERT), 8, "群系满水 = 8")
	assert_eq(Tiles.water_level(Tiles.WATER_JUNGLE), 8)
	assert_eq(Tiles.water_level(Tiles.WATER_SWAMP), 8)


func test_water_level_non_water() -> void:
	assert_eq(Tiles.water_level(Tiles.STONE), 0, "石头不是水 = 0")
	assert_eq(Tiles.water_level(Tiles.AIR), 0)
	assert_eq(Tiles.water_level(Tiles.LAVA), 0, "岩浆不算 water")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: FAIL — `Invalid call. Nonexistent function 'water_level' in base 'Tiles'`

- [ ] **Step 3: 实现 `water_level`**

在 `scripts/world/tile_data.gd` 的 `is_water` 函数后面加 (此时 21 个彩色常量还没建, 先只覆盖现有 id; Task 2 会补彩色分支):

```gdscript
# tile id → 水位 (1-8). 满水(含群系满水)=8, 非水=0.
# 渲染层 display_water_tile 用它反查档位。
func water_level(tile_id: int) -> int:
	if tile_id == WATER or tile_id == WATER_DESERT or tile_id == WATER_JUNGLE or tile_id == WATER_SWAMP:
		return 8
	if tile_id == WATER_L7: return 7
	if tile_id == WATER_L6: return 6
	if tile_id == WATER_L5: return 5
	if tile_id == WATER_L4: return 4
	if tile_id == WATER_L3: return 3
	if tile_id == WATER_L2: return 2
	if tile_id == WATER_L1: return 1
	return 0
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: PASS (3 passing)

- [ ] **Step 5: Commit**

```bash
git add scripts/world/tile_data.gd tests/unit/test_biome_water_flow_color.gd
git commit -m "feat(water): Tiles.water_level() — tile id 反查水位

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 21 个彩色薄水常量 + `display_water_tile` + `is_biome_water_visual`

**Files:**
- Modify: `scripts/world/tile_data.gd` (常量区 + 函数区)
- Test: `tests/unit/test_biome_water_flow_color.gd`

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_biome_water_flow_color.gd` 追加:

```gdscript
func test_biome_water_visual_constants() -> void:
	# 21 个连号 94-114, 三族各 7 档
	assert_eq(Tiles.WATER_DESERT_L1, 94)
	assert_eq(Tiles.WATER_DESERT_L7, 100)
	assert_eq(Tiles.WATER_JUNGLE_L1, 101)
	assert_eq(Tiles.WATER_JUNGLE_L7, 107)
	assert_eq(Tiles.WATER_SWAMP_L1, 108)
	assert_eq(Tiles.WATER_SWAMP_L7, 114)


func test_water_level_covers_colored() -> void:
	assert_eq(Tiles.water_level(Tiles.WATER_DESERT_L3), 3, "沙漠 L3 = 档 3")
	assert_eq(Tiles.water_level(Tiles.WATER_JUNGLE_L5), 5)
	assert_eq(Tiles.water_level(Tiles.WATER_SWAMP_L7), 7)


func test_is_biome_water_visual() -> void:
	assert_true(Tiles.is_biome_water_visual(Tiles.WATER_DESERT_L3))
	assert_true(Tiles.is_biome_water_visual(Tiles.WATER_SWAMP_L7))
	assert_false(Tiles.is_biome_water_visual(Tiles.WATER), "普通满水不算 visual-only")
	assert_false(Tiles.is_biome_water_visual(Tiles.WATER_L3))
	assert_false(Tiles.is_biome_water_visual(Tiles.WATER_DESERT), "群系满水是真数据, 不算 visual-only")


func test_display_water_tile_desert() -> void:
	# 沙漠列: 普通薄水 → 沙漠彩色; 满水 → 沙漠满水
	assert_eq(Tiles.display_water_tile(Tiles.WATER_L3, Tiles.WATER_DESERT), Tiles.WATER_DESERT_L3)
	assert_eq(Tiles.display_water_tile(Tiles.WATER, Tiles.WATER_DESERT), Tiles.WATER_DESERT)


func test_display_water_tile_jungle_swamp() -> void:
	assert_eq(Tiles.display_water_tile(Tiles.WATER_L5, Tiles.WATER_JUNGLE), Tiles.WATER_JUNGLE_L5)
	assert_eq(Tiles.display_water_tile(Tiles.WATER_L7, Tiles.WATER_SWAMP), Tiles.WATER_SWAMP_L7)


func test_display_water_tile_plain_passthrough() -> void:
	# 平原/雪原 (full = 普通 WATER): 不染色, 原样返回
	assert_eq(Tiles.display_water_tile(Tiles.WATER_L3, Tiles.WATER), Tiles.WATER_L3)
	assert_eq(Tiles.display_water_tile(Tiles.WATER, Tiles.WATER), Tiles.WATER)
	# 非水原样穿过
	assert_eq(Tiles.display_water_tile(Tiles.STONE, Tiles.WATER_DESERT), Tiles.STONE)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: FAIL — `Invalid get index 'WATER_DESERT_L1'` (常量未定义)

- [ ] **Step 3: 加 21 常量**

在 `scripts/world/tile_data.gd` 群系满水常量后面 (约 `tile_data.gd:109`, `WATER_SWAMP := 83` 那行后) 加:

```gdscript
# 群系薄水 (visual-only): 沙漠/丛林/沼泽 × 7 档. 只出现在 terrain_layer 画面层,
# 永不进 chunk 数据 / 存档 / 联机 → 不需要行为表条目。颜色 = 水当前所在群系。
const WATER_DESERT_L1 := 94
const WATER_DESERT_L2 := 95
const WATER_DESERT_L3 := 96
const WATER_DESERT_L4 := 97
const WATER_DESERT_L5 := 98
const WATER_DESERT_L6 := 99
const WATER_DESERT_L7 := 100
const WATER_JUNGLE_L1 := 101
const WATER_JUNGLE_L2 := 102
const WATER_JUNGLE_L3 := 103
const WATER_JUNGLE_L4 := 104
const WATER_JUNGLE_L5 := 105
const WATER_JUNGLE_L6 := 106
const WATER_JUNGLE_L7 := 107
const WATER_SWAMP_L1 := 108
const WATER_SWAMP_L2 := 109
const WATER_SWAMP_L3 := 110
const WATER_SWAMP_L4 := 111
const WATER_SWAMP_L5 := 112
const WATER_SWAMP_L6 := 113
const WATER_SWAMP_L7 := 114

# display_water_tile 用: 档位(1-8) → tile id. 索引 0 占位. 普通水 id 不连续故显式列。
const _GENERIC_LV := [0, WATER_L1, WATER_L2, WATER_L3, WATER_L4, WATER_L5, WATER_L6, WATER_L7, WATER]
const _DESERT_LV  := [0, WATER_DESERT_L1, WATER_DESERT_L2, WATER_DESERT_L3, WATER_DESERT_L4, WATER_DESERT_L5, WATER_DESERT_L6, WATER_DESERT_L7, WATER_DESERT]
const _JUNGLE_LV  := [0, WATER_JUNGLE_L1, WATER_JUNGLE_L2, WATER_JUNGLE_L3, WATER_JUNGLE_L4, WATER_JUNGLE_L5, WATER_JUNGLE_L6, WATER_JUNGLE_L7, WATER_JUNGLE]
const _SWAMP_LV   := [0, WATER_SWAMP_L1, WATER_SWAMP_L2, WATER_SWAMP_L3, WATER_SWAMP_L4, WATER_SWAMP_L5, WATER_SWAMP_L6, WATER_SWAMP_L7, WATER_SWAMP]
```

- [ ] **Step 4: `water_level` 补彩色分支**

把 Task 1 写的 `water_level` 顶部加一句覆盖 21 个连号 (94-114), 紧跟函数第一行 `func water_level(...)` 下:

```gdscript
func water_level(tile_id: int) -> int:
	# 彩色薄水 (94-114): 三族各 7 档, 连号 → 档 = (offset % 7) + 1
	if tile_id >= WATER_DESERT_L1 and tile_id <= WATER_SWAMP_L7:
		return ((tile_id - WATER_DESERT_L1) % 7) + 1
	if tile_id == WATER or tile_id == WATER_DESERT or tile_id == WATER_JUNGLE or tile_id == WATER_SWAMP:
		return 8
	if tile_id == WATER_L7: return 7
	# ... (其余不变)
```

- [ ] **Step 5: 加 `is_biome_water_visual` + `display_water_tile`**

在 `water_level` 后面加:

```gdscript
# 是不是 21 个 visual-only 彩色薄水之一 (tileset 动画门 / art_cache 用)。
func is_biome_water_visual(tile_id: int) -> bool:
	return tile_id >= WATER_DESERT_L1 and tile_id <= WATER_SWAMP_L7

# 数据里存的普通水 stored_id → 按所在群系该画的彩色 visual id。
# full_water_id = 该群系的满水 id (WATER / WATER_DESERT / WATER_JUNGLE / WATER_SWAMP),
# 由调用方用 WorldGenerator._biome_water_tile(biome) 得到 → Tiles 不依赖 biome 编号。
# 非水 stored_id 原样返回。
func display_water_tile(stored_id: int, full_water_id: int) -> int:
	var lvl: int = water_level(stored_id)
	if lvl <= 0:
		return stored_id
	match full_water_id:
		WATER_DESERT: return _DESERT_LV[lvl]
		WATER_JUNGLE: return _JUNGLE_LV[lvl]
		WATER_SWAMP:  return _SWAMP_LV[lvl]
		_:            return _GENERIC_LV[lvl]
```

- [ ] **Step 6: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: PASS (全部通过)

- [ ] **Step 7: Commit**

```bash
git add scripts/world/tile_data.gd tests/unit/test_biome_water_flow_color.gd
git commit -m "feat(water): 21 彩色薄水常量 + display_water_tile 纯映射

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `BlocksArt` — 带调色板的薄水 atlas + 21 平行常量

**Files:**
- Modify: `scripts/art/blocks_art.gd` (常量区 + `get_water_level_atlas` 附近 ~2459 + `water_palette_for` ~2450)
- Test: `tests/unit/test_biome_water_flow_color.gd`

- [ ] **Step 1: 写失败测试**

追加:

```gdscript
const BlocksArt = preload("res://scripts/art/blocks_art.gd")


func test_blocksart_colored_constants_align() -> void:
	# BlocksArt 与 Tiles 的 id 必须数值对齐
	assert_eq(BlocksArt.WATER_DESERT_L1, Tiles.WATER_DESERT_L1)
	assert_eq(BlocksArt.WATER_JUNGLE_L4, Tiles.WATER_JUNGLE_L4)
	assert_eq(BlocksArt.WATER_SWAMP_L7, Tiles.WATER_SWAMP_L7)


func test_get_water_level_atlas_p_size() -> void:
	# 带调色板的薄水 atlas: 64x16 (4 帧), 跟原 get_water_level_atlas 同尺寸
	var tex := BlocksArt.get_water_level_atlas_p(3, BlocksArt._P_WATER_DESERT)
	assert_not_null(tex)
	assert_eq(tex.get_width(), 64)
	assert_eq(tex.get_height(), 16)


func test_water_palette_for_colored() -> void:
	# 彩色薄水 id 也能查到对应族调色板
	assert_eq(BlocksArt.water_palette_for(BlocksArt.WATER_DESERT_L3), BlocksArt._P_WATER_DESERT)
	assert_eq(BlocksArt.water_palette_for(BlocksArt.WATER_JUNGLE_L5), BlocksArt._P_WATER_JUNGLE)
	assert_eq(BlocksArt.water_palette_for(BlocksArt.WATER_SWAMP_L1), BlocksArt._P_WATER_SWAMP)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: FAIL — `Invalid get index 'WATER_DESERT_L1'` (BlocksArt 常量未定义)

- [ ] **Step 3: BlocksArt 加 21 平行常量**

在 `scripts/art/blocks_art.gd` 的 `WATER_SWAMP := 83` 行 (约 `blocks_art.gd:38`) 后加 (数值必须跟 tile_data.gd 完全一致):

```gdscript
# 群系薄水 (visual-only, 跟 Tiles 同号 94-114)
const WATER_DESERT_L1 := 94
const WATER_DESERT_L2 := 95
const WATER_DESERT_L3 := 96
const WATER_DESERT_L4 := 97
const WATER_DESERT_L5 := 98
const WATER_DESERT_L6 := 99
const WATER_DESERT_L7 := 100
const WATER_JUNGLE_L1 := 101
const WATER_JUNGLE_L2 := 102
const WATER_JUNGLE_L3 := 103
const WATER_JUNGLE_L4 := 104
const WATER_JUNGLE_L5 := 105
const WATER_JUNGLE_L6 := 106
const WATER_JUNGLE_L7 := 107
const WATER_SWAMP_L1 := 108
const WATER_SWAMP_L2 := 109
const WATER_SWAMP_L3 := 110
const WATER_SWAMP_L4 := 111
const WATER_SWAMP_L5 := 112
const WATER_SWAMP_L6 := 113
const WATER_SWAMP_L7 := 114
```

- [ ] **Step 4: 加 `get_water_level_atlas_p`, 原函数复用**

把现有 `get_water_level_atlas` (约 `blocks_art.gd:2459`) 改成薄壳, 新增带调色板版:

```gdscript
static func get_water_level_atlas(level: int) -> ImageTexture:
	return get_water_level_atlas_p(level, _P_WATER)


# 同上但用指定调色板 (群系薄水分色用). 复用同一套水帧 + clip。
static func get_water_level_atlas_p(level: int, palette: Dictionary) -> ImageTexture:
	assert(level >= 1 and level <= 7, "level 必须 1-7 (8 档体系)")
	var clip_rows: int = (8 - level) * 2  # 顶部清除多少行 (16px/8档 = 每档 2px)
	var frames: Array = [_WATER, _WATER_F1, _WATER_F2, _WATER_F3]
	var dst := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for i in range(4):
		var clipped: Array = _clip_water_top(frames[i], clip_rows)
		var frame_img: Image = PixelArt.grid_to_image(clipped, palette)
		dst.blit_rect(frame_img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	return ImageTexture.create_from_image(dst)
```

- [ ] **Step 5: 扩 `water_palette_for` 覆盖彩色薄水 id**

把现有 `water_palette_for` (约 `blocks_art.gd:2450`) 改成:

```gdscript
static func water_palette_for(tile_id: int) -> Dictionary:
	if tile_id == WATER_DESERT or (tile_id >= WATER_DESERT_L1 and tile_id <= WATER_DESERT_L7):
		return _P_WATER_DESERT
	if tile_id == WATER_JUNGLE or (tile_id >= WATER_JUNGLE_L1 and tile_id <= WATER_JUNGLE_L7):
		return _P_WATER_JUNGLE
	if tile_id == WATER_SWAMP or (tile_id >= WATER_SWAMP_L1 and tile_id <= WATER_SWAMP_L7):
		return _P_WATER_SWAMP
	return _P_WATER
```

- [ ] **Step 6: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/art/blocks_art.gd tests/unit/test_biome_water_flow_color.gd
git commit -m "feat(water): BlocksArt 21 彩色薄水常量 + get_water_level_atlas_p

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 注册 21 张贴图 (art_cache) + tileset (tileset_builder)

> 老坑: tileset_builder + art_cache 任一漏掉 → tile 不显示也不报错。两处都加。

**Files:**
- Modify: `scripts/autoload/art_cache.gd` (约 `art_cache.gd:163` 群系满水分支附近 / 或新加循环)
- Modify: `scripts/world/tileset_builder.gd` (tile_ids 数组 ~45, 动画门 ~133)
- Test: `tests/unit/test_biome_water_flow_color.gd`

- [ ] **Step 1: 写失败测试**

追加:

```gdscript
func test_all_21_colored_have_textures() -> void:
	# 21 个彩色薄水都该在 ArtCache 有世界贴图 (漏注册 → 缺 key)
	for tid in range(Tiles.WATER_DESERT_L1, Tiles.WATER_SWAMP_L7 + 1):
		assert_not_null(ArtCache.block_textures.get(tid), "彩色薄水 %d 该有贴图" % tid)


func test_tileset_has_21_colored_sources() -> void:
	# TileSet 必须注册这 21 个 source, 否则 set_cell 不显示
	var ts := load("res://scripts/world/tileset_builder.gd").build()
	for tid in range(Tiles.WATER_DESERT_L1, Tiles.WATER_SWAMP_L7 + 1):
		assert_true(ts.has_source(tid), "TileSet 缺 source %d" % tid)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: FAIL — `block_textures.get(94)` 返回 null

- [ ] **Step 3: art_cache 生成 21 张贴图**

在 `scripts/autoload/art_cache.gd` 的主 `for tile_id in tile_ids` 循环**结束之后** (约 `art_cache.gd:180` 那个 `else:` 分支所属循环收尾处), 加一段独立循环 (不塞进 if/elif, 避免落到 else 兜底):

```gdscript
	# 群系薄水 (visual-only, 21 张): 3 族 × 7 档, 同薄水 atlas 换调色板染色。
	# 不在上面 tile_ids 主循环里 (它们不进数据, 单独按族×档生成)。
	for base_id in [BlocksArt.WATER_DESERT_L1, BlocksArt.WATER_JUNGLE_L1, BlocksArt.WATER_SWAMP_L1]:
		var pal: Dictionary = BlocksArt.water_palette_for(base_id)
		for lvl in range(1, 8):
			var tid: int = base_id + (lvl - 1)
			var tex: ImageTexture = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas_p(lvl, pal))
			block_textures[tid] = tex
			block_icons[tid] = tex   # 不是 item, icon 复用世界贴图防缺 key 崩
```

- [ ] **Step 4: tileset_builder 注册 21 id + 动画门**

(a) `scripts/world/tileset_builder.gd` tile_ids 数组 (约 `tileset_builder.gd:45`, `WATER_SWAMP,` 那行后) 加:

```gdscript
		Tiles.WATER_DESERT_L1, Tiles.WATER_DESERT_L2, Tiles.WATER_DESERT_L3,
		Tiles.WATER_DESERT_L4, Tiles.WATER_DESERT_L5, Tiles.WATER_DESERT_L6, Tiles.WATER_DESERT_L7,
		Tiles.WATER_JUNGLE_L1, Tiles.WATER_JUNGLE_L2, Tiles.WATER_JUNGLE_L3,
		Tiles.WATER_JUNGLE_L4, Tiles.WATER_JUNGLE_L5, Tiles.WATER_JUNGLE_L6, Tiles.WATER_JUNGLE_L7,
		Tiles.WATER_SWAMP_L1, Tiles.WATER_SWAMP_L2, Tiles.WATER_SWAMP_L3,
		Tiles.WATER_SWAMP_L4, Tiles.WATER_SWAMP_L5, Tiles.WATER_SWAMP_L6, Tiles.WATER_SWAMP_L7,
```

(b) 动画门 (约 `tileset_builder.gd:133`) 让彩色薄水也走 4 帧动画:

```gdscript
				# 水 (8 档水位 + 3 群系满水 + 21 群系薄水) 都启用 4 帧动画
				if Tiles.is_water(tile_id) or Tiles.is_biome_water_visual(tile_id):
```

- [ ] **Step 5: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_biome_water_flow_color.gd -gexit`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add scripts/autoload/art_cache.gd scripts/world/tileset_builder.gd tests/unit/test_biome_water_flow_color.gd
git commit -m "feat(water): 注册 21 彩色薄水到 art_cache + tileset (含 4 帧动画)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 接入 world.gd 两个画水入口

**Files:**
- Modify: `scripts/world/world.gd` (加 `_display_water_tile` 帮手; 改 `_set_water_tile_fast` ~1857; 改区块加载 ~938)
- Test: `tests/integration/test_biome_water_flow_color.gd` (新建)

- [ ] **Step 1: 写失败集成测试**

新建 `tests/integration/test_biome_water_flow_color.gd`:

```gdscript
# 集成: world_seed → 群系 → 画水颜色 链路. 验证 _display_water_tile 真按列染色。
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const World = preload("res://scripts/world/world.gd")

const SEED := 12345


# 扫出该 seed 下某 biome 的一列 x (扫不到返回 -999999)
func _find_col(biome_id: int) -> int:
	for x in range(-400, 400):
		if WorldGenerator._biome_at(x, SEED) == biome_id:
			return x
	return -999999


func test_display_colors_by_current_biome() -> void:
	var w = World.new()
	w.world_seed = SEED
	add_child_autofree(w)

	var dx := _find_col(WorldGenerator.BIOME_DESERT)
	assert_ne(dx, -999999, "该 seed 应有沙漠列")
	# 数据是普通薄水, 画到沙漠列 → 沙漠彩色
	assert_eq(w._display_water_tile(dx, Tiles.WATER_L3), Tiles.WATER_DESERT_L3)

	var fx := _find_col(WorldGenerator.BIOME_FOREST)
	assert_ne(fx, -999999, "该 seed 应有森林列")
	# 森林 (无特殊水) → 不染色, 还是普通蓝薄水
	assert_eq(w._display_water_tile(fx, Tiles.WATER_L3), Tiles.WATER_L3)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_biome_water_flow_color.gd -gexit`
Expected: FAIL — `Nonexistent function '_display_water_tile'`

- [ ] **Step 3: world.gd 加 `_display_water_tile` 帮手**

在 `scripts/world/world.gd` 的 `_set_water_tile_fast` 函数 (约 `world.gd:1849`) **上面**加:

```gdscript
# 数据里存普通水 stored_id; 画到屏幕前按列查群系换成彩色 visual id。
# 彩色 id 只进 terrain_layer (画面), 绝不回写 chunk_manager (数据保持普通水)。
func _display_water_tile(x: int, stored_id: int) -> int:
	if Tiles.water_level(stored_id) <= 0:
		return stored_id   # 不是水, 原样 (省一次 biome 查询)
	var full: int = WorldGenerator._biome_water_tile(WorldGenerator._biome_at(x, world_seed))
	return Tiles.display_water_tile(stored_id, full)
```

- [ ] **Step 4: 改 `_set_water_tile_fast` 的绘制行**

`scripts/world/world.gd:1857` 原:

```gdscript
	else:
		terrain_layer.set_cell(pos, tile_id, Vector2i.ZERO)
```

改为 (数据已在上一行 `chunk_manager.set_tile(x, y, tile_id)` 存了普通水, 这里只改画面):

```gdscript
	else:
		terrain_layer.set_cell(pos, _display_water_tile(x, tile_id), Vector2i.ZERO)
```

- [ ] **Step 5: 改区块加载绘制行**

`scripts/world/world.gd:938` 原:

```gdscript
			else:
				terrain_layer.set_cell(pos, tid, Vector2i.ZERO)
```

改为:

```gdscript
			else:
				terrain_layer.set_cell(pos, _display_water_tile(world_x, tid), Vector2i.ZERO)
```

> 说明: 此 else 分支收的是非 AIR / 非水晶 / 非 autotile-family 的 tile。水 (普通 + 群系满水) 都落这里。`_display_water_tile` 对非水原样返回, 所以其他方块不受影响。

- [ ] **Step 6: 跑集成测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_biome_water_flow_color.gd -gexit`
Expected: PASS

- [ ] **Step 7: 跑全量 water 相关测试确认没回归**

Run:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 全绿 (特别关注 `test_biome_water` / `test_water_leveling` / `test_water_settles` / `test_finer_water` 无回归)

- [ ] **Step 8: Commit**

```bash
git add scripts/world/world.gd tests/integration/test_biome_water_flow_color.gd
git commit -m "feat(water): 群系水流动按所在群系染色 — 画面层换色, 数据存普通水

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 真机验收 (手动跑游戏看效果)

**Files:** 无 (验收)

- [ ] **Step 1: 重建缓存跑游戏**

> 改了 tileset / 资源, 用 `--rebuild`。

Run: `./run.sh --rebuild`

- [ ] **Step 2: 肉眼验收**

- 找到沙漠绿洲 / 丛林 / 沼泽的水。
- 挖开让水流动 (横向铺 + 往下落), 确认薄水保持本群系颜色 (沙漠青绿 / 丛林翠绿 / 沼泽墨绿), 不再变蓝。
- 让群系水流过边界进入平原, 确认它变蓝 (颜色 = 当前所在群系)。
- 普通平原水仍是蓝色, 其他方块外观无变化。

- [ ] **Step 3: (可选) 部署上线**

> 用户偏好"做好就 push" (见 deploy 约定)。确认效果 OK 后:

```bash
git push origin main
```
GitHub Actions 自动 build + 部署网页, 3-5 分钟生效。

---

## 自查 (Self-Review 记录)

- **Spec 覆盖**: 美术 21 张 (T3/T4) ✓; 纯函数 water_level/biome_water_visual/display_water_tile (T1/T2) ✓; 两画水入口 (T5) ✓; 不动 water_sim/存档/联机 (T5 仅改画面行, 数据行不动) ✓; 测试单元+集成 (T1-T5) ✓。
- **Placeholder**: 无 TBD / TODO, 每个改动均给完整代码。
- **类型/命名一致**: `water_level` / `is_biome_water_visual` / `display_water_tile` / `get_water_level_atlas_p` / `_display_water_tile` 全程一致; 21 常量两文件同号 94-114; `display_water_tile(stored_id, full_water_id)` 签名贯穿 T2/T5。
- **风险**: id 撞号 (执行前再 grep 94-114 确认没被新 WIP 占) [[feedback_tileset_registration]]; `WATER_L1..L7` id 不连续故 `_GENERIC_LV` 显式列 (不可用算术)。
