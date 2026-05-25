# 鼠标光标管理: 检测鼠标位置, 自动切 箭头/剑.
# 挂在 World 下作 child 节点.
#
# 14 px 半径范围内有 slime/zombie → 剑
# 其它 → 默认箭头
extends Node

const CursorArt = preload("res://scripts/art/cursor_art.gd")

const MODE_DEFAULT := 0
const MODE_SWORD := 1

const ENEMY_HIT_RADIUS := 14.0   # 鼠标距敌人多近算"瞄准" (px)

var _arrow: ImageTexture
var _sword: ImageTexture
var _mode: int = -1


func _ready() -> void:
	_arrow = CursorArt.arrow()
	_sword = CursorArt.sword()
	_set_mode(MODE_DEFAULT)


func _process(_delta: float) -> void:
	_set_mode(_detect_mode())


func _detect_mode() -> int:
	var world: Node = get_parent()
	if world == null:
		return MODE_DEFAULT
	var mouse_world: Vector2 = world.get_global_mouse_position()
	# 鼠标贴近任何生物 (slime/zombie/牛/羊/猪/村民) → 剑. 唯独玩家除外.
	for group_name in ["slimes", "zombies", "animals", "villagers"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(mouse_world) < ENEMY_HIT_RADIUS:
				return MODE_SWORD
	return MODE_DEFAULT


func _set_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode
	match mode:
		MODE_DEFAULT:
			Input.set_custom_mouse_cursor(_arrow, Input.CURSOR_ARROW, Vector2.ZERO)
		MODE_SWORD:
			Input.set_custom_mouse_cursor(_sword, Input.CURSOR_ARROW, Vector2(13, 1))
