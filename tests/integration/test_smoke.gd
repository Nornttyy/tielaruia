extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_main_scene_loads_without_crash():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	assert_not_null(main, "Main 节点存在")
	var world = main.get_node_or_null("World")
	assert_not_null(world, "World 子节点存在")


func test_player_spawns_and_falls_to_ground():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player, "玩家被实例化")
	var initial_y = player.global_position.y
	# 跑 60 帧 (~1 秒)；玩家应该落地或保持稳定
	await wait_frames(60)
	assert_lt(player.global_position.y, 256 * 16.0, "玩家未掉出世界底部")
	assert_gt(player.global_position.y, initial_y - 100.0, "玩家未飞天 (排除奇怪动量)")


func test_sky_light_grid_initialized():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	# 顶部 (0,0) 应被天光直射
	assert_true(SkyLightGrid.is_sky_exposed(0, 0), "世界顶部有天光")
	# 底部 (0, 250) 应该被遮挡
	assert_false(SkyLightGrid.is_sky_exposed(0, 250), "世界底部无天光")
