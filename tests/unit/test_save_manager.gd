extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SaveData = preload("res://scripts/save/save_data.gd")
const SAVE_PATH := "user://save.tres"


func before_each():
	# 清理上一次测试可能留的存档
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func after_each():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_no_save_initially():
	assert_false(SaveManager.has_save(), "干净环境无存档")


func test_save_creates_file():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var ok = SaveManager.save(main)
	assert_true(ok)
	assert_true(SaveManager.has_save())


func test_save_captures_seed_and_spawn():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(3)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	assert_not_null(data)
	assert_eq(data.world_seed, 42)
	var world = main.get_node("World")
	assert_eq(data.spawn_point, world.spawn_point)


func test_save_captures_player_position_and_hp():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world = main.get_node("World")
	var player = world.get_player()
	player.global_position = Vector2(123, 456)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	assert_eq(data.player_position, Vector2(123, 456))


func test_save_captures_inventory():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv_node = player.get_node("PlayerInventory")
	inv_node.inventory.add("dirt", 5)
	inv_node.inventory.add("log", 3)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	assert_eq(data.inventory_slots.size(), 36, "9+27 = 36 槽")
	# 至少有 dirt 和 log 在快照里
	var ids: Array = []
	for s in data.inventory_slots:
		if s != null:
			ids.append(s.item_id)
	assert_true("dirt" in ids)
	assert_true("log" in ids)


func test_delete_save_removes_file():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	SaveManager.save(main)
	assert_true(SaveManager.has_save())
	SaveManager.delete_save()
	assert_false(SaveManager.has_save())
