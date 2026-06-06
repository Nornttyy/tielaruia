# 物品定义表 (autoload)。所有 item_id → 属性查询的单一入口。
extends Node

const _DEFS := {
	"dirt":         {"placeable_tile_id": Tiles.DIRT,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"grass":        {"placeable_tile_id": Tiles.GRASS,     "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"stone":        {"placeable_tile_id": Tiles.STONE,     "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"sand":         {"placeable_tile_id": Tiles.SAND,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"cactus":       {"placeable_tile_id": Tiles.CACTUS,    "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"log":          {"placeable_tile_id": Tiles.LOG,       "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"leaves":       {"placeable_tile_id": Tiles.LEAVES,        "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"pine_leaves":  {"placeable_tile_id": Tiles.LEAVES_PINE,   "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"autumn_leaves":{"placeable_tile_id": Tiles.LEAVES_AUTUMN, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"planks":       {"placeable_tile_id": Tiles.PLANKS,    "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"workbench":    {"placeable_tile_id": Tiles.WORKBENCH, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"door":         {"placeable_tile_id": Tiles.DOOR,      "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"wood_sword":   {"placeable_tile_id": -1,              "tool_kind": "sword",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"wood_pickaxe": {"placeable_tile_id": -1,              "tool_kind": "pickaxe", "tool_tier": 1, "max_stack": 1, "damage_mult": 0.5},
	"wood_axe":     {"placeable_tile_id": -1,              "tool_kind": "axe",     "tool_tier": 1, "max_stack": 1, "damage_mult": 0.0},
	"slime_jelly":  {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40},
	"slime_crown":  {"placeable_tile_id": -1,              "tool_kind": "summon",    "tool_tier": 0, "max_stack": 1, "summon_boss": "king_slime"},
	"skull_summon": {"placeable_tile_id": -1,              "tool_kind": "summon",    "tool_tier": 0, "max_stack": 1, "summon_boss": "skeleton_king"},  # 骷髅头骨: 召唤骷髅王
	"slime_ball":   {"placeable_tile_id": -1,              "tool_kind": "slimeball", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0},  # Boss 掉落武器, tier 5 让伤害高于铁剑 (tier 4)
	"bone_sword":   {"placeable_tile_id": -1,              "tool_kind": "sword",     "tool_tier": 7, "max_stack": 1, "damage_mult": 1.3, "sword_style": "sweep"},  # 骷髅王掉落, 阔剑(横扫), 比普通阔剑(1.2)更强
	"apple":        {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
	"stone_sword":   {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"stone_pickaxe": {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1, "damage_mult": 0.5},
	"stone_axe":     {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1, "damage_mult": 0.0},
	"copper_sword":   {"placeable_tile_id": -1,                    "tool_kind": "sword",   "tool_tier": 3, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"copper_pickaxe": {"placeable_tile_id": -1,                    "tool_kind": "pickaxe", "tool_tier": 3, "max_stack": 1, "damage_mult": 0.5},
	"copper_axe":     {"placeable_tile_id": -1,                    "tool_kind": "axe",     "tool_tier": 3, "max_stack": 1, "damage_mult": 0.0},
	"silver_ore":     {"placeable_tile_id": -1,                    "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"silver_sword":   {"placeable_tile_id": -1,                    "tool_kind": "sword",   "tool_tier": 5, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"silver_pickaxe": {"placeable_tile_id": -1,                    "tool_kind": "pickaxe", "tool_tier": 5, "max_stack": 1, "damage_mult": 0.5},
	"silver_axe":     {"placeable_tile_id": -1,                    "tool_kind": "axe",     "tool_tier": 5, "max_stack": 1, "damage_mult": 0.0},
	"slime_torch":   {"placeable_tile_id": Tiles.SLIME_TORCH,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"coal":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_ore":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"copper_ore":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"tin_ore":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"gold_ore":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"diamond":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"hell_crystal":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"torch":         {"placeable_tile_id": Tiles.TORCH,            "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_pickaxe":  {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 4, "max_stack": 1, "damage_mult": 0.5},
	"iron_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 4, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"iron_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 4, "max_stack": 1, "damage_mult": 0.0},
	"gold_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 6, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"gold_pickaxe":  {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 6, "max_stack": 1, "damage_mult": 0.5},
	"gold_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 6, "max_stack": 1, "damage_mult": 0.0},
	"diamond_sword":   {"placeable_tile_id": -1,                   "tool_kind": "sword",   "tool_tier": 7, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"diamond_pickaxe": {"placeable_tile_id": -1,                   "tool_kind": "pickaxe", "tool_tier": 7, "max_stack": 1, "damage_mult": 0.5},
	"diamond_axe":     {"placeable_tile_id": -1,                   "tool_kind": "axe",     "tool_tier": 7, "max_stack": 1, "damage_mult": 0.0},
	"bone":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"spider_eye":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"feather":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"cloud_boots":   {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 1},
	"lens":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"furnace":       {"placeable_tile_id": Tiles.FURNACE,          "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"cooking_pot":   {"placeable_tile_id": Tiles.COOKING_POT,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"iron_ingot":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"copper_ingot":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"tin_ingot":     {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"silver_ingot":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"gold_ingot":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"cooked_meat":   {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 50},
	"raw_meat":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 30},
	# 料理 (在铁锅里做, 吃了回血 + 短时 buff). buff_kind: speed/jump/mining/regen
	"bread":         {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 30, "buff_kind": "speed",  "buff_secs": 60.0},
	"mushroom_soup": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 30, "buff_kind": "regen",  "buff_secs": 30.0},
	"apple_pie":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 45, "buff_kind": "jump",   "buff_secs": 60.0},
	"meat_skewer":   {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 60, "buff_kind": "mining", "buff_secs": 60.0},
	"mushroom_stew": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 65, "buff_kind": "mining", "buff_secs": 60.0},
	"apple_jam":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 35, "buff_kind": "regen",  "buff_secs": 30.0},
	"jelly_pudding": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40, "buff_kind": "jump",   "buff_secs": 60.0},
	# 海鲜 (钓鱼获得, 生吃回血; 都是第3步寿司/刺身的料). 紫菜 food_fill=0 = 纯材料不可吃.
	"salmon":        {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
	"tuna":          {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 28},
	"octopus":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 22},
	"sea_urchin":    {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 20},
	"lobster":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 38},
	"eel":           {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 26},
	"sweet_shrimp":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 15},
	"scallop":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 18},
	"seaweed":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
	"grilled_fish":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 45, "buff_kind": "speed", "buff_secs": 60.0},
	# 蘑菇: 可吃 (+30 饥饿), 可放回 (玩家也能种回小室). 矿洞蘑菇地掉
	"mushroom":      {"placeable_tile_id": Tiles.MUSHROOM,         "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 30},
	# === 地狱 Phase 1 ===
	"hell_stone":    {"placeable_tile_id": Tiles.HELL_STONE,       "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"obsidian":      {"placeable_tile_id": Tiles.OBSIDIAN,         "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"hell_fruit":    {"placeable_tile_id": Tiles.HELL_FRUIT,       "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 40},
	# === 远程武器: 弓 + 箭 ===
	"wood_bow":      {"placeable_tile_id": -1,                     "tool_kind": "bow",     "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0},
	"wood_arrow":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	# === 地狱矿石 ===
	"hell_crystal_ingot": {"placeable_tile_id": -1,                "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"hell_alloy_ore":     {"placeable_tile_id": Tiles.HELL_ALLOY_ORE, "tool_kind": "",     "tool_tier": 0, "max_stack": 99},
	"sandstone":          {"placeable_tile_id": Tiles.SANDSTONE,     "tool_kind": "",     "tool_tier": 0, "max_stack": 99},
	"cloud":              {"placeable_tile_id": Tiles.CLOUD,         "tool_kind": "",     "tool_tier": 0, "max_stack": 99},
	"hell_alloy_ingot":   {"placeable_tile_id": -1,                "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	# === 盔甲 (Phase 6): 3 槽位 (helmet/chest/pants) × 5 tier (copper/iron/silver/gold/diamond) ===
	# 1 防御 = 0.5 减伤 (减伤后下限 1). hover 显示防御值.
	"copper_helmet":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 4},
	"copper_chest":   {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 6},
	"copper_pants":   {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 4},
	"iron_helmet":    {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 6},
	"iron_chest":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 10},
	"iron_pants":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 6},
	"silver_helmet":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 8},
	"silver_chest":   {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 14},
	"silver_pants":   {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 8},
	"gold_helmet":    {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 10},
	"gold_chest":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 18},
	"gold_pants":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 10},
	"diamond_helmet": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 14},
	"diamond_chest":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 24},
	"diamond_pants":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 14},
	# 骷髅盔甲 (骷髅王几率掉, 金钻之间强力套装): 头12/胸20/腿12 = 总44
	"skeleton_helmet": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "helmet", "defense": 12},
	"skeleton_chest":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "chest",  "defense": 20},
	"skeleton_pants":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 1, "armor_slot": "pants",  "defense": 12},
	# === 地狱武器 (tier 8): 用 hell_alloy_ingot + hell_crystal_ingot 合 ===
	"hell_sword":    {"placeable_tile_id": -1, "tool_kind": "sword",   "tool_tier": 8, "max_stack": 1, "damage_mult": 1.2, "sword_style": "sweep"},
	"hell_pickaxe":  {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 8, "max_stack": 1, "damage_mult": 0.5},
	"hell_axe":      {"placeable_tile_id": -1, "tool_kind": "axe",     "tool_tier": 8, "max_stack": 1, "damage_mult": 0.0},
	# === 短剑 (dagger): 戳·快·伤害小(0.8). 跟同名阔剑(<mat>_sword)成对, tier 一致 ===
	"wood_dagger":    {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 1, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"stone_dagger":   {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 2, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"copper_dagger":  {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 3, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"iron_dagger":    {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 4, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"silver_dagger":  {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 5, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"gold_dagger":    {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 6, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"diamond_dagger": {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 7, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	"hell_dagger":    {"placeable_tile_id": -1, "tool_kind": "sword", "tool_tier": 8, "max_stack": 1, "damage_mult": 0.8, "sword_style": "thrust"},
	# === 法杖 (Phase 7): 持杖 LMB → 消耗 mana 发火球 ===
	# 法杖 3 tier (起步早): wood = 学徒, iron = 中期, hell = 末期
	"wood_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 5,  "spell_damage": 8},
	"iron_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 12, "spell_damage": 15},
	"hell_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 20, "spell_damage": 22},
	# 骷髅法杖 (骷髅王几率掉): 不发火球, 而是召唤友方小骷髅帮打 (summons_minion 标记)
	"skull_staff":   {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "mana_cost": 18, "summons_minion": true},
	# 魔力药水: 喝下 → 立刻 +30 mana (类似食物回血但回魔)
	"mana_potion":   {"placeable_tile_id": -1, "tool_kind": "",        "tool_tier": 0, "max_stack": 16, "mana_refill": 30},
	"leather":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"wool":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"grappling_hook":{"placeable_tile_id": -1,                     "tool_kind": "hook",    "tool_tier": 1, "max_stack": 1},
	"fishing_rod":   {"placeable_tile_id": -1,                     "tool_kind": "fishing", "tool_tier": 1, "max_stack": 1},
	"kitchen_knife": {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"cutting_board": {"placeable_tile_id": Tiles.CUTTING_BOARD,    "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"rice":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"rice_seed":     {"placeable_tile_id": -1,                     "tool_kind": "seed",    "tool_tier": 0, "max_stack": 99},
	"cooked_rice":   {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 25},
	"fish_slice":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 18},
	# 寿司 + 刺身 (菜板做, 吃了回血 + buff). 海鲜全是第 2 步钓来的.
	"sushi":         {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 70, "buff_kind": "speed",  "buff_secs": 60.0},
	"sashimi":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 50, "buff_kind": "regen",  "buff_secs": 30.0},
	"onigiri":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 35},
	"shrimp_sushi":  {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 45, "buff_kind": "speed",  "buff_secs": 60.0},
	"uni_gunkan":    {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 55, "buff_kind": "mining", "buff_secs": 60.0},
	"chest":         {"placeable_tile_id": Tiles.CHEST,            "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"bed":           {"placeable_tile_id": Tiles.BED,              "tool_kind": "",        "tool_tier": 0, "max_stack": 1},
	# === 菜园 v1 ===
	# 小麦种子: 右键 GRASS 上才能种 (player_action 专门处理). placeable -1 = 不走通用放置.
	"wheat_seed":    {"placeable_tile_id": -1,                     "tool_kind": "seed",    "tool_tier": 0, "max_stack": 99},
	# 小麦: 食物, 吃了回 5 HP
	"wheat":         {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 20},
	# 新群系 (雪原 / 丛林 / 沼泽) 方块物品
	"snow":          {"placeable_tile_id": Tiles.SNOW,             "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"ice":           {"placeable_tile_id": Tiles.ICE,              "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"jungle_grass":  {"placeable_tile_id": Tiles.JUNGLE_GRASS,     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"mud":           {"placeable_tile_id": Tiles.MUD,              "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"swamp_grass":   {"placeable_tile_id": Tiles.SWAMP_GRASS,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	# 平台 + 墙. is_wall=true 时 try_place 放到 wall_layer 而不是 terrain_layer.
	"wood_platform": {"placeable_tile_id": Tiles.WOOD_PLATFORM,    "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"wood_wall":     {"placeable_tile_id": Tiles.WOOD_WALL,        "tool_kind": "",        "tool_tier": 0, "max_stack": 99, "is_wall": true},
	"stone_wall":    {"placeable_tile_id": Tiles.STONE_WALL,       "tool_kind": "",        "tool_tier": 0, "max_stack": 99, "is_wall": true},
	"dirt_wall":     {"placeable_tile_id": Tiles.DIRT_WALL,        "tool_kind": "",        "tool_tier": 0, "max_stack": 99, "is_wall": true},
	"grass_wall":    {"placeable_tile_id": Tiles.GRASS_WALL,       "tool_kind": "",        "tool_tier": 0, "max_stack": 99, "is_wall": true},
	# === 锤子 (8 tier): 破坏背景墙 (不挖方块). tier 越高砸墙越快. damage_mult 0 = 不当武器. ===
	"wood_hammer":    {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 1, "max_stack": 1, "damage_mult": 0.0},
	"stone_hammer":   {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 2, "max_stack": 1, "damage_mult": 0.0},
	"copper_hammer":  {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 3, "max_stack": 1, "damage_mult": 0.0},
	"iron_hammer":    {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 4, "max_stack": 1, "damage_mult": 0.0},
	"silver_hammer":  {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 5, "max_stack": 1, "damage_mult": 0.0},
	"gold_hammer":    {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 6, "max_stack": 1, "damage_mult": 0.0},
	"diamond_hammer": {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 7, "max_stack": 1, "damage_mult": 0.0},
	"hell_hammer":    {"placeable_tile_id": -1, "tool_kind": "hammer", "tool_tier": 8, "max_stack": 1, "damage_mult": 0.0},
	"rope":          {"placeable_tile_id": Tiles.ROPE,             "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"jungle_dirt":   {"placeable_tile_id": Tiles.JUNGLE_DIRT,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"snow_dirt":     {"placeable_tile_id": Tiles.SNOW_DIRT,        "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"jungle_leaves": {"placeable_tile_id": Tiles.JUNGLE_LEAVES,    "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
}


func get_def(item_id: String) -> Variant:
	return _DEFS.get(item_id, null)


# 全部物品 id (创造模式"物品大全"用)
func all_item_ids() -> Array:
	return _DEFS.keys()


func is_placeable(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.placeable_tile_id != -1


func max_stack(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.max_stack


# 剑的攻击方式: "thrust"(短剑·戳) / "sweep"(阔剑·扫) / ""(非剑或没标).
# 攻击逻辑按这个选戳还是扫, 不再按 tier.
func sword_style(item_id: String) -> String:
	var def = get_def(item_id)
	return "" if def == null else def.get("sword_style", "")


func is_food(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.get("food_fill", 0) > 0


func food_fill(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.get("food_fill", 0)


# === 料理 buff helper ===
# 料理吃下后给的临时增益类型: "speed"/"jump"/"mining"/"regen", 无 buff 返回 "".
func food_buff_kind(item_id: String) -> String:
	var def = get_def(item_id)
	return "" if def == null else def.get("buff_kind", "")


# 该 buff 持续秒数. 无 buff 返回 0.
func food_buff_secs(item_id: String) -> float:
	var def = get_def(item_id)
	return 0.0 if def == null else def.get("buff_secs", 0.0)


func food_has_buff(item_id: String) -> bool:
	return food_buff_kind(item_id) != ""


# 是否墙类物品 (放进 wall_layer, 不阻挡走路, 但能给方块"支撑"靠它)
func is_wall(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.get("is_wall", false)


# === 盔甲 helper ===
# 返回 "" / "helmet" / "chest" / "pants" — 物品的装备槽; "" 表示不是盔甲
func armor_slot(item_id: String) -> String:
	var def = get_def(item_id)
	return "" if def == null else def.get("armor_slot", "")


# 该物品的防御值 (1 防御 = 0.5 减伤). 非盔甲返 0.
func defense(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.get("defense", 0)


# 魔力药水: 喝下回复 mana_refill mana. 非药水返 0.
func mana_refill(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.get("mana_refill", 0)


func is_mana_potion(item_id: String) -> bool:
	return mana_refill(item_id) > 0


# 召唤道具: 使用后触发 Boss 召唤 (如史莱姆王冠)
func is_summon(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.get("tool_kind", "") == "summon"
