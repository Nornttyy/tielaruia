extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_walk_loads_new_chunks_unloads_old():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world = main.get_node("World")
	var cm: Node = world.chunk_manager
	# 初始 5 chunks (-2..2)
	assert_eq(cm.loaded_chunk_count(), 5)
	# 瞬移玩家到 chunk 10 (world_x ≈ 10 * 64 * 16 = 10240)
	var player: Node2D = world.get_player()
	player.global_position = Vector2(10 * 64 * 12 + 100, player.global_position.y)
	await wait_frames(3)
	# chunk 10 ± 2 应加载, 老的卸载
	for cx in [8, 9, 10, 11, 12]:
		assert_true(cm.is_chunk_loaded(cx), "走远后 chunk %d 应 loaded" % cx)
	for cx in [-2, 0, 2]:
		assert_false(cm.is_chunk_loaded(cx), "走远后老 chunk %d 应 unloaded" % cx)


func test_modified_tile_persists_after_unload_reload():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world = main.get_node("World")
	var cm: Node = world.chunk_manager
	# 改 chunk 0 内一个 tile
	world._set_tile(10, 50, Tiles.STONE)
	assert_eq(cm.get_tile(10, 50), Tiles.STONE)
	# 走远卸载 chunk 0
	var player: Node2D = world.get_player()
	player.global_position = Vector2(10 * 64 * 12 + 100, player.global_position.y)
	await wait_frames(3)
	assert_false(cm.is_chunk_loaded(0), "走远后 chunk 0 应 unloaded")
	# 走回来加载
	player.global_position = Vector2(100, player.global_position.y)
	await wait_frames(3)
	assert_true(cm.is_chunk_loaded(0), "走回 chunk 0 应 loaded")
	assert_eq(cm.get_tile(10, 50), Tiles.STONE, "改过的 tile 在 reload 后恢复 (delta 持久)")
