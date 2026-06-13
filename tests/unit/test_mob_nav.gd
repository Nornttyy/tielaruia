# 寻路跟随器 steer 验收: 朝下一路点的方向 + 该不该跳 (爬台阶/跨坑); 没路返回 NO_PATH。
extends GutTest

const MobNav = preload("res://scripts/entities/mob_nav.gd")


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


func test_flat_walks_toward_goal_no_jump() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)
	var nav = MobNav.new()
	var dir: int = nav.steer(cm, Vector2i(0, 2), Vector2i(10, 2), 1.0)
	assert_eq(dir, 1, "平地朝目标(右)走")
	assert_false(nav.want_jump, "平地不跳")


func test_staircase_wants_jump_up() -> void:
	var cm := GridCM.new()
	for x in range(0, 6):
		cm.set_solid(x, 6 - x)
	var nav = MobNav.new()
	var dir: int = nav.steer(cm, Vector2i(0, 5), Vector2i(5, 0), 1.0)
	assert_eq(dir, 1, "朝楼梯顶(右)走")
	assert_true(nav.want_jump, "爬台阶要跳")


func test_at_gap_edge_wants_jump() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)
	cm.solid.erase(Vector2i(5, 3))   # x=5 一格坑
	var nav = MobNav.new()
	# 怪正站在坑边 (x=4) → 该跳过去
	var dir: int = nav.steer(cm, Vector2i(4, 2), Vector2i(10, 2), 1.0)
	assert_eq(dir, 1, "朝对面(右)走")
	assert_true(nav.want_jump, "站在坑边该跳过坑")


func test_no_path_returns_sentinel() -> void:
	var cm := GridCM.new()
	cm.fill_floor(0, 11, 3)
	for y in range(-1, 3):
		cm.set_solid(5, y)   # 4 格高墙, 翻不过绕不开
	var nav = MobNav.new()
	var dir: int = nav.steer(cm, Vector2i(0, 2), Vector2i(10, 2), 1.0)
	assert_eq(dir, MobNav.NO_PATH, "没路 → 返回 NO_PATH (怪退回反应式)")
