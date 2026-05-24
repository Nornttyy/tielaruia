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
