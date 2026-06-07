# 水下植物: 集合判定 + chunk_manager 元数据层 的纯逻辑测试。
extends GutTest


func test_submersible_set() -> void:
	assert_true(Tiles.is_submersible_plant(Tiles.PLANT_GRASS), "装饰草可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.MUSHROOM), "蘑菇可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.WHEAT_0), "小麦可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.RICE_0), "稻子可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.LOG), "树干可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.LEAVES), "树叶可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.CACTUS), "仙人掌可淹")
	assert_false(Tiles.is_submersible_plant(Tiles.TORCH), "火把不淹 (功能件)")
	assert_false(Tiles.is_submersible_plant(Tiles.ROPE), "绳子不淹 (功能件)")
	assert_false(Tiles.is_submersible_plant(Tiles.STONE), "石头不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.AIR), "空气不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.WATER), "水不淹")
