extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_full_survival_loop():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	var pt: Vector2i = action.player_tile()

	# 1. 给玩家 4 个 log (绕开拾取的随机概率，集中测合成+后续)
	inv.inventory.add("log", 4)

	# 2. 2x2 合成 1 log → 4 planks, 4 次 → 16 planks
	for i in 4:
		cp.open(2)
		cp.place_in_cell(0, 0, "log", 1)
		var p1 = cp.get_output_preview()
		assert_eq(p1.output_id, "planks", "log 应合 planks")
		cp.simulate_take_output()
		assert_eq(cp.get_cursor_item().count, 4, "应得 4 planks")
		cp.close()
	# 库存 planks 至少 16
	var total_planks := 0
	for s in inv.inventory.slots:
		if s != null and s.item_id == "planks":
			total_planks += s.count
	assert_gte(total_planks, 16)

	# 4. 2x2 合 4 planks → 1 workbench
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	var p3 = cp.get_output_preview()
	assert_eq(p3.output_id, "workbench")
	cp.simulate_take_output()
	cp.close()
	# 把 workbench 移到 hotbar 0
	var wb_idx := -1
	for i in 36:
		if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "workbench":
			wb_idx = i
			break
	assert_gte(wb_idx, 0)
	inv.inventory.swap(0, wb_idx)
	inv.set_hotbar_selection(0)

	# 5. 放工作台
	var wb_target: Vector2i = pt + Vector2i(2, -1)
	terrain.set_cell(wb_target, -1)
	world._set_tile(wb_target.x, wb_target.y, Tiles.AIR)
	action.aim_override = wb_target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(wb_target), Tiles.WORKBENCH)

	# 6. 3x3 合 wood_pickaxe (5 planks, 不要 stick)
	cp.open(3)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(0, 2, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	cp.place_in_cell(2, 1, "planks", 1)
	var p4 = cp.get_output_preview()
	assert_eq(p4.output_id, "wood_pickaxe")
	cp.simulate_take_output()
	cp.close()

	# 7. 选中 wood_pickaxe 挖石头
	var pk_idx := -1
	for i in 36:
		if inv.inventory.slots[i] != null and inv.inventory.slots[i].item_id == "wood_pickaxe":
			pk_idx = i
			break
	assert_gte(pk_idx, 0)
	if pk_idx > 8:
		inv.inventory.swap(0, pk_idx)
		inv.set_hotbar_selection(0)
	else:
		inv.set_hotbar_selection(pk_idx)
	var stone_target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(stone_target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(stone_target.x, stone_target.y, Tiles.STONE)
	action.aim_override = stone_target
	action.primary_override = true
	await wait_frames(90)
	assert_eq(terrain.get_cell_source_id(stone_target), -1, "stone 应被挖空")
