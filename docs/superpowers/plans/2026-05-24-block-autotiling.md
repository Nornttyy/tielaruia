# 方块自动连接 (Block Autotiling) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让 15 种地形/墙/木板/叶方块根据 8 邻居自动呈现 47 种泰拉瑞亚 (Terraria) 风格的视觉变体 (圆角、内凹、孤立块描边)。

**Architecture:** 自己写 8-bit 邻居 mask → 47 atlas 坐标查表 (256 项静态常量), 不走 Godot terrain。每方块的 47 变体在启动时由「现有 16×16 内部纹理 + 5 族手画的 47 边缘模板」用语义化字符调色合成。`TileMapLayer.set_cell(coord, source_id, atlas_coord)` 调用集中到 `Autotile.refresh_*` 帮手, 放置/破坏自动重算 1+8 格。

**Tech Stack:** Godot 4.3 + GDScript + GUT (测试框架). 现有 chunk/tile 渲染管线 (`world.gd` + `chunk_manager.gd` + `TileMapLayer`)。

**Spec:** `docs/superpowers/specs/2026-05-24-block-autotiling-design.md`

---

## File Structure

### 新建文件 (Create)

| 文件 | 职责 |
|---|---|
| `scripts/world/blob_lookup.gd` | 纯数据 + 静态函数. `mask_to_key(mask)` → 8 字符 key, `VARIANT_KEYS` 47 项, `ATLAS_COORD[256]` → Vector2i |
| `scripts/world/autotile.gd` | 帮手层. `refresh_tile()` 和 `refresh_with_neighbors()` 集中 set_cell + 邻居 mask 计算 |
| `scripts/art/edge_templates.gd` | 5 族 × 47 边缘模板 (语义字符 ASCII) + `FAMILY_OF[tile_id]` 映射 |
| `tests/unit/test_blob_lookup.gd` | 验证 mask → key 和 47 唯一性 |
| `tests/unit/test_edge_templates.gd` | 验证 5 族每族 47 模板存在 + 尺寸 16×16 |
| `tests/unit/test_blocks_art_atlas.gd` | 验证 atlas 是 128×96 + 像素非空 |
| `tests/unit/test_autotile.gd` | 验证邻居查询 + 4 邻居/8 邻居 mask 计算 |

### 修改文件 (Modify)

| 文件 | 改动摘要 |
|---|---|
| `scripts/art/blocks_art.gd` | 调色板新增 `_o/_e/_h/_H` 4 槽位 (15 个适用方块); 新增 `build_atlas(tile_id) -> ImageTexture`; `get_texture()` 继续返回单图供物品图标 |
| `scripts/autoload/art_cache.gd` | `block_textures[tile_id]` 由单图改为 atlas (128×96); 新增 `block_icons[tile_id]` 单图 |
| `scripts/world/tileset_builder.gd` | 每 source 创建 47 个 atlas cell 而不是 1 个; 给所有实心 cell 加碰撞 polygon |
| `scripts/world/world.gd` | `_on_chunk_loaded` 和 `_set_tile` 改用 `Autotile.refresh_*` |
| `scripts/player/player_action.gd` | `_finish_mine` 和 `try_place` 改用 `Autotile.refresh_with_neighbors` |
| `scripts/world/village_placer.gd` | `place` 中所有 `set_cell` 改用 `Autotile.refresh_tile` (盖完一片后再补一次邻居刷新) |

---

## 关键参考: 47 变体 key 编码

每个 8-bit 邻居 mask (N/E/S/W + NE/SE/SW/NW) → 8 字符 key:

- **字符 0-3**: N/E/S/W 边状态. `O` = 开 (邻居为空), `C` = 闭 (邻居同族)
- **字符 4-7**: NE/SE/SW/NW 角状态.
  - 若两个相邻边都是 `C` (邻居在): `I` = 对角邻居在 (interior, 不画细节); `X` = 对角邻居缺 (concave, 画凹角细节)
  - 若任一相邻边是 `O`: `.` (角不重要, 已被边状态决定)

**47 个唯一 key (按"封闭边数"分组排序, 即 atlas 顺序 0..46):**

```
索引   key         描述
0     OOOO....    孤立块 (4 圆角)
1     COOO....    只有北邻居 (顶边封闭, 其它 3 边描边)
2     OCOO....    只有东邻居
3     OOCO....    只有南邻居
4     OOOC....    只有西邻居
5     CCOOI...    N+E 封闭, NE 角内 (interior)
5+1   CCOOX...    N+E 封闭, NE 角缺 (concave) [NE 在角 chars 第 0 位, 即 key 第 4 位]
... 实际索引按下面算法生成 ...
```

**生成算法 (T1 实现 enumerate_keys()):**

```
for sides in 0..15:                   # 16 个 N/E/S/W 组合
  for corner_modifier in valid combos:  # 仅"两相邻边都闭"的角需变体
    key = encode(sides, corner_modifier)
    if key not yet collected: append to list
sort by (popcount(sides), key)         # 0 边封闭在前, 4 边在最后
assert len == 47
```

**邻居 mask 位定义** (bit 编号, LSB 起):
- bit 0 = N (上)
- bit 1 = E (右)
- bit 2 = S (下)
- bit 3 = W (左)
- bit 4 = NE
- bit 5 = SE
- bit 6 = SW
- bit 7 = NW

**Atlas 布局** (128×96 px = 8 列 × 6 行 × 16 px):
- 索引 i → (col = i % 8, row = i / 8) → atlas_coord = Vector2i(col, row)

---

# Part 1 — 工程脚手架

---

### Task 1: blob_lookup.gd — 邻居 mask → variant key + atlas 查表

**Files:**
- Create: `scripts/world/blob_lookup.gd`
- Test: `tests/unit/test_blob_lookup.gd`

- [ ] **Step 1: 写失败的测试**

```gdscript
# tests/unit/test_blob_lookup.gd
extends GutTest

const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


func test_isolated_block():
	# mask 0 = 无任何邻居
	assert_eq(BlobLookup.mask_to_key(0), "OOOO....")


func test_only_north_neighbor():
	# N (bit 0) = 1, 其它 0
	assert_eq(BlobLookup.mask_to_key(1), "COOO....")


func test_north_and_east_no_corner():
	# N + E 闭, NE 角缺 (concave): bits 0|1 = 3
	assert_eq(BlobLookup.mask_to_key(0b0000_0011), "CCOOX...")


func test_north_and_east_with_corner():
	# N + E + NE: bits 0|1|16 = 19
	assert_eq(BlobLookup.mask_to_key(0b0001_0011), "CCOOI...")


func test_north_open_makes_ne_dot():
	# E + NE 但 N 开 → NE 角不重要
	assert_eq(BlobLookup.mask_to_key(0b0001_0010), "OCOO....")


func test_fully_interior():
	# 全 8 邻居都在: mask = 0xFF
	assert_eq(BlobLookup.mask_to_key(0xFF), "CCCCIIII")


func test_variant_keys_count_47():
	# 47 唯一 variant key
	assert_eq(BlobLookup.VARIANT_KEYS.size(), 47)


func test_variant_keys_unique():
	var seen := {}
	for k in BlobLookup.VARIANT_KEYS:
		assert_false(seen.has(k), "重复 key: %s" % k)
		seen[k] = true


func test_atlas_coord_isolated_is_origin():
	# 索引 0 (OOOO....) → atlas (0, 0)
	assert_eq(BlobLookup.ATLAS_COORD[0], Vector2i(0, 0))


func test_atlas_coord_size_256():
	assert_eq(BlobLookup.ATLAS_COORD.size(), 256)


func test_atlas_coord_in_range():
	# 所有坐标在 8×6 范围内
	for v in BlobLookup.ATLAS_COORD:
		assert_true(v.x >= 0 and v.x < 8, "col 越界: %d" % v.x)
		assert_true(v.y >= 0 and v.y < 6, "row 越界: %d" % v.y)


func test_atlas_coord_only_47_unique():
	var seen := {}
	for v in BlobLookup.ATLAS_COORD:
		seen[v] = true
	assert_eq(seen.size(), 47)
```

