extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_cloud_boots_item_def():
	var def = ItemDB.get_def("cloud_boots")
	assert_not_null(def, "云靴物品存在")
	assert_eq(def["max_stack"], 1, "云靴不堆叠")

func test_cloud_boots_has_icon():
	assert_true(ItemsArt.has_icon("cloud_boots"), "云靴有图标")
