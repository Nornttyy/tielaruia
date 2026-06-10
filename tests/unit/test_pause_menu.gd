extends GutTest

const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")


func _make() -> CanvasLayer:
	var pm = PauseMenuScene.instantiate()
	add_child_autofree(pm)
	return pm


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_initially_hidden():
	var pm = _make()
	assert_false(pm.visible)


func test_open_shows_and_pauses():
	var pm = _make()
	pm.open()
	assert_true(pm.visible)
	assert_true(get_tree().paused)


func test_close_hides_and_unpauses():
	var pm = _make()
	pm.open()
	pm.close()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_toggle_open_close():
	var pm = _make()
	assert_false(pm.visible)
	pm.toggle()
	assert_true(pm.visible)
	pm.toggle()
	assert_false(pm.visible)


func test_resume_button_closes():
	var pm = _make()
	pm.open()
	pm._on_resume_pressed()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_return_to_menu_button_emits_signal():
	var pm = _make()
	pm.open()
	var emitted := [false]
	pm.return_to_menu.connect(func(): emitted[0] = true)
	pm._on_return_to_menu_pressed()
	assert_true(emitted[0])


# ---- 联机房不能改游戏模式 (用户要求: 生存房/对战房不能设置游戏模式) ----

func test_creative_button_hidden_in_multiplayer():
	var prev_status = NetworkManager.status
	NetworkManager.status = "connected"   # 模拟在联机房 (生存房/对战房)
	var pm = _make()
	pm.open()
	assert_false(pm._creative_button.visible, "联机房里创造模式按钮该藏起来")
	NetworkManager.status = prev_status


func test_creative_toggle_blocked_in_multiplayer():
	var prev_status = NetworkManager.status
	var prev_creative = GameSettings.creative_mode
	NetworkManager.status = "connected"
	GameSettings.creative_mode = false
	var pm = _make()
	pm._on_creative_pressed()              # 联机时点击应被拦
	assert_false(GameSettings.creative_mode, "联机房里不该能切到创造模式")
	NetworkManager.status = prev_status
	GameSettings.creative_mode = prev_creative


func test_creative_toggle_works_singleplayer():
	var prev_status = NetworkManager.status
	var prev_creative = GameSettings.creative_mode
	NetworkManager.status = "idle"         # 单机
	GameSettings.creative_mode = false
	var pm = _make()
	pm.open()
	assert_true(pm._creative_button.visible, "单机时创造模式按钮可见")
	pm._on_creative_pressed()
	assert_true(GameSettings.creative_mode, "单机时能切创造模式")
	NetworkManager.status = prev_status
	GameSettings.creative_mode = prev_creative


# ---- 关闭联机按钮 (房主停房间但留在世界继续玩) ----

func test_close_mp_button_host_only():
	var prev_status = NetworkManager.status
	var prev_host = NetworkManager.is_host
	# 房主 + 联机 → 显示
	NetworkManager.status = "connected"
	NetworkManager.is_host = true
	var pm = _make()
	pm.open()
	assert_true(pm._close_mp_button.visible, "房主联机时显示关闭联机按钮")
	pm.close()
	# 加入方 (非房主) → 不显示 (离开用回主菜单)
	NetworkManager.is_host = false
	pm.open()
	assert_false(pm._close_mp_button.visible, "加入方不显示关闭联机按钮")
	NetworkManager.status = prev_status
	NetworkManager.is_host = prev_host


func test_close_mp_disconnects_and_stays_in_world():
	var prev_status = NetworkManager.status
	var prev_host = NetworkManager.is_host
	NetworkManager.status = "connected"
	NetworkManager.is_host = true
	var pm = _make()
	pm.open()
	var went_menu := [false]
	pm.return_to_menu.connect(func(): went_menu[0] = true)
	pm._on_close_mp_pressed()
	assert_false(pm.visible, "关闭联机后暂停菜单收起 (恢复游戏)")
	assert_false(get_tree().paused, "关闭联机后不暂停 (继续玩)")
	assert_false(went_menu[0], "关闭联机不该回主菜单")
	assert_eq(NetworkManager.status, "idle", "关闭联机后已断开 (status=idle)")
	NetworkManager.status = prev_status
	NetworkManager.is_host = prev_host


# ---- 公共房不显示"多人游戏/踢人" (用户: 公共房本来就是多人游戏) ----

func _reset_nm() -> void:
	NetworkManager.status = "idle"
	NetworkManager.is_host = false
	NetworkManager.in_public_room = false


func test_public_room_hides_mp_and_kick():
	NetworkManager.status = "connected"
	NetworkManager.is_host = true
	NetworkManager.in_public_room = true
	var pm = _make()
	pm.open()
	assert_false(pm._multiplayer_button.visible, "公共房不该显示'多人游戏'按钮")
	assert_false(pm._kick_button.visible, "公共房不该显示'踢人'")
	_reset_nm()


func test_single_player_shows_mp_button():
	_reset_nm()
	var pm = _make()
	pm.open()
	assert_true(pm._multiplayer_button.visible, "单机该显示'多人游戏'按钮(可开房邀请)")
	assert_false(pm._kick_button.visible, "单机没人可踢")


func test_private_host_shows_mp_and_kick():
	NetworkManager.status = "connected"
	NetworkManager.is_host = true
	NetworkManager.in_public_room = false   # 私人房
	var pm = _make()
	pm.open()
	assert_true(pm._multiplayer_button.visible, "私人房该显示'多人游戏'(可看房间码)")
	assert_true(pm._kick_button.visible, "私人房房主该能踢人")
	_reset_nm()


# 多人设置已从主菜单挪进暂停菜单的多人面板 (用户要求)
func test_mp_settings_built_in_hostpanel():
	var pm = _make()
	var vb = pm.get_node("HostPanel/VBox")
	var has_label := false
	var has_checkbox := false
	for c in vb.get_children():
		if c is Label and c.text == "多人设置":
			has_label = true
		if c is HBoxContainer:
			for cc in c.get_children():
				if cc is CheckBox:
					has_checkbox = true
	assert_true(has_label, "暂停菜单多人面板有'多人设置'区")
	assert_true(has_checkbox, "多人设置里有开关 (名字/聊天)")


# 用户要求: 先调好多人设置, 再点"创建房间"才开房 (不是一点多人游戏就立刻开)
func test_create_room_button_flow():
	_reset_nm()
	var pm = _make()
	pm._on_multiplayer_pressed()
	assert_true(pm._create_room_button.visible, "点'多人游戏'先显示'创建房间'按钮")
	assert_eq(NetworkManager.status, "idle", "开多人面板时还没真开房")
	pm._on_create_room_pressed()
	assert_false(pm._create_room_button.visible, "点了'创建房间'后按钮隐藏")