- [ ] **Step 2: 跑测试验证失败**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blob_lookup.gd -gexit`
Expected: FAIL with "BlobLookup not found" 或类似

- [ ] **Step 3: 实现 blob_lookup.gd**

```gdscript
# scripts/world/blob_lookup.gd
# 8-bit 邻居 mask → 8 字符 variant key → atlas 坐标. 47 唯一变体.
# 用于 Terraria 风格自动连接 (blob autotiling).
#
# Mask bit 编号 (LSB 起):
#   0=N, 1=E, 2=S, 3=W, 4=NE, 5=SE, 6=SW, 7=NW
#
# Key 8 字符: chars 0-3 = N/E/S/W 边 (O 开 / C 闭),
#             chars 4-7 = NE/SE/SW/NW 角 (I/X/.)
extends RefCounted


# 按"封闭边数"排序的 47 唯一 key. atlas 索引 = 此数组下标.
static var VARIANT_KEYS: Array[String] = _enumerate_keys()

# 256 项查表: mask → atlas Vector2i (col, row). 8 列 6 行.
static var ATLAS_COORD: Array = _build_atlas_coord()


static func mask_to_key(mask: int) -> String:
	var n: bool = (mask & 1) != 0
	var e: bool = (mask & 2) != 0
	var s: bool = (mask & 4) != 0
	var w: bool = (mask & 8) != 0
	var ne: bool = (mask & 16) != 0
	var se: bool = (mask & 32) != 0
	var sw: bool = (mask & 64) != 0
	var nw: bool = (mask & 128) != 0

	var sides := ""
	sides += "C" if n else "O"
	sides += "C" if e else "O"
	sides += "C" if s else "O"
	sides += "C" if w else "O"

	var corners := ""
	# NE 角: 看 N 和 E
	corners += _corner_char(n, e, ne)
	# SE 角: 看 S 和 E
	corners += _corner_char(s, e, se)
	# SW 角: 看 S 和 W
	corners += _corner_char(s, w, sw)
	# NW 角: 看 N 和 W
	corners += _corner_char(n, w, nw)

	return sides + corners


static func _corner_char(side_a: bool, side_b: bool, diag: bool) -> String:
	if not (side_a and side_b):
		return "."
	return "I" if diag else "X"


static func _enumerate_keys() -> Array[String]:
	# 扫 256 个 mask, dedup 出 47 个 key, 按 (闭边数, key 字典序) 排序.
	var seen := {}
	for m in range(256):
		var k := mask_to_key(m)
		if not seen.has(k):
			seen[k] = _closed_side_count(m)
	var pairs: Array = []
	for k in seen.keys():
		pairs.append([seen[k], k])
	pairs.sort_custom(func(a, b):
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1]
	)
	var result: Array[String] = []
	for p in pairs:
		result.append(p[1])
	return result


static func _closed_side_count(mask: int) -> int:
	var c: int = 0
	if mask & 1: c += 1
	if mask & 2: c += 1
	if mask & 4: c += 1
	if mask & 8: c += 1
	return c


static func _build_atlas_coord() -> Array:
	# 每个 mask 映射到它的 key 在 VARIANT_KEYS 里的下标, 再换算成 (col, row).
	var key_to_index := {}
	for i in VARIANT_KEYS.size():
		key_to_index[VARIANT_KEYS[i]] = i
	var result: Array = []
	result.resize(256)
	for m in range(256):
		var k := mask_to_key(m)
		var idx: int = key_to_index[k]
		result[m] = Vector2i(idx % 8, idx / 8)
	return result
```

- [ ] **Step 4: 跑测试验证通过**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blob_lookup.gd -gexit`
Expected: 11 passing, 0 failing

- [ ] **Step 5: Commit**

```bash
git add scripts/world/blob_lookup.gd tests/unit/test_blob_lookup.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): blob_lookup — 8-bit mask → 47 唯一 variant + 256→atlas 查表

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: edge_templates.gd 骨架 (5 族 47 占位模板 + family 映射)

**Files:**
- Create: `scripts/art/edge_templates.gd`
- Test: `tests/unit/test_edge_templates.gd`

模板用 `.` (透明, 显示内部纹理) + `o/e/h/H` (边缘语义色) 5 字符. 初始全填 `.` (无边缘装饰), 后续 T10-T14 替换成真正的手画图案. 这样 atlas 构建走通后, 视觉先和现状一样 (没边), 再逐族画上去.

- [ ] **Step 1: 写失败的测试**

```gdscript
# tests/unit/test_edge_templates.gd
extends GutTest

const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


func test_five_families_defined():
	assert_true(EdgeTemplates.TEMPLATES.has("soil"))
	assert_true(EdgeTemplates.TEMPLATES.has("rock"))
	assert_true(EdgeTemplates.TEMPLATES.has("wood"))
	assert_true(EdgeTemplates.TEMPLATES.has("leaf"))
	assert_true(EdgeTemplates.TEMPLATES.has("wall"))


func test_each_family_has_47_templates():
	for fam in ["soil", "rock", "wood", "leaf", "wall"]:
		var tpl: Dictionary = EdgeTemplates.TEMPLATES[fam]
		assert_eq(tpl.size(), 47, "%s 族应有 47 模板, 实际 %d" % [fam, tpl.size()])


func test_templates_keyed_by_variant_keys():
	for fam in ["soil", "rock", "wood", "leaf", "wall"]:
		var tpl: Dictionary = EdgeTemplates.TEMPLATES[fam]
		for vk in BlobLookup.VARIANT_KEYS:
			assert_true(tpl.has(vk), "%s 族缺 key %s" % [fam, vk])


func test_each_template_is_16x16():
	for fam in EdgeTemplates.TEMPLATES.keys():
		var tpl: Dictionary = EdgeTemplates.TEMPLATES[fam]
		for vk in tpl.keys():
			var rows: Array = tpl[vk]
			assert_eq(rows.size(), 16, "%s/%s 行数 %d" % [fam, vk, rows.size()])
			for i in 16:
				var row: String = rows[i]
				assert_eq(row.length(), 16, "%s/%s 第 %d 行长度 %d" % [fam, vk, i, row.length()])


func test_family_of_covers_15_tiles():
	var expected_ids: Array = [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.SAND,
		BlocksArt.STONE, BlocksArt.DEEP_STONE, BlocksArt.BEDROCK,
		BlocksArt.COAL_ORE, BlocksArt.IRON_ORE,
		BlocksArt.PLANKS,
		BlocksArt.LEAVES, BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN,
		BlocksArt.GRASS_WALL, BlocksArt.DIRT_WALL, BlocksArt.STONE_WALL,
	]
	for tid in expected_ids:
		assert_true(EdgeTemplates.FAMILY_OF.has(tid), "tile %d 未映射到 family" % tid)


func test_family_of_grass_is_soil():
	assert_eq(EdgeTemplates.FAMILY_OF[BlocksArt.GRASS], "soil")


func test_family_of_stone_is_rock():
	assert_eq(EdgeTemplates.FAMILY_OF[BlocksArt.STONE], "rock")


func test_family_of_planks_is_wood():
	assert_eq(EdgeTemplates.FAMILY_OF[BlocksArt.PLANKS], "wood")


func test_family_of_leaves_is_leaf():
	assert_eq(EdgeTemplates.FAMILY_OF[BlocksArt.LEAVES], "leaf")


func test_family_of_grass_wall_is_wall():
	assert_eq(EdgeTemplates.FAMILY_OF[BlocksArt.GRASS_WALL], "wall")
```

- [ ] **Step 2: 跑测试验证失败**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_edge_templates.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现 edge_templates.gd (占位)**

```gdscript
# scripts/art/edge_templates.gd
# 5 族 × 47 边缘模板. 每模板 16×16, 字符语义:
#   .  透明 (显示下面的内部纹理)
#   o  外描边 (outline, 最暗)
#   e  边缘暗影 (edge shadow)
#   h  边缘高光 (edge highlight)
#   H  强高光 (顶部/光照面)
# 调色时按方块自己的 _P_xxx 调色板的 _o/_e/_h/_H 槽位染色.
#
# T2: 全模板初始为全 "." (无装饰, 视觉等同现状).
# T10-T14: 逐族手画填充实际边缘.
extends RefCounted

const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


# tile_id → 边缘族名
const FAMILY_OF: Dictionary = {
	BlocksArt.GRASS: "soil",
	BlocksArt.DIRT: "soil",
	BlocksArt.SAND: "soil",
	BlocksArt.STONE: "rock",
	BlocksArt.DEEP_STONE: "rock",
	BlocksArt.BEDROCK: "rock",
	BlocksArt.COAL_ORE: "rock",
	BlocksArt.IRON_ORE: "rock",
	BlocksArt.PLANKS: "wood",
	BlocksArt.LEAVES: "leaf",
	BlocksArt.LEAVES_PINE: "leaf",
	BlocksArt.LEAVES_AUTUMN: "leaf",
	BlocksArt.GRASS_WALL: "wall",
	BlocksArt.DIRT_WALL: "wall",
	BlocksArt.STONE_WALL: "wall",
}


