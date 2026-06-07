# 3 格门集成: 自动开关 / 整扇挖掉 / 放置占 3 连格.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_door_auto_open_and_close() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var cm = world.chunk_manager
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 4
	var by: int = pt.y
	# 放一扇关着的门 (底/中/顶)
	world._set_tile(bx, by, Tiles.DOOR)
	world._set_tile(bx, by - 1, Tiles.DOOR_MID)
	world._set_tile(bx, by - 2, Tiles.DOOR_TOP)
	# 玩家挪到门旁 → 一 tick → 整扇开
	player.global_position = Vector2((bx - 1) * 6 + 3, by * 6 + 3)
	world._tick_doors()
	assert_eq(cm.get_tile(bx, by), Tiles.DOOR_OPEN, "靠近: 门底应开")
	assert_eq(cm.get_tile(bx, by - 1), Tiles.DOOR_OPEN, "靠近: 门中应开")
	assert_eq(cm.get_tile(bx, by - 2), Tiles.DOOR_OPEN, "靠近: 门顶应开")
	# 玩家走远 → 一 tick → 整扇关回
	player.global_position = Vector2((bx - 30) * 6 + 3, by * 6 + 3)
	world._tick_doors()
	assert_eq(cm.get_tile(bx, by), Tiles.DOOR, "走远: 门底应关回")
	assert_eq(cm.get_tile(bx, by - 1), Tiles.DOOR_MID, "走远: 门中应关回")
	assert_eq(cm.get_tile(bx, by - 2), Tiles.DOOR_TOP, "走远: 门顶应关回")


func test_mine_removes_whole_door() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	# 距离 3: 在 4 格触及内, 但在自动开门盒 (±2) 外 → 保持关着, 测纯挖
	var bx: int = pt.x + 3
	var by: int = pt.y
	world._set_tile(bx, by, Tiles.DOOR)
	world._set_tile(bx, by - 1, Tiles.DOOR_MID)
	world._set_tile(bx, by - 2, Tiles.DOOR_TOP)
	# 挖中段 → 整扇消失
	action.aim_override = Vector2i(bx, by - 1)
	action.primary_override = true
	await wait_seconds(0.9)
	action.primary_override = false
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by)), -1, "门底应被挖掉")
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by - 1)), -1, "门中应被挖掉")
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by - 2)), -1, "门顶应被挖掉")


func test_place_makes_3_connected_tiles() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var cm = world.chunk_manager
	inv.pickup("door", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 2
	var by: int = pt.y
	# 清出门位 + 上方 2 格空; 下方给地 (支撑)
	world._set_tile(bx, by, Tiles.AIR)
	world._set_tile(bx, by - 1, Tiles.AIR)
	world._set_tile(bx, by - 2, Tiles.AIR)
	world._set_tile(bx, by + 1, Tiles.DIRT)
	action.aim_override = Vector2i(bx, by)
	var ok: bool = action.try_place()
	assert_true(ok, "应能放下 3 格门")
	assert_eq(cm.get_tile(bx, by), Tiles.DOOR, "放置: 门底")
	assert_eq(cm.get_tile(bx, by - 1), Tiles.DOOR_MID, "放置: 门中")
	assert_eq(cm.get_tile(bx, by - 2), Tiles.DOOR_TOP, "放置: 门顶")
