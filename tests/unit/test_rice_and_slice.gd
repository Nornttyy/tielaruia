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

func test_cooked_rice():
	assert_true(db.is_food("cooked_rice"), "米饭能吃")
	assert_eq(db.food_fill("cooked_rice"), 25)
	var r = rdb.get_recipe("cooked_rice")
	assert_not_null(r)
	assert_eq(r.output_id, "cooked_rice")
	assert_eq(r.get("requires", ""), "pot", "米饭锅里煮")

func test_fish_slice():
	assert_true(db.is_food("fish_slice"), "鱼片能吃 (生鱼片)")
	assert_eq(db.food_fill("fish_slice"), 18)

# 三文鱼/金枪鱼/鳗鱼 → 鱼片, 都在菜板切
func test_fish_slice_recipes():
	for rid in ["fish_slice_salmon", "fish_slice_tuna", "fish_slice_eel"]:
		var r = rdb.get_recipe(rid)
		assert_not_null(r, "%s 配方应存在" % rid)
		assert_eq(r.output_id, "fish_slice")
		assert_eq(r.get("requires", ""), "board", "%s 菜板上切" % rid)

func test_icons_in_game():
	assert_not_null(ArtCache.get_inventory_icon("cooked_rice"))
	assert_not_null(ArtCache.get_inventory_icon("fish_slice"))
