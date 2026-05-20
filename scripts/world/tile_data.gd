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
		# 不实心 (玩家可穿过)；100% 掉树叶本身
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["leaves", 100, 1, 1]],
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
		# 关时实心；开/关由 Door 单独场景处理碰撞
		"solid": true, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["door", 100, 1, 1]],
	},
	BEDROCK: {
		"solid": true, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LEAVES_PINE: {
		# 松针：不实心 + 掉松针变种
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["pine_leaves", 100, 1, 1]],
	},
	LEAVES_AUTUMN: {
		# 秋叶：不实心 + 掉秋叶变种
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["autumn_leaves", 100, 1, 1]],
	},
	SLIME_TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["slime_torch", 100, 1, 1]],
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
