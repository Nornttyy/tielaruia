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
var _phase: float = 0.0     # 随机错峰, 避免所有怪同帧重算


func _init() -> void:
	_phase = randf() * 0.3


# from_tile/goal_tile = 怪/玩家所在格. 返回 -1/0/1 水平方向; NO_PATH=没路。
func steer(cm, from_tile: Vector2i, goal_tile: Vector2i, delta: float) -> int:
	want_jump = false
	_t -= delta
	if _t <= 0.0 or path.is_empty():
		_t = REPATH_SEC + _phase
		path = MobPathfinder.find_path(cm, from_tile, goal_tile)
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
	return from_tile.x == wp.x and absi(from_tile.y - wp.y) <= 1
