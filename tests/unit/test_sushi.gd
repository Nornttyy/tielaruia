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

func test_sushi_defs():
	var expect := {
		"sushi":        {"fill": 70, "kind": "speed"},
		"sashimi":      {"fill": 50, "kind": "regen"},
		"onigiri":      {"fill": 35, "kind": ""},
		"shrimp_sushi": {"fill": 45, "kind": "speed"},
		"uni_gunkan":   {"fill": 55, "kind": "mining"},
	}
	for id in expect:
		assert_true(db.is_food(id), "%s 能吃" % id)
		assert_eq(db.food_fill(id), expect[id].fill, "%s food_fill" % id)
		assert_eq(db.food_buff_kind(id), expect[id].kind, "%s buff" % id)

# 5 种寿司都在菜板做
func test_sushi_recipes_require_board():
	for id in ["sushi", "sashimi", "onigiri", "shrimp_sushi", "uni_gunkan"]:
		var r = rdb.get_recipe(id)
		assert_not_null(r, "%s 配方应存在" % id)
		assert_eq(r.get("requires", ""), "board", "%s 菜板上做" % id)

func test_sushi_icons():
	for id in ["sushi", "sashimi", "onigiri", "shrimp_sushi", "uni_gunkan"]:
		assert_not_null(ArtCache.get_inventory_icon(id), "%s 应有图标" % id)
