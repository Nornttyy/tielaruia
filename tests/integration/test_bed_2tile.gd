# 2 格宽床集成: 放置占 2 连格 / 砍任一半整张消 / 点任一半都能睡 + 玩家躺床中央。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE := 6.0


func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return main


func test_place_makes_2_connected_tiles() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var cm = world.chunk_manager
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("bed", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 3
	var by: int = pt.y
	# 清出床位 (左+右) 空, 下方给地做支撑
	world._set_tile(bx, by, Tiles.AIR)
	world._set_tile(bx + 1, by, Tiles.AIR)
	world._set_tile(bx, by + 1, Tiles.DIRT)
	action.aim_override = Vector2i(bx, by)
	var ok: bool = action.try_place()
	assert_true(ok, "应能放下 2 格床")
	assert_eq(cm.get_tile(bx, by), Tiles.BED, "放置: 左半 (床头)")
	assert_eq(cm.get_tile(bx + 1, by), Tiles.BED_RIGHT, "放置: 右半 (床尾)")
	# 视觉层也要有 (确认 BED_RIGHT 进了 tileset, 否则不显示)
	assert_ne(terrain.get_cell_source_id(Vector2i(bx + 1, by)), -1, "右半要进 tileset 能显示")


func test_place_blocked_when_right_tile_occupied() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var cm = world.chunk_manager
	inv.pickup("bed", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 3
	var by: int = pt.y
	world._set_tile(bx, by, Tiles.AIR)
	world._set_tile(bx + 1, by, Tiles.STONE)   # 右格被占
	world._set_tile(bx, by + 1, Tiles.DIRT)
	action.aim_override = Vector2i(bx, by)
	var ok: bool = action.try_place()
	assert_false(ok, "右格被占 → 放不了 (2 格床需要 2 格空)")
	assert_ne(cm.get_tile(bx, by), Tiles.BED, "左格也不该放上")


func test_mine_left_half_removes_both() -> void:
	await _mine_one_half_removes_both(false)


func test_mine_right_half_removes_both() -> void:
	await _mine_one_half_removes_both(true)


func _mine_one_half_removes_both(mine_right: bool) -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 2   # 床左+2/右+3, 两半都稳在 REACH_TILES(4) 内 (放 +3 时右半 +4 是边界, 玩家轻微漂移即够不着)
	var by: int = pt.y
	world._set_tile(bx, by, Tiles.BED)
	world._set_tile(bx + 1, by, Tiles.BED_RIGHT)
	# 砍左半 (bx) 或右半 (bx+1) → 整张都该消 (硬度 0.5, ~30 物理帧挖完). 逐帧轮询到挖完为止.
	action.aim_override = Vector2i(bx + 1, by) if mine_right else Vector2i(bx, by)
	action.primary_override = true
	for _i in range(60):
		await wait_frames(1)
		if terrain.get_cell_source_id(Vector2i(bx, by)) == -1 \
				and terrain.get_cell_source_id(Vector2i(bx + 1, by)) == -1:
			break
	action.primary_override = false
	assert_eq(terrain.get_cell_source_id(Vector2i(bx, by)), -1, "左半应被挖掉")
	assert_eq(terrain.get_cell_source_id(Vector2i(bx + 1, by)), -1, "右半应联动消掉")


func test_sleep_centers_player_on_2wide_bed() -> void:
	var main = await _boot()
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var pt: Vector2i = action.player_tile()
	var bx: int = pt.x + 3
	var by: int = pt.y
	world._set_tile(bx, by, Tiles.BED)
	world._set_tile(bx + 1, by, Tiles.BED_RIGHT)
	world.sleep_in_bed(Vector2i(bx, by))   # 锚点=左格
	assert_true(world._sleeping, "应进入睡觉")
	# 床中央 = 左右两格接缝 = (bx + 1.0) * TILE
	assert_almost_eq(player.global_position.x, (float(bx) + 1.0) * TILE, 1.0, "玩家躺床正中 (不偏左)")
	world._wake_up()
