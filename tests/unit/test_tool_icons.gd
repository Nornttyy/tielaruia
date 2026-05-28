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
	# V3 改动不应该坏掉别的 icon (coal / iron_ore / silver_ore 现在走 ArtCache 的 block tile,
	# 不再在 ItemsArt 里, 所以不测它们)
	for item_id in ["slime_jelly", "apple",
			"raw_meat", "leather", "wool", "grappling_hook"]:
		var tex: ImageTexture = ItemsArt.get_icon(item_id)
		assert_not_null(tex, "%s 返回 null" % item_id)
		assert_eq(tex.get_width(), 16, "%s 宽 != 16" % item_id)
		assert_eq(tex.get_height(), 16, "%s 高 != 16" % item_id)


# 矿物物品 (挖矿掉的) 应该用世界里的方块图, 不是小块岩屑图.
# 用 ArtCache.get_inventory_icon (才是游戏里实际用的查找路径).
func test_ore_items_use_block_tile_icon():
	const BlocksArt = preload("res://scripts/art/blocks_art.gd")
	var cases := {
		"coal": BlocksArt.COAL_ORE,
		"iron_ore": BlocksArt.IRON_ORE,
		"silver_ore": BlocksArt.SILVER_ORE,
		"copper_ore": BlocksArt.COPPER_ORE,
		"tin_ore": BlocksArt.TIN_ORE,
		"gold_ore": BlocksArt.GOLD_ORE,
		"diamond": BlocksArt.DIAMOND_ORE,
		"hell_crystal": BlocksArt.HELL_CRYSTAL,
	}
	for item_id in cases:
		var tile_id: int = cases[item_id]
		var item_tex: ImageTexture = ArtCache.get_inventory_icon(item_id)
		var block_tex: ImageTexture = ArtCache.block_icons[tile_id]
		assert_eq(item_tex, block_tex,
			"%s 应直接用 block tile 图 (BlocksArt id %d)" % [item_id, tile_id])


# 锭 (ingot) 应该是干净的金属条, 不是 block 图.
func test_ingot_items_use_custom_ingot_icon():
	# 跟 block tile 图不一样就行 (用自己画的 ingot 形状)
	for item_id in ["iron_ingot", "copper_ingot", "tin_ingot", "silver_ingot", "gold_ingot", "hell_crystal_ingot"]:
		var tex: ImageTexture = ArtCache.get_inventory_icon(item_id)
		assert_not_null(tex, "%s 没图" % item_id)
		assert_eq(tex.get_width(), 16, "%s 宽 != 16" % item_id)
		assert_eq(tex.get_height(), 16, "%s 高 != 16" % item_id)
