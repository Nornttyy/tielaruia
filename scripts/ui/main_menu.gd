# 主菜单：背景层 (天空渐变 + 云 + 山 + 树 + 地面 + slime) + 标题层 (LOGO + 呼吸)
# + 按钮层 (4 按钮 + hover ▶ + 淡出过渡) + 设置子面板 (主音量滑条)。
# 由 main.gd 实例化并监听 start_game 信号。
extends CanvasLayer

signal start_game(opts: Dictionary)
signal continue_game(save_data: Resource)

# 难度枚举: 0 简单, 1 普通, 2 困难
const DIFF_EASY := 0
const DIFF_NORMAL := 1
const DIFF_HARD := 2

const MenuSceneArt = preload("res://scripts/art/menu_scene_art.gd")
const LogoArt = preload("res://scripts/art/logo_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")
const ParticlesArt = preload("res://scripts/fx/particles_art.gd")

const VIEWPORT_SIZE := Vector2(1280, 720)
const CLOUD_COUNT := 4
const TREE_COUNT := 5
const SLIME_COUNT := 2
const CLOUD_SPEED_RANGE := Vector2(6.0, 14.0)
const SLIME_HOP_INTERVAL := 2.5

const BTN_NORMAL_BG := Color8(58, 42, 26)
const BTN_NORMAL_BORDER := Color8(212, 181, 138)
const BTN_NORMAL_TEXT := Color8(242, 194, 101)
const BTN_HOVER_BG := Color8(90, 58, 42)
const BTN_HOVER_BORDER := Color8(242, 194, 101)
const BTN_HOVER_TEXT := Color8(255, 245, 220)
const BTN_PRESSED_BG := Color8(42, 26, 10)

@onready var _hills: Sprite2D = $BackgroundLayer/Hills
@onready var _trees_root: Node2D = $BackgroundLayer/Trees
@onready var _clouds_root: Node2D = $BackgroundLayer/Clouds
@onready var _slimes_root: Node2D = $BackgroundLayer/Slimes

var _cloud_speeds: Array[float] = []
var _slime_hop_timers: Array[float] = []
var _slime_base_y: Array[float] = []


func _ready() -> void:
	_setup_sky_gradient()
	_setup_stars()
	_setup_hills()
	_setup_trees()
	_setup_clouds()
	_setup_torches()
	_setup_slimes()
	_setup_title()
	_start_title_breathing()
	_setup_buttons()
	_setup_settings_panel()
	_setup_new_game_panel()
	_setup_world_select_panel()
	# i18n: 用当前语言覆盖 .tscn 默认中文; 切语言时再调一次刷新.
	_refresh_localized_text()
	Locale.language_changed.connect(_on_language_changed)


# 接 Locale.language_changed: 切语言时刷新所有 UI 文字, 并重建 saves list (因为它是动态生成).
func _on_language_changed(_new_lang: String) -> void:
	_refresh_localized_text()
	# WorldSelectPanel 可见时 saves list 里的 "[简单]" / "进入" / "删除" 也要重刷
	if has_node("WorldSelectPanel") and $WorldSelectPanel.visible:
		_refresh_saves_list()
	# 多人面板的状态文字 (依赖当前 NetworkManager.status) 也要重译
	if has_node("MultiplayerPanel") and $MultiplayerPanel.visible:
		_refresh_multiplayer_status()


