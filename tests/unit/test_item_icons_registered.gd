extends GutTest

# 回归守卫: 游戏里取物品图标走 ArtCache.get_inventory_icon (不是直接 ItemsArt.get_icon)。
# ArtCache 有一份写死的 item_icons 清单, 漏加 → 背包/掉落没图 + console warning。
# 这里把所有料理 + 钓鱼物品都断言"有图", 防再漏 (鱼竿没图就是栽在这)。
func test_food_and_fishing_items_have_inventory_icon():
	var ids := [
		# 第 1 步料理
		"bread", "mushroom_soup", "apple_pie", "meat_skewer",
		"mushroom_stew", "apple_jam", "jelly_pudding",
		# 第 2 步钓鱼
		"fishing_rod", "grilled_fish",
		"salmon", "tuna", "octopus", "sea_urchin", "lobster",
		"eel", "sweet_shrimp", "scallop", "seaweed",
		# 做饭工作站 (放置物)
		"cooking_pot",
		# 空岛 (audit 发现漏注册)
		"feather", "cloud_boots",
	]
	for id in ids:
		var tex = ArtCache.get_inventory_icon(id)
		assert_not_null(tex, "%s 在游戏里应有图标 (ArtCache.get_inventory_icon)" % id)


# 16 把剑 (8 短剑 + 8 阔剑) 都要有游戏内图标, 且短剑≠阔剑造型 (用户要求"造型不能一样")
func test_all_16_swords_have_distinct_icons():
	for mat in ["wood", "stone", "copper", "iron", "silver", "gold", "diamond", "hell"]:
		var dagger_tex = ArtCache.get_inventory_icon(mat + "_dagger")
		var sword_tex = ArtCache.get_inventory_icon(mat + "_sword")
		assert_not_null(dagger_tex, "%s_dagger 应有游戏内图标 (没图标合成栏空白)" % mat)
		assert_not_null(sword_tex, "%s_sword 应有游戏内图标" % mat)
		if dagger_tex != null and sword_tex != null:
			# 造型必须不同 (短剑短窄 / 阔剑长宽) — 比图标像素数据
			assert_ne(dagger_tex.get_image().get_data(), sword_tex.get_image().get_data(),
				"%s 短剑和阔剑造型不能一样" % mat)
