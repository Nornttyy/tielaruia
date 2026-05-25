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
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		# dirt 必掉 + 20% 概率额外掉 grass (稀有种子)
		"drops": [["dirt", 100, 1, 1], ["grass", 20, 1, 1]],
	},
	DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	SAND: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["sand", 100, 1, 1]],
	},
	LOG: {
		# 原木不实心 — 玩家可穿过树干 (像 Terraria)
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LEAVES: {
		# 不实心 (玩家可穿过)；100% 掉树叶本身 + 5% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["leaves", 100, 1, 1], ["apple", 5, 1, 1]],
	},
	PLANKS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["planks", 100, 1, 1]],
	},
	WORKBENCH: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["workbench", 100, 1, 1]],
	},
	DOOR: {
		# M1 简化: 视为始终开启 (非实心), 玩家可穿过
		# M2 加 Door 单独场景做开/关碰撞切换
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["door", 100, 1, 1]],
	},
	BEDROCK: {
		"solid": true, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LEAVES_PINE: {
		# 松针：不实心 + 掉松针变种 + 5% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["pine_leaves", 100, 1, 1], ["apple", 5, 1, 1]],
	},
	LEAVES_AUTUMN: {
		# 秋叶：不实心 + 掉秋叶变种 + 5% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["autumn_leaves", 100, 1, 1], ["apple", 5, 1, 1]],
	},
	SLIME_TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["slime_torch", 100, 1, 1]],
	},
	TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["torch", 100, 1, 1]],
	},
	COAL_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["coal", 100, 1, 1]],
	},
	IRON_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
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
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["copper_ore", 100, 1, 1]],
	},
	TIN_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["tin_ore", 100, 1, 1]],
	},
	GOLD_ORE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 3, "axe": -1, "sword": -1},
		"drops": [["gold_ore", 100, 1, 1]],
	},
	DIAMOND_ORE: {
		# 钻石: 金镐 (tier 4) 才能挖 — 进阶门槛
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 4, "axe": -1, "sword": -1},
		"drops": [["diamond", 100, 1, 1]],
	},
	HELL_CRYSTAL: {
		# 地狱晶体: 钻石镐 (tier 5) 才能挖 — 终局装备
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 5, "axe": -1, "sword": -1},
		"drops": [["hell_crystal", 100, 1, 1]],
	},
	CACTUS: {
		# 仙人掌: 不实心 (玩家穿过, 像 LOG), 任何工具都能砍, 掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["cactus", 100, 1, 1]],
	},
	CACTUS_BODY: {
		# 仙人掌身体段: 行为同 CACTUS, 砍了也掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
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
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["log", 100, 1, 1]],
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
