extends GutTest

const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")


func _make() -> CanvasLayer:
	var mm = MainMenuScene.instantiate()
	add_child_autofree(mm)
	return mm


func before_each():
	GameSettings.master_volume = 1.0


func after_each():
	GameSettings.master_volume = 1.0


# ---- background ----

func test_has_background_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("BackgroundLayer"))


func test_background_has_sky():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("BackgroundLayer/Sky"))


# 背景只留树 (用户要求): 云/太阳/鸟/史莱姆/地面都不画了
func test_background_only_trees_no_clouds():
	var mm = _make()
	var clouds = mm.get_node_or_null("BackgroundLayer/Clouds")
	assert_true(clouds == null or clouds.get_child_count() == 0, "背景不该有云了")
	# 地面隐藏
	var ground = mm.get_node_or_null("BackgroundLayer/Ground")
	if ground != null:
		assert_false(ground.visible, "地面该隐藏 (只留树)")


func test_background_has_trees():
	var mm = _make()
	# 树现在画在前景层 TreesFront (站在草地前面); 老的 Trees 层保留但空着.
	var front = mm.get_node_or_null("BackgroundLayer/TreesFront")
	assert_not_null(front, "应有前景树层 TreesFront")
	assert_gt(front.get_child_count(), 0, "前景树层里该有树")


# ---- title ----

func test_has_title_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("TitleLayer"))


func test_title_has_logo_label():
	var mm = _make()
	var logo = mm.get_node_or_null("TitleLayer/LogoLabel")
	assert_not_null(logo)
	assert_eq(logo.text, "teilaruia")


func test_title_has_shadow_label():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("TitleLayer/LogoShadow"))


func test_title_has_subtitle():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("TitleLayer/Subtitle"))


# ---- buttons ----

func test_has_button_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("ButtonLayer"))


func test_has_three_buttons():
	var mm = _make()
	var vb = mm.get_node_or_null("ButtonLayer/VBox")
	assert_not_null(vb)
	# NewGame, Multiplayer, Settings (Continue 早删, Quit 网页版没必要)
	assert_eq(vb.get_child_count(), 3, "3 个按钮容器")


func test_multiplayer_button_shows_panel():
	var mm = _make()
	var panel = mm.get_node_or_null("MultiplayerPanel")
	assert_not_null(panel)
	assert_false(panel.visible)
	mm._on_multiplayer_pressed()
	assert_true(panel.visible, "点联机后面板显示")


func test_new_game_button_shows_character_select_panel():
	# Plan 3: "开始游戏" 先开选角色面板 (选完角色再开 WorldSelectPanel)
	var mm = _make()
	assert_not_null(mm._character_panels, "应有选角色/捏人面板")
	assert_false(mm._character_panels.visible, "初始隐藏")
	mm._on_new_game_pressed()
	assert_true(mm._character_panels.visible, "点开始游戏后 选角色面板 显示")
	assert_false(mm.get_node("ButtonLayer/VBox").visible)

func test_character_chosen_opens_world_select():
	# 选完角色 → WorldSelectPanel 显示
	var mm = _make()
	var ws_panel = mm.get_node_or_null("WorldSelectPanel")
	mm._on_character_chosen()
	assert_true(ws_panel.visible, "选完角色后 WorldSelectPanel 显示")


func test_new_game_panel_start_button_emits_start_game_with_opts():
	var mm = _make()
	# 直接显 NewGamePanel (跳过 WorldSelectPanel 这一步, 测试只关心 Start 按钮)
	mm.get_node("NewGamePanel").visible = true
	var captured: Array = []
	mm.start_game.connect(func(opts: Dictionary): captured.append(opts))
	var start_btn: Button = mm.get_node("NewGamePanel/VBox/ButtonRow/StartButton")
	start_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	assert_eq(captured.size(), 1, "应发一次 start_game")
	var opts: Dictionary = captured[0]
	assert_true("world_seed" in opts)
	assert_true("world_name" in opts)
	assert_true("difficulty" in opts)


func test_new_game_panel_cancel_hides_panel():
	var mm = _make()
	mm.get_node("NewGamePanel").visible = true
	var panel = mm.get_node("NewGamePanel")
	var cancel_btn: Button = mm.get_node("NewGamePanel/VBox/ButtonRow/CancelButton")
	cancel_btn.pressed.emit()
	assert_false(panel.visible, "取消后 NewGamePanel 隐藏")


func test_hover_arrow_initially_invisible():
	var mm = _make()
	var arrow = mm.get_node_or_null("ButtonLayer/VBox/NewGameRow/Arrow")
	assert_not_null(arrow)
	assert_false(arrow.visible)


# ---- settings panel ----

func test_has_settings_panel():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("SettingsPanel"))


func test_settings_panel_initially_hidden():
	var mm = _make()
	assert_false(mm.get_node("SettingsPanel").visible)


func test_volume_slider_reflects_game_settings():
	GameSettings.master_volume = 0.7
	var mm = _make()
	var slider: HSlider = mm.get_node("SettingsPanel/VBox/VolumeRow/Slider")
	assert_almost_eq(slider.value, 70.0, 0.5)


func test_slider_change_updates_game_settings():
	var mm = _make()
	var slider: HSlider = mm.get_node("SettingsPanel/VBox/VolumeRow/Slider")
	slider.value = 50.0
	slider.value_changed.emit(50.0)
	assert_almost_eq(GameSettings.master_volume, 0.5, 0.01)


