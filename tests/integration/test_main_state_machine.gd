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


func test_start_game_signal_creates_loading_screen():
	var m = _make()
	await get_tree().process_frame
	m._main_menu.start_game.emit({"world_seed": 42, "world_name": "t", "difficulty": 1})
	await get_tree().process_frame
	var ls: CanvasLayer = null
	for c in m.get_children():
		if c is CanvasLayer and c.name == "LoadingScreen":
			ls = c
			break
	assert_not_null(ls, "_start_game 应创建 LoadingScreen")


func test_loading_screen_removed_after_load_completes():
	var m = _make()
	await get_tree().process_frame
	m._main_menu.start_game.emit({"world_seed": 42, "world_name": "t", "difficulty": 1})
	# 等加载流程 (7 步 + 0.5s 淡出 ≈ 1-2s, 给充足余量)
	await get_tree().create_timer(3.0).timeout
	for c in m.get_children():
		assert_ne(c.name, "LoadingScreen", "加载完成后 LoadingScreen 应被 queue_free")
	assert_eq(m._state, "game")
	assert_ne(m.world, null)
	assert_ne(m.world.get_player(), null)


func test_boot_to_game_skips_loading_screen():
	# boot_to_game 走老路径, 不创建 LoadingScreen
	var m = _make()
	await get_tree().process_frame
	m.boot_to_game(42)
	await wait_frames(2)
	for c in m.get_children():
		assert_ne(c.name, "LoadingScreen", "boot_to_game 不应创建 LoadingScreen")
	assert_eq(m._state, "game")
