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
	"wood_sword":   {"placeable_tile_id": -1,              "tool_kind": "sword",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0},
	"wood_pickaxe": {"placeable_tile_id": -1,              "tool_kind": "pickaxe", "tool_tier": 1, "max_stack": 1, "damage_mult": 0.5},
	"wood_axe":     {"placeable_tile_id": -1,              "tool_kind": "axe",     "tool_tier": 1, "max_stack": 1, "damage_mult": 0.0},
	"slime_jelly":  {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40},
	"apple":        {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
	"stone_sword":   {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1, "damage_mult": 1.0},
	"stone_pickaxe": {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1, "damage_mult": 0.5},
	"stone_axe":     {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1, "damage_mult": 0.0},
	"copper_sword":   {"placeable_tile_id": -1,                    "tool_kind": "sword",   "tool_tier": 3, "max_stack": 1, "damage_mult": 1.0},
	"copper_pickaxe": {"placeable_tile_id": -1,                    "tool_kind": "pickaxe", "tool_tier": 3, "max_stack": 1, "damage_mult": 0.5},
	"copper_axe":     {"placeable_tile_id": -1,                    "tool_kind": "axe",     "tool_tier": 3, "max_stack": 1, "damage_mult": 0.0},
	"silver_ore":     {"placeable_tile_id": -1,                    "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"silver_sword":   {"placeable_tile_id": -1,                    "tool_kind": "sword",   "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0},
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
	"iron_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0},
	"iron_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 4, "max_stack": 1, "damage_mult": 0.0},
	"gold_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 6, "max_stack": 1, "damage_mult": 1.0},
	"gold_pickaxe":  {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 6, "max_stack": 1, "damage_mult": 0.5},
	"gold_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 6, "max_stack": 1, "damage_mult": 0.0},
	"diamond_sword":   {"placeable_tile_id": -1,                   "tool_kind": "sword",   "tool_tier": 7, "max_stack": 1, "damage_mult": 1.0},
	"diamond_pickaxe": {"placeable_tile_id": -1,                   "tool_kind": "pickaxe", "tool_tier": 7, "max_stack": 1, "damage_mult": 0.5},
	"diamond_axe":     {"placeable_tile_id": -1,                   "tool_kind": "axe",     "tool_tier": 7, "max_stack": 1, "damage_mult": 0.0},
	"bone":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"spider_eye":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"lens":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"furnace":       {"placeable_tile_id": Tiles.FURNACE,          "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"iron_ingot":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"copper_ingot":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"tin_ingot":     {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"silver_ingot":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"gold_ingot":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"cooked_meat":   {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 50},
	"raw_meat":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 30},
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
	# === 地狱武器 (tier 8): 用 hell_alloy_ingot + hell_crystal_ingot 合 ===
	"hell_sword":    {"placeable_tile_id": -1, "tool_kind": "sword",   "tool_tier": 8, "max_stack": 1, "damage_mult": 1.0},
	"hell_pickaxe":  {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 8, "max_stack": 1, "damage_mult": 0.5},
	"hell_axe":      {"placeable_tile_id": -1, "tool_kind": "axe",     "tool_tier": 8, "max_stack": 1, "damage_mult": 0.0},
	# === 法杖 (Phase 7): 持杖 LMB → 消耗 mana 发火球 ===
	# 法杖 3 tier (起步早): wood = 学徒, iron = 中期, hell = 末期
	"wood_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 5,  "spell_damage": 8},
	"iron_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 12, "spell_damage": 15},
	"hell_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 20, "spell_damage": 22},
	# 魔力药水: 喝下 → 立刻 +30 mana (类似食物回血但回魔)
	"mana_potion":   {"placeable_tile_id": -1, "tool_kind": "",        "tool_tier": 0, "max_stack": 16, "mana_refill": 30},
	"leather":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"wool":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"grappling_hook":{"placeable_tile_id": -1,                     "tool_kind": "hook",    "tool_tier": 1, "max_stack": 1},
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
	"rope":          {"placeable_tile_id": Tiles.ROPE,             "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"jungle_dirt":   {"placeable_tile_id": Tiles.JUNGLE_DIRT,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"snow_dirt":     {"placeable_tile_id": Tiles.SNOW_DIRT,        "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"jungle_leaves": {"placeable_tile_id": Tiles.JUNGLE_LEAVES,    "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
}


func get_def(item_id: String) -> Variant:
	return _DEFS.get(item_id, null)


func is_placeable(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.placeable_tile_id != -1


func max_stack(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.max_stack


func is_food(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.get("food_fill", 0) > 0


func food_fill(item_id: String) -> int:
	var def = get_def(item_id)
	return 0 if def == null else def.get("food_fill", 0)


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
