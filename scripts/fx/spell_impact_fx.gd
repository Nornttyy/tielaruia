# 法杖命中的"招牌形状"特效 (粒子之外多点特色, 用 _draw 画线/环/云):
#   spark=分叉电弧 / explosion=冲击波环 / splash=涟漪环 / gas=扩散毒云 / sparkle=旋转符文环 / gust=旋风弧
# 自己画 + 渐隐, 寿命到自删 (跟 earth_crack 一个套路, 但用 _draw 不用 Line2D 节点)。
extends Node2D

var kind: String = "explosion"
var base: Color = Color(1, 1, 1, 1)
var _t: float = 0.0
var _dur: float = 0.3
var _bolts: Array = []   # 闪电分叉点 (一次生成, 之后只闪)


func setup(k: String, c: Color) -> void:
	kind = k
	base = c


func _ready() -> void:
	z_index = 12   # 盖在地形/生物上面
	match kind:
		"spark":   _dur = 0.24; _gen_bolts()
		"splash":  _dur = 0.45
		"gas":     _dur = 0.6
		"sparkle": _dur = 0.5
		"gust":    _dur = 0.36
		_:         _dur = 0.3


# 5 道从中心向外的分叉锯齿电弧 (一次定下来, _draw 里只改透明度闪烁). 更长更分叉 = 更夸张
func _gen_bolts() -> void:
	for b in 5:
		var ang: float = randf_range(-PI, PI)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p: Vector2 = Vector2.ZERO
		var pts: PackedVector2Array = PackedVector2Array([p])
		for seg in 5:
			p += dir * randf_range(11.0, 20.0) + Vector2(randf_range(-9, 9), randf_range(-9, 9))
			pts.append(p)
		_bolts.append(pts)


func _process(delta: float) -> void:
	_t += delta
	if _t >= _dur:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var f: float = _t / _dur          # 进度 0→1
	var fade: float = 1.0 - f          # 透明 1→0
	var c: Color = base
	# 起手白闪核: 前 25% 寿命有一团亮白圆"砰"一下 (让命中更夸张, 各形状通用)
	if f < 0.25:
		var ca: float = (1.0 - f / 0.25)
		draw_circle(Vector2.ZERO, lerpf(10.0, 4.0, f / 0.25), Color(1, 1, 1, 0.7 * ca))
	match kind:
		"spark":
			# 闪电: 5 道分叉电弧 + 高频闪烁, 粗白芯
			var a: float = fade * (0.6 + 0.4 * sin(_t * 90.0))
			for pts in _bolts:
				draw_polyline(pts, Color(c.r, c.g, c.b, a), 4.5)
				draw_polyline(pts, Color(1, 1, 1, a * 0.9), 2.0)
		"explosion":
			# 火: 两道扩散冲击波环 (大 + 粗 + 内圈实)
			var r: float = lerpf(4.0, 66.0, f)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 48, Color(c.r, c.g, c.b, fade), 5.0 * fade + 1.5)
			draw_arc(Vector2.ZERO, r * 0.6, 0.0, TAU, 40, Color(c.lightened(0.3).r, c.lightened(0.3).g, c.lightened(0.3).b, fade * 0.8), 3.0 * fade + 1.0)
		"splash":
			# 水: 三道错开的涟漪环 (更大)
			for k in 3:
				var rr: float = lerpf(2.0, 42.0, clampf(f + k * 0.22, 0.0, 1.0))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 36, Color(c.r, c.g, c.b, fade * 0.9), 3.0)
		"gas":
			# 毒: 两层扩散的半透明绿云 (更大更浓)
			var rg: float = lerpf(5.0, 38.0, f)
			draw_circle(Vector2.ZERO, rg, Color(c.r, c.g, c.b, fade * 0.38))
			draw_circle(Vector2.ZERO, rg * 0.6, Color(c.darkened(0.2).r, c.darkened(0.2).g, c.darkened(0.2).b, fade * 0.45))
		"sparkle":
			# 魔法: 旋转符文双环 (环 + 8 根放射刻度, 更大更粗)
			var rad: float = lerpf(5.0, 32.0, f)
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 32, Color(c.r, c.g, c.b, fade), 3.0)
			draw_arc(Vector2.ZERO, rad * 0.55, 0.0, TAU, 24, Color(c.lightened(0.4).r, c.lightened(0.4).g, c.lightened(0.4).b, fade * 0.8), 2.0)
			var rot: float = _t * 6.0
			for i in 8:
				var ang: float = rot + i * TAU / 8.0
				var d: Vector2 = Vector2(cos(ang), sin(ang))
				draw_line(d * (rad - 5.0), d * (rad + 5.0), Color(1, 1, 1, fade * 0.85), 2.0)
		"gust":
			# 风: 4 条向外扫的长旋臂弧 (更大更粗)
			var ext: float = lerpf(8.0, 46.0, f)
			for i in 4:
				var a0: float = i * TAU / 4.0 + _t * 4.5
				draw_arc(Vector2.ZERO, ext, a0, a0 + 2.0, 16, Color(c.r, c.g, c.b, fade), 3.5)
