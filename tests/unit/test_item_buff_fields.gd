extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
var db

func before_each():
	db = ItemDBClass.new()
	add_child_autofree(db)

func test_apple_grants_well_fed():
	assert_eq(db.food_buff_kind("apple"), "well_fed", "苹果提供吃得好")
	assert_almost_eq(db.food_buff_secs("apple"), 300.0, 0.001)
	assert_true(db.food_has_buff("apple"))

func test_buff_helpers_unknown():
	assert_eq(db.food_buff_kind("nonexistent"), "")
	assert_false(db.food_has_buff("nonexistent"))
