# 平台跳跃 A* 寻路核心验收 (stub 网格, 不依赖真世界): 平地/楼梯爬升/跨坑/下落/无路。
extends GutTest

const MobPathfinder = preload("res://scripts/entities/mob_pathfinder.gd")


# 假 chunk_manager: 一组实心格, 其余空气。
class GridCM:
	extends RefCounted
	var solid: Dictionary = {}
	func set_solid(x: int, y: int) -> void:
		solid[Vector2i(x, y)] = true
	func fill_floor(x0: int, x1: int, y: int) -> void:
		for x in range(x0, x1 + 1):
			set_solid(x, y)
	func get_tile(x: int, y: int) -> int:
		return Tiles.STONE if solid.has(Vector2i(x, y)) else Tiles.AIR


func test_flat_ground_walk() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)            # 地板 y=3, 脚站 y=2
	var path: Array = MobPathfinder.find_path(cm, Vector2i(0, 2), Vector2i(10, 2))
	assert_false(path.is_empty(), "平地该找到路")
	assert_eq(path.back(), Vector2i(10, 2), "终点是目标格")
	for c in path:
		assert_eq(c.y, 2, "平地路点都在地面那一层")


func test_staircase_climb() -> void:
	var cm := GridCM.new()
	# 阶梯: x 列地板在 y=6-x (越往右越高); 脚站格 (x, 5-x)
	for x in range(0, 6):
		cm.set_solid(x, 6 - x)
	var path: Array = MobPathfinder.find_path(cm, Vector2i(0, 5), Vector2i(5, 0))
	assert_false(path.is_empty(), "楼梯该能一格一格跳上去")
	assert_eq(path.back(), Vector2i(5, 0), "爬到楼梯顶")


func test_gap_jump() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)
	cm.solid.erase(Vector2i(5, 3))     # 第 5 列挖个 1 格坑
	var path: Array = MobPathfinder.find_path(cm, Vector2i(0, 2), Vector2i(10, 2))
	assert_false(path.is_empty(), "1 格坑该能跨过去")
	assert_eq(path.back(), Vector2i(10, 2), "跨坑后到达对面目标")


func test_drop_down_ledge() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 5, 3)             # 高台 y=3
	cm.fill_floor(6, 11, 6)            # 低台 y=6
	var path: Array = MobPathfinder.find_path(cm, Vector2i(0, 2), Vector2i(10, 5))
	assert_false(path.is_empty(), "该能走到边沿跳下低台")
	assert_eq(path.back(), Vector2i(10, 5), "落到低台目标")


func test_no_path_through_tall_wall() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)
	# 第 5 列竖一道 4 格高墙 (超过 JUMP_H=2), 没法翻也没法绕 (一维)
	for y in range(-1, 3):
		cm.set_solid(5, y)
	var path: Array = MobPathfinder.find_path(cm, Vector2i(0, 2), Vector2i(10, 2))
	assert_true(path.is_empty(), "太高的墙翻不过去 → 返回空 (怪退回反应式)")


func test_snap_to_ground() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 5, 6)
	# 目标点悬空 (y=2), 下方 y=5 才是脚站格 → snap 下去
	var snapped = MobPathfinder.snap_to_ground(cm, 2, 2)
	assert_eq(snapped, Vector2i(2, 5), "悬空目标吸附到下方地面")
