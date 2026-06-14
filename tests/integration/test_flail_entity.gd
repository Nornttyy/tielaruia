# 链锤球实体验收: 绕玩家转 → 松手甩出 → 到最远 → 飞回 → 消失。
extends GutTest

const FlailScene = preload("res://scenes/entities/flail.tscn")

var _player: Node2D


func before_each() -> void:
	_player = Node2D.new()
	_player.global_position = Vector2(100, 100)
	add_child_autofree(_player)


func _make_flail() -> Node:
	var f = FlailScene.instantiate()
	add_child_autofree(f)
	f.setup(_player, null, 12, {"melee_knockback": 200.0, "gun_visual": "fire"})
	return f


func test_orbits_around_player() -> void:
	var f = _make_flail()
	assert_true(f.is_orbiting(), "刚生成应在绕转态")
	# 转几帧, 球应始终在玩家附近 (绕转半径内外一点)
	for i in 5:
		f._physics_process(0.05)
	var dist: float = f.global_position.distance_to(_player.global_position)
	assert_almost_eq(dist, 40.0, 6.0, "绕转时球在 ~40px 半径上")


func test_release_flies_out_then_returns() -> void:
	var f = _make_flail()
	f.release(Vector2(300, 100))   # 甩向右边
	assert_false(f.is_orbiting(), "松手后不再绕转")
	# 跑足够多帧: 应先飞远再飞回到玩家身边 (queue_free 在手动跑帧下不立即生效, 改测位置)
	var max_dist := 0.0
	var came_back := false
	for i in 120:
		if not is_instance_valid(f):
			came_back = true
			break
		f._physics_process(0.03)
		var d: float = f.global_position.distance_to(_player.global_position)
		max_dist = max(max_dist, d)
		if max_dist > 100.0 and d < 20.0:
			came_back = true   # 飞远过 + 又回到玩家身边
			break
	assert_true(came_back, "球飞出去再飞回到玩家身边 (max=%.0f)" % max_dist)


func test_far_point_is_beyond_orbit() -> void:
	var f = _make_flail()
	f.release(Vector2(400, 100))
	var max_dist := 0.0
	for i in 60:
		if not is_instance_valid(f):
			break
		f._physics_process(0.02)
		max_dist = max(max_dist, f.global_position.distance_to(_player.global_position))
	assert_true(max_dist > 100.0, "甩出去能飞到 100px 开外 (实测 %.0f)" % max_dist)
