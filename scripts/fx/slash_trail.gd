# 挥砍/突刺的拖尾光弧 (像素风: 全用 draw_rect 小方块, 不抗锯齿, 保持像素感)。
#   mode "arc"  : 沿 start_a→end_a 扫一道像素新月弧 (挥剑)
#   mode "line" : 沿 angle 甩一道像素直线 streak (突刺)
extends Node2D

var mode: String = "arc"
var base: Color = Color(1, 1, 1, 1)
var start_a: float = 0.0
var end_a: float = 0.0
var reach: float = 26.0
var _t: float = 0.0
var _sweep: float = 0.20   # 划出来的时间 (跟挥剑节奏对齐)
var _fade: float = 0.14    # 划完再渐隐的时间


func setup_arc(p_start: float, p_end: float, p_reach: float, p_color: Color, sweep: float) -> void:
	mode = "arc"
	start_a = p_start
	end_a = p_end
	reach = p_reach
	base = p_color
	_sweep = max(0.08, sweep)


func setup_line(p_angle: float, p_reach: float, p_color: Color) -> void:
	mode = "line"
	start_a = p_angle
	reach = p_reach
	base = p_color
	_sweep = 0.09
	_fade = 0.12


func _ready() -> void:
	z_index = 13   # 盖在生物/武器上面


func _process(delta: float) -> void:
	_t += delta
	if _t >= _sweep + _fade:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var fade: float = 1.0
	if _t > _sweep:
		fade = clamp(1.0 - (_t - _sweep) / _fade, 0.0, 1.0)
	if mode == "line":
		_draw_line_streak(fade)
	else:
		_draw_arc_crescent(fade)


# 像素小方块: 在 (cx,cy) 画一个 size×size 实心方块 (整数对齐, 像素锐利)。
func _blk(cx: float, cy: float, size: float, col: Color) -> void:
	var h: float = size * 0.5
	draw_rect(Rect2(round(cx) - h, round(cy) - h, size, size), col, true)


# 像素新月弧: 沿弧从 start_a 排一串方块到当前进度角, 尾巴淡、刃头亮白。
func _draw_arc_crescent(fade: float) -> void:
	var p: float = clamp(_t / _sweep, 0.0, 1.0)
	var cur_a: float = start_a + (end_a - start_a) * p
	var steps: int = 16
	for i in steps + 1:
		var f: float = float(i) / float(steps)
		var a: float = start_a + (cur_a - start_a) * f
		# 尾→头 越来越亮 (拖尾感)
		var av: float = fade * (0.30 + 0.70 * f)
		# 两条半径叠出一点厚度 (内浅外深)
		var col_out: Color = base
		col_out.a = 0.85 * av
		var col_in: Color = base
		col_in.a = 0.45 * av
		var po: Vector2 = Vector2(reach, 0).rotated(a)
		var pi2: Vector2 = Vector2(reach - 4.0, 0).rotated(a)
		_blk(po.x, po.y, 3.0, col_out)
		_blk(pi2.x, pi2.y, 2.0, col_in)
	# 刃头白热方块
	var tip: Vector2 = Vector2(reach, 0).rotated(cur_a)
	_blk(tip.x, tip.y, 4.0, Color(1, 1, 1, 0.9 * fade))


# 像素突刺 streak: 沿 angle 从根到尖排一串方块, 尖端冲出去 + 白芯。
func _draw_line_streak(fade: float) -> void:
	var p: float = clamp(_t / _sweep, 0.0, 1.0)
	var dir: Vector2 = Vector2(1, 0).rotated(start_a)
	var tip_len: float = reach * (0.6 + 0.4 * p)
	var steps: int = 10
	for i in steps + 1:
		var f: float = float(i) / float(steps)
		var pt: Vector2 = dir * (tip_len * f)
		# 根粗尖细
		var sz: float = 4.0 - 2.0 * f
		var col: Color = base
		col.a = 0.8 * fade * (0.5 + 0.5 * f)
		_blk(pt.x, pt.y, max(1.0, sz), col)
	# 尖端白热
	var tip: Vector2 = dir * tip_len
	_blk(tip.x, tip.y, 3.0, Color(1, 1, 1, 0.9 * fade))
