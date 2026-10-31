extends GutTest
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Light = preload("res://scripts/world/color_light_grid.gd")

class CM extends Node:
	var tiles := {}
	func _enter_tree(): add_to_group("chunk_manager")
	func get_tile(x: int, y: int) -> int: return tiles.get(Vector2i(x, y), Tiles.AIR)

var cm: CM
var saved_time: float
func before_each():
	cm = CM.new()
	add_child_autofree(cm)
	saved_time = TimeOfDay.time
	TimeOfDay.time = 0.5
	SkyLightGrid.recompute_from([])
func after_each():
	TimeOfDay.time = saved_time
	SkyLightGrid.recompute_from([])

func test_female_uses_distinct_clothed_body_for_idle_walk_and_actions():
	for frame in [0, 5, 6, 12, 19]:
		var male := Pack.player_frame({"gender": 0, "hair_style": 0}, frame).get_image()
		var female := Pack.player_frame({"gender": 1, "hair_style": 0}, frame).get_image()
		assert_ne(male.get_region(Rect2i(8, 21, 19, 15)).get_data(), female.get_region(Rect2i(8, 21, 19, 15)).get_data())
		assert_eq(female.get_size(), Vector2i(32, 44))
	assert_ne(Pack.action_frame({"gender": 0}, 0, "swing", 1, 0).get_image().get_data(), Pack.action_frame({"gender": 1}, 0, "swing", 1, 0).get_image().get_data())

func test_full_hair_catalog_has_real_nonempty_source_frames():
	var ids := {}
	for i in Pack.hair_count():
		var id := Pack.hair_id(i)
		ids[id] = true
		assert_not_null(Pack.source_image("Player_Hair_%d.png" % id))
	assert_eq(ids.size(), 165)
	var short := Pack.player_frame({"hair_style": 0}, 0).get_image()
	var long := Pack.player_frame({"hair_style": 4}, 0).get_image()
	assert_ne(short.get_data(), long.get_data())

func _pixel(grid: PackedByteArray, index: int) -> Vector3:
	return Vector3(grid[index * 4], grid[index * 4 + 1], grid[index * 4 + 2])

func test_water_gets_darker_and_bluer_with_depth_even_when_camera_moves():
	for x in range(-30, 31):
		for y in range(60, 101): cm.tiles[Vector2i(x, y)] = Tiles.WATER
	var grid := Light.compute_region(cm, -8, 55, 9, 100)
	var surface := _pixel(grid, (60 - 55) * 17 + 8)
	var deep := _pixel(grid, (85 - 55) * 17 + 8)
	assert_gt(surface.x, deep.x)
	assert_gt(surface.z, deep.z)
	assert_gt(deep.z, deep.x * 3.0)
	var shifted := Light.compute_region(cm, -8, 75, 9, 100)
	assert_eq(_pixel(shifted, (85 - 75) * 17 + 8), deep, "深水明暗不依赖镜头起点")

func test_sealed_room_stays_dark_and_torch_is_warm():
	for x in range(-30, 31): cm.tiles[Vector2i(x, 60)] = Tiles.STONE
	var unlit := Light.compute_region(cm, -10, 55, 11, 85)
	assert_eq(_pixel(unlit, (70 - 55) * 21 + 10), Vector3.ZERO)
	cm.tiles[Vector2i(0, 70)] = Tiles.TORCH
	var lit := Light.compute_region(cm, -10, 55, 11, 85)
	var near := _pixel(lit, (70 - 55) * 21 + 13)
	assert_gt(near.x, near.y)
	assert_gt(near.y, near.z)
	assert_gt(near.x, _pixel(lit, (70 - 55) * 21 + 20).x)

func test_opening_admits_daylight_and_solid_rock_blocks_lamps():
	for x in range(-30, 31): cm.tiles[Vector2i(x, 60)] = Tiles.STONE
	cm.tiles.erase(Vector2i(0, 60))
	SkyLightGrid.recompute_from([])
	var open := Light.compute_region(cm, -10, 55, 11, 85)
	assert_gt(_pixel(open, (65 - 55) * 21 + 13).x, 100.0)
	assert_eq(Light.emission(Tiles.STONE), Vector3.ZERO)
	assert_gt(Light.emission(Tiles.LAVA).x, Light.emission(Tiles.LAVA).z)

func test_day_night_light_has_color():
	TimeOfDay.time = 0.5
	assert_eq(Light.sky_color(), Vector3.ONE)
	TimeOfDay.time = 0.0
	assert_gt(Light.sky_color().z, Light.sky_color().x)

func test_thick_living_tree_canopy_does_not_cast_black_columns():
	for y in range(20, 60): cm.tiles[Vector2i(0, y)] = Tiles.LIVING_LEAF
	var grid := Light.compute_region(cm, -1, 15, 2, 75)
	assert_gt(_pixel(grid, (65 - 15) * 3 + 1).x, 220.0)
