# 鼠标光标管理: 用户改 — 删了剑光标, 永远用箭头.
# 挂在 World 下作 child 节点.
extends Node

const CursorArt = preload("res://scripts/art/cursor_art.gd")


func _ready() -> void:
	Input.set_custom_mouse_cursor(CursorArt.arrow(), Input.CURSOR_ARROW, Vector2.ZERO)
