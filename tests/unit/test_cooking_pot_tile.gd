extends GutTest

const ItemDBClass = preload("res://scripts/items/item_db.gd")

func test_cooking_pot_tile_const():
	assert_eq(Tiles.COOKING_POT, 74, "锅 tile id = 74")

func test_cooking_pot_solid_mineable():
	assert_true(Tiles.is_solid(Tiles.COOKING_POT))
	assert_true(Tiles.is_mineable(Tiles.COOKING_POT))

func test_cooking_pot_item_placeable():
	var db = ItemDBClass.new()
	add_child_autofree(db)
	assert_true(db.is_placeable("cooking_pot"))
	assert_eq(db.get_def("cooking_pot").placeable_tile_id, Tiles.COOKING_POT)

func test_cooking_pot_in_tileset_ids():
	var src: String = FileAccess.get_file_as_string("res://scripts/world/tileset_builder.gd")
	assert_true(src.find("Tiles.COOKING_POT") != -1, "tileset_builder 必须注册 COOKING_POT")

func test_cooking_pot_has_art():
	var tex = ArtCache.block_textures.get(Tiles.COOKING_POT)
	assert_not_null(tex, "锅必须有贴图")
