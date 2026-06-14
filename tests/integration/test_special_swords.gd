# 代号神兵验收: 7 把 (蓝月/火神/绿叶/冰雪剑/天陨/星陨/噬魂)。
# 不能合成, 只能开宝箱掉。前 5 把挥剑射元素弹; 星陨命中召陨星; 噬魂命中吸血。
extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

# 挥剑射元素弹的 5 把
const PROJ_SWORDS := ["blue_moon", "fire_god", "leaf_blade", "frost_blade", "skyfall_blade"]
# 全部 11 把神兵
const ALL_SWORDS := ["blue_moon", "fire_god", "leaf_blade", "frost_blade", "skyfall_blade", "starfall_blade", "soul_eater", "void_blade", "magnet_blade", "echo_blade", "crimson_blade"]


func test_all_swords_registered() -> void:
	for id in ALL_SWORDS:
		var def: Variant = ItemDB.get_def(id)
		assert_true(def != null, "%s 在 ItemDB" % id)
		assert_eq(String(def.get("tool_kind", "")), "sword", "%s 是阔剑" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标(按元素发光剑)" % id)


func test_swords_are_chest_only() -> void:
	# 神兵不能合成 (没配方), 只能开宝箱掉
	for id in ALL_SWORDS:
		assert_null(RecipeDB.get_recipe(id), "%s 不该有合成配方 (只宝箱掉)" % id)
		assert_true(ChestStorage.SPECIAL_WEAPONS.has(id), "%s 在宝箱战利品池" % id)


func test_proj_swords_fire_element() -> void:
	for id in PROJ_SWORDS:
		assert_true(bool(ItemDB.get_def(id).get("swing_proj", false)), "%s 挥剑发射元素弹" % id)


func test_onhit_mechanics() -> void:
	# 星陨: 命中召唤陨星 (meteor_on_hit > 0)
	assert_true(int(ItemDB.get_def("starfall_blade").get("meteor_on_hit", 0)) > 0, "星陨命中召陨星")
	# 噬魂: 命中吸血 (lifesteal > 0)
	assert_true(float(ItemDB.get_def("soul_eater").get("lifesteal", 0.0)) > 0.0, "噬魂命中吸血")
	# 虚空: 概率秒杀 (void_chance > 0)
	assert_true(float(ItemDB.get_def("void_blade").get("void_chance", 0.0)) > 0.0, "虚空概率秒杀")
	# 磁极: 吸掉落物 (magnet_radius > 0)
	assert_true(float(ItemDB.get_def("magnet_blade").get("magnet_radius", 0.0)) > 0.0, "磁极吸掉落物")
	# 回响: 延时再爆 (echo_delay > 0)
	assert_true(float(ItemDB.get_def("echo_blade").get("echo_delay", 0.0)) > 0.0, "回响延时再爆")
	# 赤霄: 连击加速 (combo_haste)
	assert_true(bool(ItemDB.get_def("crimson_blade").get("combo_haste", false)), "赤霄连击加速")


func test_skyfall_is_random_element() -> void:
	assert_true(bool(ItemDB.get_def("skyfall_blade").get("swing_proj_random", false)), "天陨随机元素")
	assert_true(bool(ItemDB.get_def("blue_moon").get("gun_pierce", false)), "蓝月剑气穿透")
	assert_true(ItemDB.get_def("fire_god").has("gun_explode_radius"), "火神火焰弹会炸")
	assert_true(ItemDB.get_def("leaf_blade").has("gun_homing"), "绿叶弹追踪")
	assert_true(ItemDB.get_def("frost_blade").has("gun_slow_factor"), "冰雪弹减速")


func test_special_sword_icons_distinct() -> void:
	# 7 把剑颜色各不同 (元素发光剑)
	var imgs: Array = []
	for id in ALL_SWORDS:
		imgs.append(ItemsArt.get_icon(id).get_image())
	for i in range(ALL_SWORDS.size()):
		for j in range(i + 1, ALL_SWORDS.size()):
			var same: bool = true
			for y in range(0, imgs[i].get_height()):
				for x in range(0, imgs[i].get_width()):
					if imgs[i].get_pixel(x, y) != imgs[j].get_pixel(x, y):
						same = false
						break
				if not same:
					break
			assert_false(same, "%s 和 %s 图标该不同" % [ALL_SWORDS[i], ALL_SWORDS[j]])
