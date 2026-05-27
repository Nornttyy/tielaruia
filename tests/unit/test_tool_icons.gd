extends GutTest

# 验证 V3 工具图标 (7 tier × 3 tool = 21 个) 全部存在 + 都是 16×16
# 防止 PNG 路径 (120×120, 32×32) bug 复发.

const ItemsArt = preload("res://scripts/art/items_art.gd")

const TIERS := ["wood", "stone", "copper", "iron", "silver", "gold", "diamond"]
const TOOLS := ["sword", "pickaxe", "axe"]


func test_all_tool_icons_exist_and_are_16x16():
	for tier in TIERS:
		for tool in TOOLS:
			var item_id: String = "%s_%s" % [tier, tool]
			assert_true(ItemsArt.has_icon(item_id), "缺图标: %s" % item_id)
			var tex: ImageTexture = ItemsArt.get_icon(item_id)
			assert_not_null(tex, "%s 返回 null" % item_id)
			assert_eq(tex.get_width(), 16, "%s 宽 != 16" % item_id)
			assert_eq(tex.get_height(), 16, "%s 高 != 16" % item_id)


func test_copper_silver_tools_added():
	# T (V3 新增 tier) 必须有
	for tool in TOOLS:
		assert_true(ItemsArt.has_icon("copper_%s" % tool), "缺 copper_%s" % tool)
		assert_true(ItemsArt.has_icon("silver_%s" % tool), "缺 silver_%s" % tool)


func test_non_tool_icons_still_work():
	# V3 改动不应该坏掉别的 icon
	for item_id in ["slime_jelly", "apple", "coal", "iron_ore",
			"raw_meat", "leather", "wool", "grappling_hook"]:
		var tex: ImageTexture = ItemsArt.get_icon(item_id)
		assert_not_null(tex, "%s 返回 null" % item_id)
		assert_eq(tex.get_width(), 16, "%s 宽 != 16" % item_id)
		assert_eq(tex.get_height(), 16, "%s 高 != 16" % item_id)
