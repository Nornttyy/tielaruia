# 主菜单：背景层 (天空渐变 + 云 + 山 + 树 + 地面 + slime) + 标题层 (LOGO + 呼吸)
# + 按钮层 (4 按钮 + hover ▶ + 淡出过渡) + 设置子面板 (主音量滑条)。
# 由 main.gd 实例化并监听 start_game 信号。
extends CanvasLayer

signal start_game

const MenuSceneArt = preload("res://scripts/art/menu_scene_art.gd")
const LogoArt = preload("res://scripts/art/logo_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")

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
	_setup_hills()
	_setup_trees()
	_setup_clouds()
	_setup_slimes()
	_setup_title()
	_start_title_breathing()
	_setup_buttons()
	_setup_settings_panel()


func _process(delta: float) -> void:
	if not visible:
		return
	_animate_clouds(delta)
	_animate_slimes(delta)


# ---- background ----

func _setup_sky_gradient() -> void:
	# 在 Sky ColorRect 上叠一个 GradientTexture2D TextureRect 实现渐变
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(42, 26, 58))
	gradient.add_point(0.5, Color8(196, 110, 60))
	gradient.set_color(gradient.get_point_count() - 1, Color8(242, 194, 101))
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
	var t := create_tween().set_loops()
	t.tween_property(logo, "offset_top", base_y - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo, "offset_top", base_y, 1.5).set_trans(Tween.TRANS_SINE)
	var t2 := create_tween().set_loops()
	t2.tween_property(shadow, "offset_top", sh_base - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t2.tween_property(shadow, "offset_top", sh_base, 1.5).set_trans(Tween.TRANS_SINE)


# ---- buttons ----

func _setup_buttons() -> void:
	var rows := [
		{"row": "NewGameRow", "callback": _on_new_game_pressed},
		{"row": "ContinueRow", "callback": Callable()},
		{"row": "SettingsRow", "callback": _on_settings_pressed},
		{"row": "QuitRow", "callback": _on_quit_pressed},
	]
	for entry in rows:
		var row_name: String = entry["row"]
		var btn: Button = $ButtonLayer/VBox.get_node(row_name + "/Button")
		var arrow: Label = $ButtonLayer/VBox.get_node(row_name + "/Arrow")
		_apply_button_style(btn)
		btn.mouse_entered.connect(func(): arrow.visible = true)
		btn.mouse_exited.connect(func(): arrow.visible = false)
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
	# 淡出按钮 0.3s + 黑场 0.4s → emit start_game
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): start_game.emit())


func _on_settings_pressed() -> void:
	$SettingsPanel.visible = true
	$ButtonLayer/VBox.visible = false


func _on_settings_back_pressed() -> void:
	$SettingsPanel.visible = false
	$ButtonLayer/VBox.visible = true


func _on_quit_pressed() -> void:
	get_tree().quit()


# ---- settings panel ----

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
