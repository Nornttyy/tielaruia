# tileset region 缩到 6px。
extends GutTest


func test_tileset_region_is_6() -> void:
	var ts: TileSet = load("res://scripts/world/tileset_builder.gd").build()
	assert_eq(ts.tile_size, Vector2i(6, 6), "TileSet tile_size 应 6x6")
	# 抽一个 source 的 region
	var src := ts.get_source(Tiles.DIRT) as TileSetAtlasSource
	assert_eq(src.texture_region_size, Vector2i(6, 6), "atlas region 应 6x6")


func test_resize_to_6() -> void:
	# 16px 原图缩到 6px: 1 cell → 6x6
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var tex := ImageTexture.create_from_image(img)
	var out: ImageTexture = ArtCache._smart_resize_atlas(tex, 6)
	assert_eq(out.get_width(), 6)
	assert_eq(out.get_height(), 6)
