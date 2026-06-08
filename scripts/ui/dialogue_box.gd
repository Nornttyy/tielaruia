# 村民对话框: open(line) 显示, ESC 关闭. CanvasLayer 默认隐藏.
# ESC 通过 _unhandled_input 处理, 消耗事件 (在 PauseMenu 之前一级).
extends CanvasLayer

const UIStyle = preload("res://scripts/ui/ui_style.gd")

signal closed

@onready var _line_label: Label = $Panel/VBox/LineLabel


func _ready() -> void:
	visible = false
	add_to_group("dialogue_box")
	$Panel.add_theme_stylebox_override("panel", UIStyle.panel())   # 蓝色圆角对话框


func open(line: String) -> void:
	_line_label.text = line
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_pause") or event.is_action_pressed("ui_cancel_crafting"):
		close()
		get_viewport().set_input_as_handled()
