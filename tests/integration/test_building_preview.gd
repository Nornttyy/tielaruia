extends GutTest
const MainScene = preload("res://scenes/main.tscn")

func test_preview_lights_camera_and_return_to_menu():
	var previous_creative := GameSettings.creative_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main._start_art_preview()
	await get_tree().process_frame
	await get_tree().physics_frame
	var world = main.world
	assert_eq(world.camera.zoom, Vector2(2, 2), "预览镜头不被延迟的设置刷新覆盖")
	assert_gt(world.world_lighting.get_light_tiles().size(), 6, "预制屋火把必须真的发光")
	assert_null(main._autosave_timer, "美术场景不启动正常存档")
	assert_false(GameSettings.creative_mode, "试走仍然保留重力和正常跳跃")
	# 真正的世界入口必须刷新枝干接点，不能只在新生成时正确。
	var branch: Vector2i = world.spawn_point + Vector2i(-23, -6)
	var trunk: Vector2i = branch + Vector2i.RIGHT
	assert_eq(world.chunk_manager.get_tile(branch.x, branch.y), Tiles.BRANCH_L)
	assert_eq(world.terrain_layer.get_cell_atlas_coords(trunk).y, 1)
	world._set_tile(branch.x, branch.y, Tiles.AIR, true)
	assert_eq(world.terrain_layer.get_cell_atlas_coords(trunk).y, 0, "拆掉侧枝后去掉树干接头")
	world._set_tile(branch.x, branch.y, Tiles.BRANCH_L, true)
	assert_eq(world.terrain_layer.get_cell_atlas_coords(trunk).y, 1, "重新连接侧枝后恢复接头")
	# 在实际场景放置/拆除一块木材，验证数据、图层和音效一起更新。
	var player = world.get_player()
	var action = player.get_node("PlayerAction")
	var inventory = player.get_node("PlayerInventory")
	inventory.set_hotbar_selection(1)
	var target: Vector2i = action.player_tile() + Vector2i(-2, -1)
	for audio_player in SfxBank._players: audio_player.stop()
	watch_signals(SfxBank)
	assert_true(action.try_place(target))
	assert_eq(world.chunk_manager.get_tile(target.x, target.y), Tiles.PLANKS)
	assert_eq(world.terrain_layer.get_cell_source_id(target), Tiles.PLANKS)
	assert_signal_emit_count(SfxBank, "sound_played", 1)
	action._mining_sound_cooldown = 0.0
	action._finish_mine(target, Tiles.PLANKS, "pickaxe", world.terrain_layer)
	assert_eq(world.chunk_manager.get_tile(target.x, target.y), Tiles.AIR)
	assert_signal_emit_count(SfxBank, "sound_played", 2)
	main._return_to_menu()
	await get_tree().process_frame
	assert_eq(main._state, "menu")
	assert_true(main._main_menu.visible)
	assert_eq(TimeOfDay.time_multiplier, 1.0)
	GameSettings.creative_mode = previous_creative
