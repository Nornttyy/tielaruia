# 水下植物: 集合判定 + chunk_manager 元数据层 的纯逻辑测试。
extends GutTest

const ChunkManager = preload("res://scripts/world/chunk_manager.gd")
const SaveData = preload("res://scripts/save/save_data.gd")


func test_submersible_set() -> void:
	# 用户要求: 只有装饰小草会被水淹没; 别的植物碰水都不消失 (水绕开它们)。
	assert_true(Tiles.is_submersible_plant(Tiles.PLANT_GRASS), "装饰小草可淹 (唯一例外)")
	assert_false(Tiles.is_submersible_plant(Tiles.MUSHROOM), "蘑菇不淹 (碰水不消失)")
	assert_false(Tiles.is_submersible_plant(Tiles.WHEAT_0), "小麦不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.RICE_0), "稻子不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.CACTUS), "仙人掌不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.LOG), "树干不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.LEAVES), "树叶不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.TORCH), "火把不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.ROPE), "绳子不淹")
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


func test_submerged_save_roundtrip() -> void:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.set_submerged(5, 100, Tiles.MUSHROOM)
	cm.set_submerged(-3, 50, Tiles.WHEAT_1)
	var serialized: Dictionary = SaveManager._serialize_submerged(cm)
	var cm2 = ChunkManager.new()
	add_child_autofree(cm2)
	SaveManager.apply_submerged(cm2, serialized)
	assert_eq(cm2.get_submerged(5, 100), Tiles.MUSHROOM, "序列化往返: 蘑菇还在")
	assert_eq(cm2.get_submerged(-3, 50), Tiles.WHEAT_1, "序列化往返: 小麦还在")


func test_old_save_without_submerged_field() -> void:
	var data = SaveData.new()
	assert_eq(data.submerged_plants, {}, "新建 SaveData 该默认空 submerged_plants")
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	SaveManager.apply_submerged(cm, {})   # 不该崩
	assert_eq(cm.get_submerged(0, 0), -1, "空档应用后无记录")
