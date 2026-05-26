# 加载层: 暮色背景 + 玩家像素小人跑步 + 真实进度条 + 可点击切换小贴士.
# 由 main.gd 在 _start_game 中 instantiate, 加载过程一步一步调 set_progress 推进.
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它

const PlayerArt = preload("res://scripts/art/player_art.gd")
const VIEWPORT_SIZE := Vector2(1280, 720)


func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()


# 暮色渐变, 复用 main_menu 的色板 (顶深紫 → 暮色橙红 → 金橙 → 暖肉粉)
func _setup_sky() -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.anchor_right = 1.0
	sky.anchor_bottom = 1.0
	sky.color = Color8(80, 50, 90)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(80, 50, 90))
	gradient.add_point(0.35, Color8(220, 110, 90))
	gradient.add_point(0.65, Color8(255, 180, 110))
	gradient.set_color(gradient.get_point_count() - 1, Color8(255, 210, 150))
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
