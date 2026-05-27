# Tile 属性表 (autoload 单例)。所有 tile 行为查询统一在这里。
extends Node

# Tile ID 常量 (与 BlocksArt 同步)
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const LOG := 5
const LEAVES := 6           # 橡木叶 (默认)
const PLANKS := 7
const WORKBENCH := 8
const DOOR := 9
const BEDROCK := 10
const LEAVES_PINE := 11     # 松针 (深暖绿)
const LEAVES_AUTUMN := 12   # 秋叶 (红橙)
const SLIME_TORCH := 13     # 史莱姆灯 (装饰, 不实心)
const TORCH := 14
const COAL_ORE := 15
const IRON_ORE := 16
const DEEP_STONE := 17
# --- 背景墙 (background wall): 装饰用, 不实心, 不可挖, 显示在主方块后面 ---
const GRASS_WALL := 18      # 草墙: 接近地表第 1-2 行
const DIRT_WALL := 19       # 土墙: 中层 (土块对应)
const STONE_WALL := 20      # 石墙: 深层 (石头对应)
const CACTUS := 21          # 仙人掌: 沙漠地表装饰 (非实心, 可砍)
const COPPER_ORE := 22      # 铜矿: 浅层 (wood 镐可挖)
const TIN_ORE := 23         # 锡矿: 浅层 (wood 镐可挖)
const GOLD_ORE := 24        # 金矿: 中深 (iron 镐才挖)
const DIAMOND_ORE := 25     # 钻石矿: 深 (iron 镐才挖)
const HELL_CRYSTAL := 26    # 地狱晶体: 接近基岩 (iron 镐才挖)
const CACTUS_BODY := 27     # 仙人掌身体段 (堆叠时非顶端用, 无 top outline 衔接顶端 CACTUS)
const WATER := 28           # 水 (非实心, 玩家穿过, 视觉半透明蓝)
const LOG_TOP := 29         # 树干顶帽 (canopy 接头)
const LOG_ROOT_L := 30      # 树根 左侧
const LOG_ROOT_R := 31      # 树根 右侧
const BRANCH_L := 32        # 树干侧枝 向左伸
const BRANCH_R := 33        # 树干侧枝 向右伸
const WATER_L1 := 34        # 1/4 水位 (流水 level 1)
const WATER_L2 := 35        # 2/4 水位 (流水 level 2)
const WATER_L3 := 36        # 3/4 水位 (流水 level 3)
# WATER (=28) 表示满水 level 4
const CHEST := 37           # 箱子: 右键打开 24 格存储, 内容跟存档持久化
const DOOR_TOP := 38        # 门上半截 (DOOR 始终是底部, DOOR_TOP 顶部). 配对成 2 格高门.
# 新群系 tile (雪原 / 丛林 / 沼泽)
const SNOW := 39            # 雪原地表 (替代 GRASS), 偏白带浅蓝阴影
const ICE := 40             # 冰块 (雪原零星), 半透明蓝
const JUNGLE_GRASS := 41    # 丛林地表, 深绿带湿气黄绿斑
const MUD := 42             # 沼泽泥土 (替代 DIRT 在沼泽), 棕黑色
const SWAMP_GRASS := 43     # 沼泽地表, 深灰绿带泥点
# 平台: 站上面 + 下方能穿过 (单向碰撞). Terraria 风
const WOOD_PLATFORM := 44
# 绳子: 垂直挂着, 玩家碰到可爬上爬下 (W/S). 不阻挡走路.
const ROPE := 45
# 群系专属泥土 + 树叶
const JUNGLE_DIRT := 46     # 丛林泥土 (深泥黄, 比普通 DIRT 偏绿/棕黑)
const SNOW_DIRT := 47       # 雪原冻土 (灰白带蓝, 比 SNOW 暗)
const JUNGLE_LEAVES := 48   # 丛林树叶 (深湿绿, 比 LEAVES 暗)
const SILVER_ORE := 49      # 银矿 (铁和金之间, tier 3 用 iron 镐挖)

