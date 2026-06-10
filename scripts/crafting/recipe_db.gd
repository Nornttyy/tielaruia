# 10 个 Demo 配方。pattern[row][col] = item_id 或 "" (空)。
# grid_size 表 pattern 的形状 (Vector2i(cols, rows))。
# RecipeMatcher 负责把 pattern 平移/镜像后对位匹配玩家的 craft grid。
extends Node

# 每个 recipe 字典：
#   id: String
#   grid_size: Vector2i(cols, rows)
#   pattern: Array[Array[String]]   # rows × cols
#   output_id: String
#   output_count: int
#   mirror_ok: bool
const _RECIPES := [
	# === 2×2 (徒手) ===
	{
		"id": "planks",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["log", ""],
			["",    ""],
		],
		"output_id": "planks",
		"output_count": 4,
		"mirror_ok": true,
	},
	{
		"id": "workbench",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["planks", "planks"],
			["planks", "planks"],
		],
		"output_id": "workbench",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "slime_torch",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["slime_jelly", ""],
			["planks",      ""],
		],
		"output_id": "slime_torch",
		"output_count": 3,
		"mirror_ok": true,
	},
	# === 3×3 (工作台) ===
	{
		"id": "door",
		"grid_size": Vector2i(2, 3),
		"pattern": [
			["planks", "planks"],
			["planks", "planks"],
			["planks", "planks"],
		],
		"output_id": "door",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "planks", ""],
			["", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "wood_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["planks", "planks", "planks"],
			["",       "planks", ""],
			["",       "planks", ""],
		],
		"output_id": "wood_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "wood_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["planks", "planks", ""],
			["planks", "planks", ""],
			["",       "planks", ""],
		],
		"output_id": "wood_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "stone",  ""],
			["", "stone",  ""],
			["", "planks", ""],
		],
		"output_id": "stone_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["stone", "stone",  "stone"],
			["",      "planks", ""],
			["",      "planks", ""],
		],
		"output_id": "stone_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "stone_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["stone", "stone",  ""],
			["stone", "planks", ""],
			["",      "planks", ""],
		],
		"output_id": "stone_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 火把 (1x2 徒手) ===
	{
		"id": "torch",
		"grid_size": Vector2i(1, 2),
		"pattern": [
			["coal"],
			["log"],
		],
		"output_id": "torch",
		"output_count": 4,
		"mirror_ok": false,
	},
	# === 铁工具 (3x3 工作台, tier 3) ===
	{
		"id": "iron_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "iron_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "iron_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "iron_ingot", ""],
			["", "iron_ingot", ""],
			["", "planks", ""],
		],
		"output_id": "iron_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "iron_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "iron_ingot", ""],
			["iron_ingot", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "iron_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 铜工具 (tier 3, 跟铁同形状但用 copper_ingot) ===
	{
		"id": "copper_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["copper_ingot", "copper_ingot", "copper_ingot"],
			["", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "copper_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "copper_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "copper_ingot", ""],
			["", "copper_ingot", ""],
			["", "planks", ""],
		],
		"output_id": "copper_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "copper_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["copper_ingot", "copper_ingot", ""],
			["copper_ingot", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "copper_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 银工具 (tier 5, 同形状用 silver_ingot) ===
	{
		"id": "silver_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["silver_ingot", "silver_ingot", "silver_ingot"],
			["", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "silver_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "silver_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "silver_ingot", ""],
			["", "silver_ingot", ""],
			["", "planks", ""],
		],
		"output_id": "silver_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "silver_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["silver_ingot", "silver_ingot", ""],
			["silver_ingot", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "silver_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 床 (3 planks 底 + 3 wool 顶, 横放) ===
	{
		"id": "bed",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["",     "",     ""],
			["wool", "wool", "wool"],
			["planks", "planks", "planks"],
		],
		"output_id": "bed",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 箱子 (8 个 planks 围一圈, 中空) ===
	{
		"id": "chest",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["planks", "planks", "planks"],
			["planks", "",       "planks"],
			["planks", "planks", "planks"],
		],
		"output_id": "chest",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 钩爪 (用铁锭做钩头 + 木板做柄 + leather 当绳子) ===
	{
		"id": "grappling_hook",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "iron_ingot", ""],
			["", "iron_ingot", ""],
			["leather", "", ""],
		],
		"output_id": "grappling_hook",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 金工具 (tier 6, 用 gold_ingot + planks) ===
	{
		"id": "gold_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "gold_ingot", ""],
			["", "gold_ingot", ""],
			["", "planks", ""],
		],
		"output_id": "gold_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "gold_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["gold_ingot", "gold_ingot", "gold_ingot"],
			["", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "gold_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "gold_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["gold_ingot", "gold_ingot", ""],
			["gold_ingot", "planks", ""],
			["", "planks", ""],
		],
		"output_id": "gold_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 钻石工具 (tier 5, 终局; 用 diamond + planks) ===
	{
		"id": "diamond_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "diamond", ""],
			["", "diamond", ""],
			["", "planks",  ""],
		],
		"output_id": "diamond_sword",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 短剑(dagger): 比对应阔剑省 1 格 (短刀身). 材料在上, 柄在下, 2 格高. ===
	{
		"id": "wood_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "planks", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "wood_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "stone_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "stone", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "stone_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "copper_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "copper_ingot", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "copper_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "iron_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "iron_ingot", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "iron_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "silver_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "silver_ingot", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "silver_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "gold_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "gold_ingot", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "gold_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "diamond_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "diamond", ""], ["", "planks", ""], ["", "", ""]],
		"output_id": "diamond_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "hell_dagger", "grid_size": Vector2i(3, 3),
		"pattern": [["", "hell_alloy_ingot", ""], ["", "hell_crystal_ingot", ""], ["", "", ""]],
		"output_id": "hell_dagger", "output_count": 1, "mirror_ok": true,
	},
	{
		# 骷髅头骨 (召唤骷髅王): 8 个骨头围成头骨形 (空心)
		"id": "skull_summon", "grid_size": Vector2i(3, 3),
		"pattern": [["bone", "bone", "bone"], ["bone", "", "bone"], ["bone", "bone", "bone"]],
		"output_id": "skull_summon", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "diamond_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["diamond", "diamond", "diamond"],
			["",        "planks",  ""],
			["",        "planks",  ""],
		],
		"output_id": "diamond_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
	{
		"id": "diamond_axe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["diamond", "diamond", ""],
			["diamond", "planks",  ""],
			["",        "planks",  ""],
		],
		"output_id": "diamond_axe",
		"output_count": 1,
		"mirror_ok": true,
	},
	# === 史莱姆王冠 (9 史莱姆胶满格, 工作台) ===
	{
		"id": "slime_crown",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["slime_jelly", "slime_jelly", "slime_jelly"],
			["slime_jelly", "slime_jelly", "slime_jelly"],
			["slime_jelly", "slime_jelly", "slime_jelly"],
		],
		"output_id": "slime_crown",
		"output_count": 1,
		"requires": "workbench",
		"mirror_ok": true,
	},
	# 云靴: 2 云块 + 2 羽毛 → 二段跳鞋 (要工作台). 羽毛打哈比鸟掉, 云块挖空岛.
	{
		"id": "cloud_boots",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["cloud", "cloud"],
			["feather", "feather"],
		],
		"output_id": "cloud_boots",
		"output_count": 1,
		"requires": "workbench",
		"mirror_ok": true,
	},
	# === 平台 + 墙 ===
	# 木平台: 2 planks 横排 → 4 个平台
	{
		"id": "wood_platform",
		"grid_size": Vector2i(2, 1),
		"pattern": [
			["planks", "planks"],
		],
		"output_id": "wood_platform",
		"output_count": 4,
		"mirror_ok": true,
	},
	# 木墙: 1 planks → 4 木墙
	{
		"id": "wood_wall",
		"grid_size": Vector2i(1, 1),
		"pattern": [
			["planks"],
		],
		"output_id": "wood_wall",
		"output_count": 4,
		"mirror_ok": true,
	},
	# 石墙: 1 stone → 4 石墙
	{
		"id": "stone_wall",
		"grid_size": Vector2i(1, 1),
		"pattern": [
			["stone"],
		],
		"output_id": "stone_wall",
		"output_count": 4,
		"mirror_ok": true,
	},
	# 绳子: 1 leather → 6 rope
	{
		"id": "rope",
		"grid_size": Vector2i(1, 1),
		"pattern": [
			["leather"],
		],
		"output_id": "rope",
		"output_count": 6,
		"mirror_ok": true,
	},
	# === 熔炉 (用 8 石头围 □ 形) ===
	{
		"id": "furnace",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["stone", "stone", "stone"],
			["stone", "",      "stone"],
			["stone", "stone", "stone"],
		],
		"output_id": "furnace",
		"output_count": 1,
		"mirror_ok": true,
	},
	# 铁锅 (做饭工作站): 5 铁锭 U 形, 熔炉炼. 放下后只能叠在炉子上.
	{
		"id": "cooking_pot",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "",           "iron_ingot"],
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["",           "",           ""],
		],
		"output_id": "cooking_pot",
		"output_count": 1,
		"mirror_ok": true,
		"requires": "furnace",
	},
	# === 冶炼 (要求附近有 furnace) ===
	# 3 个矿石横排 → 1 个对应锭. mirror_ok 让横/竖都能匹配
	{
		"id": "iron_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["iron_ore", "iron_ore", "iron_ore"]],
		"output_id": "iron_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	{
		"id": "copper_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["copper_ore", "copper_ore", "copper_ore"]],
		"output_id": "copper_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	{
		"id": "tin_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["tin_ore", "tin_ore", "tin_ore"]],
		"output_id": "tin_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	{
		"id": "silver_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["silver_ore", "silver_ore", "silver_ore"]],
		"output_id": "silver_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	{
		"id": "gold_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["gold_ore", "gold_ore", "gold_ore"]],
		"output_id": "gold_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	# 熟肉: 1 raw_meat 在 2x2 任意角
	{
		"id": "cooked_meat",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["raw_meat", ""],
			["",         ""],
		],
		"output_id": "cooked_meat",
		"output_count": 1,
		"mirror_ok": true,
		"requires": "pot",
	},
	# === 料理 (都在铁锅做, requires "pot") ===
	{ "id": "bread", "grid_size": Vector2i(3, 1),
	  "pattern": [["wheat", "wheat", "wheat"]],
	  "output_id": "bread", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "mushroom_soup", "grid_size": Vector2i(2, 1),
	  "pattern": [["mushroom", "mushroom"]],
	  "output_id": "mushroom_soup", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "apple_pie", "grid_size": Vector2i(3, 1),
	  "pattern": [["apple", "apple", "wheat"]],
	  "output_id": "apple_pie", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "meat_skewer", "grid_size": Vector2i(3, 1),
	  "pattern": [["raw_meat", "raw_meat", "mushroom"]],
	  "output_id": "meat_skewer", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "mushroom_stew", "grid_size": Vector2i(3, 1),
	  "pattern": [["mushroom", "raw_meat", "mushroom"]],
	  "output_id": "mushroom_stew", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "apple_jam", "grid_size": Vector2i(3, 1),
	  "pattern": [["apple", "apple", "apple"]],
	  "output_id": "apple_jam", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	{ "id": "jelly_pudding", "grid_size": Vector2i(3, 1),
	  "pattern": [["slime_jelly", "slime_jelly", "apple"]],
	  "output_id": "jelly_pudding", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	# 烤鱼: 任意一种鱼(三文鱼/金枪鱼/鳗鱼) → 烤鱼, 锅里做
	{ "id": "grilled_fish_salmon", "grid_size": Vector2i(1, 1),
	  "pattern": [["salmon"]],
	  "output_id": "grilled_fish", "output_count": 1, "mirror_ok": true, "requires": "pot" },
	{ "id": "grilled_fish_tuna", "grid_size": Vector2i(1, 1),
	  "pattern": [["tuna"]],
	  "output_id": "grilled_fish", "output_count": 1, "mirror_ok": true, "requires": "pot" },
	{ "id": "grilled_fish_eel", "grid_size": Vector2i(1, 1),
	  "pattern": [["eel"]],
	  "output_id": "grilled_fish", "output_count": 1, "mirror_ok": true, "requires": "pot" },
	# 米饭: 2 米 → 米饭 (锅里煮)
	{ "id": "cooked_rice", "grid_size": Vector2i(2, 1),
	  "pattern": [["rice", "rice"]],
	  "output_id": "cooked_rice", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "pot" },
	# 鱼片: 三文鱼/金枪鱼/鳗鱼 → 鱼片 (菜板上切)
	{ "id": "fish_slice_salmon", "grid_size": Vector2i(1, 1),
	  "pattern": [["salmon"]],
	  "output_id": "fish_slice", "output_count": 1, "mirror_ok": true, "requires": "board" },
	{ "id": "fish_slice_tuna", "grid_size": Vector2i(1, 1),
	  "pattern": [["tuna"]],
	  "output_id": "fish_slice", "output_count": 1, "mirror_ok": true, "requires": "board" },
	{ "id": "fish_slice_eel", "grid_size": Vector2i(1, 1),
	  "pattern": [["eel"]],
	  "output_id": "fish_slice", "output_count": 1, "mirror_ok": true, "requires": "board" },
	# 章鱼/龙虾/扇贝 也能在菜板切成鱼片 (之前钓上来没用, 约 1/3 鱼获白钓)
	{ "id": "fish_slice_octopus", "grid_size": Vector2i(1, 1),
	  "pattern": [["octopus"]],
	  "output_id": "fish_slice", "output_count": 1, "mirror_ok": true, "requires": "board" },
	{ "id": "fish_slice_lobster", "grid_size": Vector2i(1, 1),
	  "pattern": [["lobster"]],
	  "output_id": "fish_slice", "output_count": 2, "mirror_ok": true, "requires": "board" },
	{ "id": "fish_slice_scallop", "grid_size": Vector2i(1, 1),
	  "pattern": [["scallop"]],
	  "output_id": "fish_slice", "output_count": 1, "mirror_ok": true, "requires": "board" },
	# 寿司 + 刺身 (都在菜板做, requires "board")
	{ "id": "sushi", "grid_size": Vector2i(3, 1),
	  "pattern": [["fish_slice", "cooked_rice", "seaweed"]],
	  "output_id": "sushi", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "board" },
	{ "id": "sashimi", "grid_size": Vector2i(2, 1),
	  "pattern": [["fish_slice", "fish_slice"]],
	  "output_id": "sashimi", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "board" },
	{ "id": "onigiri", "grid_size": Vector2i(2, 1),
	  "pattern": [["cooked_rice", "seaweed"]],
	  "output_id": "onigiri", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "board" },
	{ "id": "shrimp_sushi", "grid_size": Vector2i(2, 1),
	  "pattern": [["sweet_shrimp", "cooked_rice"]],
	  "output_id": "shrimp_sushi", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "board" },
	{ "id": "uni_gunkan", "grid_size": Vector2i(3, 1),
	  "pattern": [["sea_urchin", "cooked_rice", "seaweed"]],
	  "output_id": "uni_gunkan", "output_count": 1, "mirror_ok": true, "rotate_ok": true, "requires": "board" },
	# === 远程武器 ===
	# 木弓: 3 planks + 3 wool (羊毛当弓弦), 3x3 弧形
	{
		"id": "wood_bow",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["",       "planks", "wool"],
			["planks", "",       "wool"],
			["",       "planks", "wool"],
		],
		"output_id": "wood_bow",
		"output_count": 1,
		"mirror_ok": true,
	},
	# 鱼竿: 3 planks 当竿身 (斜) + 2 wool 当鱼线. 普通合成.
	{
		"id": "fishing_rod",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["",       "",       "planks"],
			["",       "planks", "wool"],
			["planks", "",       "wool"],
		],
		"output_id": "fishing_rod",
		"output_count": 1,
		"mirror_ok": true,
	},
	# 菜刀: 铁锭 + 木板 (做菜板的材料). 普通合成.
	{
		"id": "kitchen_knife",
		"grid_size": Vector2i(1, 2),
		"pattern": [["iron_ingot"], ["planks"]],
		"output_id": "kitchen_knife",
		"output_count": 1,
		"mirror_ok": true,
	},
	# 菜板: 2 木板 + 1 菜刀 (做寿司工作站). 普通合成.
	{
		"id": "cutting_board",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["planks", "planks"],
			["kitchen_knife", ""],
		],
		"output_id": "cutting_board",
		"output_count": 1,
		"mirror_ok": true,
	},
	# 魔晶锭: 3 hell_crystal → 1 ingot. 熔炉烧, 跟其他金属同形 (3 横排).
	{
		"id": "hell_crystal_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["hell_crystal", "hell_crystal", "hell_crystal"]],
		"output_id": "hell_crystal_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	# 地狱合金锭: 3 hell_alloy_ore → 1 ingot. 熔炉.
	{
		"id": "hell_alloy_ingot",
		"grid_size": Vector2i(3, 1),
		"pattern": [["hell_alloy_ore", "hell_alloy_ore", "hell_alloy_ore"]],
		"output_id": "hell_alloy_ingot",
		"output_count": 1,
		"mirror_ok": true,
		"rotate_ok": true,
		"requires": "furnace",
	},
	# === 盔甲: 5 tier × 3 件 = 15 配方. 都是 3x3 工作台. ===
	# 头盔: 5 锭 (倒 U 形): . X X X . / . X . X . / 共 5 (上排 3 + 下排 2 ingot)
	# 胸甲: 8 锭 (T 形带洞): X . X / X X X / X X X
	# 裤子: 7 锭 (n 形): X X X / X . X / X . X
	#
	# 铜盔甲
	{
		"id": "copper_helmet", "grid_size": Vector2i(3, 3),
		"pattern": [["copper_ingot","copper_ingot","copper_ingot"], ["copper_ingot","","copper_ingot"], ["","",""]],
		"output_id": "copper_helmet", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "copper_chest", "grid_size": Vector2i(3, 3),
		"pattern": [["copper_ingot","","copper_ingot"], ["copper_ingot","copper_ingot","copper_ingot"], ["copper_ingot","copper_ingot","copper_ingot"]],
		"output_id": "copper_chest", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "copper_pants", "grid_size": Vector2i(3, 3),
		"pattern": [["copper_ingot","copper_ingot","copper_ingot"], ["copper_ingot","","copper_ingot"], ["copper_ingot","","copper_ingot"]],
		"output_id": "copper_pants", "output_count": 1, "mirror_ok": true,
	},
	# 铁盔甲
	{
		"id": "iron_helmet", "grid_size": Vector2i(3, 3),
		"pattern": [["iron_ingot","iron_ingot","iron_ingot"], ["iron_ingot","","iron_ingot"], ["","",""]],
		"output_id": "iron_helmet", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "iron_chest", "grid_size": Vector2i(3, 3),
		"pattern": [["iron_ingot","","iron_ingot"], ["iron_ingot","iron_ingot","iron_ingot"], ["iron_ingot","iron_ingot","iron_ingot"]],
		"output_id": "iron_chest", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "iron_pants", "grid_size": Vector2i(3, 3),
		"pattern": [["iron_ingot","iron_ingot","iron_ingot"], ["iron_ingot","","iron_ingot"], ["iron_ingot","","iron_ingot"]],
		"output_id": "iron_pants", "output_count": 1, "mirror_ok": true,
	},
	# 银盔甲
	{
		"id": "silver_helmet", "grid_size": Vector2i(3, 3),
		"pattern": [["silver_ingot","silver_ingot","silver_ingot"], ["silver_ingot","","silver_ingot"], ["","",""]],
		"output_id": "silver_helmet", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "silver_chest", "grid_size": Vector2i(3, 3),
		"pattern": [["silver_ingot","","silver_ingot"], ["silver_ingot","silver_ingot","silver_ingot"], ["silver_ingot","silver_ingot","silver_ingot"]],
		"output_id": "silver_chest", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "silver_pants", "grid_size": Vector2i(3, 3),
		"pattern": [["silver_ingot","silver_ingot","silver_ingot"], ["silver_ingot","","silver_ingot"], ["silver_ingot","","silver_ingot"]],
		"output_id": "silver_pants", "output_count": 1, "mirror_ok": true,
	},
	# 金盔甲
	{
		"id": "gold_helmet", "grid_size": Vector2i(3, 3),
		"pattern": [["gold_ingot","gold_ingot","gold_ingot"], ["gold_ingot","","gold_ingot"], ["","",""]],
		"output_id": "gold_helmet", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "gold_chest", "grid_size": Vector2i(3, 3),
		"pattern": [["gold_ingot","","gold_ingot"], ["gold_ingot","gold_ingot","gold_ingot"], ["gold_ingot","gold_ingot","gold_ingot"]],
		"output_id": "gold_chest", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "gold_pants", "grid_size": Vector2i(3, 3),
		"pattern": [["gold_ingot","gold_ingot","gold_ingot"], ["gold_ingot","","gold_ingot"], ["gold_ingot","","gold_ingot"]],
		"output_id": "gold_pants", "output_count": 1, "mirror_ok": true,
	},
	# 钻石盔甲: 用 diamond (raw, 不是 ingot)
	{
		"id": "diamond_helmet", "grid_size": Vector2i(3, 3),
		"pattern": [["diamond","diamond","diamond"], ["diamond","","diamond"], ["","",""]],
		"output_id": "diamond_helmet", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "diamond_chest", "grid_size": Vector2i(3, 3),
		"pattern": [["diamond","","diamond"], ["diamond","diamond","diamond"], ["diamond","diamond","diamond"]],
		"output_id": "diamond_chest", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "diamond_pants", "grid_size": Vector2i(3, 3),
		"pattern": [["diamond","diamond","diamond"], ["diamond","","diamond"], ["diamond","","diamond"]],
		"output_id": "diamond_pants", "output_count": 1, "mirror_ok": true,
	},
	# === 法杖 (Phase 7) ===
	# 木法杖: 1 leaves (魔草) + 2 planks 竖排 (新手, 工作台). 易合, 学徒能玩.
	{
		"id": "wood_staff", "grid_size": Vector2i(1, 3),
		"pattern": [["leaves"], ["planks"], ["planks"]],
		"output_id": "wood_staff", "output_count": 1, "mirror_ok": false,
	},
	# 铁法杖: 1 diamond (顶宝石) + 2 iron_ingot 竖排
	{
		"id": "iron_staff", "grid_size": Vector2i(1, 3),
		"pattern": [["diamond"], ["iron_ingot"], ["iron_ingot"]],
		"output_id": "iron_staff", "output_count": 1, "mirror_ok": false,
	},
	# 地狱法杖: 2 hell_crystal_ingot (顶魔晶) + 1 hell_alloy_ingot (杖身)
	{
		"id": "hell_staff", "grid_size": Vector2i(1, 3),
		"pattern": [["hell_crystal_ingot"], ["hell_crystal_ingot"], ["hell_alloy_ingot"]],
		"output_id": "hell_staff", "output_count": 1, "mirror_ok": false,
	},
	# 魔力药水: 1 hell_crystal + 1 silver_ingot (2x1 横排, 工作台). 出 2 瓶
	{
		"id": "mana_potion", "grid_size": Vector2i(2, 1),
		"pattern": [["hell_crystal", "silver_ingot"]],
		"output_id": "mana_potion", "output_count": 2, "mirror_ok": true,
	},
	# === 地狱武器 (tier 8): 3 alloy + 1 crystal (魔晶护手/装饰) + 2 planks (柄) ===
	# 剑形: . X .  /  . X .  /  . X .  + crystal 当装饰
	{
		"id": "hell_sword", "grid_size": Vector2i(3, 3),
		"pattern": [["","hell_alloy_ingot",""], ["","hell_alloy_ingot",""], ["","hell_crystal_ingot",""]],
		"output_id": "hell_sword", "output_count": 1, "mirror_ok": true,
	},
	# 镐形: X X X  /  . X .  /  . X .
	{
		"id": "hell_pickaxe", "grid_size": Vector2i(3, 3),
		"pattern": [["hell_alloy_ingot","hell_alloy_ingot","hell_alloy_ingot"], ["","hell_crystal_ingot",""], ["","hell_alloy_ingot",""]],
		"output_id": "hell_pickaxe", "output_count": 1, "mirror_ok": true,
	},
	# 斧形: X X .  /  X X .  /  . X .
	{
		"id": "hell_axe", "grid_size": Vector2i(3, 3),
		"pattern": [["hell_alloy_ingot","hell_alloy_ingot",""], ["hell_alloy_ingot","hell_crystal_ingot",""], ["","hell_alloy_ingot",""]],
		"output_id": "hell_axe", "output_count": 1, "mirror_ok": true,
	},
	# 木箭: 2 planks 竖排 → 4 支. 用 2x1 形避开已有 "1 planks→wood_wall" 1x1 配方冲突.
	{
		"id": "wood_arrow",
		"grid_size": Vector2i(1, 2),
		"pattern": [
			["planks"],
			["planks"],
		],
		"output_id": "wood_arrow",
		"output_count": 4,
		"mirror_ok": false,
	},
	# 手枪: 上排 3 铁锭(枪管) + 下排左 1 木板(握把) → 1 把. L 形像枪.
	{
		"id": "pistol",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["planks",     "",           ""],
		],
		"output_id": "pistol",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 子弹: 2 铁锭竖排 → 8 发. 跟木箭(1x2 planks)同形但材料不同, 不撞.
	{
		"id": "bullet",
		"grid_size": Vector2i(1, 2),
		"pattern": [
			["iron_ingot"],
			["iron_ingot"],
		],
		"output_id": "bullet",
		"output_count": 8,
		"mirror_ok": false,
	},
	# 冲锋枪: 铜+铁枪身 + 中下木握把 (握把居中, 区别手枪的左握把)
	{
		"id": "smg",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["copper_ingot", "iron_ingot", "iron_ingot"],
			["",             "planks",     ""],
		],
		"output_id": "smg",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 突击步枪: 3 铁锭枪管 + 双木握把 (2 木在左, 区别手枪 1 木)
	{
		"id": "assault_rifle",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["planks",     "planks",     ""],
		],
		"output_id": "assault_rifle",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 霰弹枪: 双排铁枪身(厚) + 双木握把 → 近战大威力
	{
		"id": "shotgun",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["planks",     "planks",     ""],
		],
		"output_id": "shotgun",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 狙击枪: 长铁枪管 + 右上金锭(瞄准镜) + 左下木握把 → 高级
	{
		"id": "sniper",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["",           "",           "gold_ingot"],
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["planks",     "",           ""],
		],
		"output_id": "sniper",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 激光枪: 银枪身 + 铁 + 钻石(透镜) + 木握把 → 穿透
	{
		"id": "laser_gun",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["silver_ingot", "iron_ingot", "diamond"],
			["",             "planks",     ""],
		],
		"output_id": "laser_gun",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 火焰喷射器: 铁枪管 + 双煤(燃料) → 喷火
	{
		"id": "flamethrower",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["iron_ingot", "iron_ingot", "iron_ingot"],
			["coal",       "coal",       ""],
		],
		"output_id": "flamethrower",
		"output_count": 1,
		"mirror_ok": false,
	},
	# 冰冻枪: 钻石(冰晶) + 铁枪身 + 右下木握把 → 减速
	{
		"id": "freeze_ray",
		"grid_size": Vector2i(3, 2),
		"pattern": [
			["diamond",    "iron_ingot", "iron_ingot"],
			["",           "",           "planks"],
		],
		"output_id": "freeze_ray",
		"output_count": 1,
		"mirror_ok": false,
	},
	# === 锤子 (破墙): 形状 X X X / X X . / . X . (区别于镐 XXX/.X./.X. 和斧 XX./XX./.X.)
	# 头=材质, 柄=planks. 木锤全 planks 也不撞木镐 (silhouette 不同).
	{
		"id": "wood_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["planks","planks","planks"], ["planks","planks",""], ["","planks",""]],
		"output_id": "wood_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "stone_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["stone","stone","stone"], ["stone","stone",""], ["","planks",""]],
		"output_id": "stone_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "copper_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["copper_ingot","copper_ingot","copper_ingot"], ["copper_ingot","copper_ingot",""], ["","planks",""]],
		"output_id": "copper_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "iron_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["iron_ingot","iron_ingot","iron_ingot"], ["iron_ingot","iron_ingot",""], ["","planks",""]],
		"output_id": "iron_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "silver_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["silver_ingot","silver_ingot","silver_ingot"], ["silver_ingot","silver_ingot",""], ["","planks",""]],
		"output_id": "silver_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "gold_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["gold_ingot","gold_ingot","gold_ingot"], ["gold_ingot","gold_ingot",""], ["","planks",""]],
		"output_id": "gold_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "diamond_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["diamond","diamond","diamond"], ["diamond","diamond",""], ["","planks",""]],
		"output_id": "diamond_hammer", "output_count": 1, "mirror_ok": true,
	},
	{
		"id": "hell_hammer", "grid_size": Vector2i(3, 3),
		"pattern": [["hell_alloy_ingot","hell_alloy_ingot","hell_alloy_ingot"], ["hell_alloy_ingot","hell_crystal_ingot",""], ["","hell_alloy_ingot",""]],
		"output_id": "hell_hammer", "output_count": 1, "mirror_ok": true,
	},
]


func all_recipes() -> Array:
	return _RECIPES


func get_recipe(recipe_id: String) -> Variant:
	for r in _RECIPES:
		if r.id == recipe_id:
			return r
	return null
