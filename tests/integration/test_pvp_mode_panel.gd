extends GutTest

# 对战房模式选择: 三种模式装备不同 + 魔法/枪械可选具体武器 + 模式→房间 tag 映射。
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
	# 魔法/枪械: 给的是选中的那把武器
	assert_true(_list_has(PvpModePanel.mode_loadout("magic", "hell_staff"), "hell_staff"), "魔法=选的法杖")
	assert_true(_list_has(PvpModePanel.mode_loadout("gun", "sniper"), "sniper"), "枪械=选的枪")
	# 三种都给共用装备
	for k in ["classic", "magic", "gun"]:
		assert_true(_list_has(PvpModePanel.mode_loadout(k), "health_potion"), "%s 该有血药" % k)
		assert_true(_list_has(PvpModePanel.mode_loadout(k), "iron_pickaxe"), "%s 该有镐" % k)


func test_mode_to_room_tag():
	# 不同模式 → 不同公共房 tag (bridge 据此分房, 同模式才碰面)
	assert_eq(PvpModePanel._MODE_TAG["classic"], "PVP")
	assert_eq(PvpModePanel._MODE_TAG["magic"], "PVP-MAGIC")
	assert_eq(PvpModePanel._MODE_TAG["gun"], "PVP-GUN")


func test_pvp_subtag_rooms_are_combat():
	# enter_public("PVP-MAGIC") 也该算对战房 (room_mode=pvp), 否则进去打不了人
	var prev_status = NetworkManager.status
	var prev_mode = NetworkManager.room_mode
	NetworkManager.enter_public("PVP-MAGIC", 0, 0, 0)   # 无 bridge 会提前返回, 但 room_mode 已设
	assert_eq(NetworkManager.room_mode, "pvp", "PVP-MAGIC 房是对战房")
	NetworkManager.enter_public("PVP-GUN", 0, 0, 0)
	assert_eq(NetworkManager.room_mode, "pvp", "PVP-GUN 房是对战房")
	NetworkManager.enter_public("SV", 0, 0, 0)
	assert_eq(NetworkManager.room_mode, "survival", "生存房不是对战")
	NetworkManager.status = prev_status
	NetworkManager.room_mode = prev_mode
	NetworkManager.in_public_room = false


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
	# 发魔法 (选地狱法杖): 有法杖, 没剑
	assert_true(panel._grant_loadout("magic", "hell_staff", inv_node), "发魔法装备应成功")
	var ids := {}
	for s in inv_node.inventory.slots:
		if s != null:
			ids[s.item_id] = true
	assert_true(ids.has("hell_staff"), "魔法该有选的法杖")
	assert_false(ids.has("iron_sword"), "魔法不该有剑")
	# 换枪械 (选狙击枪): 清空重发 → 有狙, 没法杖
	panel._grant_loadout("gun", "sniper", inv_node)
	ids = {}
	for s in inv_node.inventory.slots:
		if s != null:
			ids[s.item_id] = true
	assert_true(ids.has("sniper"), "换枪后该有狙击枪")
	assert_false(ids.has("hell_staff"), "换枪后不该还留着法杖")


# --- T4: 模式面板只选模式 + 关闭按钮; 武器在独立"切武器"视图 ---

func test_mode_view_has_3_modes_plus_close():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._show_modes()
	# 经典 + 魔法 + 枪械 + 关闭 = 4 个按钮 (用户: 退出按钮 / 只选模式不选武器)
	assert_eq(panel._content.get_child_count(), 4, "模式视图: 3 模式 + 关闭")


func test_weapons_for_each_mode():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	# 魔法 = 3 法杖 (骷髅法杖已删)
	assert_eq(panel._weapons_for("magic").size(), 3, "魔法 3 法杖 (无骷髅)")
	assert_false(_list_has(panel._weapons_for("magic"), "skull_staff"), "切武器列表无骷髅法杖")
	# 枪械 = 15 把枪
	assert_eq(panel._weapons_for("gun").size(), 15, "枪械 15 把")
	# 经典 = 剑 + 弓
	assert_true(_list_has(panel._weapons_for("classic"), "iron_sword"), "经典含剑")
	assert_true(_list_has(panel._weapons_for("classic"), "wood_bow"), "经典含弓")


func test_weapon_switch_view_lists_current_mode():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._current_mode_key = "magic"
	panel._show_weapon_switch()
	# ← 切换模式 + 3 法杖 + 关闭 = 5
	assert_eq(panel._content.get_child_count(), 5, "切武器视图: 返回 + 3 法杖 + 关闭")


func test_panel_in_group_for_crafting_key():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	assert_true(panel.is_in_group("pvp_mode_panel"), "战斗房合成键靠这个 group 找到面板")
	assert_true(panel.has_method("open_weapon_switch"), "该有 open_weapon_switch 给合成键调")


# 用户: 首次进战斗房选模式时不给"关闭" (必须选一个才开始); 之后重开才有关闭。
func test_first_entry_modes_have_no_close():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._show_modes(false)
	assert_eq(panel._content.get_child_count(), 3, "首次: 只 3 个模式, 无关闭按钮")