# 5 族模板字典. TEMPLATES[family][variant_key] = Array[String] 16 行 × 16 字符.
static var TEMPLATES: Dictionary = _build_empty_templates()


static func _build_empty_templates() -> Dictionary:
	var blank: Array = []
	for _i in 16:
		blank.append("................")
	var result: Dictionary = {}
	for fam in ["soil", "rock", "wood", "leaf", "wall"]:
		var fam_dict: Dictionary = {}
		for vk in BlobLookup.VARIANT_KEYS:
			fam_dict[vk] = blank.duplicate()
		result[fam] = fam_dict
	return result
```

- [ ] **Step 4: 跑测试验证通过**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_edge_templates.gd -gexit`
Expected: 10 passing

- [ ] **Step 5: Commit**

```bash
git add scripts/art/edge_templates.gd tests/unit/test_edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): edge_templates 骨架 (5 族×47 全透明占位 + tile→family 映射)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: blocks_art.gd 调色板扩展 + build_atlas()

**Files:**
- Modify: `scripts/art/blocks_art.gd` (15 个调色板字典加 `_o/_e/_h/_H`, 新增 `build_atlas()`)
- Test: `tests/unit/test_blocks_art_atlas.gd`

- [ ] **Step 1: 写失败的测试**

```gdscript
# tests/unit/test_blocks_art_atlas.gd
extends GutTest

const BlocksArt = preload("res://scripts/art/blocks_art.gd")


func test_build_atlas_returns_128x96_texture():
	var tex: ImageTexture = BlocksArt.build_atlas(BlocksArt.STONE)
	assert_not_null(tex)
	var img: Image = tex.get_image()
	assert_eq(img.get_width(), 128)
	assert_eq(img.get_height(), 96)


func test_atlas_isolated_cell_has_content():
	# atlas (0,0) 是 isolated 变体, 应当有非透明像素 (内部纹理被画)
	var tex: ImageTexture = BlocksArt.build_atlas(BlocksArt.STONE)
	var img: Image = tex.get_image()
	var any_opaque: bool = false
	for y in 16:
		for x in 16:
			if img.get_pixel(x, y).a > 0.0:
				any_opaque = true
				break
		if any_opaque:
			break
	assert_true(any_opaque, "isolated 变体应有像素")


func test_atlas_interior_cell_matches_original_pattern():
	# 索引 46 (CCCCIIII = interior, 全闭无凹) 应与现有 get_texture 几乎一致
	# (模板全透明, 仅显示内部纹理)
	var atlas: ImageTexture = BlocksArt.build_atlas(BlocksArt.STONE)
	var single: ImageTexture = BlocksArt.get_texture(BlocksArt.STONE)
	var atlas_img: Image = atlas.get_image()
	var single_img: Image = single.get_image()
	# 索引 46 → col=6, row=5 → pixel offset (96, 80)
	for y in 16:
		for x in 16:
			var atlas_px: Color = atlas_img.get_pixel(96 + x, 80 + y)
			var single_px: Color = single_img.get_pixel(x, y)
			assert_eq(atlas_px, single_px, "(%d,%d) 不匹配" % [x, y])


func test_palette_has_edge_slots():
	# 验证 15 个方块的调色板都有 _o/_e/_h/_H
	var ids: Array = [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.SAND,
		BlocksArt.STONE, BlocksArt.DEEP_STONE, BlocksArt.BEDROCK,
		BlocksArt.COAL_ORE, BlocksArt.IRON_ORE,
		BlocksArt.PLANKS,
		BlocksArt.LEAVES, BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN,
		BlocksArt.GRASS_WALL, BlocksArt.DIRT_WALL, BlocksArt.STONE_WALL,
	]
	for tid in ids:
		var pal: Dictionary = BlocksArt.get_full_palette(tid)
		for slot in ["_o", "_e", "_h", "_H"]:
			assert_true(pal.has(slot), "tile %d 缺 %s" % [tid, slot])
```

- [ ] **Step 2: 跑测试验证失败**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blocks_art_atlas.gd -gexit`
Expected: FAIL ("build_atlas not found")

- [ ] **Step 3: 给 15 个调色板字典加 _o/_e/_h/_H**

为每个适用调色板末尾加 4 个槽位. 选色规则:
- `_o` (outline): 取调色板里**最暗**的颜色再 ×0.6 (alpha 1.0)
- `_e` (edge shadow): 比 base 暗 20%
- `_h` (edge highlight): 比 base 亮 20%
- `_H` (strong highlight): 比 base 亮 50%

具体颜色按方块语义微调. 示例 (STONE):

```gdscript
const _P_STONE := {
	"s": Color8(156, 144, 136),
	"S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158),
	"k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181),
	"m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),
	"o": Color8(184, 154, 130),
	# 新增:
	"_o": Color8(40, 32, 28),    # 极暗 outline
	"_e": Color8(95, 85, 78),    # 边缘暗影
	"_h": Color8(195, 180, 168), # 边缘高光
	"_H": Color8(220, 205, 190), # 顶部强高光
}
```

对所有 15 个适用调色板 (`_P_GRASS, _P_DIRT, _P_SAND, _P_STONE, _P_DEEP_STONE, _P_BEDROCK, _P_COAL_ORE, _P_IRON_ORE, _P_PLANKS, _P_LEAVES, _P_LEAVES_PINE, _P_LEAVES_AUTUMN, _P_GRASS_WALL, _P_DIRT_WALL, _P_STONE_WALL`) 都加 4 槽位, 颜色按上面规则相对各自基底色取值.

- [ ] **Step 4: 新增 `get_full_palette` 和 `build_atlas` 函数**

在 blocks_art.gd 文件末尾添加:

```gdscript
# 返回方块完整调色板 (含 _o/_e/_h/_H 边缘槽位).
static func get_full_palette(tile_id: int) -> Dictionary:
	assert(_PATTERN_MAP.has(tile_id), "未知 tile_id: %d" % tile_id)
	return _PATTERN_MAP[tile_id][1]


# 构建 47 变体 atlas (128×96 = 8 列 × 6 行 × 16 px).
# 仅对 EdgeTemplates.FAMILY_OF 里有的方块有效; 其它方块抛 assert.
static func build_atlas(tile_id: int) -> ImageTexture:
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	const BlobLookup = preload("res://scripts/world/blob_lookup.gd")
	const PixelArt = preload("res://scripts/art/pixel_art.gd")

	assert(EdgeTemplates.FAMILY_OF.has(tile_id),
		"tile %d 没在 FAMILY_OF 里, 不支持 autotile" % tile_id)

	var family: String = EdgeTemplates.FAMILY_OF[tile_id]
	var family_tpl: Dictionary = EdgeTemplates.TEMPLATES[family]
	var base_pattern: Array = _PATTERN_MAP[tile_id][0]
	var palette: Dictionary = _PATTERN_MAP[tile_id][1]
	var transparent := Color(0, 0, 0, 0)

	var atlas_img := Image.create(128, 96, false, Image.FORMAT_RGBA8)
	atlas_img.fill(transparent)

	for i in BlobLookup.VARIANT_KEYS.size():
		var variant_key: String = BlobLookup.VARIANT_KEYS[i]
		var edge: Array = family_tpl[variant_key]
		var col: int = i % 8
		var row: int = i / 8
		var ox: int = col * 16
		var oy: int = row * 16
		for y in 16:
			var base_row: String = base_pattern[y]
			var edge_row: String = edge[y]
			for x in 16:
				var edge_ch: String = edge_row.substr(x, 1)
				var color: Color
				if edge_ch == ".":
					# 显示内部纹理
					var base_ch: String = base_row.substr(x, 1)
					if palette.has(base_ch):
						color = palette[base_ch]
					else:
						color = transparent
				else:
					# 边缘装饰: 用 _o/_e/_h/_H 槽位
					var slot: String = "_" + edge_ch
					if palette.has(slot):
						color = palette[slot]
					else:
						push_warning("tile %d 缺槽位 %s (variant %s)" % [tile_id, slot, variant_key])
						color = transparent
				atlas_img.set_pixel(ox + x, oy + y, color)

	return ImageTexture.create_from_image(atlas_img)
```

