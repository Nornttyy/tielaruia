# 法杖射程 + 水之法杖"飞到落地才炸"验收。
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")
const PlayerAction = preload("res://scripts/player/player_action.gd")


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


func test_staff_default_lifetime_longer_than_old() -> void:
	# 法杖球默认寿命加长 (射程变大) — 比老的子弹默认 1.2s 长
	assert_gt(PlayerAction.STAFF_BULLET_LIFETIME, 1.2, "法杖球默认寿命该比 1.2s 长 (加大射程)")


func test_normal_staff_has_no_explicit_lifetime() -> void:
	# 普通法杖 (闪电) 不单独设 bullet_lifetime → 用默认长寿命 (_cast_bullet_spell 补)
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var opts: Dictionary = pa._proj_opts_from_def(ItemDB.get_def("lightning_staff"))
	assert_false(opts.has("lifetime"), "闪电法杖不显式设寿命 → 走默认")


func test_water_opts_land_only_and_long_life() -> void:
	var pa = PlayerAction.new()
	add_child_autofree(pa)
	var opts: Dictionary = pa._proj_opts_from_def(ItemDB.get_def("water_staff"))
	assert_true(opts.get("explode_on_land_only", false), "水之法杖: 只落地才炸")
	assert_gt(float(opts.get("lifetime", 0.0)), 3.0, "水之法杖寿命够长 → 飞到落地")


func test_water_ball_passes_through_enemy_in_air() -> void:
	# explode_on_land_only: 空中穿过怪不炸不伤 (像水球, 砸地才溅)
	var e := _stub(Vector2(40, 0))
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(300, 0), 5, null, 200.0, {"explode_radius": 22.0, "explode_dmg": 8, "explode_on_land_only": true})
	await wait_frames(40)
	assert_eq(e.hits, 0, "水球空中穿过怪, 不在半空炸")


func test_normal_explode_ball_hits_enemy_in_air() -> void:
	# 对照: 不带 explode_on_land_only 的爆裂球, 空中命中怪就炸
	var e := _stub(Vector2(40, 0))
	var b = BulletScene.instantiate()
	add_child_autofree(b)
	b.setup(Vector2(0, 0), Vector2(300, 0), 5, null, 200.0, {"explode_radius": 22.0, "explode_dmg": 8})
	await wait_frames(40)
	assert_gt(e.hits, 0, "普通爆裂球空中命中怪就炸")
