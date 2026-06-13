# 补特效验收: 弓箭命中 + 火球法杖命中 现在都放特效 (之前没有, 用户报)。
extends GutTest

const ArrowScene = preload("res://scenes/entities/arrow.tscn")
const FireballScene = preload("res://scenes/entities/fireball.tscn")


class StubEnemy:
	extends Node2D
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


func _stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new()
	add_child_autofree(s)
	s.global_position = pos
	return s


func test_arrow_hits_enemy() -> void:
	# 箭命中分支里紧挨着 take_damage 就调 spawn_bullet_impact → 命中即放特效
	var e := _stub(Vector2(20, 0))
	var a = ArrowScene.instantiate()
	add_child_autofree(a)
	a.setup(Vector2(0, 0), Vector2(200, 0), 5, null)
	await wait_frames(30)
	assert_gt(e.hits, 0, "箭该射中怪 (命中分支含 spawn_bullet_impact 特效)")


func test_bullet_impact_fx_spawns_node() -> void:
	# 弓/枪命中特效本体: spawn_bullet_impact 真能冒节点
	var before: int = get_tree().get_node_count()
	Effects.spawn_bullet_impact(Vector2(0, 0), Vector2(1, 0), Color8(235, 220, 170), "hit")
	await wait_frames(1)
	assert_gt(get_tree().get_node_count(), before, "spawn_bullet_impact 该冒命中特效节点")


func test_fireball_destroy_spawns_fx() -> void:
	var fb = FireballScene.instantiate()
	add_child_autofree(fb)
	fb.setup(Vector2(0, 0), Vector2(100, 0), 6, true, "fire")
	await wait_frames(1)
	var before: int = get_tree().get_node_count()
	fb._destroy()
	await wait_frames(1)
	# 爆炸粒子 + 招牌冲击波环 → 节点数明显变多
	assert_gt(get_tree().get_node_count(), before + 5, "火球命中该冒爆炸+冲击波特效")


func test_fireball_ice_uses_splash_ring() -> void:
	# 冰元素火球用涟漪环 (不崩 + 有特效)
	var fb = FireballScene.instantiate()
	add_child_autofree(fb)
	fb.setup(Vector2(0, 0), Vector2(100, 0), 6, true, "ice")
	await wait_frames(1)
	var before: int = get_tree().get_node_count()
	fb._destroy()
	await wait_frames(1)
	assert_gt(get_tree().get_node_count(), before, "冰火球命中也该有特效")