- [ ] **Step 5: 跑测试验证通过**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blocks_art_atlas.gd -gexit`
Expected: 4 passing

- [ ] **Step 6: Commit**

```bash
git add scripts/art/blocks_art.gd tests/unit/test_blocks_art_atlas.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 15 调色板加边缘槽位 + build_atlas() 合成 128×96 atlas

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: art_cache.gd — atlas 缓存 + 独立 icon 缓存

**Files:**
- Modify: `scripts/autoload/art_cache.gd`

`block_textures[tile_id]` 的语义变为:
- 若 tile_id 在 EdgeTemplates.FAMILY_OF 里 → 存 128×96 atlas (供 TileSet 用)
- 否则 → 存 16×16 单图 (现有行为, 供 WORKBENCH/DOOR/LOG 等)

`block_icons[tile_id]` 新增, 总是 16×16 单图, 供 UI/物品栏:
- 若是 autotile 方块 → 取 atlas 中 mask=255 (全邻居) 那一格 (interior)
- 否则 → 复用 `block_textures[tile_id]`

- [ ] **Step 1: 改 _build_blocks**

```gdscript
# scripts/autoload/art_cache.gd
const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")

var block_textures: Dictionary = {}        # int → ImageTexture (atlas 或单图)
var block_icons: Dictionary = {}           # int → 16×16 ImageTexture
# ...

func _build_blocks() -> void:
	var tile_ids := [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.STONE, BlocksArt.SAND,
		BlocksArt.LOG, BlocksArt.LEAVES, BlocksArt.PLANKS, BlocksArt.WORKBENCH,
		BlocksArt.DOOR, BlocksArt.BEDROCK,
		BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN, BlocksArt.SLIME_TORCH,
		BlocksArt.DEEP_STONE, BlocksArt.COAL_ORE, BlocksArt.IRON_ORE, BlocksArt.TORCH,
		BlocksArt.GRASS_WALL, BlocksArt.DIRT_WALL, BlocksArt.STONE_WALL,
	]
	for tile_id in tile_ids:
		if EdgeTemplates.FAMILY_OF.has(tile_id):
			block_textures[tile_id] = BlocksArt.build_atlas(tile_id)
			block_icons[tile_id] = _extract_interior_icon(block_textures[tile_id])
		else:
			var single: ImageTexture = BlocksArt.get_texture(tile_id)
			block_textures[tile_id] = single
			block_icons[tile_id] = single


# 从 atlas 抽 mask=255 那一格 (全邻居 interior = "CCCCIIII") 作为 UI 图标.
static func _extract_interior_icon(atlas: ImageTexture) -> ImageTexture:
	var atlas_coord: Vector2i = BlobLookup.ATLAS_COORD[255]
	var ox: int = atlas_coord.x * 16
	var oy: int = atlas_coord.y * 16
	var src: Image = atlas.get_image()
	var dst := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	dst.blit_rect(src, Rect2i(ox, oy, 16, 16), Vector2i.ZERO)
	return ImageTexture.create_from_image(dst)
```

- [ ] **Step 2: 改 get_inventory_icon 用 block_icons**

把 `get_inventory_icon` 函数里 `return block_textures[_ITEM_TO_TILE[item_id]]` 改为 `return block_icons[_ITEM_TO_TILE[item_id]]`.

- [ ] **Step 3: 启动验证不崩**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blocks_art_palette.gd -gexit`
Expected: 现有 palette 测试不应受影响, 全通过.

如果其他依赖 `block_textures` 的代码 (art_preview.gd, main_menu.gd, place_bounce.gd) 现在拿到的是 atlas 而不是 16×16, 视觉会变大. 这些是 P1.5 fx, 不在本 spec 范围. **改它们改用 `block_icons`**:

- `scripts/art_preview.gd:57` — `spr.texture = ArtCache.block_textures[tile_id]` → `block_icons[tile_id]`
- `scripts/ui/main_menu.gd:129` — `ArtCache.block_textures.get(Tiles.TORCH)` → `ArtCache.block_icons.get(Tiles.TORCH)`
- `scripts/fx/place_bounce.gd:14` — `texture = ArtCache.block_textures[tile_id]` → `ArtCache.block_icons[tile_id]`

`tileset_builder.gd:24` 继续用 `block_textures` (它需要 atlas).

- [ ] **Step 4: Commit**

```bash
git add scripts/autoload/art_cache.gd scripts/art_preview.gd scripts/ui/main_menu.gd scripts/fx/place_bounce.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): art_cache atlas + block_icons 单图分离 (UI 用 icon, TileSet 用 atlas)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: tileset_builder.gd — 每 source 47 个 atlas cell

**Files:**
- Modify: `scripts/world/tileset_builder.gd`

每个 atlas source 不再只创建 `Vector2i.ZERO` 一个 cell, 而是创建 47 个 cell (col 0..7, row 0..5, 跳过 col=7 row=5). 每个实心方块的所有 47 cell 都加 16×16 碰撞 polygon.

非 autotile 方块 (LOG, WORKBENCH, DOOR, BEDROCK 但 BEDROCK 在 autotile 里... 等等, BEDROCK 是实心且在 family_of "rock" 里, 所以走 autotile. 不在 family_of 里的: LOG, WORKBENCH, DOOR, SLIME_TORCH, TORCH — 仍保持单 cell.)

- [ ] **Step 1: 改 build() 函数**

```gdscript
# scripts/world/tileset_builder.gd
extends RefCounted

const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	ts.add_physics_layer()

	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
		Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.SLIME_TORCH,
		Tiles.DEEP_STONE, Tiles.COAL_ORE, Tiles.IRON_ORE, Tiles.TORCH,
		Tiles.GRASS_WALL, Tiles.DIRT_WALL, Tiles.STONE_WALL,
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(16, 16)
		ts.add_source(source, tile_id)

		if EdgeTemplates.FAMILY_OF.has(tile_id):
			# Autotile 方块: 创建全部 47 cell
			for i in BlobLookup.VARIANT_KEYS.size():
				var coord := Vector2i(i % 8, i / 8)
				source.create_tile(coord)
				if Tiles.is_solid(tile_id):
					var props = source.get_tile_data(coord, 0)
					props.add_collision_polygon(0)
					props.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
					]))
		else:
			# 非 autotile: 单 cell
			source.create_tile(Vector2i.ZERO)
			if Tiles.is_solid(tile_id):
				var props = source.get_tile_data(Vector2i.ZERO, 0)
				props.add_collision_polygon(0)
				props.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))

	return ts
```

- [ ] **Step 2: 启动游戏验证 TileSet 不报错**

Run: `godot --headless --path /workspace/teilaruia --quit-after 3 res://scenes/world/world.tscn 2>&1 | grep -iE "error|warn" | head -20`
Expected: 没有 "Tile not found" 或 atlas 越界报错. (现有的 libfontconfig 警告等可忽略.)

- [ ] **Step 3: Commit**

```bash
git add scripts/world/tileset_builder.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): tileset_builder — autotile 方块创建 47 cell + 全部加碰撞

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: autotile.gd — 邻居 mask 计算 + refresh 帮手

**Files:**
- Create: `scripts/world/autotile.gd`
- Test: `tests/unit/test_autotile.gd`

`Autotile` 提供 2 个静态函数:
- `refresh_tile(layer, world_pos, tile_id, query)` — 算 mask, set_cell 该一格
- `refresh_with_neighbors(layer, world_pos, query)` — 重算该格 + 8 邻居共 9 格 (用于放置/破坏后)

`query: Callable(x, y) -> int` 由调用者注入, 决定"邻居算不算同一连接族":
- 前景实心: `func(x, y): return Tiles.is_solid(chunk_manager.get_tile(x, y))`
- 前景叶 (按 species): `func(x, y): return chunk_manager.get_tile(x, y) == LEAVES_PINE`
- 背景墙 (按种): 类似

但 query 直接返回 bool (是否"邻居算闭"), 由调用方决定语义.

- [ ] **Step 1: 写失败的测试**

```gdscript
# tests/unit/test_autotile.gd
extends GutTest

const Autotile = preload("res://scripts/world/autotile.gd")


