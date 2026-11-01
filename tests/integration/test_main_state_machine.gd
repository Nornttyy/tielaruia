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


# Await the actual completion condition, not a fixed machine-dependent delay.
func _wait_for_load(main: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + 45000
	while main._loading and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_false(main._loading, "Load must finish within 45 seconds")
	await get_tree().process_frame

func test_new_world_is_frozen_until_ready_then_restores_processing():
	var main = _make()
	main._main_menu.start_game.emit({"world_seed": 42, "world_name": "load-test", "world_size": 0})
	var screen = main.get_node("LoadingScreen")
	assert_true(screen.generating)
	assert_not_null(screen.get_node("Content/TitleLayer/OriginalLogo").texture)
	await get_tree().process_frame
	assert_true(main._loading)
	assert_eq(main.world.process_mode, Node.PROCESS_MODE_DISABLED)
	var pause := InputEventAction.new()
	pause.action = "ui_pause"
	pause.pressed = true
	main._unhandled_input(pause)
	assert_false(get_tree().paused, "Cannot pause halfway through world initialization")
	await _wait_for_load(main)
	assert_null(main.get_node_or_null("LoadingScreen"))
	assert_eq(main.world.process_mode, Node.PROCESS_MODE_INHERIT)
	assert_not_null(main.world.get_player())
	assert_gt(_item_count(main, "copper_pickaxe"), 0)

func test_saved_world_restores_inventory_and_position_before_fade():
	var data := SaveData.new()
	data.version = 4
	data.world_seed = 42
	data.world_size = 0
	data.player_position = Vector2(600, -1200)
	data.player_hp = 77.0
	data.inventory_slots = [{"item_id": "torch", "count": 12}]
	var main = _make()
	main._continue_game(data)
	var screen = main.get_node("LoadingScreen")
	assert_false(screen.generating)
	var deadline: int = Time.get_ticks_msec() + 45000
	while not screen._finishing and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_true(screen._finishing)
	assert_null(main._pending_save_data)
	assert_gt(main.world.get_node("DarknessLayer").update_count, 0, "Lighting must be ready behind the fading overlay")
	assert_eq(main.world.get_player().position, data.player_position)
	assert_eq(main.world.get_player().get_node("PlayerHealth").current_health, 77)
	assert_eq(_item_count(main, "torch"), 12)
	assert_eq(_item_count(main, "copper_pickaxe"), 0)
	assert_null(main._autosave_timer, "No save before restoration and world reveal")
	await _wait_for_load(main)
	assert_null(main.get_node_or_null("LoadingScreen"))


func test_boot_to_game_skips_loading_screen():
	# boot_to_game 走老路径, 不创建 LoadingScreen
	var m = _make()
	await get_tree().process_frame
	m.boot_to_game(42)
	await wait_frames(2)
	for c in m.get_children():
		assert_ne(c.name, "LoadingScreen", "boot_to_game 不应创建 LoadingScreen")
	assert_eq(m._state, "game")

func _item_count(main: Node, item_id: String) -> int:
	var count := 0
	for slot in main.world.get_player().get_node("PlayerInventory").inventory.slots:
		if slot != null and slot.item_id == item_id:
			count += slot.count
	return count
