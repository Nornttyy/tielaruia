# 子弹验收: 跟箭相反 — 笔直飞, 不受重力下坠, 且比箭快.
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const ArrowScene = preload("res://scenes/entities/arrow.tscn")


func test_bullet_flies_straight_no_drop() -> void:
	# 纯水平射出 → 飞一会儿后 y 几乎不变 (无重力下坠), x 一直前进
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(100, 0), 9, null)
	await wait_frames(20)   # 推进若干物理帧
	assert_almost_eq(bullet.global_position.y, 0.0, 1.0, "子弹笔直飞: y 基本不变 (无重力)")
	assert_gt(bullet.global_position.x, 0.0, "子弹一直往右飞")


func test_bullet_velocity_stays_horizontal() -> void:
	# 飞行中竖直速度始终≈0 (跟箭 velocity.y>0 相反)
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(100, 0), 9, null)
	await wait_frames(15)
	assert_almost_eq(bullet.velocity.y, 0.0, 0.01, "子弹竖直速度恒为 0 (不下坠)")


func test_bullet_faster_than_arrow() -> void:
	# 同样水平射, 同帧数后子弹应飞得更远 (560 vs 260)
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(100, 0), 9, null)
	var arrow = ArrowScene.instantiate()
	add_child_autofree(arrow)
	arrow.setup(Vector2(0, 0), Vector2(100, 0), 5, null)
	await wait_frames(10)
	assert_gt(bullet.global_position.x, arrow.global_position.x, "子弹比箭飞得快/远")
