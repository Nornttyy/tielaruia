# 链锤神兵验收: 7 把 (雷神/炼狱/深渊/巨力/寒冰/烈焰/绿叶)。
# 不能合成, 只能开宝箱掉。flail 基础 (大射程+强击退) + 各自特殊机制。
extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

const ALL_FLAILS := ["thunder_flail", "inferno_flail", "abyss_flail", "titan_flail", "frost_flail", "flame_flail", "leaf_flail"]


func test_all_flails_registered() -> void:
	for id in ALL_FLAILS:
		var def: Variant = ItemDB.get_def(id)
		assert_true(def != null, "%s 在 ItemDB" % id)
		assert_eq(String(def.get("tool_kind", "")), "sword", "%s 是近战" % id)
		assert_true(float(def.get("melee_reach_bonus", 0.0)) > 0.0, "%s 是链锤(大射程)" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 有发光链锤图标" % id)


func test_flails_are_chest_only() -> void:
	for id in ALL_FLAILS:
		assert_null(RecipeDB.get_recipe(id), "%s 不该有合成配方 (只宝箱掉)" % id)
		assert_true(ChestStorage.SPECIAL_WEAPONS.has(id), "%s 在宝箱战利品池" % id)


func test_flail_mechanics() -> void:
	# 雷神锤: 闪电连跳 (chain_lightning > 0)
	assert_true(int(ItemDB.get_def("thunder_flail").get("chain_lightning", 0)) > 0, "雷神锤闪电连跳")
	# 炼狱锤: 命中即爆 (blast_on_hit > 0)
	assert_true(float(ItemDB.get_def("inferno_flail").get("blast_on_hit", 0.0)) > 0.0, "炼狱锤命中即爆")
	# 深渊锤: 吸怪 (pull_in)
	assert_true(bool(ItemDB.get_def("abyss_flail").get("pull_in", false)), "深渊锤吸怪")
	# 巨力锤: 超强击退 (knockback 比普通链锤大)
	assert_true(float(ItemDB.get_def("titan_flail").get("melee_knockback", 0.0)) > 300.0, "巨力锤超强击退")
	# 元素锤甩元素弹 (swing_proj)
	for id in ["frost_flail", "flame_flail", "leaf_flail"]:
		assert_true(bool(ItemDB.get_def(id).get("swing_proj", false)), "%s 甩元素弹" % id)


func test_flail_icons_distinct() -> void:
	var imgs: Array = []
	for id in ALL_FLAILS:
		imgs.append(ItemsArt.get_icon(id).get_image())
	for i in range(ALL_FLAILS.size()):
		for j in range(i + 1, ALL_FLAILS.size()):
			var same: bool = true
			for y in range(0, imgs[i].get_height()):
				for x in range(0, imgs[i].get_width()):
					if imgs[i].get_pixel(x, y) != imgs[j].get_pixel(x, y):
						same = false
						break
				if not same:
					break
			assert_false(same, "%s 和 %s 图标该不同" % [ALL_FLAILS[i], ALL_FLAILS[j]])
