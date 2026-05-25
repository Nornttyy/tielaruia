# 天上的太阳/月亮/星星. CanvasLayer 固定屏幕位置, layer = -8 (在山前天空后).
# 太阳走半圆弧 (白天), 月亮走对称弧 (夜里), 60 颗星星仅夜里淡入 + 眨眼.
extends CanvasLayer

const CelestialArt = preload("res://scripts/art/celestial_art.gd")

const STAR_COUNT := 35    # 70 → 35 (perf, 视觉差别不大)
const VIEWPORT_W := 1280.0
# 节流: 天体更新每 0.05s (20Hz) 一次, 太阳/月亮弧走得慢, 星眨眼 sin 也不需要 60Hz
const _UPDATE_INTERVAL := 0.05
var _update_timer: float = 0.0
const VIEWPORT_H := 720.0
const HORIZON_Y := 420.0       # 跟 mountains_layer 同步
const ARC_HEIGHT := 360.0      # 弧顶到 horizon 的高度
const ARC_RADIUS_X := 520.0    # 太阳/月亮水平摆动半径

var _sun: Sprite2D
var _moon: Sprite2D
var _stars_root: Node2D
var _star_data: Array = []  # 每颗 {node: ColorRect/Sprite2D, phase: float, base_alpha: float}
var _time_accum: float = 0.0
var _layer_alpha: float = 1.0   # 由 ScenicDirector 设 (0=矿洞 1=地表)


func _ready() -> void:
	layer = -8
	# 太阳
	_sun = Sprite2D.new()
	_sun.texture = CelestialArt.sun(30)
	_sun.centered = true
	_sun.visible = false
	add_child(_sun)
	# 月亮
	_moon = Sprite2D.new()
	_moon.texture = CelestialArt.moon(22)
	_moon.centered = true
	_moon.visible = false
	add_child(_moon)
	# 星星
	_stars_root = Node2D.new()
	_stars_root.name = "Stars"
	add_child(_stars_root)
	_spawn_stars()


# 启动随机布满上 60% 屏幕
func _spawn_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 31415
	var star_tex: ImageTexture = CelestialArt.star()
	for i in STAR_COUNT:
		var sp := Sprite2D.new()
		sp.texture = star_tex
		sp.position = Vector2(
			rng.randf_range(0.0, VIEWPORT_W),
			rng.randf_range(0.0, VIEWPORT_H * 0.55)
		)
		# 不同尺寸的星 (有大有小)
		sp.scale = Vector2.ONE * rng.randf_range(0.7, 1.6)
		_stars_root.add_child(sp)
		_star_data.append({
			"node": sp,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.2, 3.0),
			"base_alpha": rng.randf_range(0.5, 1.0),
		})


func _process(delta: float) -> void:
	_update_timer -= delta
	if _update_timer > 0.0:
		return
	# 累积 dt 用作 update 的 delta (这样 sin twinkle 累计正确)
	var step: float = _UPDATE_INTERVAL - _update_timer  # = 已过去的真实时间
	_update_timer = _UPDATE_INTERVAL
	update_celestial(step)


# 把 sun/moon/star 的可见性 + 位置 + 透明度 全算出来.
# 拆出来当作公开方法, 让单元测试能直接调 (不必等帧)
func update_celestial(delta: float) -> void:
	_time_accum += delta
	var t: float = TimeOfDay.time
	# === 太阳 (白天 0.3 ≤ t < 0.7) ===
	if t >= 0.3 and t < 0.7:
		var u: float = (t - 0.3) / 0.4   # 0..1
		var theta: float = u * PI         # 0..PI
		var fade: float = _arc_fade(u)
		_sun.position = Vector2(
			VIEWPORT_W * 0.5 - cos(theta) * ARC_RADIUS_X,
			HORIZON_Y - sin(theta) * ARC_HEIGHT
		)
		_sun.modulate.a = fade * _layer_alpha
		_sun.visible = true
	else:
		_sun.visible = false
	# === 月亮 (夜里 t < 0.2 or t >= 0.8) ===
	if t < 0.2 or t >= 0.8:
		# night_t: 0 在日落 (t=0.8), 1 在日出 (t=0.2)
		var nt: float
		if t >= 0.8:
			nt = (t - 0.8) / 0.4
		else:
			nt = (t + 0.2) / 0.4
		var theta_m: float = nt * PI
		var fade_m: float = _arc_fade(nt)
		_moon.position = Vector2(
			VIEWPORT_W * 0.5 - cos(theta_m) * ARC_RADIUS_X,
			HORIZON_Y - sin(theta_m) * ARC_HEIGHT
		)
		_moon.modulate.a = fade_m * _layer_alpha
		_moon.visible = true
	else:
		_moon.visible = false
	# === 星星 (夜里淡入 + 眨眼) ===
	var night_amount: float = 1.0 - TimeOfDay.day_factor()
	_stars_root.visible = night_amount > 0.02
	if _stars_root.visible:
		for sd in _star_data:
			var twinkle: float = (sin(_time_accum * sd.speed + sd.phase) + 1.0) * 0.5  # 0..1
			var a: float = sd.base_alpha * (0.3 + twinkle * 0.7) * night_amount * _layer_alpha
			sd.node.modulate.a = a


# 弧线两端 (u≈0 或 u≈1) 平滑淡入淡出, 避开离散闪烁
func _arc_fade(u: float) -> float:
	if u < 0.08:
		return u / 0.08
	if u > 0.92:
		return (1.0 - u) / 0.08
	return 1.0


func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


func current_alpha() -> float:
	return _layer_alpha


# 测试用
func sun_visible() -> bool:
	return _sun.visible


func moon_visible() -> bool:
	return _moon.visible


func stars_root_alpha() -> float:
	if not _stars_root.visible:
		return 0.0
	# 算所有星的平均 alpha 当作"夜里强度"指标
	if _star_data.is_empty():
		return 0.0
	var total: float = 0.0
	for sd in _star_data:
		total += sd.node.modulate.a
	return total / float(_star_data.size())


func star_count() -> int:
	return _star_data.size()
