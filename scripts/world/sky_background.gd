# 天空背景: 一整张铺满屏幕的 ColorRect, 颜色跟随 TimeOfDay.sky_color() 变化.
# 放在 CanvasLayer layer = -10, 渲染在所有 world 节点之后.
extends ColorRect

var _layer_alpha: float = 1.0  # 由 ScenicDirector 设 (矿洞里压暗到 0.3)
var _biome_tint: Color = Color(1, 1, 1)  # 群系色调 (multiply, 1=不变); 由 ScenicDirector 设


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	color = TimeOfDay.sky_color()


func _process(_delta: float) -> void:
	# 天空色 = 时间天空色 × 群系色调 (沙漠偏橙/雪原偏蓝...), 再按深度 lerp 到黑
	var c: Color = TimeOfDay.sky_color()
	c = Color(c.r * _biome_tint.r, c.g * _biome_tint.g, c.b * _biome_tint.b, c.a)
	c = c.lerp(Color.BLACK, 1.0 - _layer_alpha)
	color = c


func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


# 群系色调 (不同群系天空不同). ScenicDirector 按玩家所在 biome 平滑设过来.
func set_biome_tint(c: Color) -> void:
	_biome_tint = c


func current_alpha() -> float:
	return _layer_alpha
