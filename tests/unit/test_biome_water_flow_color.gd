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
