# 切模式 = 新一局: 重置竞技场, 把玩家搭的方块清掉 (用户报: 换模式方块还在)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const PvpModePanel = preload("res://scripts/ui/pvp_mode_panel.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func test_reset_arena_clears_placed_blocks():
	var prev_mode = NetworkManager.room_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	NetworkManager.room_mode = "pvp"
	PvpArena.build(world)                 # 先铺干净竞技场
	# 在竞技场清理区内(中央上空)搭一个方块
	var tx: int = PvpArena.CENTER_X
	var ty: int = PvpArena.FLOOR_Y - 10
	world._set_tile(tx, ty, Tiles.DIRT)
	assert_eq(world.chunk_manager.get_tile(tx, ty), Tiles.DIRT, "前置: 先搭一个 dirt")
	# 切模式触发的重置
	panel._reset_arena()
	assert_ne(world.chunk_manager.get_tile(tx, ty), Tiles.DIRT, "重置竞技场后, 搭的方块该被清掉")
	NetworkManager.room_mode = prev_mode
