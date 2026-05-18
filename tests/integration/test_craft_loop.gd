extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_craft_planks_from_log():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	# 玩家持 1 log
	inv.inventory.add("log", 1)
	# 开 2x2
	cp.open(2)
	# 把 log 放到 (0,0)
	cp.place_in_cell(0, 0, "log", 1)
	# 现在 output_preview 应为 planks x 4
	var preview = cp.get_output_preview()
	assert_not_null(preview, "log 应触发 planks 配方")
	assert_eq(preview.output_id, "planks")
	assert_eq(preview.output_count, 4)
	# 点击 output → cursor 拿 4 planks
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_not_null(ci)
	assert_eq(ci.item_id, "planks")
	assert_eq(ci.count, 4)
	# 关闭面板 → cursor + cells 退回 inventory
	cp.close()
	# 检查 inventory 中有 4 planks
	var total_planks: int = 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "planks":
			total_planks += slot.count
	assert_eq(total_planks, 4)


func test_craft_workbench_from_planks():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	inv.inventory.add("planks", 4)
	cp.open(2)
	cp.place_in_cell(0, 0, "planks", 1)
	cp.place_in_cell(0, 1, "planks", 1)
	cp.place_in_cell(1, 0, "planks", 1)
	cp.place_in_cell(1, 1, "planks", 1)
	var preview = cp.get_output_preview()
	assert_eq(preview.output_id, "workbench")
	cp.simulate_take_output()
	var ci = cp.get_cursor_item()
	assert_eq(ci.item_id, "workbench")
	assert_eq(ci.count, 1)
