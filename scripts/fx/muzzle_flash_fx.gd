# 枪械"招牌形状"特效 (开火 + 命中通用, 全部画出来, 零粒子) —
# 枪口: star=四角星闪 / fan=霰弹扇楔 / beam=激光光束 / flame=火锥 / frost=冰晶刺
#       arc=小电弧 / rune=旋转符文环 / drip=毒液喷珠 / splat=果冻溅开 / leaves=叶片回旋
# 命中: hit=打中怪的放射爆闪 / wallhit=打到方块的反弹火星
# 跟法杖 spell_impact_fx 一个套路: _draw 画形状 + 渐隐 + 寿命到自删.
# 节点整体旋转朝射击/飞行方向, 形状全画在 +X 方向.
extends Node2D

var kind: String = "star"
var base: Color = Color(1.0, 0.9, 0.6, 1.0)
var power: float = 1.0      # 大威力枪 >1 → 形状更大 (跟 gun_shake 挂钩)
var _t: float = 0.0
var _dur: float = 0.14
var _bolts: Array = []      # 电弧分叉点 (一次生成, 之后只闪)


func setup(k: String, dir: Vector2, c: Color, p: float = 1.0) -> void:
	kind = k
	base = c
	power = maxf(p, 0.5)
	rotation = dir.angle() if dir.length() > 0.01 else 0.0


func _ready() -> void:
	z_index = 12   # 盖在地形/生物上面
	match kind:
		"arc":    _dur = 0.16; _gen_bolts()
		"fan":    _dur = 0.18
		"flame":  _dur = 0.2
		"rune":   _dur = 0.22
		"splat":  _dur = 0.2
		"drip":   _dur = 0.2
		"leaves": _dur = 0.22
		"frost":  _dur = 0.18
		"beam":   _dur = 0.12
		"hit":    _dur = 0.16; _gen_burst()
		"wallhit": _dur = 0.18; _gen_sparks()
		_:        _dur = 0.12


# 3 道朝前的小锯齿电弧 (一次定下来, _draw 里只改透明度闪烁)
func _gen_bolts() -> void:
	for b in 3:
		var ang: float = randf_range(-0.5, 0.5)
		var dir: Vector2 = Vector2(cos(ang), sin(ang))
		var p: Vector2 = Vector2.ZERO
		var pts: PackedVector2Array = PackedVector2Array([p])
		for seg in 3:
			p += dir * randf_range(5.0, 9.0) * power + Vector2(randf_range(-4, 4), randf_range(-4, 4))
			pts.append(p)
		_bolts.append(pts)


# 打中怪: 5 根全方向放射刺 (角度随机偏一点, 长短不一) — 一次定下来
func _gen_burst() -> void:
	for i in 5:
		var ang: float = i * TAU / 5.0 + randf_range(-0.3, 0.3)
		_bolts.append([Vector2(cos(ang), sin(ang)), randf_range(0.7, 1.3)])