func test_mask_isolated():
	# query 全返回 false → mask = 0
	var query := func(_x: int, _y: int): return false
	assert_eq(Autotile.compute_mask(0, 0, query), 0)


func test_mask_all_solid():
	var query := func(_x: int, _y: int): return true
	assert_eq(Autotile.compute_mask(0, 0, query), 0xFF)


func test_mask_only_north():
	# 只有 (cx, cy-1) 是闭的
	var query := func(x: int, y: int): return x == 5 and y == 9
	# bit 0 = N
	assert_eq(Autotile.compute_mask(5, 10, query), 1)


func test_mask_only_east():
	var query := func(x: int, y: int): return x == 6 and y == 10
	# bit 1 = E
	assert_eq(Autotile.compute_mask(5, 10, query), 2)


func test_mask_diagonal_NE():
	var query := func(x: int, y: int): return x == 6 and y == 9
	# bit 4 = NE
	assert_eq(Autotile.compute_mask(5, 10, query), 16)


func test_mask_NE_corner_full():
	# N + E + NE 都闭
	var solid: Dictionary = {Vector2i(5,9): true, Vector2i(6,10): true, Vector2i(6,9): true}
	var query := func(x: int, y: int): return solid.has(Vector2i(x, y))
	# bits 0 (N) | 1 (E) | 4 (NE) = 19
	assert_eq(Autotile.compute_mask(5, 10, query), 19)
```

- [ ] **Step 2: 跑测试验证失败**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_autotile.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 实现 autotile.gd**

```gdscript
# scripts/world/autotile.gd
# 统一邻居 mask 计算 + TileMapLayer set_cell 的帮手.
# query 参数: Callable(x: int, y: int) -> bool, 返回邻居 (x, y) 是否"与我同族" (闭).
extends RefCounted

const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


# 计算 8-bit 邻居 mask. bits: 0=N 1=E 2=S 3=W 4=NE 5=SE 6=SW 7=NW.
static func compute_mask(world_x: int, world_y: int, query: Callable) -> int:
	var m: int = 0
	if query.call(world_x,     world_y - 1): m |= 1    # N
	if query.call(world_x + 1, world_y):     m |= 2    # E
	if query.call(world_x,     world_y + 1): m |= 4    # S
	if query.call(world_x - 1, world_y):     m |= 8    # W
	if query.call(world_x + 1, world_y - 1): m |= 16   # NE
	if query.call(world_x + 1, world_y + 1): m |= 32   # SE
	if query.call(world_x - 1, world_y + 1): m |= 64   # SW
	if query.call(world_x - 1, world_y - 1): m |= 128  # NW
	return m


# 写入单格 TileMapLayer (带 atlas_coord 自动计算).
# source_id 通常 = tile_id (TileSet 注册时 ID == tile_id).
static func refresh_tile(layer: TileMapLayer, world_pos: Vector2i, source_id: int, query: Callable) -> void:
	var mask: int = compute_mask(world_pos.x, world_pos.y, query)
	var atlas: Vector2i = BlobLookup.ATLAS_COORD[mask]
	layer.set_cell(world_pos, source_id, atlas)


# 重算 (world_pos) + 8 邻居共 9 格. 用于放置/破坏后让周围 atlas_coord 一起更新.
# 每个邻居各自需要查它自己的 source_id (可能是不同方块), 通过 layer.get_cell_source_id 拿到.
# 邻居若是空气 (source_id == -1) 则跳过.
static func refresh_with_neighbors(layer: TileMapLayer, world_pos: Vector2i, query: Callable) -> void:
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			var p := world_pos + Vector2i(dx, dy)
			var sid: int = layer.get_cell_source_id(p)
			if sid == -1:
				continue
			refresh_tile(layer, p, sid, query)
```

- [ ] **Step 4: 跑测试验证通过**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_autotile.gd -gexit`
Expected: 6 passing

- [ ] **Step 5: Commit**

```bash
git add scripts/world/autotile.gd tests/unit/test_autotile.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): Autotile.compute_mask + refresh_tile/refresh_with_neighbors

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: hook autotile 到 world.gd chunk_loaded 渲染

**Files:**
- Modify: `scripts/world/world.gd` (`_on_chunk_loaded`)

把 chunk_loaded 时的两处 `set_cell(coord, tid, Vector2i.ZERO)` 替换成 `Autotile.refresh_tile(...)`, query 走 chunk_manager.

**关键细节**: 前景层的 query 判定"对方是不是实心 (Tiles.is_solid)", 这样符合 spec 的"所有实心方块互相连接". 背景墙的 query 判定"对方是不是相同 wall id".

但叶子是非实心方块, 也需要 autotile (按 species 连接). 所以前景 query 不能简单用 is_solid, 要按当前方块决定查询规则.

简洁方案: 一个工厂函数 `make_query_for(layer, tile_id, chunk_manager)`:
- 若 tile_id 是 leaf 类: query 返回 "邻居 tile_id == tile_id"
- 若 tile_id 是 wall 类 (虽然 wall 不在前景层): query 返回 "邻居 == tile_id"
- 否则 (实心方块): query 返回 "Tiles.is_solid(邻居)"

这个工厂放在 `autotile.gd` 里.

- [ ] **Step 1: 给 autotile.gd 加 make_terrain_query() 和 make_wall_query()**

在 autotile.gd 末尾添加:

```gdscript
# 创建前景层邻居查询. 按 tile_id 类型分:
# - LEAVES/LEAVES_PINE/LEAVES_AUTUMN: 只认相同 species
# - 其它 (实心方块): 认任何实心方块为邻居
# 注意: 此 query 用于前景层 (tiles), 不用于墙层 (walls).
static func make_terrain_query(tile_id: int, chunk_manager: Object) -> Callable:
	const LEAVES = 6
	const LEAVES_PINE = 11
	const LEAVES_AUTUMN = 12
	if tile_id == LEAVES or tile_id == LEAVES_PINE or tile_id == LEAVES_AUTUMN:
		return func(x: int, y: int): return chunk_manager.get_tile(x, y) == tile_id
	return func(x: int, y: int): return Tiles.is_solid(chunk_manager.get_tile(x, y))


# 创建背景墙邻居查询. 各种墙各自独立: 只认相同 wall id.
static func make_wall_query(wall_id: int, chunk_manager: Object) -> Callable:
	return func(x: int, y: int): return chunk_manager.get_wall(x, y) == wall_id
```

- [ ] **Step 2: 改 world.gd::_on_chunk_loaded**

把 line 193-211 的 chunk_loaded handler 改成:

```gdscript
func _on_chunk_loaded(c: Chunk) -> void:
	const Autotile = preload("res://scripts/world/autotile.gd")
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	var chunk_start: int = c.chunk_x * ChunkConstants.CHUNK_WIDTH
	for lx in c.tiles.size():
		var world_x: int = chunk_start + lx
		var col: Array = c.tiles[lx]
		var wall_col: Array = c.walls[lx]
		for y in col.size():
			var tid: int = col[y]
			if tid != Tiles.AIR:
				var pos := Vector2i(world_x, y)
				if EdgeTemplates.FAMILY_OF.has(tid):
					var q := Autotile.make_terrain_query(tid, chunk_manager)
					Autotile.refresh_tile(terrain_layer, pos, tid, q)
				else:
					# 非 autotile 方块 (LOG/WORKBENCH/DOOR/TORCH 等): 单 cell
					terrain_layer.set_cell(pos, tid, Vector2i.ZERO)
			var wid: int = wall_col[y]
			if wid != Tiles.AIR:
				var pos := Vector2i(world_x, y)
				if EdgeTemplates.FAMILY_OF.has(wid):
					var q := Autotile.make_wall_query(wid, chunk_manager)
					Autotile.refresh_tile(wall_layer, pos, wid, q)
				else:
					wall_layer.set_cell(pos, wid, Vector2i.ZERO)
		SkyLightGrid.invalidate_column(world_x)
	world_lighting.on_chunk_loaded(c.chunk_x, ChunkConstants.CHUNK_WIDTH, c.tiles)
	darkness_layer.recompute_chunk(c.chunk_x, ChunkConstants.CHUNK_WIDTH, ChunkConstants.WORLD_HEIGHT)
