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


func test_background_has_clouds():
	var mm = _make()
	var clouds = mm.get_node_or_null("BackgroundLayer/Clouds")
	assert_not_null(clouds)
	assert_gt(clouds.get_child_count(), 0, "至少一朵云")


func test_background_has_trees():
	var mm = _make()
	var trees = mm.get_node_or_null("BackgroundLayer/Trees")
	assert_not_null(trees)
	assert_gt(trees.get_child_count(), 0)


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


func test_new_game_button_shows_world_select_panel():
	# 现在 "开始游戏" 先开 WorldSelectPanel (创建/继续二选一), 不直接进 NewGamePanel
	var mm = _make()
	var ws_panel = mm.get_node_or_null("WorldSelectPanel")
	assert_not_null(ws_panel, "应有 WorldSelectPanel")
	assert_false(ws_panel.visible, "初始隐藏")
	mm._on_new_game_pressed()
	assert_true(ws_panel.visible, "点开始游戏后 WorldSelectPanel 显示")
	assert_false(mm.get_node("ButtonLayer/VBox").visible)


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
