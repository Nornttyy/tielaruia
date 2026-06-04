# 水源块 tile: 实心·可挖·不掉物·有贴图·不算流动液体.
extends GutTest

const WaterSim = preload("res://scripts/world/water_sim.gd")


func test_water_source_tile_defined():
	assert_eq(Tiles.WATER_SOURCE, 86, "WATER_SOURCE = 86 (下一个空 id, 84/85 是门)")
	assert_true(Tiles.is_solid(Tiles.WATER_SOURCE), "水源块实心 (能挖能站, 水从底下冒)")


func test_water_source_drops_nothing():
	# 挖掉不掉物 → 玩家拿不到 → 防无限水
	var drops: Dictionary = Tiles.drops_for(Tiles.WATER_SOURCE, "pickaxe")
	assert_eq(drops.size(), 0, "水源块挖了不掉物品")


func test_water_source_texture_built():
	assert_not_null(ArtCache.block_textures.get(Tiles.WATER_SOURCE), "水源块该有世界贴图 (没画=不显示)")


func test_water_source_not_liquid():
	var sim = WaterSim.new()
	add_child_autofree(sim)
	assert_false(sim.is_liquid(Tiles.WATER_SOURCE), "水源块不算流动液体 (免污染游泳/作物判定)")