```

- [ ] **Step 3: 处理跨 chunk 边界重绘**

当新 chunk 加载时, 它的边缘方块查询邻接 chunk 的方块. 若邻接 chunk 未加载, `chunk_manager.get_tile` 返回 AIR → 当前 chunk 边缘方块画成"有外描边" (假象). 后来邻接 chunk 加载时, 它自己会正常渲染, 但**已经画过的**先到 chunk 的边缘列不会自动更新.

修复: 在 `_on_chunk_loaded` 末尾, 额外刷新左右邻接 chunk 的最近 1 列 (若它们已加载).

在 `_on_chunk_loaded` 末尾 (darkness_layer.recompute_chunk 之后) 加:

```gdscript
	# 跨 chunk 边界修正: 刷邻接 chunk 朝向本 chunk 的 1 列
	for neighbor_cx in [c.chunk_x - 1, c.chunk_x + 1]:
		if not chunk_manager.is_chunk_loaded(neighbor_cx):
			continue
		var col_x: int
		if neighbor_cx < c.chunk_x:
			# 左邻接 chunk: 刷它的最右列 (world_x = chunk_start - 1)
			col_x = c.chunk_x * ChunkConstants.CHUNK_WIDTH - 1
		else:
			# 右邻接 chunk: 刷它的最左列
			col_x = (c.chunk_x + 1) * ChunkConstants.CHUNK_WIDTH
		for y in ChunkConstants.WORLD_HEIGHT:
			var sid: int = terrain_layer.get_cell_source_id(Vector2i(col_x, y))
			if sid != -1 and EdgeTemplates.FAMILY_OF.has(sid):
				var q := Autotile.make_terrain_query(sid, chunk_manager)
				Autotile.refresh_tile(terrain_layer, Vector2i(col_x, y), sid, q)
			var wsid: int = wall_layer.get_cell_source_id(Vector2i(col_x, y))
			if wsid != -1 and EdgeTemplates.FAMILY_OF.has(wsid):
				var wq := Autotile.make_wall_query(wsid, chunk_manager)
				Autotile.refresh_tile(wall_layer, Vector2i(col_x, y), wsid, wq)
```

- [ ] **Step 4: 启动游戏验证 chunk 加载不崩 + 视觉无明显回退**

由于此时 edge_templates 全透明, 视觉应**几乎和现状一样** (只是相邻方块之间可能没有了原本的轻微差异, 因为现在所有变体在透明模板下都等于内部纹理). 这是预期的.

Run: `godot --headless --path /workspace/teilaruia --quit-after 5 res://scenes/world/world.tscn 2>&1 | grep -iE "error" | head -10`
Expected: 无新 error (chunk 加载流程跑通).

- [ ] **Step 5: Commit**

```bash
git add scripts/world/autotile.gd scripts/world/world.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): world.gd::_on_chunk_loaded 改用 Autotile.refresh_tile (前景+墙)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: hook autotile 到放置/破坏路径 (with_neighbors)

**Files:**
- Modify: `scripts/world/world.gd` (`_set_tile`)
- Modify: `scripts/player/player_action.gd` (`_finish_mine`, `try_place`)
- Modify: `scripts/world/village_placer.gd` (`place`, `_clear_bounding_rect`)

放置或破坏后, 需重算自己 + 8 邻居. 因为破坏后该格变 air, 邻居的 mask 也变了.

- [ ] **Step 1: 改 world.gd::_set_tile**

把现有 `_set_tile` (line 394-409) 改成:

```gdscript
func _set_tile(x: int, y: int, tile_id: int) -> void:
	const Autotile = preload("res://scripts/world/autotile.gd")
	const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	var old_tid: int = chunk_manager.get_tile(x, y)
	chunk_manager.set_tile(x, y, tile_id)
	var pos := Vector2i(x, y)
	if tile_id == Tiles.AIR:
		terrain_layer.set_cell(pos, -1)
	elif EdgeTemplates.FAMILY_OF.has(tile_id):
		var q := Autotile.make_terrain_query(tile_id, chunk_manager)
		Autotile.refresh_tile(terrain_layer, pos, tile_id, q)
	else:
		terrain_layer.set_cell(pos, tile_id, Vector2i.ZERO)
	# 重算 8 邻居 (它们 mask 变了)
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var npos := pos + Vector2i(dx, dy)
			var nsid: int = terrain_layer.get_cell_source_id(npos)
			if nsid == -1:
				continue
			if EdgeTemplates.FAMILY_OF.has(nsid):
				var nq := Autotile.make_terrain_query(nsid, chunk_manager)
				Autotile.refresh_tile(terrain_layer, npos, nsid, nq)
	SkyLightGrid.invalidate_column(x)
	world_lighting.on_tile_removed(x, y, old_tid)
	world_lighting.on_tile_placed(x, y, tile_id)
	darkness_layer.recompute_around(x, y, 8)
```

- [ ] **Step 2: 改 player_action.gd::_finish_mine (line 211-223)**

`terrain.set_cell(tile, -1)` 后, world._set_tile 会接管刷新, 所以这一行**移除**即可 (world._set_tile 内部清的). 把这一行删掉:

```gdscript
func _finish_mine(tile: Vector2i, tid: int, tool_kind: String, terrain: TileMapLayer) -> void:
	# (移除 terrain.set_cell(tile, -1); world._set_tile 内部处理)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, Tiles.AIR)
	SkyLightGrid.invalidate_column(tile.x)
	Effects.spawn_block_break(tile, tid)
	SfxBank.play("break", 0.15)
	var drops: Dictionary = Tiles.drops_for(tid, tool_kind)
	for item_id in drops:
		for _i in drops[item_id]:
			_spawn_drop(item_id, tile)
```

- [ ] **Step 3: 改 player_action.gd::try_place (line 270)**

同理, 把 `terrain.set_cell(tile, def.placeable_tile_id, Vector2i.ZERO)` 移除, 让 world._set_tile 接管:

```gdscript
	# 在 line 270 删除 terrain.set_cell(...)
	var world: Node = terrain.get_parent()
	if world.has_method("_set_tile"):
		world._set_tile(tile.x, tile.y, def.placeable_tile_id)
	# ... 其余不变 ...
```

- [ ] **Step 4: 改 village_placer.gd::place**

village_placer 在 chunk 加载前就调用 (放村庄), 不能用 world._set_tile. 应直接调用 Autotile.refresh_tile, 并在每屋 stamp 完后给该屋 footprint 的所有邻居刷一遍.

简化方案: village_placer 仍然只写 chunk_manager + 不直接刷 TileMapLayer (line 33, 45, 76 删除 terrain_layer.set_cell). chunk_loaded 信号触发时 world.gd 会从 chunk 数据画一遍 (T7 已实现 autotile 渲染), 自然就把 village 也连上了.

把 line 33 (`terrain_layer.set_cell(pos, -1)`), line 45 (`terrain_layer.set_cell(pos, tid, Vector2i.ZERO)`), line 76 (`terrain_layer.set_cell(pos, -1)`) 全部删除. 同时 `place` 和 `_clear_bounding_rect` 的 `terrain_layer: TileMapLayer` 参数也可删, 调用方对应去掉传参 (查 grep "VillagePlacer.place" 看调用方).

但保险起见, 保留参数 (调用方传 null), 在函数体跳过相关行. 这样调用方不用改. 简单做法:

```gdscript
# village_placer.gd
# 在 line 33: 删除
# 在 line 45: 删除
# 在 line 76: 删除
# (terrain_layer 参数保留但不使用)
```

或者直接把这 3 行 `if terrain_layer != null: terrain_layer.set_cell(...)` 整段删掉.

- [ ] **Step 5: 启动游戏手动验证**

```
godot --path /workspace/teilaruia
```

(用户手动: 1) 加载存档或新世界, 2) 挖一块土, 邻居方块视觉应即时刷新; 3) 放一块土, 同样.)

如果不能交互式启动 (无图形), 跑 chunk streaming integration test:

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_chunk_streaming.gd -gexit`
Expected: 通过 (chunk 加载/卸载流程仍正常).

- [ ] **Step 6: Commit**

```bash
git add scripts/world/world.gd scripts/player/player_action.gd scripts/world/village_placer.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 放置/破坏路径接入 autotile (with_neighbors 自动重算 8 邻居)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: smoke test — 端到端跑通 + 现有测试全过

**Files:**
- (无新改动, 仅验证)

- [ ] **Step 1: 跑全部 unit 测试**

Run: `godot --editor --headless --path /workspace/teilaruia --quit-after 3 2>&1 | tail -5 && godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit 2>&1 | tail -20`
Expected: 全部通过 (含新加的 blob_lookup / edge_templates / blocks_art_atlas / autotile).

- [ ] **Step 2: 跑全部 integration 测试**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit 2>&1 | tail -20`
Expected: 全部通过. 特别注意 test_chunk_streaming, test_mine_drop_pickup, test_workbench_3x3, test_save_full — 这些覆盖 set_cell 路径.

