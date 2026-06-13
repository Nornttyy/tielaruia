# _reset_arena 工具: 重建竞技场把搭的方块清掉。
# (注: 切模式已不再调它 — 用户改主意要保留方块; 清场只发生在 赢了重开 / 空房满 1 分钟。)
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
