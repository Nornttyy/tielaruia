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


# 3 道从中心向外的分叉锯齿电弧 (一次定下来, _draw 里只改透明度闪烁)
func _gen_bolts() -> void:
	for b in 3:
		var ang: float = randf_range(-PI, PI)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p: Vector2 = Vector2.ZERO
		var pts: PackedVector2Array = PackedVector2Array([p])
		for seg in 4:
			p += dir * randf_range(7.0, 13.0) + Vector2(randf_range(-6, 6), randf_range(-6, 6))
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
	match kind:
		"spark":
			# 闪电: 分叉电弧 + 高频闪烁, 白芯
			var a: float = fade * (0.55 + 0.45 * sin(_t * 90.0))
			for pts in _bolts:
				draw_polyline(pts, Color(c.r, c.g, c.b, a), 2.5)
				draw_polyline(pts, Color(1, 1, 1, a * 0.85), 1.0)
		"explosion":
			# 火: 扩散冲击波环 (由小变大变淡)
			var r: float = lerpf(3.0, 44.0, f)
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 40, Color(c.r, c.g, c.b, fade), 3.0 * fade + 0.8)
		"splash":
			# 水: 两道错开的涟漪环
			for k in 2:
				var rr: float = lerpf(2.0, 30.0, clampf(f + k * 0.28, 0.0, 1.0))
				draw_arc(Vector2.ZERO, rr, 0.0, TAU, 32, Color(c.r, c.g, c.b, fade * 0.85), 2.0)
		"gas":
			# 毒: 扩散的半透明绿云 (实心圆变大变淡)
			var rg: float = lerpf(4.0, 26.0, f)
			draw_circle(Vector2.ZERO, rg, Color(c.r, c.g, c.b, fade * 0.33))
		"sparkle":
			# 魔法: 旋转符文环 (环 + 6 根放射刻度)
			var rad: float = lerpf(4.0, 22.0, f)
			draw_arc(Vector2.ZERO, rad, 0.0, TAU, 28, Color(c.r, c.g, c.b, fade), 1.5)
			var rot: float = _t * 6.0
			for i in 6:
				var ang: float = rot + i * TAU / 6.0
				var d: Vector2 = Vector2(cos(ang), sin(ang))
				draw_line(d * (rad - 3.0), d * (rad + 3.0), Color(1, 1, 1, fade * 0.8), 1.0)
		"gust":
			# 风: 3 条向外扫的旋臂弧
			var ext: float = lerpf(6.0, 30.0, f)
			for i in 3:
				var a0: float = i * TAU / 3.0 + _t * 4.0
				draw_arc(Vector2.ZERO, ext, a0, a0 + 1.6, 12, Color(c.r, c.g, c.b, fade), 2.0)
