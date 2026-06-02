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
