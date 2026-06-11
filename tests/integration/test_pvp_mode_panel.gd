extends GutTest

# 对战房模式选择: 三种模式装备不同 + 选了清空背包重发对应整套。
const MainScene = preload("res://scenes/main.tscn")
const PvpModePanel = preload("res://scripts/ui/pvp_mode_panel.gd")


func _list_has(items: Array, id: String) -> bool:
	for pair in items:
		if String(pair[0]) == id:
			return true
	return false


func test_mode_loadouts_differ_by_weapon():
	assert_true(_list_has(PvpModePanel.mode_loadout("classic"), "iron_sword"), "经典=剑")
	assert_true(_list_has(PvpModePanel.mode_loadout("classic"), "wood_bow"), "经典=弓")
	assert_true(_list_has(PvpModePanel.mode_loadout("magic"), "iron_staff"), "魔法=法杖")
	assert_true(_list_has(PvpModePanel.mode_loadout("gun"), "smg"), "枪械=枪")
	# 三种都给共用装备 (血药/镐)
	for k in ["classic", "magic", "gun"]:
		assert_true(_list_has(PvpModePanel.mode_loadout(k), "health_potion"), "%s 该有血药" % k)
		assert_true(_list_has(PvpModePanel.mode_loadout(k), "iron_pickaxe"), "%s 该有镐" % k)


func test_grant_clears_and_swaps_loadout():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var inv_node: Node = player.get_node("PlayerInventory")
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	# 先发经典: 有剑, 没法杖
	assert_true(panel._grant_loadout("classic", inv_node), "发经典装备应成功")
	var ids := {}
	for s in inv_node.inventory.slots:
		if s != null:
			ids[s.item_id] = true
	assert_true(ids.has("iron_sword"), "经典该有剑")
	assert_false(ids.has("iron_staff"), "经典不该有法杖")
	# 换魔法: 清空重发 → 有法杖, 没剑 (不残留上一套)
	panel._grant_loadout("magic", inv_node)
	ids = {}
	for s in inv_node.inventory.slots:
		if s != null:
			ids[s.item_id] = true
	assert_true(ids.has("iron_staff"), "换魔法后该有法杖")
	assert_false(ids.has("iron_sword"), "换魔法后不该还留着剑")
