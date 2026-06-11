# B 波法杖机制验收: 爆炸范围伤害 (一发炸一片) / 击飞 (狂风强击退).
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubEnemy:
	extends Node2D
	var current_health: int = 100
	var hits: int = 0
	var last_kb: float = 0.0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(d: int, _src: Vector2, kb: float = 0.0) -> void:
		current_health -= d
		hits += 1
		last_kb = kb


func _stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


func test_explosion_hits_cluster() -> void:
	var a := _stub(Vector2(20, 0))
	var b := _stub(Vector2(28, 6))   # 离 a ~10px, 在爆炸半径内但不在子弹直线上
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	# 慢速直线撞上 a → 爆炸半径 30 → a + b 都该受伤
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 5, null, 60.0, {"explode_radius": 30.0, "explode_dmg": 7})
	await wait_frames(40)
	assert_gt(a.hits, 0, "爆炸: 直接命中点的怪受伤")
	assert_gt(b.hits, 0, "爆炸: 半径内旁边的怪也受伤 (范围伤害)")


func test_wind_strong_knockback() -> void:
	var a := _stub(Vector2(20, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2(0, 0), Vector2(200, 0), 3, null, 60.0, {"knockback": 460.0, "launch": true})
	await wait_frames(40)
	assert_gt(a.hits, 0, "狂风弹命中怪")
	assert_almost_eq(a.last_kb, 460.0, 1.0, "狂风给怪强击退(460=弹飞)")
