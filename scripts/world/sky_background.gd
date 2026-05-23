# 天空背景: 一整张铺满屏幕的 ColorRect, 颜色跟随 TimeOfDay.sky_color() 变化.
# 放在 CanvasLayer layer = -10, 渲染在所有 world 节点之后.
extends ColorRect


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	color = TimeOfDay.sky_color()


func _process(_delta: float) -> void:
	color = TimeOfDay.sky_color()