# 用 Locale.t() 把所有面板的静态文字 (标题/按钮/标签/placeholder) 重新拉一遍.
# 动态内容 (saves list, status label) 不在这里, 由各自的 refresh 函数管.
func _refresh_localized_text() -> void:
	# Logo 下面的副标题
	if has_node("TitleLayer/Subtitle"):
		$TitleLayer/Subtitle.text = Locale.t("menu_subtitle")

	# 主菜单 3 按钮
	$ButtonLayer/VBox/NewGameRow/Button.text = Locale.t("menu_new_game")
	$ButtonLayer/VBox/MultiplayerRow/Button.text = Locale.t("menu_multiplayer")
	$ButtonLayer/VBox/SettingsRow/Button.text = Locale.t("menu_settings")

	# 设置面板
	$SettingsPanel/VBox/TitleLabel.text = Locale.t("settings_title")
	$SettingsPanel/VBox/VolumeRow/Label.text = Locale.t("settings_master_volume")
	$SettingsPanel/VBox/ZoomRow/Label.text = Locale.t("settings_camera_zoom")
	$SettingsPanel/VBox/LanguageRow/Label.text = Locale.t("lang_label")
	$SettingsPanel/VBox/NameRow/Label.text = Locale.t("settings_player_name")
	$SettingsPanel/VBox/NameRow/LineEdit.placeholder_text = Locale.t("settings_player_name_placeholder")
	$SettingsPanel/VBox/EnemyHpBarRow/Label.text = Locale.t("settings_enemy_hp_bar")
	$SettingsPanel/VBox/EnemyHpNumberRow/Label.text = Locale.t("settings_enemy_hp_number")
	$SettingsPanel/VBox/ScrollWheelRow/Label.text = Locale.t("settings_scroll_zoom")
	$SettingsPanel/VBox/BackButton.text = Locale.t("settings_back")

	# 世界选择面板
	$WorldSelectPanel/VBox/TitleLabel.text = Locale.t("world_select_title")
	$WorldSelectPanel/VBox/NewWorldButton.text = Locale.t("world_new")
	$WorldSelectPanel/VBox/EmptyLabel.text = Locale.t("world_select_empty")
	$WorldSelectPanel/VBox/BackButton.text = Locale.t("world_back")

	# 新建世界面板
	$NewGamePanel/VBox/TitleLabel.text = Locale.t("newgame_title")
	$NewGamePanel/VBox/NameRow/Label.text = Locale.t("newgame_name_label")
	$NewGamePanel/VBox/NameRow/LineEdit.placeholder_text = Locale.t("newgame_default_world_name")
	$NewGamePanel/VBox/SeedRow/Label.text = Locale.t("newgame_seed_label")
	$NewGamePanel/VBox/SeedRow/LineEdit.placeholder_text = Locale.t("newgame_seed_placeholder")
	$NewGamePanel/VBox/SeedRow/RandomButton.text = Locale.t("newgame_seed_random")
	$NewGamePanel/VBox/DifficultyRow/Label.text = Locale.t("newgame_difficulty_label")
	$NewGamePanel/VBox/DifficultyRow/EasyButton.text = Locale.t("newgame_difficulty_easy")
	$NewGamePanel/VBox/DifficultyRow/NormalButton.text = Locale.t("newgame_difficulty_normal")
	$NewGamePanel/VBox/DifficultyRow/HardButton.text = Locale.t("newgame_difficulty_hard")
	$NewGamePanel/VBox/ModeRow/Label.text = Locale.t("newgame_mode_label")
	$NewGamePanel/VBox/ModeRow/SurvivalButton.text = Locale.t("newgame_mode_survival")
	$NewGamePanel/VBox/ModeRow/CreativeButton.text = Locale.t("newgame_mode_creative")
	$NewGamePanel/VBox/ButtonRow/CancelButton.text = Locale.t("newgame_cancel")
	$NewGamePanel/VBox/ButtonRow/StartButton.text = Locale.t("newgame_start")

	# 多人游戏面板
	$MultiplayerPanel/VBox/TitleLabel.text = Locale.t("mp_title")
	$MultiplayerPanel/VBox/JoinRow/JoinInput.placeholder_text = Locale.t("mp_room_code_placeholder")
	$MultiplayerPanel/VBox/JoinRow/JoinButton.text = Locale.t("mp_join_label")
	$MultiplayerPanel/VBox/BackButton.text = Locale.t("mp_back")


func _process(delta: float) -> void:
	if not visible:
		return
	_animate_clouds(delta)
	_animate_slimes(delta)


# ---- background ----

func _setup_sky_gradient() -> void:
	# 在 Sky ColorRect 上叠一个 GradientTexture2D TextureRect 实现渐变.
	# 白天色板: 顶 深天蓝 → 中 中天蓝 → 底 浅天蓝白 (用户要求白天)
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(95, 150, 220))         # 顶: 深天蓝
	gradient.add_point(0.5, Color8(140, 195, 240))      # 中: 中天蓝
	gradient.set_color(gradient.get_point_count() - 1, Color8(200, 225, 245))  # 底: 浅蓝
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.width = 64
	grad_tex.height = 256
	var sky: ColorRect = $BackgroundLayer/Sky
	var tex_rect := TextureRect.new()
	tex_rect.name = "SkyGradient"
	tex_rect.texture = grad_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(tex_rect)


func _setup_hills() -> void:
	_hills.texture = MenuSceneArt.make_hill()
	# 80×10 像素 → 屏宽，高度放大 6 倍
	_hills.scale = Vector2(VIEWPORT_SIZE.x / 80.0, 6.0)
	_hills.position = Vector2(0, VIEWPORT_SIZE.y * 0.55)


func _setup_trees() -> void:
	var tree_tex = MenuSceneArt.make_tree()
	var x_positions := [80.0, 280.0, 540.0, 820.0, 1100.0]
	var scales := [3.0, 4.0, 3.5, 4.5, 3.0]
	for i in TREE_COUNT:
		var s := Sprite2D.new()
		s.texture = tree_tex
		s.centered = false
		s.scale = Vector2(scales[i], scales[i])
		# 12×16 像素 × scale，树底贴到地面 (y = 0.75 * 720)
		s.position = Vector2(x_positions[i], VIEWPORT_SIZE.y * 0.75 - 16.0 * scales[i])
		_trees_root.add_child(s)