- [ ] **Step 3: 头无图启动 + 5 秒退出**

Run: `godot --headless --path /workspace/teilaruia --quit-after 5 res://scenes/main.tscn 2>&1 | grep -iE "error|push_error" | grep -v libfontconfig | head -10`
Expected: 无新报错.

- [ ] **Step 4 (人审): 在 Mac 上启动游戏看视觉**

(用户操作, 仅验证, 不修改代码:) 打开游戏, 观察:
- 地形仍能看到
- 挖一块/放一块即时刷新
- 此时视觉**应几乎和原版一样** (因为 edge_templates 是全透明占位), 没有边缘装饰. 这是预期, Part 2 开始填模板才会看到泰拉瑞亚效果.

- [ ] **Step 5: Commit (无代码改动则跳过)**

无新代码改动则跳过. 若发现回归需 fix, 提交 fix 后再继续.

---

# Part 2 — 手画 5 族边缘模板

> **执行说明**: 每个 Part 2 task 是「填 1 个 family 的 47 模板」, 不是 5 分钟的活, 实际 1-2 小时手画 + 反复视觉校验. 执行者 (Claude 或 subagent) 应**先画 4 个最关键的 variant** (孤立 / 顶单边 / 三边带凹角 / 全 interior 透明), 跑 atlas 测试 + 启动游戏看视觉, 再补剩余 43 个. 每完成一族即 commit.
>
> **每个 Part 2 task 都是「填 edge_templates.gd 的 1 个 family 字典里的 47 个模板」**. 模板字符:
> - `.` 透明 (显示内部纹理)
> - `o` 外描边 (最暗 — `_o` 槽位)
> - `e` 边缘暗影 (`_e` 槽位)
> - `h` 边缘高光 (`_h` 槽位)
> - `H` 强高光 (`_H` 槽位, 通常顶部)
>
> **47 个 variant_key 的视觉含义** (按 atlas 索引 0..46 排列):
>
> | 索引范围 | 闭边数 | 含义 | 数量 |
> |---|---|---|---|
> | 0       | 0 | 孤立块, 4 角全圆 | 1 |
> | 1-4     | 1 | 单边封闭 (顶/右/底/左), 其它 3 边描边 | 4 |
> | 5-14    | 2 | 双边封闭 (对边或相邻); 相邻时 1 角 (I/X 2 状态) | 10 |
> | 15-30   | 3 | 三边封闭; 2 角各 I/X 共 4 状态 | 16 |
> | 31-46   | 4 | 四边封闭; 4 角各 I/X 共 16 状态 | 16 |
> | **总计** | | | **47** |
>
> **画的优先顺序 (重要程度高 → 低)**:
> 1. 索引 0 (孤立块) — 最显眼, 必画清楚
> 2. 索引 1-4 (单边封闭) — 表面/悬挂块常见
> 3. 索引 31 (CCCCXXXX) 全凹角变体 — 表面坑洼地常见
> 4. 索引 46 (CCCCIIII) 全内部变体 — 应**全透明** (没邻居能看到, 显示纯内部纹理)
> 5. 其他外角 (单边/双边凸出) 次之
> 6. 内凹角 (X 状态) 次之, 因为视觉影响小
>
> **绘画指导原则**:
> - 顶边 (N=open) 朝上 → 画 1 行 `H` (强高光) + 1 行 `e` (轻暗影)
> - 其它边 (E/S/W = open) → 画 1px `o` (外描边)
> - 外凸角 (两边都 open) → 圆角: 角点的 16×16 像素改 `o`, 内退一格
> - 内凹角 (两边闭但对角 open, 即 `X`) → 内角描 1-2 px `e` 暗影 + 高光
> - 内部纹理保持 `.` (透明)

---

### Task 10: 石族 47 模板 (STONE/DEEP_STONE/BEDROCK/COAL_ORE/IRON_ORE)

**Files:**
- Modify: `scripts/art/edge_templates.gd` (在 `_build_empty_templates` 之外定义 `_ROCK_TEMPLATES` 字典 → 在 `_build_empty_templates` 调用末尾替换 `result["rock"] = _ROCK_TEMPLATES`)

风格指南 (石族, 与土族区分):
- 描边硬朗、整齐, 不像土族那样碎
- 顶部高光 1 行 (光从上来)
- 外圆角小 (只圆 1px), 强调"石头方正"感
- 内凹角描 2px 灰暗影 (`e`)
- **不要**在中间出现细节装饰 (留 `.` 让内部 STONE 纹理透出来)

- [ ] **Step 1: 在 edge_templates.gd 顶端定义 _ROCK_TEMPLATES 常量**

(每个 variant 一个 16 行 × 16 字符 ASCII grid. 完整 47 项. 因数据量大, 在执行此 task 时直接填到源文件; 这里给 3 个示例作为模式参考.)

```gdscript
# 示例 (实际执行 task 时填全部 47 项):
const _ROCK_TEMPLATES := {
	# 孤立块: 4 圆角 + 顶高光 + 4 边描边
	"OOOO....": [
		".oHHHHHHHHHHHHo.",
		"oHHHHHHHHHHHHHHo",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oH............He",
		"oeeeeeeeeeeeeeeo",
		".oeeeeeeeeeeeeo.",
	],
	# 只 N 邻居: 顶无装饰, 其它 3 边描边 + 圆 BL/BR 角
	"COOO....": [
		"................",
		"................",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"o..............e",
		"oeeeeeeeeeeeeeeo",
		".oeeeeeeeeeeeeo.",
	],
	# 全闭 + 全 interior: 完全透明 (露出内部纹理)
	"CCCCIIII": [
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
		"................",
	],
	# ... 其余 44 项 ...
}
```

(完成任务时, **每个 variant_key 都必须存在**; 用 BlobLookup.VARIANT_KEYS 遍历对照填.)

- [ ] **Step 2: 把 _ROCK_TEMPLATES 装到 TEMPLATES 字典**

修改 `_build_empty_templates`, 让 "rock" 族返回 `_ROCK_TEMPLATES.duplicate()` 而不是占位 blank:

```gdscript
static func _build_empty_templates() -> Dictionary:
	var blank: Array = []
	for _i in 16:
		blank.append("................")
	var result: Dictionary = {}
	for fam in ["soil", "wood", "leaf", "wall"]:
		var fam_dict: Dictionary = {}
		for vk in BlobLookup.VARIANT_KEYS:
			fam_dict[vk] = blank.duplicate()
		result[fam] = fam_dict
	result["rock"] = _ROCK_TEMPLATES.duplicate(true)
	return result
```

- [ ] **Step 3: 跑 edge_templates 单元测试验证模板格式合法**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_edge_templates.gd -gexit`
Expected: 全过 (尺寸 + 47 个 key 都在).

- [ ] **Step 4: 跑 blocks_art_atlas 测试验证 atlas 仍能合成**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blocks_art_atlas.gd -gexit`
Expected: 全过.

- [ ] **Step 5: 视觉验证 (人审 + 截图)**

启动游戏到一片有 STONE / DEEP_STONE / COAL_ORE / IRON_ORE 的地下区域. 观察:
- 孤立 1 块石头 → 看到 4 圆角 + 顶高光
- 大块石头 → 中间无装饰, 边缘有描边
- 石头里嵌矿 → 矿和石之间无黑边 (因为同属实心连接族)

如果效果不对, 修改对应 variant_key 的 grid, 重跑测试.

- [ ] **Step 6: Commit**

