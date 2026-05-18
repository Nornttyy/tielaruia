# 6 个 Demo 配方。pattern[row][col] = item_id 或 "" (空)。
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
		"id": "stick",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["planks", ""],
			["planks", ""],
		],
		"output_id": "stick",
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
		"id": "wood_sword",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["", "planks", ""],
			["", "planks", ""],
			["", "stick",  ""],
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
			["",       "stick",  ""],
			["",       "stick",  ""],
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
			["planks", "stick",  ""],
			["",       "stick",  ""],
		],
		"output_id": "wood_axe",
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