func _setup_stars() -> void:
	# 暮色顶部 14 颗微亮星, 随机位置 + 缓慢闪烁
	var sky_layer: Control = $BackgroundLayer
	for i in 14:
		var s := ColorRect.new()
		s.color = Color(1, 1, 0.88, 0.7)
		s.size = Vector2(2, 2)
		var x: float = randf() * VIEWPORT_SIZE.x
		var y: float = randf_range(20.0, VIEWPORT_SIZE.y * 0.28)
		s.position = Vector2(x, y)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sky_layer.add_child(s)
		var period: float = randf_range(1.2, 2.6)
		var min_a: float = randf_range(0.15, 0.45)
		var t := create_tween().set_loops()
		t.tween_property(s, "modulate:a", min_a, period).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


func _setup_torches() -> void:
	# 用游戏内 BlocksArt 的 TORCH 像素贴图 (16×16 放大 3x) + 软光晕 + 火花粒子, 与游戏内火把统一
	var torch_tex: Texture2D = ArtCache.block_icons.get(Tiles.TORCH)
	if torch_tex == null:
		return
	var glow_tex: Texture2D = ArtCache.radial_gradient(160)
	var ground_layer: Node = $BackgroundLayer
	var torch_x := [180.0, 1050.0]
	var ground_y: float = VIEWPORT_SIZE.y * 0.75
	for tx in torch_x:
		# 光晕 (画在最底)
		var glow := Sprite2D.new()
		glow.texture = glow_tex
		glow.modulate = Color(1.0, 0.65, 0.25, 0.45)
		glow.scale = Vector2(1.4, 1.4)
		glow.position = Vector2(tx, ground_y - 30.0)
		ground_layer.add_child(glow)
		# 火把本体 (像素画 16×16 → 48×48). 像素图本身已含火苗, 不再叠 flame_overlay.
		var torch := Sprite2D.new()
		torch.texture = torch_tex
		torch.scale = Vector2(3, 3)
		torch.centered = false
		torch.position = Vector2(tx - 24.0, ground_y - 48.0)
		ground_layer.add_child(torch)
		# 光晕呼吸 (alpha 节律), 让火光感来自光晕本身而非贴图叠加
		var t := create_tween().set_loops()
		t.tween_property(glow, "modulate:a", 0.60, 0.10)
		t.tween_property(glow, "modulate:a", 0.35, 0.13)
		t.tween_property(glow, "modulate:a", 0.50, 0.09)
		t.tween_property(glow, "modulate:a", 0.45, 0.12)
		# 周期生成上升火花
		_start_menu_spark_timer(Vector2(tx, ground_y - 42.0), ground_layer)


func _start_menu_spark_timer(spawn_pos: Vector2, parent: Node) -> void:
	var timer := Timer.new()
	timer.wait_time = randf_range(0.15, 0.25)
	timer.one_shot = false
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(func():
		_spawn_menu_spark(spawn_pos, parent)
		timer.wait_time = randf_range(0.15, 0.30)
	)


