# 水之法杖: 只落地(撞实心)才炸, 空中穿过怪不引爆 (用户要求, 像水球砸地才溅)。
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubEnemy:
	extends Node2D
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func melee_hit_radius() -> float:
		return 6.0
	func take_damage(_d: int, _src: Vector2, _kb: float) -> void:
		hits += 1


# x>=3 格 (36px) 是实心墙, 其余空气 → 子弹飞到 x36 落地
class MockCM:
	extends Node
	func _ready() -> void:
		add_to_group("chunk_manager")
	func get_tile(tx: int, _ty: int) -> int:
		return Tiles.STONE if tx >= 3 else Tiles.AIR


func _stub(pos: Vector2) -> StubEnemy:
	var s := StubEnemy.new(); add_child_autofree(s); s.global_position = pos; return s


# 空中穿过怪: 不引爆, 不扣血
func test_water_passes_through_enemy_in_air():
	var e := _stub(Vector2(18, 0))
	var b = BulletScene.instantiate(); add_child_autofree(b)
	# 60px/s = 1px/帧, 必经过 x18; 没有 chunk_manager → 一路空气, 不会落地
	b.setup(Vector2(0, 0), Vector2(300, 0), 8, null, 60.0,
		{"explode_radius": 22.0, "explode_dmg": 8, "explode_on_land_only": true})
	await wait_frames(30)
	assert_eq(e.hits, 0, "水之弹空中穿过怪, 不炸不扣血")


# 落地(撞实心墙)才炸: 墙边的怪被溅到
func test_water_explodes_on_landing():
	var cm := MockCM.new(); add_child_autofree(cm)
	await wait_frames(1)
	var e := _stub(Vector2(40, 0))   # 墙(x36)后边一点, 在爆炸半径内
	var b = BulletScene.instantiate(); add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(300, 0), 8, null, 60.0,
		{"explode_radius": 22.0, "explode_dmg": 8, "explode_on_land_only": true})
	await wait_frames(60)
	assert_gt(e.hits, 0, "撞到实心墙(落地)该炸, 溅到旁边的怪")


# 对照: 普通爆裂弹(没 land_only) 空中命中怪就炸
func test_normal_explosive_detonates_in_air():
	var e := _stub(Vector2(18, 0))
	var b = BulletScene.instantiate(); add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(300, 0), 8, null, 60.0,
		{"explode_radius": 22.0, "explode_dmg": 8})
	await wait_frames(30)
	assert_gt(e.hits, 0, "普通爆裂弹空中命中就炸 (对照, 证明不是 explode 坏了)")
