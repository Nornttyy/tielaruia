# 新近战类型验收: 双刀/流星锤/战锤 注册齐全 + 各自属性 (数据驱动手感)。
# (长矛已删)
extends GutTest


func test_melee_weapons_registered() -> void:
	for id in ["dual_blade", "flail", "warhammer"]:
		var def: Variant = ItemDB.get_def(id)
		assert_true(def != null, "%s 在 ItemDB" % id)
		assert_eq(String(def.get("tool_kind", "")), "sword", "%s 走近战(sword)系统" % id)
		assert_not_null(RecipeDB.get_recipe(id), "%s 有配方" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标" % id)


func test_melee_distinct_feel() -> void:
	var dual: Dictionary = ItemDB.get_def("dual_blade")
	var flail: Dictionary = ItemDB.get_def("flail")
	var hammer: Dictionary = ItemDB.get_def("warhammer")
	# 双刀: 攻速快 (cd 小)
	assert_lt(float(dual.get("melee_cooldown", 1.0)), 0.25, "双刀攻速快")
	assert_lt(float(dual.get("damage_mult", 1.0)), 1.0, "双刀单下伤害低")
	# 流星锤/战锤: 强击退
	assert_gt(float(flail.get("melee_knockback", 0.0)), 200.0, "流星锤强击退")
	assert_gt(float(hammer.get("melee_knockback", 0.0)), 200.0, "战锤把怪砸飞")
	assert_gt(float(hammer.get("damage_mult", 1.0)), 1.5, "战锤高伤")
