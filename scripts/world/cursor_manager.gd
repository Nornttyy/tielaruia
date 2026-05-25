# 鼠标光标管理: 检测鼠标位置, 自动切 箭头/剑/镐子.
# 挂在 World 下作 child 节点, 用 World 的 chunk_manager 查方块, get_tree 查实体.
#
# 检测优先级 (先到先 win): 敌人 > 方块 > 默认.
# 14 px 半径范围内有 slime/zombie → 剑
# 鼠标格子是 solid (含矿石/方块) → 镐
# 其它 → 默认箭头
extends Node

const CursorArt = preload("res://scripts/art/cursor_art.gd")

const MODE_DEFAULT := 0
const MODE_SWORD := 1
const MODE_PICK := 2

const TILE_SIZE := 16
const ENEMY_HIT_RADIUS := 14.0   # 鼠标距敌人多近算"瞄准" (px)

var _arrow: ImageTexture
var _sword: ImageTexture
var _pick: ImageTexture
var _mode: int = -1


func _ready() -> void:
	_arrow = CursorArt.arrow()
	_sword = CursorArt.sword()
	_pick = CursorArt.pickaxe()
	_set_mode(MODE_DEFAULT)


func _process(_delta: float) -> void:
	_set_mode(_detect_mode())


func _detect_mode() -> int:
	var world: Node = get_parent()
	if world == null:
		return MODE_DEFAULT
	var mouse_world: Vector2 = world.get_global_mouse_position()
	# 1) 鼠标贴近 slime/zombie → 剑
	for group_name in ["slimes", "zombies"]:
		for e in get_tree().get_nodes_in_group(group_name):
			if not is_instance_valid(e):
				continue
			if e.global_position.distance_to(mouse_world) < ENEMY_HIT_RADIUS:
				return MODE_SWORD
	# 2) 鼠标格子是 solid 方块 → 镐子 (含矿石)
	var cm = world.get("chunk_manager")
	if cm != null:
		var tx: int = int(floor(mouse_world.x / TILE_SIZE))
		var ty: int = int(floor(mouse_world.y / TILE_SIZE))
		var tile: int = cm.get_tile(tx, ty)
		if tile != Tiles.AIR and Tiles.is_solid(tile):
			return MODE_PICK
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
		MODE_PICK:
			Input.set_custom_mouse_cursor(_pick, Input.CURSOR_ARROW, Vector2.ZERO)
