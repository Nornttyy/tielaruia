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
	# 索引 = ATLAS_COORD[255] 对应 "CCCCIIII" (全闭+全 interior) 变体,
	# 模板全透明 → 应仅显示内部纹理, 像素与原 get_texture 一致
	const BlobLookup = preload("res://scripts/world/blob_lookup.gd")
	var atlas: ImageTexture = BlocksArt.build_atlas(BlocksArt.STONE)
	var single: ImageTexture = BlocksArt.get_texture(BlocksArt.STONE)
	var atlas_img: Image = atlas.get_image()
	var single_img: Image = single.get_image()
	var coord: Vector2i = BlobLookup.ATLAS_COORD[255]
	var ox: int = coord.x * 16
	var oy: int = coord.y * 16
	for y in 16:
		for x in 16:
			var atlas_px: Color = atlas_img.get_pixel(ox + x, oy + y)
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
