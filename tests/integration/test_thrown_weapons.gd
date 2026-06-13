# 投掷武器验收: 手里剑/炸弹/回旋镖 注册齐全 + 回旋镖飞出打怪再飞回。
extends GutTest

const BoomerangScene = preload("res://scenes/entities/boomerang.tscn")
const ShurikenScene = preload("res://scenes/entities/shuriken.tscn")


class StubEnemy:
	extends Node2D
	var hits: int = 0
	func _ready() -> void:
		add_to_group("slimes")
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


func test_thrown_items_registered() -> void:
	for id in ["shuriken", "bomb", "boomerang"]:
		var def: Variant = ItemDB.get_def(id)
		assert_true(def != null, "%s 在 ItemDB" % id)
		assert_eq(String(def.get("tool_kind", "")), "thrown", "%s 是投掷武器" % id)
		assert_not_null(RecipeDB.get_recipe(id), "%s 有配方" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标" % id)
	# 炸弹 = 抛物线落地炸; 手里剑 = 物理飞镖(非魔法); 回旋镖 = 自定义
	assert_true(ItemDB.get_def("bomb").has("gun_explode_radius"), "炸弹会炸")
	assert_eq(String(ItemDB.get_def("shuriken").get("throw_kind", "")), "shuriken", "手里剑走物理飞镖(不是魔法弹/星星贴图)")
	assert_false(ItemDB.get_def("shuriken").has("gun_visual"), "手里剑不再用魔法弹贴图 (无 gun_visual)")
	assert_eq(String(ItemDB.get_def("boomerang").get("throw_kind", "")), "boomerang", "回旋镖走自定义投射物")


func test_boomerang_hits_then_returns() -> void:
	var thrower := Node2D.new()
	add_child_autofree(thrower)
	thrower.global_position = Vector2(0, 0)
	var enemy := StubEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector2(40, 0)   # 在飞出路上
	var bm = BoomerangScene.instantiate()
	add_child(bm)   # 不 autofree: 它自己飞回后 queue_free, 要验证这点
	bm.setup(Vector2(0, 0), Vector2(300, 0), 8, thrower)
	await wait_frames(20)
	assert_gt(enemy.hits, 0, "回旋镖飞出去该打到路上的怪")
	# 飞到 MAX_DIST 再飞回 thrower → 最终自己消失
	await wait_frames(120)
	assert_false(is_instance_valid(bm), "回旋镖飞回被接住后该消失")


func test_shuriken_flies_straight_and_pierces() -> void:
	# 手里剑笔直飞 + 穿透 (路上两只怪都打到), 且是物理飞镖 (不依赖魔法弹)
	var e1 := StubEnemy.new()
	add_child_autofree(e1)
	e1.global_position = Vector2(30, 0)
	var e2 := StubEnemy.new()
	add_child_autofree(e2)
	e2.global_position = Vector2(60, 0)
	var shk = ShurikenScene.instantiate()
	add_child_autofree(shk)
	shk.setup(Vector2(0, 0), Vector2(300, 0), 6, null)
	await wait_frames(20)
	assert_gt(e1.hits, 0, "手里剑打到第一只怪")
	assert_gt(e2.hits, 0, "穿透打到第二只怪")
