extends GutTest

# 地狱恶魔领主 (Demon Lord) — T1: 召唤道具 + 神装物品登记 (见 spec 2026-06-12)。
# Boss 本体的 spawn/受伤/掉落测试在 T2 加。
const CraftingPanel = preload("res://scripts/ui/crafting_panel.gd")
const DemonLordScene = preload("res://scenes/entities/demon_lord.tscn")

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


# === T2: Boss 本体 ===

func test_demon_lord_in_boss_and_slimes_groups():
	var boss = DemonLordScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	assert_true(boss.is_in_group("boss"), "在 boss 组 → 顶部血条显示")
	assert_true(boss.is_in_group("slimes"), "在 slimes 组 → 近战/枪能打中")
	assert_eq(boss.boss_display_name(), "地狱恶魔领主")
	assert_gt(boss.max_health, 1000, "Boss 血厚 (>1000)")
	assert_eq(boss.melee_hit_radius(), 16.0, "大体型近战命中半径")


func test_demon_lord_takes_damage():
	var boss = DemonLordScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var hp0: int = boss.current_health
	boss.take_damage(50)
	assert_lt(boss.current_health, hp0, "受伤掉血")


func test_demon_lord_enrages_below_40pct():
	var boss = DemonLordScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	assert_false(boss._is_enraged(), "满血不狂暴")
	boss.current_health = int(boss.max_health * 0.3)
	assert_true(boss._is_enraged(), "血 < 40% → 狂暴")


func test_demon_lord_death_drops_hell_crystal():
	var boss = DemonLordScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	boss.take_damage(9999999)   # 一击致死
	await wait_frames(1)
	# _die 保底掉 3~6 地狱水晶, 无 entities_root 时落到 boss 的父节点 (= 本测试)
	var crystals: int = 0
	for c in get_children():
		if "item_id" in c and String(c.item_id) == "hell_crystal":
			crystals += 1
	assert_gt(crystals, 0, "死亡保底掉地狱水晶")