# 一颗向上飘的暖色火花. 0.8s 内淡出 + 上升 + 微随机水平摆.
func _spawn_menu_spark(pos: Vector2, parent: Node) -> void:
	var color: Color
	if randf() < 0.05:
		color = Color(1.0, 0.3, 0.1)  # 5% 红
	else:
		color = Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.5, 0.2), randf())
	var spark := Sprite2D.new()
	spark.texture = ParticlesArt.get_torch_spark(color)
	spark.scale = Vector2(2, 2)
	spark.position = pos + Vector2(randf_range(-3, 3), 0)
	parent.add_child(spark)
	var rise: float = randf_range(40.0, 80.0)
	var drift: float = randf_range(-12.0, 12.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(spark, "position:y", spark.position.y - rise, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(spark, "position:x", spark.position.x + drift, 0.8)
	t.tween_property(spark, "modulate:a", 0.0, 0.8).set_trans(Tween.TRANS_QUAD)
	t.chain().tween_callback(spark.queue_free)


func _setup_clouds() -> void:
	var cloud_tex = MenuSceneArt.make_cloud()
	for i in CLOUD_COUNT:
		var s := Sprite2D.new()
		s.texture = cloud_tex
		s.centered = false
		s.scale = Vector2(4.0, 4.0)
		var x: float = randf() * VIEWPORT_SIZE.x
		var y: float = randf_range(40.0, VIEWPORT_SIZE.y * 0.3)
		s.position = Vector2(x, y)
		_clouds_root.add_child(s)
		_cloud_speeds.append(randf_range(CLOUD_SPEED_RANGE.x, CLOUD_SPEED_RANGE.y))


func _setup_slimes() -> void:
	var sf = SlimeArt.build_sprite_frames()
	var slime_x := [400.0, 880.0]
	for i in SLIME_COUNT:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sf
		anim.animation = "idle"
		anim.play()
		anim.scale = Vector2(3.0, 3.0)
		# 16×12 sprite，底部贴地面
		var base_y: float = VIEWPORT_SIZE.y * 0.75 - 12.0 * 3.0
		anim.position = Vector2(slime_x[i], base_y)
		_slimes_root.add_child(anim)
		_slime_hop_timers.append(randf_range(0.0, SLIME_HOP_INTERVAL))
		_slime_base_y.append(base_y)


func _animate_clouds(delta: float) -> void:
	for i in _clouds_root.get_child_count():
		var c: Sprite2D = _clouds_root.get_child(i)
		c.position.x += _cloud_speeds[i] * delta
		var cloud_w := 24.0 * c.scale.x
		if c.position.x > VIEWPORT_SIZE.x:
			c.position.x = -cloud_w


func _animate_slimes(delta: float) -> void:
	for i in _slimes_root.get_child_count():
		_slime_hop_timers[i] -= delta
		if _slime_hop_timers[i] > 0.0:
			continue
		_slime_hop_timers[i] = SLIME_HOP_INTERVAL + randf_range(-0.5, 0.5)
		var slime: AnimatedSprite2D = _slimes_root.get_child(i)
		var base_y: float = _slime_base_y[i]
		var t := create_tween()
		t.tween_property(slime, "position:y", base_y - 24.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		t.tween_property(slime, "position:y", base_y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_callback(_slime_back_to_idle.bind(slime))
		slime.animation = "hop"
		slime.play()


func _slime_back_to_idle(slime: AnimatedSprite2D) -> void:
	slime.animation = "idle"
	slime.play()


# ---- title ----

func _setup_title() -> void:
	var logo: Label = $TitleLayer/LogoLabel
	var shadow: Label = $TitleLayer/LogoShadow
	LogoArt.style_main_label(logo)
	LogoArt.style_shadow_label(shadow)


func _start_title_breathing() -> void:
	var logo: Label = $TitleLayer/LogoLabel
	var shadow: Label = $TitleLayer/LogoShadow
	var base_y := logo.offset_top
	var sh_base := shadow.offset_top
	# Y 漂浮 (上下 4 px)
	var t := create_tween().set_loops()
	t.tween_property(logo, "offset_top", base_y - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo, "offset_top", base_y, 1.5).set_trans(Tween.TRANS_SINE)
	var t2 := create_tween().set_loops()
	t2.tween_property(shadow, "offset_top", sh_base - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t2.tween_property(shadow, "offset_top", sh_base, 1.5).set_trans(Tween.TRANS_SINE)
	# 缩放呼吸 (1.0 ↔ 1.06), 配合 pivot 居中
	logo.pivot_offset = logo.size / 2.0
	shadow.pivot_offset = shadow.size / 2.0
	var t3 := create_tween().set_loops()
	t3.tween_property(logo, "scale", Vector2(1.06, 1.06), 1.8).set_trans(Tween.TRANS_SINE)
	t3.tween_property(logo, "scale", Vector2(1.0, 1.0), 1.8).set_trans(Tween.TRANS_SINE)
	# 主标签颜色冷暖循环, 模拟金光呼吸
	var c_warm := Color8(255, 230, 150)
	var c_cool := Color8(220, 180, 80)
	var t4 := create_tween().set_loops()
	t4.tween_property(logo, "theme_override_colors/font_color", c_warm, 2.2).set_trans(Tween.TRANS_SINE)
	t4.tween_property(logo, "theme_override_colors/font_color", c_cool, 2.2).set_trans(Tween.TRANS_SINE)


# ---- buttons ----

func _setup_buttons() -> void:
	var rows := [
		{"row": "NewGameRow", "callback": _on_new_game_pressed},
		{"row": "MultiplayerRow", "callback": _on_multiplayer_pressed},
		{"row": "SettingsRow", "callback": _on_settings_pressed},
	]
	for entry in rows:
		var row_name: String = entry["row"]
		var btn: Button = $ButtonLayer/VBox.get_node(row_name + "/Button")
		var arrow: Label = $ButtonLayer/VBox.get_node(row_name + "/Arrow")
		_apply_button_style(btn)
		btn.pivot_offset = btn.size / 2.0
		btn.mouse_entered.connect(func():
			arrow.visible = true
			# hover 时按钮微微放大 (1.05) 给视觉反馈
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.05, 1.05), 0.08).set_trans(Tween.TRANS_QUAD)
		)
		btn.mouse_exited.connect(func():
			arrow.visible = false
			var tw := create_tween()
			tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.10).set_trans(Tween.TRANS_QUAD)
		)
		var cb: Callable = entry["callback"]
		if cb.is_valid():
			btn.pressed.connect(cb)


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_NORMAL_BG
	normal.border_color = BTN_NORMAL_BORDER
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BTN_HOVER_BG
	hover.border_color = BTN_HOVER_BORDER
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BTN_PRESSED_BG
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 6
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color8(40, 30, 20)
	disabled.border_color = Color8(100, 80, 60)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", BTN_NORMAL_TEXT)
	btn.add_theme_color_override("font_hover_color", BTN_HOVER_TEXT)
	btn.add_theme_color_override("font_pressed_color", BTN_NORMAL_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color8(120, 100, 80))
	btn.add_theme_font_size_override("font_size", 18)


func _on_new_game_pressed() -> void:
	# 点 "开始游戏" → 显 WorldSelectPanel + 刷新存档列表
	$WorldSelectPanel.visible = true
	$ButtonLayer/VBox.visible = false
	_refresh_saves_list()


# 重新扫所有存档, 动态生成 UI 列表条目
func _refresh_saves_list() -> void:
	var list: VBoxContainer = $WorldSelectPanel/VBox/SavesScroll/SavesList
	var empty_label: Label = $WorldSelectPanel/VBox/EmptyLabel
	# 清旧条目
	for child in list.get_children():
		child.queue_free()
	var saves: Array = SaveManager.list_saves()
	empty_label.visible = saves.is_empty()
	for entry in saves:
		var save_name: String = entry["name"]
		var data = entry["data"]
		_make_save_row(list, save_name, data)


# 创建一行存档: [世界名 难度]  [进入]  [删除]
func _make_save_row(parent: VBoxContainer, save_name: String, data) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 44)
	row.size_flags_horizontal = 3
	# 世界名 + 难度 (难度文字按当前语言)
	var label := Label.new()
	var diff_key: String = "save_diff_normal"
	if data.difficulty == DIFF_EASY:
		diff_key = "save_diff_easy"
	elif data.difficulty == DIFF_HARD:
		diff_key = "save_diff_hard"
	label.text = "%s   [%s]" % [save_name, Locale.t(diff_key)]
	label.size_flags_horizontal = 3
	label.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396, 1.0))
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	# 进入按钮
	var enter_btn := Button.new()
	enter_btn.text = Locale.t("world_enter")
	enter_btn.custom_minimum_size = Vector2(70, 0)
	_apply_button_style(enter_btn)
	enter_btn.pressed.connect(func(): _on_load_save_pressed(save_name))
	row.add_child(enter_btn)
	# 删除按钮 (点了弹确认对话框, 防误删)
	var del_btn := Button.new()
	del_btn.text = Locale.t("world_delete")
	del_btn.custom_minimum_size = Vector2(60, 0)
	_apply_button_style(del_btn)
	del_btn.pressed.connect(func(): _confirm_delete_save(save_name))
	row.add_child(del_btn)
	parent.add_child(row)


