# 近战材质变种验收: 金/钻长矛/双刀/流星锤/战锤 注册齐全 + 高 tier = 高伤 + 图标自动换色。
extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")


func test_tier_variants_registered() -> void:
	for base in ["spear", "dual_blade", "flail", "warhammer"]:
		for pre in ["gold_", "diamond_"]:
			var id: String = pre + base
			var def: Variant = ItemDB.get_def(id)
			assert_true(def != null, "%s 在 ItemDB" % id)
			assert_eq(String(def.get("tool_kind", "")), "sword", "%s 是近战" % id)
			assert_not_null(RecipeDB.get_recipe(id), "%s 有配方" % id)
			assert_not_null(ArtCache.get_inventory_icon(id), "%s 有图标(自动换色)" % id)


func test_higher_tier_more_damage() -> void:
	# 同武器: 钻石 tier >= 金 tier > 基础 tier (高材质更狠)
	for base in ["spear", "dual_blade", "flail"]:
		var t0: int = int(ItemDB.get_def(base).get("tool_tier", 0))
		var tg: int = int(ItemDB.get_def("gold_" + base).get("tool_tier", 0))
		var td: int = int(ItemDB.get_def("diamond_" + base).get("tool_tier", 0))
		assert_gt(tg, t0, "%s: 金 tier > 基础" % base)
		assert_gt(td, tg, "%s: 钻石 tier > 金" % base)


func test_tier_icon_recolor_differs_from_base() -> void:
	# 金/钻图标 = 基础形状换金属色 → 跟基础不是同一张 (颜色变了)
	var base_tex = ItemsArt.get_icon("spear")
	var gold_tex = ItemsArt.get_icon("gold_spear")
	var dia_tex = ItemsArt.get_icon("diamond_spear")
	assert_not_null(gold_tex, "金长矛图标生成成功")
	assert_not_null(dia_tex, "钻石长矛图标生成成功")
	# 取中间一像素比较 (金属部分应换了色)
	var ib: Image = base_tex.get_image()
	var ig: Image = gold_tex.get_image()
	var diff: bool = false
	for y in range(0, ib.get_height()):
		for x in range(0, ib.get_width()):
			if ib.get_pixel(x, y) != ig.get_pixel(x, y):
				diff = true
				break
		if diff:
			break
	assert_true(diff, "金长矛图标该跟基础长矛颜色不同")