# 每 tile 的属性。drops 为 [item_id, weight%, count_min, count_max] 数组。
# tool: "pickaxe"/"axe"/"sword"/"" (空 = 徒手)
# tier: -1 = 该工具挖不动；0 = 徒手也行；1 = 需 1 级 (木质)
const _PROPS := {
	AIR: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		# dirt 必掉 + 20% 概率额外掉 grass (稀有种子)
		"drops": [["dirt", 100, 1, 1], ["grass", 20, 1, 1]],
	},
	DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	SAND: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["sand", 100, 1, 1]],
	},
	LOG: {
		# 原木不实心 — 玩家可穿过树干 (像 Terraria)
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LEAVES: {
		# 不实心. 不掉 leaves 物品 (砍树或单独砍都直接消失), 仅 20% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	PLANKS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["planks", 100, 1, 1]],
	},
	WORKBENCH: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["workbench", 100, 1, 1]],
	},
	DOOR: {
		# 门底部: 视觉占 1 格, 但和 DOOR_TOP (上一格) 配对成 2 格高门.
		# solid=false → tileset_builder 不会在物理层 0 加碰撞;
		# tileset_builder 单独在物理层 1 (门层, bit 1) 加碰撞, 怪挡住, 玩家放行.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["door", 100, 1, 1]],
	},
	DOOR_TOP: {
		# 门顶部: 跟 DOOR 一起 2 格高. 物理同 DOOR (单独物理层挡怪不挡玩家).
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		# 不掉东西 — 砍 DOOR 顶部时, 联动把底也消, 由底掉 1 个 door item.
		"drops": [],
	},
	BEDROCK: {
		"solid": true, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LEAVES_PINE: {
		# 松针 (老存档): 不实心, 不掉变种 leaves 物品, 仅 20% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	LEAVES_AUTUMN: {
		# 秋叶 (老存档): 同上
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	SLIME_TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["slime_torch", 100, 1, 1]],
	},
	TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["torch", 100, 1, 1]],
	},
	COAL_ORE: {
		# 煤: 木镐就能挖 (最浅 + 最早期)
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["coal", 100, 1, 1]],
	},
	IRON_ORE: {
		# 铁: 铜镐 (tier 3) 才能挖 — 进阶, 用铜→挖铁→升铁工具
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 3, "axe": -1, "sword": -1},
		"drops": [["iron_ore", 100, 1, 1]],
	},
	DEEP_STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	GRASS_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	DIRT_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	STONE_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	COPPER_ORE: {
		# 铜: 石镐 (tier 2) 才能挖 — 第一金属, 升级路线起点
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
		"drops": [["copper_ore", 100, 1, 1]],
	},
	TIN_ORE: {
		# 锡: 石镐 — 跟铜并列, 可代替铜也可单独装备
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
		"drops": [["tin_ore", 100, 1, 1]],
	},
	GOLD_ORE: {
		# 金: 铜/铁镐 (tier 3) — 中期
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 3, "axe": -1, "sword": -1},
		"drops": [["gold_ore", 100, 1, 1]],
	},
	DIAMOND_ORE: {
		# 钻石: 金镐 (tier 4) — 后期门槛
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 4, "axe": -1, "sword": -1},
		"drops": [["diamond", 100, 1, 1]],
	},
	HELL_CRYSTAL: {
		# 地狱晶体: 钻石镐 (tier 5) — 终局
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 5, "axe": -1, "sword": -1},
		"drops": [["hell_crystal", 100, 1, 1]],
	},
	CACTUS: {
		# 仙人掌: 不实心 (玩家穿过, 像 LOG), 任何工具都能砍, 掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["cactus", 100, 1, 1]],
	},
	CACTUS_BODY: {
		# 仙人掌身体段: 行为同 CACTUS, 砍了也掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["cactus", 100, 1, 1]],
	},
	WATER: {
		# 水: 非实心 (玩家穿过), 不可挖 (没法用工具收), 无掉落. 等以后加桶再说.
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LOG_TOP: {
		# 树干顶帽: 行为同 LOG, 砍了掉 log
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	# 流水 3 个低水位 tile. 行为同 WATER: 不实心 + 不可挖
	WATER_L1: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_L2: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_L3: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	CHEST: {
		# 非实心 (玩家能站箱子里), 可挖 (任何工具都行), 砍掉 1 个 chest item
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["chest", 100, 1, 1]],
	},
	# === 新群系地表 (像 GRASS / DIRT / SAND 一样可挖, 徒手即可) ===
	SNOW: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["snow", 100, 1, 1]],
	},
	ICE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": -1, "sword": -1},
		"drops": [["ice", 100, 1, 1]],
	},
	JUNGLE_GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	MUD: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["mud", 100, 1, 1]],
	},
	SWAMP_GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["mud", 100, 1, 1]],
	},
	# 平台: solid=false (走路不阻挡), tileset_builder 单独加 one_way 碰撞
	WOOD_PLATFORM: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wood_platform", 100, 1, 1]],
	},
	# 绳子: solid=false (玩家穿过), 但 player_controller 检测到会切换爬绳模式
	ROPE: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rope", 100, 1, 1]],
	},
	# 群系泥土 / 树叶 (跟基础 DIRT/LEAVES 类似行为, 只颜色不同)
	JUNGLE_DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["jungle_dirt", 100, 1, 1]],
	},
	SNOW_DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["snow_dirt", 100, 1, 1]],
	},
	JUNGLE_LEAVES: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	SILVER_ORE: {
		# 银: 铁镐 (tier 3) 才能挖 — 跟铁同档但更深
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 3, "axe": -1, "sword": -1},
		"drops": [["silver_ore", 100, 1, 1]],
	},
}


func is_solid(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].solid


func is_mineable(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].mineable


# 返回该 tool 挖该 tile 所需的最低 tier。-1 = 不行。0 = 徒手也行。
func required_tool_tier(tile_id: int, tool: String) -> int:
	if not _PROPS.has(tile_id):
		return -1
	var tiers: Dictionary = _PROPS[tile_id].tool_tiers
	if tiers.has(tool):
		return tiers[tool]
	return tiers.get("", -1)


# 按 drops 表权重抽样，返回 {item_id: count}。
func drops_for(tile_id: int, _tool: String) -> Dictionary:
	if not _PROPS.has(tile_id):
		return {}
	var result := {}
	for entry in _PROPS[tile_id].drops:
		var item_id: String = entry[0]
		var weight: int = entry[1]
		var roll := randi() % 100
		if roll < weight:
			var n := randi_range(entry[2], entry[3])
			if n > 0:
				result[item_id] = result.get(item_id, 0) + n
	return result
