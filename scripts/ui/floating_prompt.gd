# 跟随世界坐标的文字提示。CanvasLayer 下的 Label。
# show_prompt(world_pos, text) 后每帧重新计算屏幕位置（玩家移动时跟随）。
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")

@onready var label: Label = $Label

var _target_world_pos: Vector2 = Vector2.ZERO
var _showing: bool = false


func _ready() -> void:
	visible = false
	label.visible = false
	# 蓝色圆角小底 (跟整体 UI 统一)
	label.add_theme_stylebox_override("normal", UIStyle.prompt_box())
	label.add_theme_color_override("font_color", Color(0.85, 0.92, 1.0))


func show_prompt(world_pos: Vector2, text: String) -> void:
	_target_world_pos = world_pos
	label.text = text
	visible = true
	label.visible = true
	_showing = true
	_update_position()


func hide_prompt() -> void:
	visible = false
	label.visible = false
	_showing = false


func is_showing() -> bool:
	return _showing


func _process(_delta: float) -> void:
	if _showing:
		_update_position()


func _update_position() -> void:
	# 世界坐标 → 屏幕坐标。CanvasLayer 默认 follow_viewport_enabled=false → 直接用 viewport transform。
	var viewport := get_viewport()
	var canvas_transform := viewport.get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * _target_world_pos
	# 中心对齐 (label 宽度居中)
	label.position = screen_pos - Vector2(label.size.x / 2.0, label.size.y + 4)
