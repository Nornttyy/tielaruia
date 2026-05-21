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
	# === 铁镐 (3x3 工作台, tier 3) ===
	{
		"id": "iron_pickaxe",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["iron_ore", "iron_ore", "iron_ore"],
			["",         "planks",   ""],
			["",         "planks",   ""],
		],
		"output_id": "iron_pickaxe",
		"output_count": 1,
		"mirror_ok": true,
	},
]


func all_recipes() -> Array:
	return _RECIPES


func get_recipe(recipe_id: String) -> Variant:
	for r in _RECIPES:
		if r.id == recipe_id:
			return r
	return null
