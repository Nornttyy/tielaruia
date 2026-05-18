extends GutTest

const BlocksArt = preload("res://scripts/art/blocks_art.gd")


func test_palette_for_grass_returns_two_colors():
	var palette = BlocksArt.get_palette(BlocksArt.GRASS)
	assert_eq(palette.size(), 2)
	assert_true(palette[0] is Color)
	assert_true(palette[1] is Color)


func test_palette_for_stone():
	var palette = BlocksArt.get_palette(BlocksArt.STONE)
	assert_eq(palette.size(), 2)
	# stone 偏灰，base 灰度应 >= dark 灰度
	assert_gt(palette[0].r + palette[0].g + palette[0].b,
		palette[1].r + palette[1].g + palette[1].b)


func test_palette_for_log():
	var palette = BlocksArt.get_palette(BlocksArt.LOG)
	assert_eq(palette.size(), 2)


func test_palette_for_air_returns_default():
	# AIR (0) 没调色板，返回 fallback (2 个颜色，可以是任意)
	var palette = BlocksArt.get_palette(BlocksArt.AIR)
	assert_eq(palette.size(), 2)


func test_palette_for_unknown_returns_default():
	var palette = BlocksArt.get_palette(9999)
	assert_eq(palette.size(), 2)
