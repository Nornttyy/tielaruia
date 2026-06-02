extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
var db
var rdb

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)
	rdb = RecipeDBClass.new()
	add_child_autofree(rdb)

func test_fishing_rod_def():
	var d = db.get_def("fishing_rod")
	assert_not_null(d, "应有鱼竿 def")
	assert_eq(d.get("tool_kind", ""), "fishing", "鱼竿 tool_kind=fishing")
	assert_eq(d.get("max_stack", 0), 1, "鱼竿不可叠加")

func test_fishing_rod_recipe():
	var r = rdb.get_recipe("fishing_rod")
	assert_not_null(r, "应有鱼竿配方")
	assert_eq(r.output_id, "fishing_rod")

func test_fishing_rod_icon():
	assert_true(ItemsArt.has_icon("fishing_rod"), "鱼竿应有图标")
	var tex = ItemsArt.get_icon("fishing_rod")
	assert_not_null(tex)
	assert_eq(tex.get_width(), 16)
