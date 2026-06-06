# 端到端: 玩家能走上草斜坡 (move_and_slide + floor_max_angle); 挖斜砖掉 dirt 变 AIR.
extends GutTest
const MainScene = preload("res://scenes/main.tscn")
const TILE := 12.0

func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main

# 手搭: 在玩家脚下造一段 "平地 → ◢ → 高 1 格平地", 放玩家在低平地, 按右, 看 y 是否上升.
func test_player_walks_up_slope() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var pt: Vector2i = player.get_node("PlayerAction").player_tile()
	var bx: int = pt.x
	var gy: int = pt.y + 1   # 玩家脚下那行作地面
	# 低平地 (bx..bx+1) 地面 gy; 斜砖 ◢ 在 (bx+2, gy-1); 高平地 (bx+3..) 地面 gy-1
	for dx in range(0, 2):
		world._set_tile(bx + dx, gy, Tiles.GRASS)
		world._set_tile(bx + dx, gy - 1, Tiles.AIR)
	world._set_tile(bx + 2, gy - 1, Tiles.GRASS_SLOPE_R)
	world._set_tile(bx + 2, gy, Tiles.GRASS)
	for dx in range(3, 7):
		world._set_tile(bx + dx, gy - 1, Tiles.GRASS)
		world._set_tile(bx + dx, gy - 2, Tiles.AIR)
	# 玩家落到低平地站稳
	player.global_position = Vector2((bx + 0.5) * TILE, (gy - 1) * TILE)
	await wait_frames(10)
	var y_before: float = player.global_position.y
	# 持续按右 ~40 帧
	for _i in range(40):
		Input.action_press("move_right")
		await wait_frames(1)
	Input.action_release("move_right")
	var y_after: float = player.global_position.y
	assert_lt(y_after, y_before - TILE * 0.5, "玩家该顺斜坡走上去 (y 上升至少半格)")

func test_mine_slope_drops_dirt_and_clears() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var player = world.get_player()
	var action = player.get_node("PlayerAction")
	var inv = player.get_node("PlayerInventory")
	inv.pickup("wood_pickaxe", 1); inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var sx: int = pt.x + 2
	var sy: int = pt.y
	world._set_tile(sx, sy, Tiles.GRASS_SLOPE_R)
	world._set_tile(sx, sy + 1, Tiles.DIRT)
	action.aim_override = Vector2i(sx, sy)
	action.primary_override = true
	for _i in range(60):
		await wait_frames(1)
		if terrain.get_cell_source_id(Vector2i(sx, sy)) == -1:
			break
	action.primary_override = false
	assert_eq(terrain.get_cell_source_id(Vector2i(sx, sy)), -1, "斜砖挖掉变 AIR")
