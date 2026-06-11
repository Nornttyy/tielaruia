# C 波法杖机制验收: 地裂 (地上裂缝持续伤害) / 雀宝宝 (召唤飞鸟撞怪) / 治疗 (回血). 还查三杖注册齐全.
extends GutTest

const EarthCrackScene = preload("res://scenes/entities/earth_crack.tscn")
const FriendlyBirdScene = preload("res://scenes/entities/friendly_bird.tscn")


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


func test_earth_crack_damages_enemy_in_band() -> void:
	var e := _stub(Vector2(10, -4))   # 裂缝横向 ±40 内, 略高于裂缝 → 算"站上面"
	var crack = EarthCrackScene.instantiate()
	add_child_autofree(crack)
	crack.global_position = Vector2(0, 0)
	crack.setup(7, null)
	await wait_frames(6)
	assert_gt(e.hits, 0, "地裂: 范围内的怪持续受伤")


func test_earth_crack_ignores_far_enemy() -> void:
	var e := _stub(Vector2(120, 0))   # 横向 120 > 半宽 40 → 不该被伤
	var crack = EarthCrackScene.instantiate()
	add_child_autofree(crack)
	crack.global_position = Vector2(0, 0)
	crack.setup(7, null)
	await wait_frames(6)
	assert_eq(e.hits, 0, "地裂: 太远的怪不受伤")


func test_friendly_bird_attacks_enemy() -> void:
	var e := _stub(Vector2(24, 0))
	var bird = FriendlyBirdScene.instantiate()
	add_child_autofree(bird)
	bird.global_position = Vector2(0, 0)
	# 雀宝宝飞向最近敌怪并撞它 → 几帧内造成伤害
	await wait_frames(40)
	assert_gt(e.hits, 0, "雀宝宝: 飞过去撞到怪造成伤害")
	assert_true(bird.is_in_group("friendly_minions"), "雀宝宝在 friendly_minions 组 (玩家打不到它)")


func test_c_staffs_registered() -> void:
	for id in ["heal_staff", "bird_staff", "crack_staff"]:
		assert_true(ItemDB.get_def(id) != null, "%s 在 ItemDB" % id)
		assert_not_null(RecipeDB.get_recipe(id), "%s 有配方" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标" % id)
	# 三杖各自的机制字段
	assert_true(ItemDB.get_def("heal_staff").has("heal_amount"), "治疗法杖带 heal_amount")
	assert_eq(String(ItemDB.get_def("bird_staff").get("summon_kind", "")), "bird", "雀宝宝法杖 summon_kind=bird")
	assert_true(ItemDB.get_def("crack_staff").has("ground_crack"), "地裂法杖带 ground_crack")
