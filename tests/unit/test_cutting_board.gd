extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")
const RecipeDBClass = preload("res://scripts/crafting/recipe_db.gd")

func test_cutting_board_tile():
	assert_gt(Tiles.CUTTING_BOARD, 0, "菜板 tile 常量应存在")
	assert_true(Tiles.is_solid(Tiles.CUTTING_BOARD))
	assert_true(Tiles.is_mineable(Tiles.CUTTING_BOARD))

func test_cutting_board_item():
	var db = ItemDBClass.new()
	add_child_autofree(db)
	assert_true(db.is_placeable("cutting_board"))
	assert_eq(db.get_def("cutting_board").placeable_tile_id, Tiles.CUTTING_BOARD)

func test_cutting_board_registered():
	var src: String = FileAccess.get_file_as_string("res://scripts/world/tileset_builder.gd")
	assert_true(src.find("CUTTING_BOARD") != -1, "tileset_builder 应注册 CUTTING_BOARD")
	assert_not_null(ArtCache.block_textures.get(Tiles.CUTTING_BOARD), "菜板应有方块贴图")
	assert_not_null(ArtCache.get_inventory_icon("cutting_board"), "菜板背包图标应有")

func test_cutting_board_recipe():
	var rdb = RecipeDBClass.new()
	add_child_autofree(rdb)
	var r = rdb.get_recipe("cutting_board")
	assert_not_null(r, "应有菜板配方")
	assert_eq(r.output_id, "cutting_board")
