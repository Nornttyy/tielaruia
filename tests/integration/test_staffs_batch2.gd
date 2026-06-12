# 第二批法杖 (用户加) 上线验收: def / 图标 / 配方 / 中文名 / 对战房列表 + 护盾&强化治疗机制。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const CraftingPanel = preload("res://scripts/ui/crafting_panel.gd")
const PvpModePanel = preload("res://scripts/ui/pvp_mode_panel.gd")

const NEW_STAFFS := [
	"homing_staff", "beam_staff", "frost_staff", "bounce_star_staff",
	"meteor_staff", "penta_staff", "greater_heal_staff", "shield_staff",
]


func test_new_staffs_def_and_icon():
	for id in NEW_STAFFS:
		var def = ItemDB.get_def(id)
		assert_not_null(def, "%s 该在 item_db" % id)
		if def != null:
			assert_eq(def.get("tool_kind", ""), "staff", "%s tool_kind 该是 staff" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 该有游戏内图标" % id)


func test_new_staffs_names_recipes_and_pvp_list():
	var gun_ids := {}
	for pair in PvpModePanel._STAFFS:
		gun_ids[String(pair[0])] = true
	for id in NEW_STAFFS:
		assert_ne(String(CraftingPanel._ZH_NAMES.get(id, id)), id, "%s 该有中文名" % id)
		var r = RecipeDB.get_recipe(id)
		assert_not_null(r, "%s 该有配方" % id)
		if r != null:
			for row in r["pattern"]:
				for mat in row:
					if mat != "":
						assert_not_null(ItemDB.get_def(mat), "%s 配方材料 %s 该是真物品" % [id, mat])
		assert_true(gun_ids.has(id), "%s 该在对战房切武器列表" % id)


# 护盾杖: 施放 → 玩家进入无敌 (借 i-frame)
func test_shield_staff_grants_invuln():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action = player.get_node("PlayerAction")
	var inv = player.get_node("PlayerInventory")
	var hp = player.get_node("PlayerHealth")
	inv.inventory.add("shield_staff", 1)
	inv.set_hotbar_selection(0)
	assert_false(hp.is_invulnerable(), "施放前不无敌")
	action._try_cast_staff()
	assert_true(hp.is_invulnerable(), "施放护盾杖后该无敌 (挡伤害)")
	# 无敌期间受击不掉血
	var before: int = hp.current_health
	hp.take_damage(20, player.global_position + Vector2(40, 0), 0.0)
	assert_eq(hp.current_health, before, "护盾期间不掉血")


# 强化治疗杖: 施放 → 回血 (先扣点血再治)
func test_greater_heal_staff_heals():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action = player.get_node("PlayerAction")
	var inv = player.get_node("PlayerInventory")
	var hp = player.get_node("PlayerHealth")
	inv.inventory.add("greater_heal_staff", 1)
	inv.set_hotbar_selection(0)
	hp.current_health = 20   # 先扣血
	action._try_cast_staff()
	assert_gt(hp.current_health, 20, "强化治疗杖该回血")
