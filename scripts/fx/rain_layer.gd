# 雨点视觉层. CanvasLayer 跟相机. 雨从屏幕上方往下落.
# 由 Weather 状态控制 enabled. enabled=false 时停止生成新雨点 (现有雨点继续落完).
# 同时附带闪雷全屏白闪 + 雨天天空变暗 modulate.
extends CanvasLayer

const RAIN_COUNT := 220         # 屏幕上同时存在的雨点数 (调大让雨密一点)
const RAIN_SPEED_MIN := 600.0   # 像素/秒
const RAIN_SPEED_MAX := 900.0
const RAIN_LENGTH_MIN := 14.0   # 更长的雨痕
const RAIN_LENGTH_MAX := 24.0
const RAIN_WIDTH := 2.5         # 雨点线条宽度 (像素)
const RAIN_COLOR := Color(0.85, 0.92, 1.0, 0.95)  # 接近白蓝, 高不透明
const RAIN_TILT_X := 120.0      # 雨倾斜速度 (像素/秒, 风向)

const LIGHTNING_FLASH_COLOR := Color(1, 1, 1, 0.7)
const LIGHTNING_FLASH_DURATION := 0.12

const DARK_OVERLAY_COLOR := Color(0.05, 0.08, 0.15, 0.45)  # 雨天明显压暗
const DARK_FADE_SEC := 1.5

var _enabled: bool = false
var _drops: Array = []  # 每个 [Line2D, speed, length]
var _vp_size: Vector2

@onready var _darken_rect: ColorRect = ColorRect.new()
@onready var _lightning_rect: ColorRect = ColorRect.new()


func _ready() -> void:
	# 渲染层: 5 在 HUD (1) 上面但在菜单 (50+) 下面.
	# 雨点 + 闪雷会盖一点 HUD 但视觉清晰, 测试方便. 后续可以调到 0 让 HUD 在雨上.
	layer = 5
	# 雨天压暗的全屏 overlay
	_darken_rect.color = Color(DARK_OVERLAY_COLOR.r, DARK_OVERLAY_COLOR.g,
		DARK_OVERLAY_COLOR.b, 0.0)  # 初始透明, 雨天 fade in
	_darken_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darken_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_darken_rect)
	# 闪雷白闪
	_lightning_rect.color = Color(1, 1, 1, 0.0)
	_lightning_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_lightning_rect)
	_vp_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_vp_size_changed)


func set_enabled(v: bool) -> void:
	_enabled = v
	# 暗 overlay tween 到目标 alpha
	var target_a: float = DARK_OVERLAY_COLOR.a if v else 0.0
	var t := create_tween()
	t.tween_property(_darken_rect, "color:a", target_a, DARK_FADE_SEC)


func flash_lightning() -> void:
	# 白闪一下 + 雷声 (雷声让 SfxBank 来播, 这里只管视觉)
	_lightning_rect.color = LIGHTNING_FLASH_COLOR
	var t := create_tween()
	t.tween_property(_lightning_rect, "color:a", 0.0, LIGHTNING_FLASH_DURATION)


func _process(delta: float) -> void:
	# 维持雨点数量: 每帧最多补 8 个, 1s 内填满到目标值, 不用等 200 帧.
	if _enabled:
		var to_spawn: int = min(8, RAIN_COUNT - _drops.size())
		for _i in to_spawn:
			_spawn_drop()
	# 移动现有雨点
	for i in range(_drops.size() - 1, -1, -1):
		var d = _drops[i]
		var line: Line2D = d[0]
		var speed: float = d[1]
		line.position.x += RAIN_TILT_X * delta
		line.position.y += speed * delta
		# 落出屏幕底就回收
		if line.position.y > _vp_size.y + 50.0:
			line.queue_free()
			_drops.remove_at(i)


func _spawn_drop() -> void:
	var line := Line2D.new()
	var length: float = randf_range(RAIN_LENGTH_MIN, RAIN_LENGTH_MAX)
	line.add_point(Vector2(0, 0))
	line.add_point(Vector2(RAIN_TILT_X * length / 700.0, length))  # 跟下落方向一致的倾斜短线
	line.width = RAIN_WIDTH
	line.default_color = RAIN_COLOR
	line.position = Vector2(randf_range(-100.0, _vp_size.x + 50.0), -20.0)
	add_child(line)
	_drops.append([line, randf_range(RAIN_SPEED_MIN, RAIN_SPEED_MAX), length])


func _on_vp_size_changed() -> void:
	_vp_size = get_viewport().get_visible_rect().size
