# 对战房方块独立 (用户: 每个模式是独立房间, 方块互不同步)。
# 对战房 (room_mode=pvp) 收到对方的方块改动应被忽略; 生存房则正常应用。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot() -> Node:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_pvp_ignores_remote_tile_changes():
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	var main = await _boot()
	var world = main.get_node("World")
	var cm = world.chunk_manager
	# 选玩家附近一个 tile, 先本地清成空气
	var pt: Vector2i = world.get_player().get_node("PlayerAction").player_tile()
	var tx: int = pt.x + 3
	var ty: int = pt.y
	world._set_tile(tx, ty, Tiles.AIR)
	assert_eq(cm.get_tile(tx, ty), Tiles.AIR, "前置: 该格先是空气")

	# 对战房: 对方发来"在这放 dirt" → 该被忽略 (各房独立)
	NetworkManager.status = "connected"
	NetworkManager.room_mode = "pvp"
	world._on_remote_tile(tx, ty, Tiles.DIRT)
	assert_eq(cm.get_tile(tx, ty), Tiles.AIR, "对战房该忽略对方方块改动 (仍是空气)")

	# 生存房: 同样的远程改动 → 正常应用
	NetworkManager.room_mode = "survival"
	world._on_remote_tile(tx, ty, Tiles.DIRT)
	assert_eq(cm.get_tile(tx, ty), Tiles.DIRT, "生存房该正常同步对方方块 (变 dirt)")

	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_pvp_host_skips_initial_state_broadcast():
	# host 在对战房不广播地形 delta (各端本地 build 同一竞技场)
	var prev_m = NetworkManager.room_mode
	var main = await _boot()
	var world = main.get_node("World")
	NetworkManager.room_mode = "pvp"
	# 不该抛错 + 直接 return (无 bridge 环境下也安全)
	world._mp_broadcast_initial_state()
	world._on_initial_state({"0": [0, 50, Tiles.STONE]})
	# initial_state 在 pvp 被忽略 → 不写入 (0,50) 这格
	assert_ne(world.chunk_manager.get_tile(0, 50), Tiles.STONE, "对战房不应用对方 initial_state 地形")
	NetworkManager.room_mode = prev_m
