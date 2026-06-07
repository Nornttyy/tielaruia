# 水下植物: 集合判定 + chunk_manager 元数据层 的纯逻辑测试。
extends GutTest

const ChunkManager = preload("res://scripts/world/chunk_manager.gd")


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


func test_submerged_get_set_clear() -> void:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	assert_eq(cm.get_submerged(5, 100), -1, "没记录该返 -1")
	cm.set_submerged(5, 100, Tiles.PLANT_GRASS)
	assert_eq(cm.get_submerged(5, 100), Tiles.PLANT_GRASS, "记下后该取到")
	cm.clear_submerged(5, 100)
	assert_eq(cm.get_submerged(5, 100), -1, "清掉后该返 -1")


func test_submerged_different_chunks_no_bleed() -> void:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.set_submerged(5, 100, Tiles.MUSHROOM)
	cm.set_submerged(5 + 1000, 100, Tiles.WHEAT_1)   # 远处另一区块
	assert_eq(cm.get_submerged(5, 100), Tiles.MUSHROOM, "本区块记录不被远处覆盖")
	assert_eq(cm.get_submerged(5 + 1000, 100), Tiles.WHEAT_1, "远处区块各记各的")