# 弹 ConfirmationDialog: 真的删存档吗? OK → 删 + 刷新; 取消 → 啥也不做
func _confirm_delete_save(save_name: String) -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = Locale.t("delete_save_title")
	dlg.dialog_text = Locale.t("delete_save_message") % save_name
	dlg.ok_button_text = Locale.t("delete_save_ok")
	dlg.get_cancel_button().text = Locale.t("delete_save_cancel")
	dlg.confirmed.connect(func():
		SaveManager.delete_save_by_name(save_name)
		_refresh_saves_list()
		dlg.queue_free()
	)
	dlg.canceled.connect(func(): dlg.queue_free())
	# 用户按 X 关 (close_requested) — 老代码漏接, 对话框留 scene tree leak
	dlg.close_requested.connect(func(): dlg.queue_free())
	add_child(dlg)
	dlg.popup_centered()


# 点存档行的 "进入" → 用对应名字读存档进游戏
func _on_load_save_pressed(save_name: String) -> void:
	var data = SaveManager.load_save_by_name(save_name)
	if data == null:
		return
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): continue_game.emit(data))


# 从 WorldSelectPanel 点 "创建新世界" → 显 NewGamePanel.
# 自动给 name LineEdit 填一个不冲突的默认名 (我的世界 / 我的世界 2 / 我的世界 3 ...)
# 防 bug "不能创建多个世界" (没改名直接开始会覆盖上一个同名存档).
func _on_create_world_pressed() -> void:
	$WorldSelectPanel.visible = false
	$NewGamePanel.visible = true
	var name_edit: LineEdit = $NewGamePanel.get_node("VBox/NameRow/LineEdit")
	if name_edit != null:
		name_edit.text = _compute_unique_world_name()


# 扫已存档名, 找第一个不冲突的默认 "我的世界" / "我的世界 2" / ... .
func _compute_unique_world_name() -> String:
	var base: String = Locale.t("newgame_default_world_name")
	var existing: Dictionary = {}
	for entry in SaveManager.list_saves():
		existing[String(entry["name"])] = true
	if not existing.has(base):
		return base
	var i: int = 2
	while existing.has("%s %d" % [base, i]):
		i += 1
	return "%s %d" % [base, i]


