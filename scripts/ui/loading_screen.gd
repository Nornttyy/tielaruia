# 加载层: 暮色背景 + 玩家像素小人跑步 + 真实进度条 + 可点击切换小贴士.
# 由 main.gd 在 _start_game 中 instantiate, 加载过程一步一步调 set_progress 推进.
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它

const PlayerArt = preload("res://scripts/art/player_art.gd")
const VIEWPORT_SIZE := Vector2(1280, 720)
const BAR_SIZE := Vector2(480, 28)
const BAR_BG_COLOR := Color8(18, 32, 58)     # 深蓝底 (统一蓝色 UI)
const BAR_BORDER := Color8(72, 122, 184)     # 蓝边
const BAR_FILL_COLOR := Color8(90, 170, 240) # 蓝色进度
const TEXT_WARM := Color8(242, 194, 101)
const TIP_AUTO_INTERVAL := 4.0
const TIP_HINT_SUFFIX := "    (点击换一条)"
const FADE_DURATION := 0.5
const TIPS: PackedStringArray = [
	"小贴士: 按 A / D 左右移动",
	"小贴士: 按 空格 跳跃",
	"小贴士: 按住 鼠标左键 挖方块",
	"小贴士: 鼠标右键 (或 F) 放方块 / 吃食物",
	"小贴士: 走近箱子按 E 打开",
	"小贴士: 按 数字 1-9 切换热键栏",
	"小贴士: 走到工作台前点一下打开合成",
	"小贴士: 砍树就能拿到木头",
	"小贴士: 挖矿要用更好的镐子",
	"小贴士: 火把可以照亮山洞",
	"小贴士: 晚上小心僵尸出没!",
	"小贴士: slime 弱, 适合新手练习",
	"小贴士: 牛 / 羊 / 猪 可以打掉拿肉",
	"小贴士: 肚子饿了记得吃东西",
	"小贴士: 按 Esc 暂停游戏",
	"小贴士: 下雨天会让水变多",
	"小贴士: 闪电过后空气会更清新",
	"小贴士: 萤火虫只在晚上出来",
	"小贴士: 死了会在出生点复活, 掉的东西在原地",
	"小贴士: 看到流星记得许愿",
]

var _progress_bg: Panel
var _progress_fill: ColorRect
var _stage_label: Label
var _percent_label: Label
var _progress_tween: Tween
var _tip_button: Button
var _tip_label: Label
var _tips_shuffled: Array[String] = []
var _tip_idx: int = 0
var _tip_timer: Timer
var _fade_overlay: ColorRect


func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()
	_setup_progress_bar()
	_setup_labels()
	_setup_tip()
	_setup_fade_overlay()


# 暮色渐变, 复用 main_menu 的色板 (顶深紫 → 暮色橙红 → 金橙 → 暖肉粉)
func _setup_sky() -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.anchor_right = 1.0
	sky.anchor_bottom = 1.0
	sky.color = Color8(95, 150, 220)   # 白天底色
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	# 白天渐变 (跟主菜单一致)
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
	var tex_rect := TextureRect.new()
	tex_rect.name = "SkyGradient"
	tex_rect.texture = grad_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(tex_rect)


# 14 颗暖白小星, 顶部 28% 区域随机位置 + 闪烁
func _setup_stars() -> void:
	var stars := Control.new()
	stars.name = "Stars"
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)
	for i in 14:
		var s := ColorRect.new()
		s.color = Color(1, 1, 0.88, 0.7)
		s.size = Vector2(2, 2)
		var x: float = randf() * VIEWPORT_SIZE.x
		var y: float = randf_range(20.0, VIEWPORT_SIZE.y * 0.28)
		s.position = Vector2(x, y)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(s)
		var period: float = randf_range(1.2, 2.6)
		var min_a: float = randf_range(0.15, 0.45)
		var t := create_tween().set_loops()
		t.tween_property(s, "modulate:a", min_a, period).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


# 像素玩家小人, 跑 walk 动画
func _setup_player_runner() -> void:
	var runner := AnimatedSprite2D.new()
	runner.name = "PlayerRunner"
	runner.sprite_frames = PlayerArt.build_sprite_frames()
	runner.animation = "walk"
	runner.scale = Vector2(4.0, 4.0)
	runner.position = Vector2(VIEWPORT_SIZE.x / 2.0, VIEWPORT_SIZE.y * 0.45)
	runner.play()
	add_child(runner)


