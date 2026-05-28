extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
var db


func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)


func test_unknown_item_returns_null():
	assert_null(db.get_def("nonexistent"))


func test_dirt_is_placeable():
	var def = db.get_def("dirt")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, Tiles.DIRT)
	assert_eq(def.max_stack, 64)


func test_stone_placeable():
	var def = db.get_def("stone")
	assert_eq(def.placeable_tile_id, Tiles.STONE)


func test_wood_pickaxe_is_tool_not_placeable():
	var def = db.get_def("wood_pickaxe")
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.tool_kind, "pickaxe")
	assert_eq(def.tool_tier, 1)
	assert_eq(def.max_stack, 1)


func test_all_known_items_present():
	for item_id in ["dirt", "grass", "stone", "sand", "log", "leaves",
			"planks", "workbench", "door",
			"wood_sword", "wood_pickaxe", "wood_axe", "slime_jelly", "apple",
			"stone_sword", "stone_pickaxe", "stone_axe", "slime_torch"]:
		assert_not_null(db.get_def(item_id), "缺失 item: %s" % item_id)


func test_is_placeable():
	assert_true(db.is_placeable("dirt"))
	assert_false(db.is_placeable("wood_pickaxe"))
	assert_false(db.is_placeable("unknown"))


func test_stick_removed():
	# Terraria 风格: 没有 stick 中间品
	assert_null(db.get_def("stick"), "stick 已删除")


func test_torch_item():
	var def = db.get_def("torch")
	assert_not_null(def, "torch item 应存在")
	assert_eq(def.placeable_tile_id, Tiles.TORCH)
	assert_eq(def.max_stack, 99)
	assert_true(db.is_placeable("torch"))


func test_coal_item():
	var def = db.get_def("coal")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)
	assert_false(db.is_placeable("coal"))


func test_iron_ore_item():
	var def = db.get_def("iron_ore")
	assert_not_null(def)
	assert_eq(def.placeable_tile_id, -1)
	assert_eq(def.max_stack, 99)


func test_iron_pickaxe_item():
	var def = db.get_def("iron_pickaxe")
	assert_not_null(def)
	assert_eq(def.tool_kind, "pickaxe")
	# tier 1-7 progressive: wood/stone/copper/iron/silver/gold/diamond
	assert_eq(def.tool_tier, 4)
	assert_eq(def.max_stack, 1)
