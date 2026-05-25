# 暂停菜单：ESC 切换，3 个按钮 (继续 / 回主菜单 / 退出)。
# CanvasLayer process_mode = ALWAYS，暂停时仍响应输入。
# 由 main.gd 监听 _unhandled_input 中的 ui_pause action 调 toggle。
extends CanvasLayer

signal return_to_menu

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _return_button: Button = $VBox/ReturnToMenuButton
@onready var _quit_button: Button = $VBox/QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_return_button.pressed.connect(_on_return_to_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_resume_pressed() -> void:
	close()


func _on_return_to_menu_pressed() -> void:
	return_to_menu.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
