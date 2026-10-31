extends GutTest

const Frames = preload("res://scripts/world/tree_frames.gd")
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Auto = preload("res://scripts/world/autotile.gd")
const Blob = preload("res://scripts/world/blob_lookup.gd")
const Builder = preload("res://scripts/world/tileset_builder.gd")

class Grid extends RefCounted:
	var cells := {}
	func get_tile(x: int, y: int) -> int: return cells.get(Vector2i(x, y), Tiles.AIR)

func test_tree_join_changes_when_branches_or_roots_change():
	var grid := Grid.new()
	var p := Vector2i(-1, 20)
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 0)
	grid.cells[p + Vector2i.LEFT] = Tiles.BRANCH_L
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 1)
	grid.cells[p + Vector2i.RIGHT] = Tiles.BRANCH_R
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 3)
	grid.cells.erase(p + Vector2i.LEFT)
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 2)
	grid.cells[p + Vector2i.LEFT] = Tiles.LOG_ROOT_L
	grid.cells[p + Vector2i.RIGHT] = Tiles.LOG_ROOT_R
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 7)
	grid.cells.erase(p + Vector2i.RIGHT)
	assert_eq(Frames.frame(p, Tiles.LOG, grid).y, 5)
	assert_between(Frames.frame(p, Tiles.LOG, grid).x, 0, 2)

func test_tree_original_scale_and_attachment_edges():
	var ts := Builder.build()
	var trunk: TileSetAtlasSource = ts.get_source(Tiles.LOG)
	assert_eq(trunk.texture_region_size, Vector2i(15, 15), "20 原像素随世界缩放为 15，不能压成 12")
	assert_eq(trunk.get_tiles_count(), 24)
	for id in [Tiles.BRANCH_L, Tiles.BRANCH_R]:
		var data = ts.get_source(id).get_tile_data(Vector2i.ZERO, 0)
		assert_eq(data.texture_origin.y, 0, "枝叶垂直居中")
		assert_eq(abs(data.texture_origin.x), 9, "30 像素枝叶向格外延伸，连接端贴格边")
		assert_eq(data.get_collision_polygons_count(0), 0)
	for id in [Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R]:
		assert_eq(ts.get_source(id).texture_region_size, Vector2i(15, 15))
	var left := Pack.tree_piece(Tiles.LOG_ROOT_L, 0, 0).get_image()
	var right := Pack.tree_piece(Tiles.LOG_ROOT_R, 0, 0).get_image()
	assert_gt(left.get_pixel(12, 5).a, 0.0, "左根高端朝右接干")
	assert_gt(right.get_pixel(1, 5).a, 0.0, "右根高端朝左接干")

func test_concave_frames_do_not_copy_an_outside_corner():
	var sheet := Pack.source_image("Tiles_0.png")
	var cell := Pack.terrain_cell(sheet, "CCCCIXXI")
	assert_eq(cell.get_data(), sheet.get_region(Rect2i(108, 36, 16, 16)).get_data())
	var single := Pack.terrain_cell(sheet, "CCCCIIIX")
	assert_eq(single.get_data(), Pack.terrain_cell(sheet, "CCCCIIII").get_data(), "单个缺对角不能切出大块外角")

func test_wood_brick_glass_keep_borders_but_soil_stays_connected():
	assert_true(Auto.connects(Tiles.DIRT, Tiles.GRASS))
	assert_true(Auto.connects(Tiles.STONE, Tiles.COPPER_ORE))
	assert_true(Auto.connects(Tiles.PLANKS, Tiles.PLANKS))
	assert_false(Auto.connects(Tiles.PLANKS, 127))
	assert_false(Auto.connects(128, 129))
	assert_false(Auto.connects(Tiles.DIRT, Tiles.PLANKS))

func test_material_contact_fills_cracks_without_filling_air_edges():
	var source := Pack.source_image("Tiles_30.png")
	var cell := Pack.terrain_cell(source, "OOOO....")
	var interior := Pack.terrain_cell(source, "CCCCIIII")
	var filled := Pack._contact_cell(cell, interior, 2)
	for y in 16:
		assert_eq(filled.get_pixel(0, y), cell.get_pixel(0, y), "不填左侧空气")
		if interior.get_pixel(15, y).a > 0.0:
			assert_gt(filled.get_pixel(15, y).a, 0.0, "右侧实心接触不能露天")
	var layer := TileMapLayer.new()
	add_child_autofree(layer)
	layer.tile_set = Builder.build()
	var grid := Grid.new()
	grid.cells[Vector2i.ZERO] = Tiles.PLANKS
	grid.cells[Vector2i.RIGHT] = Tiles.STONE
	Auto.refresh_tile(layer, Vector2i.ZERO, Tiles.PLANKS, Auto.make_terrain_query(Tiles.PLANKS, grid), Auto.make_solid_query(grid))
	assert_eq(layer.get_cell_atlas_coords(Vector2i.ZERO), Pack.contact_atlas_coord(Blob.ATLAS_COORD[0], 2))
	grid.cells.erase(Vector2i.RIGHT)
	Auto.refresh_tile(layer, Vector2i.ZERO, Tiles.PLANKS, Auto.make_terrain_query(Tiles.PLANKS, grid), Auto.make_solid_query(grid))
	assert_eq(layer.get_cell_atlas_coords(Vector2i.ZERO), Blob.ATLAS_COORD[0], "挖开接触边后还原空气边")
