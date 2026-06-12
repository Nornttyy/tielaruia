# 对战房方块共享 (用户改: 同一房间能看到彼此搭的方块)。
# 玩家手动搭/挖 → 同步给同房间的人; 但竞技场地基 (PvpArena.build 几万格) 不广播 (各端本地铺)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func _boot() -> Node:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


# 对战房: 对方搭的方块 → 本地应用 (看得到)
func test_pvp_applies_remote_tile_changes():
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	var main = await _boot()
	var world = main.get_node("World")
	var cm = world.chunk_manager
	var pt: Vector2i = world.get_player().get_node("PlayerAction").player_tile()
	var tx: int = pt.x + 3
	var ty: int = pt.y
	world._set_tile(tx, ty, Tiles.AIR)
	NetworkManager.status = "connected"
	NetworkManager.room_mode = "pvp"
	world._on_remote_tile(tx, ty, Tiles.DIRT)
	assert_eq(cm.get_tile(tx, ty), Tiles.DIRT, "对战房该应用对方搭的方块 (看得到彼此搭的)")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


# 竞技场地基铺设期间 _arena_building=true (不广播); build 跑完归 false
func test_arena_build_suppresses_broadcast_then_clears():
	var main = await _boot()
	var world = main.get_node("World")
	assert_false(world._arena_building, "平时不在铺地基")
	PvpArena.build(world)
	assert_false(world._arena_building, "build 跑完该归 false (玩家搭/挖恢复广播)")
