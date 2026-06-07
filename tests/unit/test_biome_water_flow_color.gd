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
