# 群系水 (沙漠/丛林/沼泽 不同颜色的满水) 验收: tile 定义 + 统一判定 + 贴图生成 + 生成上色.
extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


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


func test_biome_water_tile_mapping() -> void:
	# 群系 → 水色 映射: 森林/雪原 = 通用蓝, 其余各自颜色
	assert_eq(WorldGenerator._biome_water_tile(WorldGenerator.BIOME_DESERT), Tiles.WATER_DESERT)
	assert_eq(WorldGenerator._biome_water_tile(WorldGenerator.BIOME_JUNGLE), Tiles.WATER_JUNGLE)
	assert_eq(WorldGenerator._biome_water_tile(WorldGenerator.BIOME_SWAMP), Tiles.WATER_SWAMP)
	assert_eq(WorldGenerator._biome_water_tile(WorldGenerator.BIOME_FOREST), Tiles.WATER, "森林=通用蓝")
	assert_eq(WorldGenerator._biome_water_tile(WorldGenerator.BIOME_SNOW), Tiles.WATER, "雪原=通用蓝")


func test_generation_places_biome_colored_water() -> void:
	# 世界 x=0..W-1, 只含正槽位 600/1200 两个群系 (至少一个可上色, 因只有 1 个是雪原).
	# 生成 1600 宽世界, 扫全图: 该能找到至少一种群系色的水 (绿洲/水塘/洞穴池/地下海).
	var seed: int = 7
	var w: Dictionary = WorldGenerator.generate(seed, 1600, 256)
	var found: bool = false
	for x in range(1600):
		var col: Array = w.tiles[x]
		for y in range(256):
			var t: int = col[y]
			if t == Tiles.WATER_DESERT or t == Tiles.WATER_JUNGLE or t == Tiles.WATER_SWAMP:
				found = true
				break
		if found:
			break
	assert_true(found, "1600 宽世界 (含 600/1200 槽位) 里该有群系色的水")


func test_forest_surface_has_ponds() -> void:
	# 出生点在森林, 用户该在地表看到水. 数森林区地表带 [80,150) 的水格.
	var w: Dictionary = WorldGenerator.generate(11, 800, 256)
	var surface_water: int = 0
	for x in range(50, 480):   # 森林区 (非森林槽位在 x>=500)
		var col: Array = w.tiles[x]
		for y in range(80, 150):
			if Tiles.is_water(col[y]):
				surface_water += 1
	assert_gt(surface_water, 120, "森林地表该有成片的水塘 (实际 %d 格)" % surface_water)
