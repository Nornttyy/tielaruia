extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")


func test_world_generates_with_village_planks_near_spawn():
	var w = WorldScene.instantiate()
	w.world_seed = 42   # 固定种子保证可重现
	add_child_autofree(w)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawn: Vector2i = w.spawn_point
	# 房 1 anchor_x=5 anchor_y=-3 → 左上 (spawn.x+5, spawn.y-3) 应是 planks
	var roof_corner: Vector2i = spawn + Vector2i(5, -3)
	assert_eq(
		w.chunk_manager.get_tile(roof_corner.x, roof_corner.y),
		Tiles.PLANKS,
		"村庄房 1 左上角应是 planks"
	)


func test_world_records_villager_spawn():
	var w = WorldScene.instantiate()
	w.world_seed = 42
	add_child_autofree(w)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(w.village_villager_spawns.size(), 1, "应有 1 个待 spawn 村民")


func test_door_at_house_entry():
	var w = WorldScene.instantiate()
	w.world_seed = 42
	add_child_autofree(w)
	await get_tree().process_frame
	await get_tree().process_frame
	var spawn: Vector2i = w.spawn_point
	# 房 1 grid 行 3 列 0 是 D, anchor=(5,-3) → 世界 (spawn.x+5, spawn.y)
	var door_pos: Vector2i = spawn + Vector2i(5, 0)
	assert_eq(
		w.chunk_manager.get_tile(door_pos.x, door_pos.y),
		Tiles.DOOR,
		"门应在房 1 左下"
	)
