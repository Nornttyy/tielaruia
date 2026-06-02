extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
var db
var rdb

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)
	rdb = RecipeDBClass.new()
	add_child_autofree(rdb)

func test_knife_def():
	assert_not_null(db.get_def("kitchen_knife"), "应有菜刀")

func test_knife_recipe():
	var r = rdb.get_recipe("kitchen_knife")
	assert_not_null(r, "应有菜刀配方")
	assert_eq(r.output_id, "kitchen_knife")

func test_knife_icon_in_game():
	assert_not_null(ArtCache.get_inventory_icon("kitchen_knife"), "菜刀游戏里应有图标")
