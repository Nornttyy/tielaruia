# 流体流动验收: 岩浆流动 + 水/岩浆=石头
extends GutTest


func test_lava_level_tiles_defined() -> void:
	assert_eq(Tiles.LAVA_L1, 71, "LAVA_L1 = 71")
	assert_eq(Tiles.LAVA_L2, 72, "LAVA_L2 = 72")
	assert_eq(Tiles.LAVA_L3, 73, "LAVA_L3 = 73")
	assert_false(Tiles.is_solid(Tiles.LAVA_L1), "LAVA_L1 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L2), "LAVA_L2 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L3), "LAVA_L3 非实心")
