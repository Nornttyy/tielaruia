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
	# === 远程武器: 枪 + 子弹 (子弹走直线/快/狠, 区别于弓的抛物线) ===
	# gun_cooldown 射速 / gun_damage 单发伤 / gun_pellets 一次几颗 / gun_spread_deg 散布角 / bullet_speed 弹速
	"pistol":        {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.22, "gun_damage": 9, "bullet_speed": 560},
	"smg":           {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 2, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.08, "gun_damage": 5, "gun_spread_deg": 7.0, "bullet_speed": 600},   # 冲锋枪: 超快/弱/略飘
	"assault_rifle": {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 3, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.14, "gun_damage": 11, "gun_spread_deg": 3.0, "bullet_speed": 700},  # 突击步枪: 快/均衡/微飘
	"shotgun":       {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 3, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.65, "gun_damage": 6, "gun_pellets": 5, "gun_spread_deg": 32.0, "bullet_speed": 520},  # 霰弹枪: 一次5颗扇形/近战狠
	"sniper":        {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.9, "gun_damage": 32, "bullet_speed": 1000},  # 狙击枪: 慢/超狠/弹速超快
	# 特殊枪 (耗子弹, 带新机制): 激光穿透 / 火焰流 / 冰冻减速
	"laser_gun":     {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.3, "gun_damage": 8, "bullet_speed": 900, "gun_pierce": true, "gun_visual": "laser"},  # 激光: 穿透一排怪
	"flamethrower":  {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.05, "gun_damage": 3, "bullet_speed": 260, "gun_spread_deg": 18.0, "gun_pierce": true, "gun_visual": "fire", "bullet_lifetime": 0.28},  # 火焰: 近距连续烧
	"freeze_ray":    {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.4, "gun_damage": 5, "bullet_speed": 480, "gun_visual": "ice", "gun_slow_factor": 0.4, "gun_slow_dur": 2.5},  # 冰冻: 命中减速
	# 魔法枪 (耗魔力 mana_cost, 不耗子弹): 追踪 / 毒
	"arcane_gun":    {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 4, "gun_cooldown": 0.35, "gun_damage": 12, "bullet_speed": 420, "gun_visual": "magic", "gun_homing": 6.0},  # 追踪魔弹: 自动追怪
	"poison_gun":    {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 3, "gun_cooldown": 0.3, "gun_damage": 4, "bullet_speed": 480, "gun_visual": "poison", "gun_dot_dps": 6, "gun_dot_dur": 4.0},  # 毒液: 命中中毒持续掉血
	"lightning_gun": {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 5, "gun_cooldown": 0.4, "gun_damage": 9, "bullet_speed": 700, "gun_visual": "lightning", "gun_chain": 3, "gun_chain_radius": 64.0},  # 闪电链: 电一只跳附近 3 只
	"star_gun":      {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 2, "gun_cooldown": 0.25, "gun_damage": 6, "bullet_speed": 380, "gun_visual": "star", "gun_bounce": 4, "bullet_lifetime": 2.5},  # 星星炮: 撞墙反弹 4 次
	"slime_gun":     {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 3, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 2, "gun_cooldown": 0.3, "gun_damage": 7, "bullet_speed": 320, "gun_visual": "slimeblob", "gun_bounce": 3, "gun_gravity": 500.0, "bullet_lifetime": 2.5},  # 史莱姆枪: 弹跳果冻团
	"frost_gun":     {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 4, "gun_cooldown": 0.35, "gun_damage": 4, "bullet_speed": 360, "gun_visual": "ice", "gun_pellets": 4, "gun_spread_deg": 28.0, "gun_slow_factor": 0.5, "gun_slow_dur": 2.0, "bullet_lifetime": 0.9},  # 冰雪枪: 扇形雪花 + 减速
	"leaf_gun":      {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 3, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 3, "gun_cooldown": 0.3, "gun_damage": 5, "bullet_speed": 420, "gun_visual": "leaf", "gun_pellets": 3, "gun_spread_deg": 22.0, "gun_pierce": true, "bullet_lifetime": 1.2},  # 绿叶枪: 扇形穿透树叶
	# === 第二批枪 (用户加): 高速扫射 / 花式弹道 / 元素异常 ===
	"minigun":       {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.05, "gun_damage": 4, "gun_spread_deg": 6.0, "bullet_speed": 720},  # 加特林: 超快连发, 微飘, 单发弱
	"twin_magic_gun":{"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 3, "gun_cooldown": 0.18, "gun_damage": 8, "bullet_speed": 600, "gun_visual": "magic", "gun_pellets": 2, "gun_spread_deg": 10.0},  # 双管魔枪: 一次 2 发魔弹
	"rocket_gun":    {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 4, "gun_cooldown": 0.7, "gun_damage": 15, "bullet_speed": 340, "gun_visual": "fire", "gun_homing": 8.0, "bullet_lifetime": 3.0},  # 追踪火箭: 自动追怪
	"ricochet_gun":  {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.3, "gun_damage": 7, "bullet_speed": 520, "gun_visual": "star", "gun_bounce": 8, "bullet_lifetime": 3.0},  # 弹跳枪: 撞墙弹 8 次满屏跳
	"tesla_gun":     {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 5, "gun_cooldown": 0.4, "gun_damage": 8, "bullet_speed": 720, "gun_visual": "lightning", "gun_chain": 6, "gun_chain_radius": 95.0},  # 特斯拉: 闪电连锁 6 个
	"cryo_gun":      {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 4, "gun_cooldown": 0.5, "gun_damage": 5, "bullet_speed": 380, "gun_visual": "ice", "gun_pellets": 3, "gun_spread_deg": 22.0, "gun_slow_factor": 0.3, "gun_slow_dur": 3.0, "bullet_lifetime": 1.0},  # 寒冰炮: 扇形 + 大幅冻住
	"venom_gun":     {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 3, "gun_cooldown": 0.3, "gun_damage": 3, "bullet_speed": 480, "gun_visual": "poison", "gun_pierce": true, "gun_dot_dps": 9, "gun_dot_dur": 5.0},  # 剧毒枪: 穿透 + 强中毒
	"railgun":       {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 6, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 1.0, "gun_damage": 30, "bullet_speed": 1400, "gun_visual": "laser", "gun_pierce": true},  # 电磁炮: 穿透一切, 超快超狠
	"bullet":        {"placeable_tile_id": -1, "tool_kind": "",    "tool_tier": 0, "max_stack": 99},
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
	"wood_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 5,  "spell_damage": 8,  "spell_element": "nature"},
	"iron_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 12, "spell_damage": 15, "spell_element": "ice"},
	"hell_staff":    {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 20, "spell_damage": 22, "spell_element": "fire"},
	# 骷髅法杖 (骷髅王几率掉): 不发火球, 而是召唤友方小骷髅帮打 (summons_minion 标记)
	"skull_staff":   {"placeable_tile_id": -1, "tool_kind": "staff",   "tool_tier": 1, "max_stack": 1, "mana_cost": 18, "summons_minion": true},
	# 机制法杖 (spell_kind=="bullet"): 发带机制的魔法弹, 复用枪的 bullet 系统 (gun_* 字段=投射物机制)
	"lightning_staff": {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 8, "spell_damage": 10, "spell_kind": "bullet", "gun_visual": "lightning", "gun_chain": 3, "gun_chain_radius": 64.0, "bullet_speed": 600},  # 闪电: 电链跳怪
	"poison_staff":    {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 6, "spell_damage": 4, "spell_kind": "bullet", "gun_visual": "poison", "gun_dot_dps": 6, "gun_dot_dur": 4.0, "bullet_speed": 480},  # 毒液: 持续掉血
	"multi_staff":     {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 10, "spell_damage": 6, "spell_kind": "bullet", "gun_visual": "magic", "gun_pellets": 3, "gun_spread_deg": 20.0, "bullet_speed": 420},  # 多重: 一次 3 发扇形
	# B 波法杖: 爆炸范围 / 抛物线 / 击飞
	"explosive_staff": {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 14, "spell_damage": 8, "spell_kind": "bullet", "gun_visual": "fire", "gun_explode_radius": 32.0, "gun_explode_dmg": 14, "bullet_speed": 400},  # 爆裂火球: 命中炸一片
	"water_staff":     {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 8, "spell_damage": 6, "spell_kind": "bullet", "gun_visual": "ice", "gun_gravity": 380.0, "gun_explode_radius": 22.0, "gun_explode_dmg": 8, "bullet_speed": 320},  # 水之: 抛物线 + 落地溅水花(visual=ice→splash, 不破方块)
	"wind_staff":      {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 6, "spell_damage": 3, "spell_kind": "bullet", "gun_visual": "wind", "gun_knockback": 460.0, "gun_launch": true, "bullet_speed": 520},  # 狂风: 把怪弹飞
	# C 波法杖 (全新机制, 不发普通弹):
	"heal_staff":  {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "mana_cost": 16, "heal_amount": 35},  # 治疗: 耗魔力给自己回血
	"bird_staff":  {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "mana_cost": 14, "summons_minion": true, "summon_kind": "bird"},  # 雀宝宝: 召唤会飞的小鸟帮打
	"crack_staff": {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 12, "spell_damage": 7, "ground_crack": true},  # 地裂: 地上裂缝持续伤害
	# === 第二批法杖 (用户加): 追踪/穿透 · 冰霜控制 · 华丽大招 · 辅助 ===
	"homing_staff":      {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 8,  "spell_damage": 9,  "spell_kind": "bullet", "gun_visual": "magic", "gun_homing": 7.0, "bullet_speed": 360},  # 追踪魔弹杖: 自动追怪
	"beam_staff":        {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 10, "spell_damage": 12, "spell_kind": "bullet", "gun_visual": "laser", "gun_pierce": true, "bullet_speed": 900},  # 穿透激光杖: 一束穿一排
	"frost_staff":       {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 8,  "spell_damage": 6,  "spell_kind": "bullet", "gun_visual": "ice", "gun_slow_factor": 0.3, "gun_slow_dur": 3.0, "bullet_speed": 420},  # 冰冻减速杖: 真冻住
	"bounce_star_staff": {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 8,  "spell_damage": 7,  "spell_kind": "bullet", "gun_visual": "star", "gun_bounce": 6, "bullet_lifetime": 3.0, "bullet_speed": 500},  # 弹跳星杖: 满屏弹
	"meteor_staff":      {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 18, "spell_damage": 12, "spell_kind": "bullet", "gun_visual": "fire", "gun_explode_radius": 40.0, "gun_explode_dmg": 18, "gun_gravity": 220.0, "bullet_speed": 360},  # 流星雨杖: 砸地大爆炸
	"penta_staff":       {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "damage_mult": 1.0, "mana_cost": 14, "spell_damage": 5,  "spell_kind": "bullet", "gun_visual": "magic", "gun_pellets": 5, "gun_spread_deg": 30.0, "bullet_speed": 460},  # 五重魔弹杖: 一次 5 发扇形
	"greater_heal_staff":{"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "mana_cost": 24, "heal_amount": 70},  # 强化治疗杖: 一口气回 70 血
	"shield_staff":      {"placeable_tile_id": -1, "tool_kind": "staff", "tool_tier": 1, "max_stack": 1, "mana_cost": 20, "shield_sec": 4.0},  # 护盾杖: 4 秒无敌护盾
	# 魔力药水: 喝下 → 立刻 +30 mana (类似食物回血但回魔)
	"mana_potion":   {"placeable_tile_id": -1, "tool_kind": "",        "tool_tier": 0, "max_stack": 16, "mana_refill": 30},
	# 生命药水: 喝下立刻回 50 HP (复用食物回血路径 food_fill; is_potion 标记 = 显示/手感算药水非食物)
	"health_potion": {"placeable_tile_id": -1, "tool_kind": "",        "tool_tier": 0, "max_stack": 16, "food_fill": 50, "is_potion": true},
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
