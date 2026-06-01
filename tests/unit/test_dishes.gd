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

# 7 道新料理: food_fill + buff 字段正确
func test_dish_defs():
	var expect := {
		"bread":         {"fill": 30, "kind": "speed"},
		"mushroom_soup": {"fill": 30, "kind": "regen"},
		"apple_pie":     {"fill": 45, "kind": "jump"},
		"meat_skewer":   {"fill": 60, "kind": "mining"},
		"mushroom_stew": {"fill": 65, "kind": "mining"},
		"apple_jam":     {"fill": 35, "kind": "regen"},
		"jelly_pudding": {"fill": 40, "kind": "jump"},
	}
	for id in expect:
		assert_true(db.is_food(id), "%s 应是食物" % id)
		assert_eq(db.food_fill(id), expect[id].fill, "%s food_fill" % id)
		assert_eq(db.food_buff_kind(id), expect[id].kind, "%s buff_kind" % id)
		assert_gt(db.food_buff_secs(id), 0.0, "%s buff_secs>0" % id)

# 熟肉无 buff (基础款)
func test_cooked_meat_no_buff():
	assert_true(db.is_food("cooked_meat"))
	assert_false(db.food_has_buff("cooked_meat"))

# 8 道料理配方都 requires "pot"
func test_dish_recipes_require_pot():
	for id in ["cooked_meat", "bread", "mushroom_soup", "apple_pie", "meat_skewer", "mushroom_stew", "apple_jam", "jelly_pudding"]:
		var r = rdb.get_recipe(id)
		assert_not_null(r, "%s 配方应存在" % id)
		assert_eq(r.get("requires", ""), "pot", "%s 应在锅里做" % id)

# 7 道新料理都能渲染出图标 (真画一遍, 抓图案宽度/颜色键错误)
func test_dishes_have_icons():
	for id in ["bread", "mushroom_soup", "apple_pie", "meat_skewer", "mushroom_stew", "apple_jam", "jelly_pudding"]:
		assert_true(ItemsArt.has_icon(id), "%s 应有图标" % id)
		var tex = ItemsArt.get_icon(id)
		assert_not_null(tex, "%s 图标应能渲染" % id)
		assert_eq(tex.get_width(), 16, "%s 图标应 16px 宽" % id)
