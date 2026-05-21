extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_villager_spawns_in_world():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var villagers = get_tree().get_nodes_in_group("villagers")
	assert_eq(villagers.size(), 1, "应有 1 个村民被 spawn")


func test_e_near_villager_opens_dialogue():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world = main.get_node("World")
	var player: Node2D = world.get_player()
	var villagers = get_tree().get_nodes_in_group("villagers")
	assert_gt(villagers.size(), 0)
	var v: Node2D = villagers[0]
	# 把玩家挪到村民身边
	player.global_position = v.global_position + Vector2(8, 0)
	var action: Node2D = player.get_node("PlayerAction")
	action._try_open_workbench_or_close()
	var db = get_tree().get_first_node_in_group("dialogue_box")
	assert_not_null(db)
	assert_true(db.visible, "对话框应被打开")
	assert_ne(db._line_label.text, "", "应显示一条词条")
