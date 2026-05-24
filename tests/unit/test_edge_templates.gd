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


# ─── 石族 (T10) 行为校验 ─────────────────────────────────────────────────

func test_rock_isolated_has_full_outline_and_top_highlight():
	# OOOO.... = 孤立块: 4 边都开 → 顶部 H 高光行 + 底部 o 描边行 + 左右描边
	var grid: Array = EdgeTemplates.TEMPLATES["rock"]["OOOO...."]
	# 顶部 row 0 应是 H (除掉 4 角的圆角 1 像素): ".HHHHHHHHHHHHHH."
	assert_eq(grid[0], ".HHHHHHHHHHHHHH.")
	# 底部 row 15 应是 o 描边 (4 角削): ".oooooooooooooo."
	assert_eq(grid[15], ".oooooooooooooo.")


func test_rock_interior_is_all_transparent():
	# CCCCIIII = 全闭 + 全内部 角: 应完全透明 (无边缘装饰)
	var grid: Array = EdgeTemplates.TEMPLATES["rock"]["CCCCIIII"]
	for row in grid:
		assert_eq(row, "................")


func test_rock_only_top_open_draws_top_edge_only():
	# N 开, E/S/W 闭 + 底部 2 角 (SE/SW) 都 interior: 顶部 2 行有装饰, 其它行全透明
	# key: N=O E=C S=C W=C, 角 NE=. (N 开 → 无关), SE=I, SW=I, NW=. (N 开)
	var grid: Array = EdgeTemplates.TEMPLATES["rock"]["OCCC.II."]
	assert_eq(grid[0], "HHHHHHHHHHHHHHHH", "顶 H")
	assert_eq(grid[1], "eeeeeeeeeeeeeeee", "顶 e 过渡")
	for y in range(2, 16):
		assert_eq(grid[y], "................", "row %d 应透明" % y)


func test_slope_templates_has_soil_with_82_variants():
	# slope-aware 模板字典. 当前只 soil 族有 (GRASS/DIRT 用).
	assert_true(EdgeTemplates.SLOPE_TEMPLATES.has("soil"))
	assert_eq(EdgeTemplates.SLOPE_TEMPLATES["soil"].size(), 82)


func test_is_slope_tile_grass_dirt_only():
	assert_true(EdgeTemplates.is_slope_tile(BlocksArt.GRASS))
	assert_true(EdgeTemplates.is_slope_tile(BlocksArt.DIRT))
	assert_false(EdgeTemplates.is_slope_tile(BlocksArt.SAND))
	assert_false(EdgeTemplates.is_slope_tile(BlocksArt.STONE))


func test_slope_template_NE_triangle_paints_TR_corner():
	# slope key: 4 边都开 + NE 对角在 → NE-slope = P. 应在 TR 角画三角.
	# key = "OOOO....P___" (sides 4 + corners 4 + slopes 4)
	var grid: Array = EdgeTemplates.SLOPE_TEMPLATES["soil"]["OOOO....P___"]
	# TR 角 (右上) 应有非"."字符 (三角填充)
	# 检 (col 15, row 0) 应是 "H" (三角内部) 或 "o" (外缘) — 反正不是 "."
	var tr_pixel: String = grid[0].substr(15, 1)
	assert_ne(tr_pixel, ".", "TR 角应有 slope 填充")
	# 而 BR 角 (col 15, row 15) 仍应是底边的字符 (不是 ".") 或边缘装饰; 这里只验 NE slope 没影响其它角
	# 简单验: BL 角 (col 0, row 15) 应是底边 o 描边 (sides 都开 → 底边画了)
	var bl_pixel: String = grid[15].substr(0, 1)
	assert_eq(bl_pixel, ".", "BL 角应被圆角削掉 (S+W 都开 + 2px 圆角)")


func test_rock_concave_NW_draws_corner_pixels():
	# CCCC...X = 4 边都闭, NW 角凹 (其它角为 I): NW 角应有 3 像素 L 形 e 阴影
	# 注意 key 字符: 4=NE 5=SE 6=SW 7=NW
	var grid: Array = EdgeTemplates.TEMPLATES["rock"]["CCCCIIIX"]
	# NW 角 (左上): 像素 (0,0), (1,0), (0,1) 应为 "e", 其它仍透明
	assert_eq(grid[0].substr(0, 2), "ee", "NW row 0 前 2px")
	assert_eq(grid[1].substr(0, 1), "e", "NW row 1 前 1px")
	# 其它角应仍透明 (interior)
	assert_eq(grid[0].substr(14, 2), "..", "NE 角应透明")
	assert_eq(grid[15].substr(14, 2), "..", "SE 角应透明")
	assert_eq(grid[15].substr(0, 2), "..", "SW 角应透明")
