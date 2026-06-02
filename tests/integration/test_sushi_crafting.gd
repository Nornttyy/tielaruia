extends GutTest

const MainScene = preload("res://scenes/main.tscn")

# 启动 + 在玩家旁边摆指定 tile 工作站 (像真玩家站在一个站台旁). 返回合成面板.
func _boot_with(station_tile: int) -> CanvasLayer:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var pa: Node = world.get_player().get_node("PlayerAction")
	var terrain: TileMapLayer = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	var pt: Vector2i = pa.player_tile()
	var spot: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(spot.x, spot.y, station_tile)
	terrain.set_cell(spot, station_tile, Vector2i.ZERO)
	return get_tree().get_first_node_in_group("crafting_panel")

# 米饭: 2 米 → 米饭 (站锅旁)
func test_craft_cooked_rice():
	var cp = await _boot_with(Tiles.COOKING_POT)
	cp.open(3)
	cp.place_in_cell(0, 0, "rice", 1)
	cp.place_in_cell(0, 1, "rice", 1)
	var p = cp.get_output_preview()
	assert_not_null(p, "2 米应出米饭")
	assert_eq(p.output_id, "cooked_rice")
	cp.close()

# 鱼片: 三文鱼 → 鱼片 (站菜板旁, 不是烤鱼! — 验证 station-aware 匹配)
func test_craft_fish_slice():
	var cp = await _boot_with(Tiles.CUTTING_BOARD)
	cp.open(3)
	cp.place_in_cell(0, 0, "salmon", 1)
	var p = cp.get_output_preview()
	assert_not_null(p, "三文鱼应切出鱼片")
	assert_eq(p.output_id, "fish_slice", "菜板旁三文鱼出鱼片 (不是烤鱼)")
	cp.close()

# 寿司: 鱼片 + 米饭 + 紫菜 → 寿司 (站菜板旁)
func test_craft_sushi():
	var cp = await _boot_with(Tiles.CUTTING_BOARD)
	cp.open(3)
	cp.place_in_cell(0, 0, "fish_slice", 1)
	cp.place_in_cell(0, 1, "cooked_rice", 1)
	cp.place_in_cell(0, 2, "seaweed", 1)
	var p = cp.get_output_preview()
	assert_not_null(p, "鱼片+米饭+紫菜应出寿司")
	assert_eq(p.output_id, "sushi")
	cp.close()
