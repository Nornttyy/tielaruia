extends GutTest

# Bug 修复回归: 背包满时一键合成应拒绝, 不能消耗材料还把产物丢了
const MainScene = preload("res://scenes/main.tscn")


func _fill_inventory_with(inv, item_id: String) -> void:
	var max_stack: int = ItemDB.max_stack(item_id)
	for i in inv.slots.size():
		inv.slots[i] = {"item_id": item_id, "count": max_stack}


func test_craft_refused_when_inventory_full_keeps_materials():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv_node: Node = player.get_node("PlayerInventory")
	var inv = inv_node.inventory
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")

	# 全部槽塞 dirt (跟产物 planks 不同 id, 不能合并)
	_fill_inventory_with(inv, "dirt")
	# log 槽放 5 个 — 合成消耗 1 后还剩 4, 槽不会腾空, 没地方放 planks
	inv.slots[0] = {"item_id": "log", "count": 5}

	cp.open(2)
	cp._on_recipe_pressed("planks")

	# 材料应保留 (回滚)
	assert_eq(inv.slots[0].item_id, "log", "材料 log 应保留")
	assert_eq(inv.slots[0].count, 5, "log 数量不变")
	# 没有 planks 进入背包
	var has_planks: bool = false
	for s in inv.slots:
		if s != null and s.item_id == "planks":
			has_planks = true
			break
	assert_false(has_planks, "背包满时不应产出 planks")


func test_craft_succeeds_when_room_exists():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv_node: Node = player.get_node("PlayerInventory")
	var inv = inv_node.inventory
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")

	# 持 1 log, 其他槽空
	inv.add("log", 1)
	cp.open(2)
	cp._on_recipe_pressed("planks")

	# log 应被消耗, planks ×4 入背包
	var total_planks: int = 0
	var total_logs: int = 0
	for s in inv.slots:
		if s == null:
			continue
		if s.item_id == "planks":
			total_planks += s.count
		elif s.item_id == "log":
			total_logs += s.count
	assert_eq(total_logs, 0, "log 应被消耗")
	assert_eq(total_planks, 4, "应得到 4 planks")


func test_craft_uses_freed_slot_when_consuming_all_materials():
	# 边界情况: log 占满某个槽, 输出 4 planks 需要这个槽腾空才能放
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv_node: Node = player.get_node("PlayerInventory")
	var inv = inv_node.inventory
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")

	# 全部槽塞 dirt, 留一个槽放 1 log (合成需要刚好 1 log)
	_fill_inventory_with(inv, "dirt")
	inv.slots[5] = {"item_id": "log", "count": 1}

	cp.open(2)
	cp._on_recipe_pressed("planks")

	# log 槽消耗后腾出, 4 planks 应放入 (max_stack=64 够装)
	var slot5 = inv.slots[5]
	assert_not_null(slot5, "原 log 槽应被 planks 占用")
	assert_eq(slot5.item_id, "planks", "槽 5 应变 planks")
	assert_eq(slot5.count, 4, "4 个 planks")
