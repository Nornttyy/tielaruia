extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
var db

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)

# 8 种能吃的海鲜: food_fill 对; 紫菜是材料(food_fill 0, 不可吃)
func test_seafood_defs():
	var expect := {
		"salmon": 25, "tuna": 28, "octopus": 22, "sea_urchin": 20,
		"lobster": 38, "eel": 26, "sweet_shrimp": 15, "scallop": 18,
	}
	for id in expect:
		assert_true(db.is_food(id), "%s 应能吃" % id)
		assert_eq(db.food_fill(id), expect[id], "%s food_fill" % id)
	# 紫菜: 纯材料, 不可吃
	assert_not_null(db.get_def("seaweed"), "应有紫菜")
	assert_false(db.is_food("seaweed"), "紫菜是材料不可吃")

# 9 种海鲜都有能渲染的图标
func test_seafood_icons():
	for id in ["salmon", "tuna", "octopus", "sea_urchin", "lobster", "eel", "sweet_shrimp", "scallop", "seaweed"]:
		assert_true(ItemsArt.has_icon(id), "%s 应有图标" % id)
		var tex = ItemsArt.get_icon(id)
		assert_not_null(tex, "%s 图标应能渲染" % id)
		assert_eq(tex.get_width(), 16, "%s 16px" % id)
