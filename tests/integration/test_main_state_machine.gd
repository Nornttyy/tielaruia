extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _make() -> Node:
	var m = MainScene.instantiate()
	add_child_autofree(m)
	return m


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_starts_in_menu_state():
	var m = _make()
	await get_tree().process_frame
	assert_eq(m._state, "menu")
	assert_true(m._main_menu.visible)


func test_boot_to_game_transitions_to_game():
	var m = _make()
	await get_tree().process_frame
	m.boot_to_game()
	await wait_frames(2)
	assert_eq(m._state, "game")
	assert_ne(m.world, null, "world 已实例化")
	assert_ne(m.world.get_player(), null, "player 已实例化")


func test_return_to_menu_clears_game_nodes():
	var m = _make()
	await get_tree().process_frame
	m.boot_to_game()
	await wait_frames(2)
	m._return_to_menu()
	await wait_frames(2)
	assert_eq(m._state, "menu")
	assert_eq(m._game_nodes.size(), 0, "game 节点已清空")
	assert_eq(m.world, null, "world 已销毁")