# 从 WorldSelectPanel 点 "返回" → 回主菜单
func _on_world_select_back_pressed() -> void:
	$WorldSelectPanel.visible = false
	$ButtonLayer/VBox.visible = true


# 配置完成 → 淡出 + 发 start_game(opts)
func _emit_start_game_with(opts: Dictionary) -> void:
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	$NewGamePanel.visible = false
	vbox.visible = true  # vbox.modulate.a 还要 fade, 显示让淡出可见
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): start_game.emit(opts))


func _on_continue_pressed() -> void:
	# 读存档, 用存档 seed + 状态启动. 没存档就 noop (按钮应已被禁用).
	var data = SaveManager.load_save()
	if data == null:
		return
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): continue_game.emit(data))


# 回主菜单时复位淡出状态: VBox 重新可见, FadeOverlay 透明.
# 由 main.gd 在 _show_menu_state 重新显示菜单时调用.
func reset_visuals() -> void:
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	if fade != null:
		fade.modulate.a = 0.0
	if vbox != null:
		vbox.modulate.a = 1.0
		vbox.visible = true
	# 关闭可能开着的子面板
	if has_node("NewGamePanel"):
		$NewGamePanel.visible = false
	if has_node("WorldSelectPanel"):
		$WorldSelectPanel.visible = false
	if has_node("SettingsPanel"):
		$SettingsPanel.visible = false
	if has_node("MultiplayerPanel"):
		$MultiplayerPanel.visible = false


func _on_settings_pressed() -> void:
	$SettingsPanel.visible = true
	$ButtonLayer/VBox.visible = false


func _on_settings_back_pressed() -> void:
	$SettingsPanel.visible = false
	$ButtonLayer/VBox.visible = true


# ---- settings panel ----

# ---- new game panel ----

func _setup_world_select_panel() -> void:
	var panel := $WorldSelectPanel
	var new_btn: Button = panel.get_node("VBox/NewWorldButton")
	var back_btn: Button = panel.get_node("VBox/BackButton")
	_apply_button_style(new_btn)
	_apply_button_style(back_btn)
	new_btn.pressed.connect(_on_create_world_pressed)
	back_btn.pressed.connect(_on_world_select_back_pressed)


func _setup_new_game_panel() -> void:
	var panel := $NewGamePanel
	var name_edit: LineEdit = panel.get_node("VBox/NameRow/LineEdit")
	var seed_edit: LineEdit = panel.get_node("VBox/SeedRow/LineEdit")
	var random_btn: Button = panel.get_node("VBox/SeedRow/RandomButton")
	var easy_btn: Button = panel.get_node("VBox/DifficultyRow/EasyButton")
	var normal_btn: Button = panel.get_node("VBox/DifficultyRow/NormalButton")
	var hard_btn: Button = panel.get_node("VBox/DifficultyRow/HardButton")
	var small_btn: Button = panel.get_node("VBox/SizeRow/SmallButton")
	var medium_btn: Button = panel.get_node("VBox/SizeRow/MediumButton")
	var large_btn: Button = panel.get_node("VBox/SizeRow/LargeButton")
	var survival_btn: Button = panel.get_node("VBox/ModeRow/SurvivalButton")
	var creative_btn: Button = panel.get_node("VBox/ModeRow/CreativeButton")
	var cancel_btn: Button = panel.get_node("VBox/ButtonRow/CancelButton")
	var start_btn: Button = panel.get_node("VBox/ButtonRow/StartButton")
	_apply_button_style(random_btn)
	_apply_button_style(easy_btn)
	_apply_button_style(normal_btn)
	_apply_button_style(hard_btn)
	_apply_button_style(small_btn)
	_apply_button_style(medium_btn)
	_apply_button_style(large_btn)
	_apply_button_style(survival_btn)
	_apply_button_style(creative_btn)
	_apply_button_style(cancel_btn)
	_apply_button_style(start_btn)
	# 难度: 3 个互斥 toggle (像 radio button)
	var diff_btns: Array = [easy_btn, normal_btn, hard_btn]
	for i in diff_btns.size():
		var btn: Button = diff_btns[i]
		var idx: int = i
		btn.toggled.connect(func(on: bool):
			if not on:
				return
			for j in diff_btns.size():
				if j != idx:
					diff_btns[j].button_pressed = false
		)
	# 世界大小: 同款 radio toggle
	var size_btns: Array = [small_btn, medium_btn, large_btn]
	for i in size_btns.size():
		var btn: Button = size_btns[i]
		var idx: int = i
		btn.toggled.connect(func(on: bool):
			if not on:
				return
			for j in size_btns.size():
				if j != idx:
					size_btns[j].button_pressed = false
		)
	# 模式: 生存/创造 同款互斥 toggle
	var mode_btns: Array = [survival_btn, creative_btn]
	for i in mode_btns.size():
		var btn: Button = mode_btns[i]
		var idx: int = i
		btn.toggled.connect(func(on: bool):
			if not on:
				return
			for j in mode_btns.size():
				if j != idx:
					mode_btns[j].button_pressed = false
		)
	# 随机种子按钮
	random_btn.pressed.connect(func():
		seed_edit.text = str(randi_range(1, 999999))
	)
	# 取消: 回 WorldSelectPanel (而不是直接到主菜单)
	cancel_btn.pressed.connect(func():
		panel.visible = false
		$WorldSelectPanel.visible = true
	)
	# 开始: 读输入 → opts → 淡出开始
	start_btn.pressed.connect(func():
		var opts: Dictionary = {}
		# 世界名 (空则按当前语言默认 "我的世界" / "My World" / ...)
		var nm: String = name_edit.text.strip_edges()
		opts["world_name"] = Locale.t("newgame_default_world_name") if nm.is_empty() else nm
		# seed: 空 / 非数字 → 随机
		var seed_text: String = seed_edit.text.strip_edges()
		if seed_text.is_empty() or not seed_text.is_valid_int():
			opts["world_seed"] = randi_range(1, 999999)
		else:
			opts["world_seed"] = int(seed_text)
		# 难度
		var diff: int = DIFF_NORMAL
		if easy_btn.button_pressed:
			diff = DIFF_EASY
		elif hard_btn.button_pressed:
			diff = DIFF_HARD
		opts["difficulty"] = diff
		# 世界大小 (0=小 1=中 2=大)
		var ws: int = 1
		if small_btn.button_pressed:
			ws = 0
		elif large_btn.button_pressed:
			ws = 2
		opts["world_size"] = ws
		opts["creative_mode"] = creative_btn.button_pressed   # 创造按钮亮 = 创造模式
		_emit_start_game_with(opts)
	)


