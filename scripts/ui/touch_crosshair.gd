# 手游准星: 一个十字+圆环, 画在瞄准点 (touch_controls 每帧把 position 设到瞄准屏幕坐标)。
# 原点(0,0)= 准星中心; position 由外部设到瞄准点。
extends Control

const COLOR := Color(1, 1, 1, 0.85)
const COLOR_OUT := Color(0, 0, 0, 0.6)   # 黑描边, 亮背景上也看得见
const R := 11.0
const GAP := 4.0
const LEN := 7.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # 准星不挡点击
	z_index = 5


func _draw() -> void:
	# 先画粗黑底 (描边), 再画白线 → 任何背景都清楚
	_draw_reticle(COLOR_OUT, 4.0)
	_draw_reticle(COLOR, 2.0)
	draw_circle(Vector2.ZERO, 2.0, COLOR_OUT)
	draw_circle(Vector2.ZERO, 1.3, COLOR)


func _draw_reticle(col: Color, w: float) -> void:
	draw_arc(Vector2.ZERO, R, 0.0, TAU, 28, col, w)
	# 四向短线 (留中心空隙)
	draw_line(Vector2(-R - LEN, 0), Vector2(-R + GAP - LEN, 0), col, w)
	draw_line(Vector2(R - GAP + LEN, 0), Vector2(R + LEN, 0), col, w)
	draw_line(Vector2(0, -R - LEN), Vector2(0, -R + GAP - LEN), col, w)
	draw_line(Vector2(0, R - GAP + LEN), Vector2(0, R + LEN), col, w)
