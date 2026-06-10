extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_mine_grass_then_pick_up():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 空手挖不动, 给个木镐 + 选中
	inv.pickup("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.GRASS, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.GRASS)
	action.aim_override = target
	action.primary_override = true
	# 挖完 (hardness 0.3s, 保留余量)
	await wait_seconds(0.5)
	action.primary_override = false
	# tile 已清
	assert_eq(terrain.get_cell_source_id(target), -1)
	# 等 pickup_delay (0.4s) 完全过期后再接近 drop
	await wait_seconds(0.5)
	# 瞬移玩家到 drop 位置触发 pickup
	player.global_position = Vector2(target.x * 12 + 6, target.y * 12 + 12)
	# 等几帧 area body_entered 信号触发
	await wait_frames(10)
	# inventory 中应有 grass 或 dirt
	var got: int = 0
	for slot in inv.inventory.slots:
		if slot != null and (slot.item_id == "dirt" or slot.item_id == "grass"):
			got += slot.count
	assert_gt(got, 0, "应至少拾到 1 个 dirt/grass")


# 按 Q 丢弃: 从选中格扣 1 + 世界里多一个掉落物 (player_controller._drop_one_selected)
func test_q_drop_one_spawns_drop_and_decrements():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	inv.pickup("dirt", 5)
	# 选中放了 dirt 的热键格 (别假设 0, 起步包可能占了 0)
	var dirt_idx: int = -1
	for i in range(9):
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == "dirt":
			dirt_idx = i
			break
	assert_gt(dirt_idx, -1, "dirt 该进热键栏")
	inv.set_hotbar_selection(dirt_idx)
	var before: int = get_tree().get_nodes_in_group("item_drops").size()
	var ok: bool = player._drop_one_selected()
	assert_true(ok, "_drop_one_selected 应成功")
	await wait_frames(2)
	# 选中格 dirt 少 1 (5 → 4)
	var dirt_total: int = 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "dirt":
			dirt_total += slot.count
	assert_eq(dirt_total, 4, "丢 1 个后剩 4")
	# 世界里多 1 个掉落物
	assert_eq(get_tree().get_nodes_in_group("item_drops").size(), before + 1, "丢出后多 1 个掉落物")


# 选中格为空时按 Q 不丢 (不报错, 返回 false)
func test_q_drop_empty_slot_noop():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	# 找一个空热键格并选中
	var empty_idx: int = -1
	for i in range(9):
		if inv.inventory.slots[i] == null:
			empty_idx = i
			break
	assert_gt(empty_idx, -1, "该有空热键格")
	inv.set_hotbar_selection(empty_idx)
	var before: int = get_tree().get_nodes_in_group("item_drops").size()
	assert_false(player._drop_one_selected(), "空格按 Q 应不丢")
	assert_eq(get_tree().get_nodes_in_group("item_drops").size(), before, "空格不该生成掉落物")