# ---- multiplayer panel ----

var _mp_wired: bool = false


func _on_multiplayer_pressed() -> void:
	$MultiplayerPanel.visible = true
	$ButtonLayer/VBox.visible = false
	_setup_multiplayer_panel_once()
	_refresh_multiplayer_status()


func _setup_multiplayer_panel_once() -> void:
	if _mp_wired:
		return
	_mp_wired = true
	var panel: Panel = $MultiplayerPanel
	var join_btn: Button = panel.get_node("VBox/JoinRow/JoinButton")
	var back_btn: Button = panel.get_node("VBox/BackButton")
	_apply_button_style(join_btn)
	_apply_button_style(back_btn)
	join_btn.pressed.connect(_on_join_pressed)
	back_btn.pressed.connect(_on_multiplayer_back_pressed)
	# 接 NetworkManager 信号 (autoload, 一直在). host 已移到 PauseMenu, 主菜单只 join.
	if NetworkManager != null:
		if not NetworkManager.status_changed.is_connected(_on_mp_status_changed):
			NetworkManager.status_changed.connect(_on_mp_status_changed)
		if not NetworkManager.error_occurred.is_connected(_on_mp_error):
			NetworkManager.error_occurred.connect(_on_mp_error)
		if not NetworkManager.hello_received.is_connected(_on_mp_hello_received):
			NetworkManager.hello_received.connect(_on_mp_hello_received)


func _on_multiplayer_back_pressed() -> void:
	$MultiplayerPanel.visible = false
	$ButtonLayer/VBox.visible = true
	if NetworkManager != null and NetworkManager.status != "idle":
		NetworkManager.disconnect_room()


func _on_join_pressed() -> void:
	var input: LineEdit = $MultiplayerPanel/VBox/JoinRow/JoinInput
	var code: String = input.text.strip_edges().to_upper()
	if code.length() != 6:
		$MultiplayerPanel/VBox/StatusLabel.text = Locale.t("mp_room_code_invalid")
		return
	if NetworkManager != null:
		NetworkManager.join(code)
	_refresh_multiplayer_status()


func _on_mp_status_changed(_s: String) -> void:
	_refresh_multiplayer_status()


func _on_mp_hello_received(seed_val: int, size_val: int, diff_val: int) -> void:
	# client 收到 host 的 hello → 用同 seed + 同世界大小 + 同难度 启游戏
	if not NetworkManager.is_host:
		_start_multiplayer_game(seed_val, size_val, diff_val)


func _start_multiplayer_game(seed_val: int, size_val: int, diff_val: int) -> void:
	# 淡出主菜单 → 发 start_game(opts), 进游戏. opts 带 multiplayer 标记.
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	$MultiplayerPanel.visible = false
	vbox.visible = true
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): start_game.emit({
		"world_seed": seed_val,
		"world_name": Locale.t("mp_default_world_name"),
		"difficulty": diff_val,
		"world_size": size_val,
		"multiplayer": true,
	}))


