# 群系水 (沙漠/丛林/沼泽 不同颜色的满水) 验收: tile 定义 + 统一判定 + 贴图生成.
extends GutTest


func test_biome_water_constants() -> void:
	assert_eq(Tiles.WATER_DESERT, 81, "WATER_DESERT = 81")
	assert_eq(Tiles.WATER_JUNGLE, 82, "WATER_JUNGLE = 82")
	assert_eq(Tiles.WATER_SWAMP, 83, "WATER_SWAMP = 83")


func test_is_water_covers_all() -> void:
	for t in [Tiles.WATER, Tiles.WATER_L1, Tiles.WATER_L2, Tiles.WATER_L3,
			Tiles.WATER_DESERT, Tiles.WATER_JUNGLE, Tiles.WATER_SWAMP]:
		assert_true(Tiles.is_water(t), "tile %d 该算水" % t)
	assert_false(Tiles.is_water(Tiles.STONE), "石头不是水")
	assert_false(Tiles.is_water(Tiles.LAVA), "岩浆不是水")
	assert_false(Tiles.is_water(Tiles.AIR), "空气不是水")


func test_biome_water_not_solid_not_mineable() -> void:
	for t in [Tiles.WATER_DESERT, Tiles.WATER_JUNGLE, Tiles.WATER_SWAMP]:
		assert_false(Tiles.is_solid(t), "群系水非实心 (玩家能游)")
		assert_false(Tiles.is_mineable(t), "群系水不可挖")


func test_biome_water_textures_built() -> void:
	# 三种群系水都该在 ArtCache 有世界贴图 (没注册进 tileset_builder/art_cache 会缺)
	for t in [Tiles.WATER_DESERT, Tiles.WATER_JUNGLE, Tiles.WATER_SWAMP]:
		assert_not_null(ArtCache.block_textures.get(t), "群系水 %d 该有世界贴图" % t)