func test_mp_settings_rows_exist_and_wire():
	var mm = _make()
	# 三个多人设置行都在
	assert_not_null(mm.get_node_or_null("MultiplayerPanel/VBox/MpNamesRow/CheckBox"), "显示名字开关在")
	assert_not_null(mm.get_node_or_null("MultiplayerPanel/VBox/MpChatRow/CheckBox"), "聊天开关在")
	assert_not_null(mm.get_node_or_null("MultiplayerPanel/VBox/MpMaxRow/Slider"), "房间人数滑条在")
	# 切名字开关 → 改 GameSettings
	var names_cb: CheckBox = mm.get_node("MultiplayerPanel/VBox/MpNamesRow/CheckBox")
	names_cb.button_pressed = false
	names_cb.toggled.emit(false)
	assert_false(GameSettings.mp_show_names, "关名字开关 → mp_show_names=false")
	GameSettings.mp_show_names = true   # 恢复
	# 房间人数滑条 → 改 mp_max_players
	var sl: HSlider = mm.get_node("MultiplayerPanel/VBox/MpMaxRow/Slider")
	sl.value = 4.0
	sl.value_changed.emit(4.0)
	assert_eq(GameSettings.mp_max_players, 4, "滑条改房间人数")
	GameSettings.mp_max_players = 8   # 恢复


func test_settings_button_opens_panel():
	var mm = _make()
	mm._on_settings_pressed()
	assert_true(mm.get_node("SettingsPanel").visible)
	assert_false(mm.get_node("ButtonLayer/VBox").visible)


func test_back_button_closes_panel():
	var mm = _make()
	mm._on_settings_pressed()
	mm._on_settings_back_pressed()
	assert_false(mm.get_node("SettingsPanel").visible)


# ---- 多语言 (i18n) ----

# 默认 (中文): 主菜单按钮应显中文
func test_default_language_buttons_are_chinese():
	Locale.set_language("zh")
	var mm = _make()
	await get_tree().process_frame
	var btn: Button = mm.get_node("ButtonLayer/VBox/NewGameRow/Button")
	assert_eq(btn.text, "开始游戏", "默认中文按钮显 \"开始游戏\"")


# 切英文后按钮 + 标签应同步刷新 (而不是留中文)
func test_switching_to_english_refreshes_buttons():
	Locale.set_language("zh")
	var mm = _make()
	await get_tree().process_frame
	Locale.set_language("en")
	# language_changed 信号同步触发, 不需等帧
	var new_game_btn: Button = mm.get_node("ButtonLayer/VBox/NewGameRow/Button")
	var settings_label: Label = mm.get_node("SettingsPanel/VBox/LanguageRow/Label")
	assert_eq(new_game_btn.text, "New Game", "英文按钮 = New Game")
	assert_eq(settings_label.text, "Language", "英文 \"语言\" 标签 = Language")
	Locale.set_language("zh")   # 恢复


# 日文切换
func test_switching_to_japanese():
	Locale.set_language("zh")
	var mm = _make()
	await get_tree().process_frame
	Locale.set_language("ja")
	var btn: Button = mm.get_node("ButtonLayer/VBox/NewGameRow/Button")
	assert_eq(btn.text, "ゲーム開始", "日文 = ゲーム開始")
	Locale.set_language("zh")


# 韩文切换
func test_switching_to_korean():
	Locale.set_language("zh")
	var mm = _make()
	await get_tree().process_frame
	Locale.set_language("ko")
	var btn: Button = mm.get_node("ButtonLayer/VBox/NewGameRow/Button")
	assert_eq(btn.text, "게임 시작", "韩文 = 게임 시작")
	Locale.set_language("zh")


# 下拉应有 4 选项, 顺序匹配 Locale.SUPPORTED
func test_language_dropdown_has_4_items():
	var mm = _make()
	var opt: OptionButton = mm.get_node("SettingsPanel/VBox/LanguageRow/OptionButton")
	assert_eq(opt.item_count, 4, "语言下拉 4 项 (zh/en/ja/ko)")


# 选下拉就应触发 Locale.set_language (走信号 → 落盘 + 信号)
func test_dropdown_selection_changes_locale():
	Locale.set_language("zh")
	var mm = _make()
	var opt: OptionButton = mm.get_node("SettingsPanel/VBox/LanguageRow/OptionButton")
	opt.selected = 1  # en
	opt.item_selected.emit(1)
	assert_eq(Locale.current_language(), "en", "选第 2 项应切到英文")
	Locale.set_language("zh")


# 回归: 按钮首次 hover 不该报 "没有 scale_tw meta" (旧 bug: get_meta(name, null) 把 null
# 当成"没给默认" → meta 不存在时报错). 改用 has_meta 判断后, 首次 + 重复 hover 都正常.
func test_button_hover_no_meta_error():
	var mm = _make()
	await wait_frames(1)
	var btn: Button = mm.get_node("ButtonLayer/VBox/NewGameRow/Button")
	assert_false(btn.has_meta("scale_tw"), "首次 hover 前不该有 scale_tw meta")
	btn.mouse_entered.emit()   # 第一次 hover: 旧代码会在 get_meta(null) 报错
	assert_true(btn.has_meta("scale_tw"), "hover 后该设上 scale_tw tween (handler 跑通)")
	btn.mouse_exited.emit()    # 读旧 meta kill 前一个 tween — 不该崩
	btn.mouse_entered.emit()   # 二次 hover: 走 has_meta=true 分支
	assert_true(btn.has_meta("scale_tw"), "重复 hover 仍正常")
