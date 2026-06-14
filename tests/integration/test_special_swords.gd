# 代号神兵验收: 蓝月/火神/绿叶/冰雪剑/天陨 注册齐全 + 挥剑射元素弹。
extends GutTest

const PlayerAction = preload("res://scripts/player/player_action.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")

const SWORDS := ["blue_moon", "fire_god", "leaf_blade", "frost_blade", "skyfall_blade"]


func test_special_swords_registered() -> void:
	for id in SWORDS:
		var def: Variant = ItemDB.get_def(id)
		assert_true(def != null, "%s 在 ItemDB" % id)
		assert_eq(String(def.get("tool_kind", "")), "sword", "%s 是阔剑" % id)
		assert_true(bool(def.get("swing_proj", false)), "%s 挥剑发射元素弹" % id)
		assert_not_null(RecipeDB.get_recipe(id), "%s 有配方" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标(按元素发光剑)" % id)


func test_special_sword_icons_distinct() -> void:
	# 5 把剑颜色各不同 (元素发光剑)
	var imgs: Array = []
	for id in SWORDS:
		imgs.append(ItemsArt.get_icon(id).get_image())
	# 任意两把不该完全一样
	for i in range(SWORDS.size()):
		for j in range(i + 1, SWORDS.size()):
			var same: bool = true
			for y in range(0, imgs[i].get_height()):
				for x in range(0, imgs[i].get_width()):
					if imgs[i].get_pixel(x, y) != imgs[j].get_pixel(x, y):
						same = false
						break
				if not same:
					break
			assert_false(same, "%s 和 %s 图标该不同" % [SWORDS[i], SWORDS[j]])


func test_skyfall_is_random_element() -> void:
	assert_true(bool(ItemDB.get_def("skyfall_blade").get("swing_proj_random", false)), "天陨随机元素")
	# 蓝月穿透 / 火神爆炸 / 绿叶追踪 / 冰雪减速
	assert_true(bool(ItemDB.get_def("blue_moon").get("gun_pierce", false)), "蓝月剑气穿透")
	assert_true(ItemDB.get_def("fire_god").has("gun_explode_radius"), "火神火焰弹会炸")
	assert_true(ItemDB.get_def("leaf_blade").has("gun_homing"), "绿叶弹追踪")
	assert_true(ItemDB.get_def("frost_blade").has("gun_slow_factor"), "冰雪弹减速")