# 打到方块: 3 根往后上方反弹的火星线 (子弹朝 +X 飞来 → 火星往 -X 半球溅)
func _gen_sparks() -> void:
	for i in 3:
		var ang: float = PI + randf_range(-0.9, 0.9)   # -X 方向 ± 50°
		_bolts.append([Vector2(cos(ang), sin(ang)), randf_range(0.6, 1.2)])


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
		"star":
			# 经典枪口星: 前向 3 根尖刺 + 竖刺 + 白亮芯 (收缩渐隐)
			var L: float = lerpf(10.0, 4.0, f) * power
			for a in [-0.5, 0.0, 0.5]:
				var d := Vector2(cos(a), sin(a))
				draw_line(d * 2.0, d * L, Color(1, 1, 1, fade), 2.5)
			draw_line(Vector2(1, -L * 0.5), Vector2(1, L * 0.5), Color(c.r, c.g, c.b, fade * 0.8), 2.0)
			draw_circle(Vector2.ZERO, 3.0 * power * fade + 1.0, Color(1, 1, 0.85, fade))
		"fan":
			# 霰弹: 扇形冲击楔 (扩散弧 + 4 根放射线, 一看就是喷一片)
			var r: float = lerpf(6.0, 22.0, f) * power
			draw_arc(Vector2.ZERO, r, -0.55, 0.55, 12, Color(1, 1, 1, fade), 3.0)
			for a in [-0.45, -0.15, 0.15, 0.45]:
				var d := Vector2(cos(a), sin(a))
				draw_line(d * 3.0, d * r, Color(c.r, c.g, c.b, fade * 0.7), 2.0)
		"beam":
			# 激光/电磁炮: 枪口短光束往前刺 (亮白芯 + 色辉光), 快速收缩
			var L: float = lerpf(26.0, 10.0, f) * power
			draw_line(Vector2(2, 0), Vector2(L, 0), Color(c.r, c.g, c.b, fade * 0.8), 5.0)
			draw_line(Vector2(2, 0), Vector2(L, 0), Color(1, 1, 1, fade), 2.2)
		"flame":
			# 火锥: 双层嵌套扇 (外橙内亮黄) + 芯
			var L: float = lerpf(8.0, 20.0, f) * power
			draw_arc(Vector2(2, 0), L, -0.5, 0.5, 10, Color(c.r, c.g, c.b, fade * 0.9), 6.0)
			draw_arc(Vector2(2, 0), L * 0.6, -0.4, 0.4, 8, Color(1, 0.85, 0.4, fade), 4.0)
			draw_circle(Vector2(3, 0), 3.0 * fade + 1.0, Color(1, 1, 0.8, fade))
		"frost":
			# 冰刺: 3 根细长晶刺 (白芯) + 扩散霜环
			var L: float = lerpf(6.0, 16.0, f) * power
			for a in [-0.45, 0.0, 0.45]:
				var d := Vector2(cos(a), sin(a))
				draw_line(d * 2.0, d * (L + 6.0), Color(c.r, c.g, c.b, fade), 2.0)
				draw_line(d * 2.0, d * (L * 0.7 + 4.0), Color(1, 1, 1, fade * 0.9), 1.2)
			draw_arc(Vector2.ZERO, lerpf(3.0, 12.0, f), 0.0, TAU, 16, Color(c.r, c.g, c.b, fade * 0.6), 1.5)
		"arc":
			# 闪电/特斯拉: 枪口炸小电弧 + 高频闪烁
			var a: float = fade * (0.6 + 0.4 * sin(_t * 80.0))
			for pts in _bolts:
				draw_polyline(pts, Color(c.r, c.g, c.b, a), 3.0)
				draw_polyline(pts, Color(1, 1, 1, a * 0.9), 1.5)
		"rune":
			# 魔法枪: 枪口前旋转符文小环 (环 + 4 根刻度)
			var rad: float = lerpf(4.0, 12.0, f) * power
			var ctr := Vector2(6, 0)
			draw_arc(ctr, rad, 0.0, TAU, 20, Color(c.r, c.g, c.b, fade), 2.0)
			var rot: float = _t * 9.0
			for i in 4:
				var ang: float = rot + i * TAU / 4.0
				var d := Vector2(cos(ang), sin(ang))
				draw_line(ctr + d * (rad - 2.0), ctr + d * (rad + 3.0), Color(1, 1, 1, fade * 0.85), 1.5)
		"drip":
			# 毒系: 3 颗液珠朝前飞散 (越飞越远越小)
			for i in 3:
				var ang: float = -0.35 + i * 0.35
				var d := Vector2(cos(ang), sin(ang))
				var pos: Vector2 = d * lerpf(4.0, 18.0, f)
				draw_circle(pos, (2.5 - i * 0.5) * fade + 0.5, Color(c.r, c.g, c.b, fade * 0.95))
		"splat":
			# 史莱姆: 果冻团溅开 (半透圆 + 亮边环)
			var r: float = lerpf(3.0, 12.0, f) * power
			var lc: Color = c.lightened(0.3)
			draw_circle(Vector2(3, 0), r, Color(c.r, c.g, c.b, fade * 0.5))
			draw_arc(Vector2(3, 0), r + 2.0, 0.0, TAU, 16, Color(lc.r, lc.g, lc.b, fade * 0.9), 2.0)
		"leaves":
			# 绿叶: 3 道小回旋弧 (转着散开)
			var ext: float = lerpf(4.0, 14.0, f) * power
			for i in 3:
				var a0: float = i * TAU / 3.0 + _t * 7.0
				draw_arc(Vector2(4, 0), ext, a0, a0 + 1.6, 8, Color(c.r, c.g, c.b, fade), 2.2)
		"hit":
			# 打中怪: 放射爆闪 — 5 根外冲短刺 (白芯) + 亮芯圆 + 小扩散环
			var L: float = lerpf(3.0, 11.0, f) * power
			for e in _bolts:
				var d: Vector2 = e[0]
				var m: float = e[1]
				draw_line(d * 2.0, d * L * m, Color(c.r, c.g, c.b, fade), 2.2)
				draw_line(d * 2.0, d * L * m * 0.6, Color(1, 1, 1, fade * 0.9), 1.2)
			draw_circle(Vector2.ZERO, 2.5 * power * fade + 0.5, Color(1, 1, 0.9, fade))
			draw_arc(Vector2.ZERO, lerpf(2.0, 9.0, f) * power, 0.0, TAU, 14, Color(c.r, c.g, c.b, fade * 0.6), 1.5)
		"wallhit":
			# 打到方块: 火星往来向反弹溅 (线越飞越远越淡) + 撞点小亮闪
			var L: float = lerpf(2.0, 13.0, f) * power
			for e in _bolts:
				var d: Vector2 = e[0]
				var m: float = e[1]
				var tip: Vector2 = d * L * m + Vector2(0, f * 4.0)   # 火星微微下坠
				draw_line(d * L * m * 0.4 + Vector2(0, f * 2.0), tip, Color(1, 0.9, 0.6, fade), 1.8)
				draw_circle(tip, 1.2 * fade + 0.3, Color(c.r, c.g, c.b, fade))
			draw_circle(Vector2.ZERO, 2.0 * power * fade + 0.5, Color(1, 1, 1, fade * 0.9))
