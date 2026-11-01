# 怪物寻路"跟随器" (每只怪持一个). 节流 ~0.6s 重算一次 A* 路径, 平时跟着路点走:
#   steer() 返回水平方向 -1/0/+1 (朝下一路点); 顺手设 want_jump (路点更高=爬 / 脚前是坑=跨坑)。
#   返回 -999 = 没路 (太远/翻不过) → 调用方退回原来的"朝玩家走+撞墙跳"反应式。
# 节流 + A* MAX_NODES 封顶 + 各怪随机错峰 → 多怪/网页也不会每帧狂算。
extends RefCounted

const MobPathfinder = preload("res://scripts/entities/mob_pathfinder.gd")
const REPATH_SEC := 0.6
const NO_PATH := -999

var path: Array = []        # 当前站立格路点
var want_jump: bool = false # steer 后读: 这帧要不要跳
var _wp: int = 0
var _t: float = 0.0
var body_height := 2
var jump_height := 2
var _initialized := false
var _last_goal := Vector2i.ZERO
var _phase: float = 0.0     # 随机错峰, 避免所有怪同帧重算


func _init() -> void:
	_phase = randf() * 0.3


# from_tile/goal_tile = 怪/玩家所在格. 返回 -1/0/1 水平方向; NO_PATH=没路。
func steer(cm, from_tile: Vector2i, goal_tile: Vector2i, delta: float) -> int:
	want_jump = false
	_t -= delta
	var changed_side := _initialized and signi(goal_tile.x - from_tile.x) != signi(_last_goal.x - from_tile.x) and goal_tile != _last_goal
	if _t <= 0.0 or not _initialized or changed_side:
		_initialized = true
		_last_goal = goal_tile
		_t = REPATH_SEC + _phase
		path = MobPathfinder.find_path(cm, from_tile, goal_tile, body_height, jump_height)
		_wp = 0
	if path.is_empty():
		return NO_PATH
	while _wp < path.size() and _reached(from_tile, path[_wp]):
		_wp += 1
	if _wp >= path.size():
		return NO_PATH   # 路点都到了 → 已贴近目标, 交给反应式贴脸打
	var wp: Vector2i = path[_wp]
	var dx: int = wp.x - from_tile.x
	var dir: int = 1 if dx > 0 else (-1 if dx < 0 else 0)
	if wp.y < from_tile.y:
		want_jump = true   # 路点在上方 → 跳上去
	elif dir != 0 and wp.y == from_tile.y and not MobPathfinder._solid(cm, from_tile.x + dir, from_tile.y + 1):
		want_jump = true   # 同高但脚前没地 (坑) → 跳过去
	return dir


func _reached(from_tile: Vector2i, wp: Vector2i) -> bool:
	return from_tile.x == wp.x and from_tile.y == wp.y


var _cm = null   # 缓存 chunk_manager

func _get_cm(tree) -> Node:
	if _cm != null and is_instance_valid(_cm):
		return _cm
	_cm = tree.get_first_node_in_group("chunk_manager") if tree != null else null
	return _cm


# 便捷: 直接传怪 + 玩家节点, 内部取 chunk_manager + 算格. 返回 -1/0/1 或 NO_PATH。
func steer_node(mob: Node2D, goal: Node2D, tile_size: int, delta: float) -> int:
	if mob == null or goal == null:
		return NO_PATH
	var cm = _get_cm(mob.get_tree())
	if cm == null:
		return NO_PATH
	var shape := mob.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if shape != null and shape.shape != null:
		body_height = maxi(1, ceili(shape.shape.get_rect().size.y * absf(shape.global_scale.y) / tile_size))
	var ft := feet_tile(mob, tile_size)
	var gt := feet_tile(goal, tile_size)
	return steer(cm, ft, gt, delta)

static func feet_tile(body: Node2D, tile_size: int) -> Vector2i:
	var feet := body.global_position
	var collision := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collision != null and collision.shape != null:
		feet.y = (collision.global_transform * Vector2(0, collision.shape.get_rect().end.y)).y
	# 地板顶面不属于空气格。向上取半像素，避免起点落进实心地板后始终无路。
	return Vector2i(floori(feet.x / tile_size), floori((feet.y - 0.5) / tile_size))

static func face(sprite: AnimatedSprite2D, direction: float) -> void:
	# 原地停下、同列时保持上次朝向，不能每帧被零横速重置成朝右。
	if sprite != null and absf(direction) > 0.01: sprite.flip_h = direction < 0.0
