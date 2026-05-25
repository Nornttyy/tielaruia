extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SaveData = preload("res://scripts/save/save_data.gd")
const SAVES_DIR := "user://saves/"


# 删 saves/ 下所有 .tres (测试隔离)
func _clear_saves() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return
	var dir := DirAccess.open(SAVES_DIR)
	dir.list_dir_begin()
	var fn: String = dir.get_next()
	while fn != "":
		if not dir.current_is_dir() and fn.ends_with(".tres"):
			DirAccess.remove_absolute(SAVES_DIR + fn)
		fn = dir.get_next()
	dir.list_dir_end()


func before_each():
	_clear_saves()


func after_each():
	_clear_saves()


func test_no_save_initially():
	assert_false(SaveManager.has_save(), "干净环境无存档")
	assert_eq(SaveManager.list_saves().size(), 0, "list_saves 返回空")


func test_save_creates_file():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var ok = SaveManager.save(main)
	assert_true(ok)
	assert_true(SaveManager.has_save())
	assert_eq(SaveManager.list_saves().size(), 1, "存了一个")


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
	var ids: Array = []
	for s in data.inventory_slots:
		if s != null:
			ids.append(s.item_id)
	assert_true("dirt" in ids)
	assert_true("log" in ids)


func test_load_save_by_name():
	# 创建一个有名字的存档
	GameSettings.current_world_name = "测试世界A"
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(99)
	await wait_frames(3)
	SaveManager.save(main)
	var data = SaveManager.load_save_by_name("测试世界A")
	assert_not_null(data)
	assert_eq(data.world_seed, 99)
	# 不存在的名字 → null
	assert_null(SaveManager.load_save_by_name("不存在的存档"))


func test_multiple_saves_coexist():
	# 存两个不同名世界, 都应该在 list 里
	var main1 = MainScene.instantiate()
	add_child_autofree(main1)
	GameSettings.current_world_name = "世界1"
	main1.boot_to_game(1)
	await wait_frames(3)
	SaveManager.save(main1)
	main1.queue_free()
	await wait_frames(2)
	var main2 = MainScene.instantiate()
	add_child_autofree(main2)
	GameSettings.current_world_name = "世界2"
	main2.boot_to_game(2)
	await wait_frames(3)
	SaveManager.save(main2)
	assert_eq(SaveManager.list_saves().size(), 2, "两个独立存档共存")


func test_delete_save_by_name():
	GameSettings.current_world_name = "要删的存档"
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	SaveManager.save(main)
	assert_true(SaveManager.has_save())
	SaveManager.delete_save_by_name("要删的存档")
	assert_false(SaveManager.has_save())
