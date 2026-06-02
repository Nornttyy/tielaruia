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

func test_grilled_fish_def():
	assert_true(db.is_food("grilled_fish"), "烤鱼应能吃")
	assert_eq(db.food_fill("grilled_fish"), 45, "烤鱼回 45 血")
	assert_eq(db.food_buff_kind("grilled_fish"), "speed", "烤鱼给跑得快")
	assert_gt(db.food_buff_secs("grilled_fish"), 0.0)

# 三文鱼/金枪鱼/鳗鱼 任意一种 → 烤鱼, 都在锅里做
func test_grilled_fish_recipes():
	var ids := ["grilled_fish_salmon", "grilled_fish_tuna", "grilled_fish_eel"]
	var found_outputs := 0
	for rid in ids:
		var r = rdb.get_recipe(rid)
		assert_not_null(r, "%s 配方应存在" % rid)
		assert_eq(r.output_id, "grilled_fish", "%s 产出烤鱼" % rid)
		assert_eq(r.get("requires", ""), "pot", "%s 在锅里做" % rid)
		found_outputs += 1
	assert_eq(found_outputs, 3, "应有 3 条烤鱼配方")

func test_grilled_fish_icon():
	assert_true(ItemsArt.has_icon("grilled_fish"))
	assert_eq(ItemsArt.get_icon("grilled_fish").get_width(), 16)
