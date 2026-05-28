extends GutTest

# 验证存档 bug 修复: _continue_game 走异步 _run_async_load,
# _apply_save_data 不能用 call_deferred 那种"下一帧" -- 那时 world 还没 init,
# chunk_manager 还是 null, 应用存档就崩了 (玩家位置/血/背包全没还原).
#
# 这个测试模拟用户路径: 改状态 → save → 回菜单 → continue → 验状态还原.

const MainScene = preload("res://scenes/main.tscn")
const SAVES_DIR := "user://saves/"
const TEST_SAVE_NAME := "_test_continue_restore"


func _clean_saves() -> void:
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.begins_with("_test_"):
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()


func before_each():
	_clean_saves()


func after_each():
	_clean_saves()


# 用户 bug: 存档"只保留时间, 别的都消失".
# 改状态 → save → continue → 验状态完整还原.
func test_continue_game_restores_full_state():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(12345)
	await wait_frames(5)

	var world = main.world
	assert_not_null(world, "world ready after boot")
	var player: Node2D = world.get_player()
	assert_not_null(player, "player exists")

	# 改玩家状态: 位置 + 背包
	var saved_pos := Vector2(600.0, -250.0)
	player.global_position = saved_pos
	var inv_node: Node = player.get_node("PlayerInventory")
	inv_node.pickup("dirt", 42)

	# 改 chunk: 在 world (10, 5) 放 stone (验 chunk_deltas 序列化)
	world.chunk_manager.set_tile(10, 5, Tiles.STONE)

	# 存档
	GameSettings.current_world_name = TEST_SAVE_NAME
	var ok := SaveManager.save(main)
	assert_true(ok, "save 写盘成功")

	# 读 SaveData 验字段存好了
	var data = SaveManager.load_save_by_name(TEST_SAVE_NAME)
	assert_not_null(data, "load 读到 SaveData")
	assert_eq(data.player_position, saved_pos, "SaveData 里位置对")
	var dirt_in_save: bool = false
	for s in data.inventory_slots:
		if s != null and s.get("item_id", "") == "dirt" and s.get("count", 0) == 42:
			dirt_in_save = true
			break
	assert_true(dirt_in_save, "SaveData 里有 dirt×42")
	assert_true(data.chunk_deltas.size() > 0, "SaveData 里有 chunk delta")

	# 模拟"回主菜单 → 点 continue": 走 _continue_game 异步路径
	main._return_to_menu()
	await wait_frames(5)
	assert_eq(main._state, "menu", "回到 menu 状态")

	main._continue_game(data)
	# _run_async_load 7 步 + tween fade, 给充足时间走完
	await wait_frames(120)
	assert_eq(main._state, "game", "continue 后回到 game 状态")

	# 关键验证: 状态是否真的还原?
	var new_world = main.world
	assert_not_null(new_world, "新 world 存在")
	var new_player: Node2D = new_world.get_player()
	assert_not_null(new_player, "新 player 存在")
	# x 应精确还原 (没有横向重力). y 可能被重力拉下来 (saved=-250 在空中),
	# 所以 y 只验"在合理范围" (saved_y 到 saved_y + 600 之间, 600 = 几秒重力下落).
	assert_almost_eq(new_player.global_position.x, saved_pos.x, 2.0, "玩家 x 位置还原")
	assert_between(new_player.global_position.y, saved_pos.y, saved_pos.y + 600.0,
		"玩家 y 在 saved 位置附近 (允许重力下落)")

	var new_inv: Node = new_player.get_node("PlayerInventory")
	var has_saved_dirt: bool = false
	for s in new_inv.inventory.slots:
		if s != null and s.item_id == "dirt" and s.count == 42:
			has_saved_dirt = true
			break
	assert_true(has_saved_dirt, "背包里 dirt×42 还原 (这是用户报的 bug)")

	# chunk delta: 不能只看 count (村庄生成器会写额外 delta),
	# 验我具体放的那块 stone tile 还在.
	var cm = new_world.chunk_manager
	assert_true(cm._deltas.has(0), "chunk 0 的 delta 还原 (含我放的 stone)")
	if cm._deltas.has(0):
		var inner: Dictionary = cm._deltas[0]
		assert_eq(inner.get(Vector2i(10, 5), -999), Tiles.STONE,
			"world (10,5) 的 stone 还原")
