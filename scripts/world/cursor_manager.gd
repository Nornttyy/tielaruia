# 鼠标光标管理 (挂在 World 下).
# 游戏里默认十字准星 (瞄准用); 暂停 / 开背包合成 / 开箱子 等"要选择"时切回普通箭头.
# 主菜单的箭头由 main._show_menu_state 设 (那时 World/本节点不存在).
extends Node

const CursorArt = preload("res://scripts/art/cursor_art.gd")

var _arrow_tex: ImageTexture
var _cross_tex: ImageTexture
var _current: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也要能切回箭头
	_arrow_tex = CursorArt.arrow()
	_cross_tex = CursorArt.crosshair()
	_apply("crosshair")   # 进游戏默认准星


func _process(_d: float) -> void:
	# 用户要求: 游戏里固定十字准星 — 开背包/合成/箱子/暂停都不再换回箭头。
	_apply("crosshair")


func _panel_open(group: String) -> bool:
	var p: Node = get_tree().get_first_node_in_group(group)
	return p != null and p.has_method("is_open") and p.is_open()


func _apply(which: String) -> void:
	if which == _current:
		return
	_current = which
	if which == "arrow":
		Input.set_custom_mouse_cursor(_arrow_tex, Input.CURSOR_ARROW, Vector2.ZERO)      # hotspot=箭尖
	else:
		Input.set_custom_mouse_cursor(_cross_tex, Input.CURSOR_ARROW, Vector2(8, 8))     # hotspot=准星正中
