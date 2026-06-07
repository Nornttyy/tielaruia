# 复现/回归: 创造模式点"物品大全"该能把方块免费拿进背包。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _count_item(pinv, id: String) -> int:
	var t: int = 0
	for s in pinv.inventory.slots:
		if s != null and s.item_id == id:
			t += s.count
	return t


func test_creative_grab_adds_block_to_inventory() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	GameSettings.creative_mode = true
	var panel = get_tree().get_first_node_in_group("crafting_panel")
	assert_not_null(panel, "该有合成面板节点")
	var world = main.get_node("World")
	var player = world.get_player()
	var pinv = player.get_node("PlayerInventory")
	# 关键前置: 面板必须绑定了玩家背包, 否则 _on_creative_grab 直接 return (= 拿不了)
	assert_not_null(panel._player_inv, "面板该已绑定玩家背包 (_player_inv)")
	var before: int = _count_item(pinv, "dirt")
	panel._on_creative_grab("dirt")
	var after: int = _count_item(pinv, "dirt")
	assert_gt(after, before, "创造点'物品大全'该把方块加进背包 (实测 before=%d after=%d)" % [before, after])
	GameSettings.creative_mode = false


func test_creative_section_visible_and_populated_when_open() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	GameSettings.creative_mode = true
	var panel = get_tree().get_first_node_in_group("crafting_panel")
	panel.open(2)   # 开背包 (2x2 手作格)
	await wait_frames(1)
	# 创造区该可见
	assert_not_null(panel._creative_section, "该建了创造区")
	assert_true(panel._creative_section.visible, "创造模式开面板时'物品大全'该可见")
	# 该有可点的物品按钮 (_creative_section → [title, scroll]; scroll → grid_c; grid_c 子 = 按钮)
	var scroll = panel._creative_section.get_child(1)
	var grid_c = scroll.get_child(0)
	gut.p("[诊断] 物品大全按钮数 = %d" % grid_c.get_child_count())
	assert_gt(grid_c.get_child_count(), 0, "物品大全该有物品按钮 (空了=拿不了方块)")
	GameSettings.creative_mode = false
	panel.close()


func test_creative_button_press_signal_grabs() -> void:
	# 测真正"按按钮"这条线: 找物品大全里第一个按钮, 发它的 pressed 信号, 看背包进没进东西。
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	GameSettings.creative_mode = true
	var panel = get_tree().get_first_node_in_group("crafting_panel")
	panel.open(2)
	await wait_frames(1)
	var world = main.get_node("World")
	var pinv = world.get_player().get_node("PlayerInventory")
	var scroll = panel._creative_section.get_child(1)
	var grid_c = scroll.get_child(0)
	var btn = grid_c.get_child(0)   # 第一个物品按钮
	assert_false(btn.disabled, "物品按钮不该是禁用的 (禁用=点不动)")
	assert_eq(btn.mouse_filter, Control.MOUSE_FILTER_STOP, "按钮该接收鼠标 (STOP)")
	# 背包此刻有多少非空槽
	var filled_before: int = 0
	for s in pinv.inventory.slots:
		if s != null:
			filled_before += 1
	btn.pressed.emit()   # = 玩家点了这个按钮
	await wait_frames(1)
	var filled_after: int = 0
	for s in pinv.inventory.slots:
		if s != null:
			filled_after += 1
	assert_gt(filled_after, filled_before, "按物品按钮该把东西加进背包 (按钮接线对不对)")
	GameSettings.creative_mode = false
	panel.close()
