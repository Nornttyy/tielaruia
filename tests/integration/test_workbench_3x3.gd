extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_place_workbench_and_craft_pickaxe():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	# 玩家持 1 workbench + 5 planks
	inv.inventory.add("workbench", 1)
	inv.inventory.add("planks", 5)
	# 选中 workbench 放置
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	# 把 target 上方原本可能存在的 tile 清掉
	terrain.set_cell(target, -1)
	world._set_tile(target.x, target.y, Tiles.AIR)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.WORKBENCH, "workbench 应被放下")
	# 现在 chebyshev ≤ 2，触发 3x3
	cp.open(3)
	# 摆 wood_pickaxe 形状
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	cp.place_in_cell(2, 1, "planks", 1)
	var preview = cp.get_output_preview()
	assert_not_null(preview, "应匹配 wood_pickaxe")
	assert_eq(preview.output_id, "wood_pickaxe")
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_eq(ci.item_id, "wood_pickaxe")
	cp.close()
	var has_pickaxe := false
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "wood_pickaxe":
			has_pickaxe = true
	assert_true(has_pickaxe, "wood_pickaxe 应入库")


func test_workbench_proximity_check():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 玩家面前 1 格放 workbench
	var pt: Vector2i = action.player_tile()
	terrain.set_cell(pt + Vector2i(1, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	assert_true(action._has_workbench_nearby(), "1 格邻居应识别")
	terrain.set_cell(pt + Vector2i(1, 0), -1)
	# 3 格远 - 超 chebyshev=2
	terrain.set_cell(pt + Vector2i(3, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	assert_false(action._has_workbench_nearby(), "3 格远应被拒")
