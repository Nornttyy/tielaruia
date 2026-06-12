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
	# 魔法 = 全部 _STAFFS (基础 3 + A/B/C 波新法杖); 召唤类(骷髅/雀宝宝)不列
	assert_eq(panel._weapons_for("magic").size(), PvpModePanel._STAFFS.size(), "魔法 = _STAFFS 全部")
	assert_true(panel._weapons_for("magic").size() >= 11, "魔法至少 11 把 (基础3 + 新8)")
	assert_true(_list_has(panel._weapons_for("magic"), "lightning_staff"), "魔法含闪电法杖 (新加)")
	assert_false(_list_has(panel._weapons_for("magic"), "skull_staff"), "切武器列表无骷髅法杖 (召唤类)")
	assert_false(_list_has(panel._weapons_for("magic"), "bird_staff"), "切武器列表无雀宝宝法杖 (召唤类)")
	# 枪械 = 23 把枪 (第一批 15 + 第二批 8)
	assert_eq(panel._weapons_for("gun").size(), 23, "枪械 23 把 (15+8)")
	assert_true(_list_has(panel._weapons_for("gun"), "railgun"), "枪械含电磁炮 (新加)")
	# 经典 = 剑 + 弓
	assert_true(_list_has(panel._weapons_for("classic"), "iron_sword"), "经典含剑")
	assert_true(_list_has(panel._weapons_for("classic"), "wood_bow"), "经典含弓")


func test_weapon_switch_view_lists_current_mode():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._current_mode_key = "magic"
	panel._show_weapon_switch()
	# ← 切换模式 + 全部法杖 + 关闭
	assert_eq(panel._content.get_child_count(), PvpModePanel._STAFFS.size() + 2, "切武器视图: 返回 + 全部法杖 + 关闭")


func test_panel_in_group_for_crafting_key():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	assert_true(panel.is_in_group("pvp_mode_panel"), "战斗房合成键靠这个 group 找到面板")
	assert_true(panel.has_method("open_weapon_switch"), "该有 open_weapon_switch 给合成键调")
	# E 键走 player_action._try_open_workbench_or_close → mp.toggle_weapon_switch (开/关)
	assert_true(panel.has_method("toggle_weapon_switch"), "该有 toggle_weapon_switch 给 E 键调")


# 切换模式必须重连到该模式的房间 (每模式一房), 哪怕刚进房还没 connected() (用户报: 只换武器没换房)
func test_pick_mode_reroutes_even_when_not_connected():
	var prev_pub = NetworkManager.in_public_room
	var prev_mode = NetworkManager.room_mode
	var prev_status = NetworkManager.status
	NetworkManager.in_public_room = true
	NetworkManager.room_mode = "pvp"
	NetworkManager.status = "hosting"   # 在公共房但还没 connected() (connected()=false)
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._current_tag = "PVP"          # 当前在经典房
	panel._pick_mode("magic")           # 选魔法 → 该重连到 PVP-MAGIC
	assert_eq(panel._current_tag, "PVP-MAGIC", "选魔法该重连到 PVP-MAGIC 房 (没连上也要 reroute)")
	# 还原
	NetworkManager.in_public_room = prev_pub
	NetworkManager.room_mode = prev_mode
	NetworkManager.status = prev_status


# E 是开关键: 面板开着再按 → 关掉
func test_toggle_weapon_switch_closes_when_open():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._show_weapon_switch()
	panel._set_open(true, false)
	assert_true(panel._panel.visible, "先打开切武器面板")
	panel.toggle_weapon_switch()   # 已开 → 关
	assert_false(panel._panel.visible, "再按一下该关掉")


# 用户报: 战斗房按 E 有时变成"合成界面" (应该是"换武器界面")。
# 根因: E 处理器原先用 combat_enabled() (要 connected()), 切模式断开重连那一瞬 connected()=false →
# 漏到合成。修成跟面板一致的 room_mode=="pvp"。这里复现那个"在对战房但还没 connected()"的窗口。
func test_e_opens_weapon_switch_not_crafting_during_reconnect():
	var prev_status = NetworkManager.status
	var prev_mode = NetworkManager.room_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var player = main.get_node("World").get_player()
	var pa: Node = player.get_node("PlayerAction")
	# 模拟"在对战房, 但断开重连窗口期" (room_mode=pvp 但没 connected)
	NetworkManager.room_mode = "pvp"
	NetworkManager.status = "hosting"   # connected()=false → combat_enabled()=false
	pa._try_open_workbench_or_close()
	await wait_frames(1)
	var mp: Node = get_tree().get_first_node_in_group("pvp_mode_panel")
	var cp: Node = get_tree().get_first_node_in_group("crafting_panel")
	assert_true(mp != null and mp._panel.visible, "断线重连窗口: E 该开换武器面板")
	assert_true(cp == null or not cp.is_open(), "断线重连窗口: E 不该开合成界面")
	NetworkManager.status = prev_status
	NetworkManager.room_mode = prev_mode


# 用户: 首次进战斗房选模式时不给"关闭" (必须选一个才开始); 之后重开才有关闭。
func test_first_entry_modes_have_no_close():
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	panel._show_modes(false)
	assert_eq(panel._content.get_child_count(), 3, "首次: 只 3 个模式, 无关闭按钮")
