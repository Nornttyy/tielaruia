# 天空背景: 一整张铺满屏幕的 ColorRect, 颜色跟随 TimeOfDay.sky_color() 变化.
# 放在 CanvasLayer layer = -10, 渲染在所有 world 节点之后.
extends ColorRect

var _layer_alpha: float = 1.0  # 由 ScenicDirector 设 (矿洞里压暗到 0.3)


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	color = TimeOfDay.sky_color()


func _process(_delta: float) -> void:
	# 矿洞里把天空色 lerp 到黑 (alpha 不变, 避免暴露后面的窗口底色)
	var c: Color = TimeOfDay.sky_color()
	c = c.lerp(Color.BLACK, 1.0 - _layer_alpha)
	color = c
	queue_redraw()


func _draw() -> void:
	# 少量横向色带形成空气层次，不加模糊、不使用写实天空照片。
	var daylight: float = TimeOfDay.day_factor()
	var base: Color = TimeOfDay.sky_color()
	var top := base.lerp(Color8(62, 141, 217), daylight * 0.7)
	var bottom := base.lerp(Color8(200, 230, 233), daylight * 0.65)
	for i in 32:
		var t := float(i) / 31.0
		var band_color := top.lerp(bottom, t * t).lerp(Color.BLACK, 1.0 - _layer_alpha)
		var y0 := floorf(size.y * i / 32.0)
		var y1 := ceilf(size.y * (i + 1) / 32.0)
		draw_rect(Rect2(0, y0, size.x, y1 - y0), band_color)


func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


func current_alpha() -> float:
	return _layer_alpha
