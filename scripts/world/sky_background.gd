# 天空背景: 一整张铺满屏幕的 ColorRect, 颜色跟随 TimeOfDay.sky_color() 变化.
# 放在 CanvasLayer layer = -10, 渲染在所有 world 节点之后.
extends ColorRect

var _layer_alpha: float = 1.0  # 由 ScenicDirector 设 (矿洞里压暗到 0.3)


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	color = TimeOfDay.sky_color()


func _process(_delta: float) -> void:
	# 矿洞里把天空色 lerp 到黑 (alpha 不变, 避免暴露后面的窗口底色)
	var c: Color = TimeOfDay.sky_color()
	c = c.lerp(Color.BLACK, 1.0 - _layer_alpha)
	color = c


func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


func current_alpha() -> float:
	return _layer_alpha