func _on_mp_error(msg: String) -> void:
	$MultiplayerPanel/VBox/StatusLabel.text = Locale.t("mp_status_error_prefix") + msg


func _refresh_multiplayer_status() -> void:
	var lbl: Label = $MultiplayerPanel/VBox/StatusLabel
	if NetworkManager == null:
		lbl.text = Locale.t("mp_module_missing")
		return
	match NetworkManager.status:
		"idle":
			lbl.text = Locale.t("mp_status_idle")
		"joining":
			lbl.text = Locale.t("mp_status_joining")
		"connected":
			lbl.text = Locale.t("mp_status_connected")
		"disconnected":
			lbl.text = Locale.t("mp_status_disconnected")
		"error":
			lbl.text = Locale.t("mp_status_error_prefix") + NetworkManager.last_error


func _setup_settings_panel() -> void:
	var slider: HSlider = $SettingsPanel/VBox/VolumeRow/Slider
	var value_label: Label = $SettingsPanel/VBox/VolumeRow/ValueLabel
	var back_btn: Button = $SettingsPanel/VBox/BackButton
	slider.value = GameSettings.master_volume * 100.0
	value_label.text = "%d" % int(slider.value)
	# 拖动只 live 应用音频 (不落盘), 松手 (drag_ended) 才存一次 — 防拖一下写几十次盘
	slider.value_changed.connect(func(v: float):
		GameSettings.set_master_volume_live(v / 100.0)
		value_label.text = "%d" % int(v)
	)
	slider.drag_ended.connect(func(_vc: bool): GameSettings.save_now())
	# 摄像机大小 slider: 0.8 (远视野) ~ 2.0 (近距离). 范围跟 game_settings.camera_zoom clamp 一致.
	var zoom_slider: HSlider = $SettingsPanel/VBox/ZoomRow/Slider
	var zoom_value_label: Label = $SettingsPanel/VBox/ZoomRow/ValueLabel
	zoom_slider.value = GameSettings.camera_zoom
	zoom_value_label.text = "%.1f" % GameSettings.camera_zoom
	zoom_slider.value_changed.connect(func(v: float):
		GameSettings.camera_zoom = v
		zoom_value_label.text = "%.1f" % v
	)
	_setup_language_dropdown()
	# 玩家名输入: 焦点离开 (text_submitted / focus_exited) 才存, 防每个字符都触发 _save()
	var name_edit: LineEdit = $SettingsPanel/VBox/NameRow/LineEdit
	name_edit.text = GameSettings.player_name
	name_edit.text_submitted.connect(func(t: String):
		GameSettings.player_name = t
		name_edit.text = GameSettings.player_name  # setter 会清洗, 回显清洗后的值
	)
	name_edit.focus_exited.connect(func():
		GameSettings.player_name = name_edit.text
		name_edit.text = GameSettings.player_name
	)
	# 怪物血条 + 血量数字: 2 个 checkbox, 切换立刻生效 (HealthBar 监听 settings_changed)
	var hp_bar_cb: CheckBox = $SettingsPanel/VBox/EnemyHpBarRow/CheckBox
	hp_bar_cb.button_pressed = GameSettings.show_enemy_hp_bar
	hp_bar_cb.toggled.connect(func(p: bool): GameSettings.show_enemy_hp_bar = p)
	var hp_num_cb: CheckBox = $SettingsPanel/VBox/EnemyHpNumberRow/CheckBox
	hp_num_cb.button_pressed = GameSettings.show_enemy_hp_number
	hp_num_cb.toggled.connect(func(p: bool): GameSettings.show_enemy_hp_number = p)
	# 滚轮: 勾上 = 缩放摄像头, 不勾 = 切换快捷栏物品 (默认)
	var scroll_cb: CheckBox = $SettingsPanel/VBox/ScrollWheelRow/CheckBox
	scroll_cb.button_pressed = GameSettings.scroll_wheel_zoom
	scroll_cb.toggled.connect(func(p: bool): GameSettings.scroll_wheel_zoom = p)
	_apply_button_style(back_btn)
	back_btn.pressed.connect(_on_settings_back_pressed)


# 语言下拉: 4 个选项, 每项用各语言本身的名字 (中文显 "中文", 英文显 "English").
# 选中当前语言, 改了就调 Locale.set_language() (它存盘 + 发信号让 UI 刷新).
func _setup_language_dropdown() -> void:
	var opt: OptionButton = $SettingsPanel/VBox/LanguageRow/OptionButton
	opt.clear()
	for code in Locale.SUPPORTED:
		opt.add_item(Locale.language_display_name(code))
	opt.selected = Locale.current_language_index()
	# item_selected(i): 用 i 反查 SUPPORTED[i] → 切语言.
	opt.item_selected.connect(func(idx: int):
		var code: String = Locale.SUPPORTED[idx]
		Locale.set_language(code)
	)