```bash
git add scripts/art/edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 石族 47 手画边缘模板 (硬朗描边 + 顶高光 + 小圆角)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: 土族 47 模板 (GRASS/DIRT/SAND)

**Files:**
- Modify: `scripts/art/edge_templates.gd` (新增 `_SOIL_TEMPLATES` + 替换 result["soil"])

风格指南 (土族, 与石族区分):
- 描边**碎**, 不是直线: 边缘像素位置略带随机抖动 (左右 ±1 px)
- 顶部高光更暖 (调色板 _H 是暖金黄)
- 外圆角更大 (2-3 px), 强调"土质柔软"
- 描边偶有"颗粒掉落" (1 个 `o` 像素孤立在描边下 1-2 行)
- GRASS 的顶部高光会自动用 GRASS 调色板的 `_H` (绿黄), DIRT 的会用棕色, SAND 的会用沙黄 — 同一模板自动适配各方块

- [ ] **Step 1: 定义 _SOIL_TEMPLATES 47 项**

按石族同样的格式, 风格上更碎. 在 edge_templates.gd 加常量字典.

- [ ] **Step 2: 把 _SOIL_TEMPLATES 装到 TEMPLATES**

```gdscript
result["soil"] = _SOIL_TEMPLATES.duplicate(true)
```

- [ ] **Step 3: 跑测试**

Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_edge_templates.gd -gexit`
Run: `godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gselect=test_blocks_art_atlas.gd -gexit`
Expected: 全过.

- [ ] **Step 4: 视觉验证**

启动游戏到地表草地+土地区域. 观察:
- 草顶高光 → 暖金黄 1-2 行
- 单块土飘空中 → 4 大圆角 + 碎描边
- 草+土相邻 → 无黑边过渡 (实心同族)
- 沙滩 → 描边略有颗粒散落感

- [ ] **Step 5: Commit**

```bash
git add scripts/art/edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 土族 47 手画边缘模板 (碎描边 + 暖高光 + 大圆角)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: 叶族 47 模板 (LEAVES/LEAVES_PINE/LEAVES_AUTUMN)

**Files:**
- Modify: `scripts/art/edge_templates.gd` (新增 `_LEAF_TEMPLATES` + 替换 result["leaf"])

风格指南 (叶族, 最特殊):
- 描边呈**簇状凹凸**, 不是直线: 每 2-3 px 一个突起/凹陷
- 透明像素较多 — 表现"叶子轮廓不规则" (描边外侧间或有 `.` 让背景透过)
- 不需要顶部高光 (叶子本身有 _LEAVES 调色板的 `h` 高光)
- 外圆角呈"啃咬感"
- 叶族只连同种叶 → 一棵橡木旁边的松树, 两种叶之间会有各自的描边可见

- [ ] **Step 1: 定义 _LEAF_TEMPLATES 47 项**

参考橡叶现有图案 (16×16 _LEAVES 已经是簇状), 边缘模板顺应这个轮廓.

- [ ] **Step 2: 装到 TEMPLATES + 跑测试**

```gdscript
result["leaf"] = _LEAF_TEMPLATES.duplicate(true)
```

Run unit tests. Expected: 全过.

- [ ] **Step 3: 视觉验证**

启动游戏到树林. 观察:
- 单棵橡树叶簇 → 描边呈不规则啃咬感
- 橡 + 松树相邻 → 两种叶之间能看到各自的边
- 一片同种叶 (内部) → 描边消失, 露出内部纹理

- [ ] **Step 4: Commit**

```bash
git add scripts/art/edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 叶族 47 手画边缘模板 (簇状描边 + 啃咬圆角 + 透明颗粒)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 13: 墙族 47 模板 (GRASS_WALL/DIRT_WALL/STONE_WALL)

**Files:**
- Modify: `scripts/art/edge_templates.gd` (新增 `_WALL_TEMPLATES` + 替换 result["wall"])

风格指南 (墙族, 最弱):
- 描边比土/石更**淡**, 用 `e` 而不是 `o` 做主描边
- 无 `H` 强高光 (墙在背景里, 不需要"亮"感)
- 外圆角小 (1 px) + 偶有 `e` 阴影做"凹陷感"
- 三种墙各自独立连接, 不同墙之间会显出各自的描边

- [ ] **Step 1: 定义 _WALL_TEMPLATES 47 项**

风格偏暗、淡, 像"远在背景"的感觉.

- [ ] **Step 2: 装到 TEMPLATES + 跑测试**

```gdscript
result["wall"] = _WALL_TEMPLATES.duplicate(true)
```

Run unit tests. Expected: 全过.

- [ ] **Step 3: 视觉验证**

启动游戏到有墙的区域 (地表草墙 / 中层土墙 / 深层石墙). 观察:
- 一片连续墙 → 描边内部消失, 视为整片
- 草墙 ↔ 土墙交界 → 各自有淡描边可见
- 墙 + 前景方块 → 互不影响 (墙在 wall_layer, 前景在 terrain_layer)

- [ ] **Step 4: Commit**

```bash
git add scripts/art/edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 墙族 47 手画边缘模板 (淡描边 + 无强高光 + 凹陷感)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 14: 木族 47 模板 (PLANKS)

**Files:**
- Modify: `scripts/art/edge_templates.gd` (新增 `_WOOD_TEMPLATES` + 替换 result["wood"])

风格指南 (木族, 单方块):
- 描边带**木色** (棕暗) — `_o` 取深棕而不是黑
- 顶高光 1 行偏暖
- 圆角中等
- 不同方向的描边强度略不同 (顶/底比左右略强, 强调"木板是横铺")

- [ ] **Step 1: 定义 _WOOD_TEMPLATES 47 项**

PLANKS 是建材, 玩家造房子多, 边缘要清晰可见.

- [ ] **Step 2: 装到 TEMPLATES + 跑测试**

```gdscript
result["wood"] = _WOOD_TEMPLATES.duplicate(true)
```

Run unit tests. Expected: 全过.

- [ ] **Step 3: 视觉验证**

启动游戏, 用木板搭一个 3×3 小房子. 观察:
- 房子外缘 → 木色描边清晰可见
- 房子内部 → 描边消失, 整片木板纹理连续
- 单块木板飘空中 (玩家测试) → 4 圆角

- [ ] **Step 4: Commit**

```bash
git add scripts/art/edge_templates.gd
git -c user.name="Claude" -c user.email="claude@anthropic.com" commit -m "feat(autotile): 木族 47 手画边缘模板 (木色描边 + 暖顶高光)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 15: 收尾 — 全 GUT 测试 + 视觉总验

**Files:**
- (无代码改动)

- [ ] **Step 1: 跑完整 GUT 测试套**

Run: `godot --editor --headless --path /workspace/teilaruia --quit-after 5 && godot --headless --path /workspace/teilaruia -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -30`
Expected: 全部通过. 数到具体多少 (现有 + 新加的 4 套测试).

- [ ] **Step 2: 启动游戏跑 60 秒, 看 chunk load 无报错**

Run: `godot --headless --path /workspace/teilaruia --quit-after 60 res://scenes/main.tscn 2>&1 | grep -iE "error|push_error" | grep -v libfontconfig | wc -l`
Expected: 0

- [ ] **Step 3: 视觉总验 (人审)**

(用户操作:) 启动游戏, 巡游地表 → 地下, 观察:
- ✅ 地形大块连接顺滑, 边缘有装饰
- ✅ 孤立方块 4 圆角
- ✅ 不同族之间能看到差异 (草边碎, 石边硬)
- ✅ 挖一块/放一块即时刷新, 8 邻居都正确
- ✅ 跨 chunk 边界也正常 (走到 chunk 边缘, 看视觉不闪)
- ✅ UI 物品栏图标仍是单 16×16 (用 block_icons)

- [ ] **Step 4: 如无 commit-able 改动, 跳过提交**

如果中途修了 bug, 提交修复. 否则不提交.

---

## 总结

**预期 commit 数:** ~14 (Part 1 共 8, Part 2 共 5, smoke test 0-2)

**关键文件 LOC 变化估算:**
- `blob_lookup.gd`: 新 ~80 行
- `edge_templates.gd`: 新 ~50 行骨架 + 5 族 × 47 模板 × ~17 行 = ~4000 行 (主要是 ASCII 数据)
- `autotile.gd`: 新 ~60 行
- `blocks_art.gd`: 改 +60 行 (调色板) +50 行 (build_atlas)
- `art_cache.gd`: 改 +20 行
- `tileset_builder.gd`: 改 +15 行
- `world.gd`: 改 +25 行
- `player_action.gd`: 改 -2 行 (删 set_cell)
- `village_placer.gd`: 改 -3 行

**测试新增:** 4 个文件, 约 30 个 test 函数.

**关键依赖顺序 (不能跳)**: T1 → T2 → T3 → T4 → T5 → T6 → T7 → T8 → T9, 然后 T10-T14 任意顺序 (推荐按"用户最常见" 优先级 = 石→土→叶→墙→木), 最后 T15.
