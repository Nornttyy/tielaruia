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
	"wood_sword":   {"placeable_tile_id": -1,              "tool_kind": "sword",   "tool_tier": 1, "max_stack": 1},
	"wood_pickaxe": {"placeable_tile_id": -1,              "tool_kind": "pickaxe", "tool_tier": 1, "max_stack": 1},
	"wood_axe":     {"placeable_tile_id": -1,              "tool_kind": "axe",     "tool_tier": 1, "max_stack": 1},
	"slime_jelly":  {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40},
	"apple":        {"placeable_tile_id": -1,              "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
	"stone_sword":   {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1},
	"stone_pickaxe": {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1},
	"stone_axe":     {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1},
	"slime_torch":   {"placeable_tile_id": Tiles.SLIME_TORCH,      "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"coal":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_ore":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"copper_ore":    {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"tin_ore":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"gold_ore":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"diamond":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"hell_crystal":  {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"torch":         {"placeable_tile_id": Tiles.TORCH,            "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"iron_pickaxe":  {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 3, "max_stack": 1},
	"iron_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 3, "max_stack": 1},
	"iron_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 3, "max_stack": 1},
	"gold_sword":    {"placeable_tile_id": -1,                     "tool_kind": "sword",   "tool_tier": 4, "max_stack": 1},
	"gold_pickaxe":  {"placeable_tile_id": -1,                     "tool_kind": "pickaxe", "tool_tier": 4, "max_stack": 1},
	"gold_axe":      {"placeable_tile_id": -1,                     "tool_kind": "axe",     "tool_tier": 4, "max_stack": 1},
	"diamond_sword":   {"placeable_tile_id": -1,                   "tool_kind": "sword",   "tool_tier": 5, "max_stack": 1},
	"diamond_pickaxe": {"placeable_tile_id": -1,                   "tool_kind": "pickaxe", "tool_tier": 5, "max_stack": 1},
	"diamond_axe":     {"placeable_tile_id": -1,                   "tool_kind": "axe",     "tool_tier": 5, "max_stack": 1},
	"bone":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
	"raw_meat":      {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64, "food_fill": 30},
	"leather":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
	"wool":          {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 64},
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
