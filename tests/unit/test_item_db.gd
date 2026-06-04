extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
var db


func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)


func test_unknown_item_returns_null():
	assert_null(db.get_def("nonexistent"))


func test_dirt_is_placeable():
	var def = db.get_def("dirt")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, Tiles.DIRT)
	assert_eq(def.max_stack, 64)


func test_stone_placeable():
	var def = db.get_def("stone")
	assert_eq(def.placeable_tile_id, Tiles.STONE)


func test_wood_pickaxe_is_tool_not_placeable():
	var def = db.get_def("wood_pickaxe")
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.tool_kind, "pickaxe")
	assert_eq(def.tool_tier, 1)
	assert_eq(def.max_stack, 1)


func test_all_known_items_present():
	for item_id in ["dirt", "grass", "stone", "sand", "log", "leaves",
			"planks", "workbench", "door",
			"wood_sword", "wood_pickaxe", "wood_axe", "slime_jelly", "apple",
			"stone_sword", "stone_pickaxe", "stone_axe", "slime_torch"]:
		assert_not_null(db.get_def(item_id), "缺失 item: %s" % item_id)


func test_is_placeable():
	assert_true(db.is_placeable("dirt"))
	assert_false(db.is_placeable("wood_pickaxe"))
	assert_false(db.is_placeable("unknown"))


func test_stick_removed():
	# Terraria 风格: 没有 stick 中间品
	assert_null(db.get_def("stick"), "stick 已删除")


func test_torch_item():
	var def = db.get_def("torch")
	assert_not_null(def, "torch item 应存在")
	assert_eq(def.placeable_tile_id, Tiles.TORCH)
	assert_eq(def.max_stack, 99)
	assert_true(db.is_placeable("torch"))


func test_coal_item():
	var def = db.get_def("coal")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)
	assert_false(db.is_placeable("coal"))


func test_iron_ore_item():
	var def = db.get_def("iron_ore")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)


func test_iron_pickaxe_item():
	var def = db.get_def("iron_pickaxe")
	assert_not_null(def)
	assert_eq(def.tool_kind, "pickaxe")
	# tier 1-7 progressive: wood/stone/copper/iron/silver/gold/diamond
	assert_eq(def.tool_tier, 4)
	assert_eq(def.max_stack, 1)


# === 剑分家: 8 短剑(dagger) + 8 阔剑(sword) ===
const _SWORD_MATS := ["wood", "stone", "copper", "iron", "silver", "gold", "diamond", "hell"]
const _SWORD_TIERS := {"wood": 1, "stone": 2, "copper": 3, "iron": 4, "silver": 5, "gold": 6, "diamond": 7, "hell": 8}


func test_8_daggers_exist():
	for mat in _SWORD_MATS:
		var def = db.get_def(mat + "_dagger")
		assert_not_null(def, "短剑应存在: %s_dagger" % mat)
		assert_eq(def.tool_kind, "sword", "%s_dagger 是 sword 类" % mat)
		assert_eq(def.tool_tier, _SWORD_TIERS[mat], "%s_dagger tier" % mat)
		assert_eq(def.max_stack, 1, "%s_dagger 不可叠" % mat)


func test_sword_style_dagger_is_thrust_sword_is_sweep():
	# 短剑永远戳, 阔剑永远扫 (不再按 tier)
	assert_eq(db.sword_style("wood_dagger"), "thrust", "短剑=戳")
	assert_eq(db.sword_style("hell_dagger"), "thrust", "高级短剑也戳")
	assert_eq(db.sword_style("wood_sword"), "sweep", "阔剑=扫")
	assert_eq(db.sword_style("diamond_sword"), "sweep", "高级阔剑也扫")
	# 非剑 / 未知 → 空字符串 (兜底不崩)
	assert_eq(db.sword_style("dirt"), "", "非剑返回空")
	assert_eq(db.sword_style("nonexistent"), "", "未知返回空")


func test_dagger_weaker_broadsword_stronger():
	# 短剑伤害小 (0.8), 阔剑伤害大 (1.2)
	assert_almost_eq(float(db.get_def("iron_dagger").damage_mult), 0.8, 0.001, "短剑 0.8")
	assert_almost_eq(float(db.get_def("iron_sword").damage_mult), 1.2, 0.001, "阔剑 1.2")


# 骨剑 (骷髅王掉落, 阔剑·强) + 有游戏内图标
func test_bone_sword_is_strong_broadsword():
	var def = db.get_def("bone_sword")
	assert_not_null(def, "骨剑应存在")
	assert_eq(def.tool_kind, "sword", "骨剑是剑")
	assert_eq(db.sword_style("bone_sword"), "sweep", "骨剑是阔剑(横扫)")
	assert_almost_eq(float(def.damage_mult), 1.3, 0.001, "骨剑比普通阔剑(1.2)更强")
	assert_eq(def.max_stack, 1, "骨剑不可叠")
	assert_not_null(ArtCache.get_inventory_icon("bone_sword"), "骨剑应有游戏内图标")


# 骷髅头骨 (召唤骷髅王的召唤道具)
func test_skull_summon_is_summon_for_skeleton_king():
	var def = db.get_def("skull_summon")
	assert_not_null(def, "骷髅头骨应存在")
	assert_true(db.is_summon("skull_summon"), "骷髅头骨是召唤道具")
	assert_eq(def.get("summon_boss", ""), "skeleton_king", "召唤的是骷髅王")
	assert_not_null(ArtCache.get_inventory_icon("skull_summon"), "骷髅头骨应有图标")


# 骷髅盔甲 3 件 (骷髅王几率掉): 槽位 + 防御 + 图标
func test_skeleton_armor_set() -> void:
	var pieces := {"skeleton_helmet": "helmet", "skeleton_chest": "chest", "skeleton_pants": "pants"}
	for id in pieces:
		var def = db.get_def(id)
		assert_not_null(def, "%s 应存在" % id)
		if def != null:
			assert_eq(def.get("armor_slot", ""), pieces[id], "%s 槽位应是 %s" % [id, pieces[id]])
			assert_gt(int(def.get("defense", 0)), 0, "%s 该有防御" % id)
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 该有游戏内图标" % id)
