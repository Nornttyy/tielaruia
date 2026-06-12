extends GutTest

# 地狱恶魔领主 (Demon Lord) — T1: 召唤道具 + 神装物品登记 (见 spec 2026-06-12)。
# Boss 本体的 spawn/受伤/掉落测试在 T2 加。
const CraftingPanel = preload("res://scripts/ui/crafting_panel.gd")

const _DEMON_ITEMS := [
	"demon_heart", "demon_trident", "inferno_staff", "demon_wings",
	"demon_helmet", "demon_chest", "demon_pants",
]


func test_all_demon_items_in_db():
	for id in _DEMON_ITEMS:
		assert_true(ItemDB.get_def(id).size() > 0, "%s 该在 item_db" % id)


func test_demon_heart_summons_demon_lord():
	var d = ItemDB.get_def("demon_heart")
	assert_eq(String(d.get("tool_kind", "")), "summon", "恶魔之心是召唤道具")
	assert_eq(String(d.get("summon_boss", "")), "demon_lord", "召唤恶魔领主")


func test_demon_weapons_strong():
	# 三叉戟比地狱剑(tier8/1.2)更强; 烈焰法杖是 fire 法杖
	assert_eq(String(ItemDB.get_def("demon_trident").get("tool_kind", "")), "sword")
	assert_true(int(ItemDB.get_def("demon_trident").get("tool_tier", 0)) >= 9, "三叉戟 tier ≥ 9")
	assert_eq(String(ItemDB.get_def("inferno_staff").get("tool_kind", "")), "staff")


func test_demon_armor_set():
	# 恶魔盔甲略强于骷髅套 (14/22/14 vs 12/20/12)
	assert_eq(String(ItemDB.get_def("demon_helmet").get("armor_slot", "")), "helmet")
	assert_eq(int(ItemDB.get_def("demon_chest").get("defense", 0)), 22, "恶魔胸甲 22 防")
	assert_eq(int(ItemDB.get_def("demon_pants").get("defense", 0)), 14)


func test_demon_heart_recipe_outputs_heart():
	var r = RecipeDB.get_recipe("demon_heart")
	assert_not_null(r, "恶魔之心该有配方")
	assert_eq(String(r.output_id), "demon_heart", "配方产出恶魔之心")


func test_demon_items_have_inventory_icons():
	for id in _DEMON_ITEMS:
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 该有背包图标" % id)


func test_demon_items_chinese_names():
	var zh = CraftingPanel._ZH_NAMES
	assert_eq(String(zh.get("demon_heart", "")), "恶魔之心")
	assert_eq(String(zh.get("demon_trident", "")), "恶魔三叉戟")
	assert_eq(String(zh.get("demon_wings", "")), "恶魔之翼")
