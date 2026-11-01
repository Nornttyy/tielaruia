extends GutTest
const Foliage = preload("res://scripts/world/foliage_layer.gd")
const Builder = preload("res://scripts/world/tileset_builder.gd")
var terrain: TileMapLayer
var foliage: Node2D

func before_each():
	terrain = TileMapLayer.new()
	terrain.tile_set = Builder.build()
	add_child_autofree(terrain)
	foliage = Foliage.new()
	foliage.setup(null, terrain)
	add_child_autofree(foliage)
	foliage.set_process(false)
	terrain.set_cell(Vector2i(8, 9), Tiles.LOG_TOP, Vector2i.ZERO)
	terrain.set_cell(Vector2i(8, 10), Tiles.LOG, Vector2i.ZERO)
	terrain.set_cell(Vector2i(7, 11), Tiles.BRANCH_L, Vector2i.ZERO)
	terrain.set_cell(Vector2i(9, 11), Tiles.BRANCH_R, Vector2i.ZERO)
	terrain.set_cell(Vector2i(6, 15), Tiles.PLANT_GRASS, Vector2i.ZERO)

func test_camera_movement_does_not_move_pivots_or_restart_wind():
	foliage.wind_time = 7.4
	foliage._refresh_visible()
	var before: Array = foliage._visible_parts.duplicate(true)
	assert_eq(before.size(), 4)
	var camera := Camera2D.new()
	add_child_autofree(camera)
	for pos in [Vector2(50.3, 30.7), Vector2(80.9, 20.2)]:
		camera.position = pos
		camera.force_update_scroll()
		foliage._refresh_visible()
		assert_eq(foliage._visible_parts.size(), before.size())
		for i in before.size():
			var part: Dictionary = foliage._visible_parts[i]
			assert_eq(part.pivot, before[i].pivot, "镜头不能带动树根或树枝连接点")
			assert_eq(Foliage.sway_angle(foliage.wind_time, part.cell, part.tid), Foliage.sway_angle(7.4, before[i].cell, before[i].tid))
	assert_eq(Foliage.trunk_column(Vector2i(7, 11), Tiles.BRANCH_L), 8)
	assert_eq(Foliage.trunk_column(Vector2i(9, 11), Tiles.BRANCH_R), 8)

func test_chopped_crown_disappears_before_next_scan_and_stops_emitting():
	foliage._refresh_visible()
	var crown: Dictionary = foliage._visible_parts[0]
	assert_true(foliage._still_present(crown))
	terrain.erase_cell(crown.cell)
	assert_false(foliage._still_present(crown))
	foliage._spawn_leaf()
	assert_eq(foliage._leaves.size(), 0)

func test_leaves_are_bounded_and_expire():
	foliage._refresh_visible()
	for i in 100: foliage._spawn_leaf()
	assert_eq(foliage._leaves.size(), Foliage.MAX_LEAVES)
	foliage._advance_leaves(12.0)
	assert_eq(foliage._leaves.size(), 0)
	terrain.set_cell(Vector2i(8, 9), Tiles.LOG_TOP, Vector2i(0, 1))
	foliage._refresh_visible()
	foliage._spawn_leaf()
	assert_eq(foliage._leaves.size(), 0, "雪原枯枝不掉绿叶")

func test_soil_and_trunk_remain_visible_static_tiles():
	for tid in [Tiles.LOG, Tiles.GRASS]:
		var source: TileSetAtlasSource = terrain.tile_set.get_source(tid)
		assert_eq(source.get_tile_data(Vector2i.ZERO, 0).modulate.a, 1.0)
	foliage._refresh_visible()
	for part in foliage._visible_parts: assert_ne(part.tid, Tiles.LOG)
