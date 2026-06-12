# 第二批枪 (用户加) 上线验收: def / 图标 / 配方 / 中文名 / 出现在对战房切武器列表。
extends GutTest

const CraftingPanel = preload("res://scripts/ui/crafting_panel.gd")
const PvpModePanel = preload("res://scripts/ui/pvp_mode_panel.gd")

const NEW_GUNS := [
	"minigun", "twin_magic_gun", "rocket_gun", "slime_smg",
	"tesla_gun", "cryo_gun", "venom_gun", "railgun",
]


func test_new_guns_def_and_icon():
	for id in NEW_GUNS:
		var def = ItemDB.get_def(id)
		assert_not_null(def, "%s 该在 item_db" % id)
		if def != null:
			assert_eq(def.get("tool_kind", ""), "gun", "%s tool_kind 该是 gun" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 该有游戏内图标 (否则背包显白块/报错)" % id)


func test_new_guns_have_chinese_names():
	for id in NEW_GUNS:
		var zh: String = String(CraftingPanel._ZH_NAMES.get(id, id))
		assert_ne(zh, id, "%s 该有中文名 (漏了就显英文 id)" % id)


func test_new_guns_craftable():
	for id in NEW_GUNS:
		var r = RecipeDB.get_recipe(id)
		assert_not_null(r, "%s 该有合成配方" % id)
		# 配方材料都得是真物品 (打错 id → 永远合不出来)
		if r != null:
			for row in r["pattern"]:
				for mat in row:
					if mat != "":
						assert_not_null(ItemDB.get_def(mat), "%s 配方材料 %s 该是真物品" % [id, mat])


func test_new_guns_in_pvp_weapon_list():
	var ids := {}
	for pair in PvpModePanel._GUNS:
		ids[String(pair[0])] = true
	for id in NEW_GUNS:
		assert_true(ids.has(id), "%s 该出现在对战房切武器列表" % id)
