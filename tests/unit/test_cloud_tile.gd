extends GutTest

# 云块: 实心可挖, 木镐就能挖, 掉 cloud 物品; cloud 物品能放回 CLOUD tile.
func test_cloud_tile_is_solid_mineable():
	assert_true(Tiles.is_solid(Tiles.CLOUD), "云块实心 (能站上去)")
	assert_true(Tiles.is_mineable(Tiles.CLOUD), "云块可挖")

func test_cloud_drops_cloud_item():
	# drops_for 权重 100 → cloud 必出 (dict: {item_id: count})
	var drops: Dictionary = Tiles.drops_for(Tiles.CLOUD, "")
	assert_true(drops.has("cloud"), "挖云块掉 cloud 物品")

func test_cloud_item_places_cloud_tile():
	var def = ItemDB.get_def("cloud")
	assert_not_null(def, "cloud 物品存在")
	assert_eq(def["placeable_tile_id"], Tiles.CLOUD, "cloud 物品放下去是 CLOUD tile")
