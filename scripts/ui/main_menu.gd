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


func _process(delta: float) -> void:
	if not visible:
		return
	_animate_clouds(delta)
	_animate_slimes(delta)


# ---- background ----

func _setup_sky_gradient() -> void:
	# 在 Sky ColorRect 上叠一个 GradientTexture2D TextureRect 实现渐变.
	# 夕阳色板: 顶 深红紫 → 中 暖橙 → 底 金黄 → 地平线 暖肉粉, 营造黄昏氛围
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(80, 50, 90))           # 顶: 深紫红
	gradient.add_point(0.35, Color8(220, 110, 90))      # 暮色橙红
	gradient.add_point(0.65, Color8(255, 180, 110))     # 金橙
	gradient.set_color(gradient.get_point_count() - 1, Color8(255, 210, 150))  # 底: 暖肉粉
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
		{"row": "ContinueRow", "callback": _on_continue_pressed},
		{"row": "MultiplayerRow", "callback": _on_multiplayer_pressed},
		{"row": "SettingsRow", "callback": _on_settings_pressed},
		{"row": "QuitRow", "callback": _on_quit_pressed},
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
	# 继续按钮: 没存档就禁用 (灰显)
	var continue_btn: Button = $ButtonLayer/VBox/ContinueRow/Button
	if continue_btn != null:
		continue_btn.disabled = not SaveManager.has_save()


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
	# 显示 "新游戏" 配置面板, 不直接开始. 用户填完点 "开始" 才真正进游戏
	$NewGamePanel.visible = true
	$ButtonLayer/VBox.visible = false


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
	if has_node("SettingsPanel"):
		$SettingsPanel.visible = false
	if has_node("MultiplayerPanel"):
		$MultiplayerPanel.visible = false
	# 刷新继续按钮 disabled 状态 (回菜单后可能刚保存了)
	var continue_btn: Button = $ButtonLayer/VBox/ContinueRow/Button
	if continue_btn != null:
		continue_btn.disabled = not SaveManager.has_save()


func _on_settings_pressed() -> void:
	$SettingsPanel.visible = true
	$ButtonLayer/VBox.visible = false


func _on_settings_back_pressed() -> void:
	$SettingsPanel.visible = false
	$ButtonLayer/VBox.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---- settings panel ----

# ---- new game panel ----

func _setup_new_game_panel() -> void:
	var panel := $NewGamePanel
	var name_edit: LineEdit = panel.get_node("VBox/NameRow/LineEdit")
	var seed_edit: LineEdit = panel.get_node("VBox/SeedRow/LineEdit")
	var random_btn: Button = panel.get_node("VBox/SeedRow/RandomButton")
	var easy_btn: Button = panel.get_node("VBox/DifficultyRow/EasyButton")
	var normal_btn: Button = panel.get_node("VBox/DifficultyRow/NormalButton")
	var hard_btn: Button = panel.get_node("VBox/DifficultyRow/HardButton")
	var cancel_btn: Button = panel.get_node("VBox/ButtonRow/CancelButton")
	var start_btn: Button = panel.get_node("VBox/ButtonRow/StartButton")
	_apply_button_style(random_btn)
	_apply_button_style(easy_btn)
	_apply_button_style(normal_btn)
	_apply_button_style(hard_btn)
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
	# 随机种子按钮
	random_btn.pressed.connect(func():
		seed_edit.text = str(randi_range(1, 999999))
	)
	# 取消: 回主菜单按钮
	cancel_btn.pressed.connect(func():
		panel.visible = false
		$ButtonLayer/VBox.visible = true
	)
	# 开始: 读输入 → opts → 淡出开始
	start_btn.pressed.connect(func():
		var opts: Dictionary = {}
		# 世界名 (空则默认)
		var nm: String = name_edit.text.strip_edges()
		opts["world_name"] = "我的世界" if nm.is_empty() else nm
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
		_emit_start_game_with(opts)
	)


# ---- multiplayer panel ----

func _setup_new_game_panel_done():
	pass


func _on_multiplayer_pressed() -> void:
	$MultiplayerPanel.visible = true
	$ButtonLayer/VBox.visible = false
	# 接 "返回" 按钮 (一次性, 在 _ready 已 setup 过就不重复)
	var back_btn: Button = $MultiplayerPanel/VBox/BackButton
	if back_btn != null and not back_btn.pressed.is_connected(_on_multiplayer_back_pressed):
		_apply_button_style(back_btn)
		back_btn.pressed.connect(_on_multiplayer_back_pressed)


func _on_multiplayer_back_pressed() -> void:
	$MultiplayerPanel.visible = false
	$ButtonLayer/VBox.visible = true


func _setup_settings_panel() -> void:
	var slider: HSlider = $SettingsPanel/VBox/VolumeRow/Slider
	var value_label: Label = $SettingsPanel/VBox/VolumeRow/ValueLabel
	var back_btn: Button = $SettingsPanel/VBox/BackButton
	slider.value = GameSettings.master_volume * 100.0
	value_label.text = "%d" % int(slider.value)
	slider.value_changed.connect(func(v: float):
		GameSettings.master_volume = v / 100.0
		value_label.text = "%d" % int(v)
	)
	_apply_button_style(back_btn)
	back_btn.pressed.connect(_on_settings_back_pressed)
