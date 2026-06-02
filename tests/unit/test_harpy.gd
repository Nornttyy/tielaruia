extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_feather_item_def():
	var def = ItemDB.get_def("feather")
	assert_not_null(def, "feather 物品存在")
	assert_eq(def["placeable_tile_id"], -1, "羽毛不是方块")

func test_feather_has_icon():
	assert_true(ItemsArt.has_icon("feather"), "羽毛有图标")
	var tex = ItemsArt.get_icon("feather")
	assert_eq(tex.get_image().get_width(), 16, "图标 16 宽")