# 进度条: 外框 (BAR_BG_COLOR + BAR_BORDER) + 内填 (BAR_FILL_COLOR)
func _setup_progress_bar() -> void:
	_progress_bg = Panel.new()
	_progress_bg.name = "ProgressBg"
	_progress_bg.custom_minimum_size = BAR_SIZE
	_progress_bg.size = BAR_SIZE
	_progress_bg.position = Vector2(
		(VIEWPORT_SIZE.x - BAR_SIZE.x) / 2.0,
		VIEWPORT_SIZE.y * 0.65,
	)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BAR_BG_COLOR
	bg_style.border_color = BAR_BORDER
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	_progress_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.color = BAR_FILL_COLOR
	_progress_fill.position = Vector2(2, 2)
	_progress_fill.size = Vector2(0, BAR_SIZE.y - 4)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bg.add_child(_progress_fill)


# 阶段文字 (居中 + 暖色) + 百分比 (进度条右边)
func _setup_labels() -> void:
	_stage_label = Label.new()
	_stage_label.name = "StageLabel"
	_stage_label.text = ""
	_stage_label.add_theme_color_override("font_color", TEXT_WARM)
	_stage_label.add_theme_font_size_override("font_size", 22)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.size = Vector2(VIEWPORT_SIZE.x, 28)
	_stage_label.position = Vector2(0, VIEWPORT_SIZE.y * 0.58)
	add_child(_stage_label)

	_percent_label = Label.new()
	_percent_label.name = "PercentLabel"
	_percent_label.text = "0%"
	_percent_label.add_theme_color_override("font_color", TEXT_WARM)
	_percent_label.add_theme_font_size_override("font_size", 18)
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_label.size = Vector2(80, 22)
	_percent_label.position = Vector2(
		_progress_bg.position.x + BAR_SIZE.x + 12,
		_progress_bg.position.y + 3,
	)
	add_child(_percent_label)


# 加载流程逐步调: percent 0..1, stage_text 阶段文字. 进度条用 tween 平滑过渡 0.2s
func set_progress(percent: float, stage_text: String) -> void:
	percent = clamp(percent, 0.0, 1.0)
	_stage_label.text = stage_text
	_percent_label.text = "%d%%" % int(round(percent * 100.0))
	var target_w: float = (BAR_SIZE.x - 4.0) * percent
	if _progress_tween != null and _progress_tween.is_running():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(
		_progress_fill, "size:x", target_w, 0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


# 小贴士: 启动 shuffle 一次顺序, 每 4s 自动切下一条, 点击也切 (+ 重置 timer)
func _setup_tip() -> void:
	_tips_shuffled.clear()
	for t in TIPS:
		_tips_shuffled.append(t)
	_tips_shuffled.shuffle()

	_tip_button = Button.new()
	_tip_button.name = "TipButton"
	_tip_button.flat = true
	_tip_button.focus_mode = Control.FOCUS_NONE
	_tip_button.size = Vector2(VIEWPORT_SIZE.x, 40)
	_tip_button.position = Vector2(0, VIEWPORT_SIZE.y * 0.85)
	add_child(_tip_button)

	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.add_theme_color_override("font_color", TEXT_WARM)
	_tip_label.add_theme_font_size_override("font_size", 18)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.size = _tip_button.size
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_button.add_child(_tip_label)
	_show_current_tip()

	_tip_button.pressed.connect(_on_tip_pressed)

	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_AUTO_INTERVAL
	_tip_timer.one_shot = false
	_tip_timer.autostart = true
	add_child(_tip_timer)
	_tip_timer.timeout.connect(_on_tip_pressed)


func _show_current_tip() -> void:
	_tip_label.text = _tips_shuffled[_tip_idx] + TIP_HINT_SUFFIX


func _on_tip_pressed() -> void:
	_tip_idx = (_tip_idx + 1) % _tips_shuffled.size()
	_show_current_tip()
	if _tip_timer != null:
		_tip_timer.start()  # 重置 4 秒自动计时


# 顶层黑色 ColorRect, 初始透明. finish_and_fade 时 tween 到不透明
func _setup_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


# 加载完成调: 0.5s 黑屏淡出 → emit finished. main.gd 接到信号后 queue_free
func finish_and_fade() -> void:
	var t := create_tween()
	t.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): finished.emit())
