# 回归: 飞太快的子弹/箭不该从怪身上"跳过去"不算命中 (用户报: 明明碰到生物却没伤害).
# 命中改成"上一帧→这一帧线段"到怪的距离判定 (扫掠), 不再只看落点那一个点.
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const ArrowScene = preload("res://scenes/entities/arrow.tscn")


class StubEnemy:
	extends Node2D
	var current_health: int = 100
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(d: int, _src: Vector2, _kb: float = 0.0) -> void:
		current_health -= d
		hits += 1


func _stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


func test_very_fast_bullet_hits_enemy_on_path() -> void:
	var enemy := _stub(Vector2(60, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	# 超快: 一帧就飞过 100px, 直接越过 x=60 — 老的"只看落点"判定会漏, 扫掠判定能打中
	bullet.setup(Vector2(0, 0), Vector2(300, 0), 5, null, 6000.0)
	await wait_frames(2)
	assert_gt(enemy.hits, 0, "超快子弹也该打中路径上的怪 (扫掠, 不穿模)")


func test_very_fast_arrow_hits_enemy_on_path() -> void:
	var enemy := _stub(Vector2(60, 0))
	var arrow = ArrowScene.instantiate()
	add_child_autofree(arrow)
	arrow.setup(Vector2(0, 0), Vector2(300, 0), 5, null)
	# 直接把速度调超大, 模拟一帧跨过怪
	arrow.velocity = Vector2(6000, 0)
	await wait_frames(2)
	assert_gt(enemy.hits, 0, "超快箭也该打中路径上的怪 (扫掠, 不穿模)")
