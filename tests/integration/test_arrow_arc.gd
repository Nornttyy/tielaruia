# 箭抛物线验收: 箭射出后应受重力下坠 (不再匀速直线飞).
extends GutTest

const ArrowScene = preload("res://scenes/entities/arrow.tscn")


func test_arrow_initial_velocity_is_straight() -> void:
	# 纯水平射出 (target 在正右方同一高度) → 初速度应纯水平, y≈0
	var arrow = ArrowScene.instantiate()
	add_child_autofree(arrow)
	arrow.setup(Vector2(0, 0), Vector2(100, 0), 5, null)
	assert_almost_eq(arrow.velocity.y, 0.0, 1.0, "刚射出: 竖直速度≈0 (还没受重力)")


func test_arrow_falls_under_gravity() -> void:
	var arrow = ArrowScene.instantiate()
	add_child_autofree(arrow)
	arrow.setup(Vector2(0, 0), Vector2(100, 0), 5, null)
	await wait_frames(20)   # 推进若干物理帧让重力累积
	# 飞行中: 获得向下速度 + 实际位置已下坠 (y 增大) + 仍在往右飞
	assert_gt(arrow.velocity.y, 0.0, "飞行中应获得向下速度 (重力 → 抛物线)")
	assert_gt(arrow.global_position.y, 0.0, "箭应已往下坠 (y 比出发点大)")
	assert_gt(arrow.global_position.x, 0.0, "水平方向仍在前进")


func test_arrow_points_along_flight() -> void:
	# 抛物线下坠时箭头应朝飞行方向 (rotation 跟着 velocity 转), 不是一直水平
	var arrow = ArrowScene.instantiate()
	add_child_autofree(arrow)
	arrow.setup(Vector2(0, 0), Vector2(100, 0), 5, null)
	await wait_frames(20)
	assert_gt(arrow.rotation, 0.0, "下坠中箭头应朝下偏转 (rotation 随飞行方向)")
