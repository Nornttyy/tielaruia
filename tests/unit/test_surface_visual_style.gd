extends GutTest

const MountainsLayer = preload("res://scripts/world/mountains_layer.gd")
const MountainsArt = preload("res://scripts/art/mountains_art.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")
const LightGrid = preload("res://scripts/world/tile_light_grid.gd")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")


class SolidTestWorld extends Node:
	func get_tile(x: int, y: int) -> int:
		return 3 if x < 4 and y >= 1 else 0


func test_daytime_texture_is_not_tinted_twice() -> void:
	var layer = MountainsLayer.new()
	var base := Color(0.30, 0.40, 0.30)
	var tint: Color = layer._texture_tint(base, 1.0, Color.SKY_BLUE)
	assert_almost_eq(tint.r, 1.0, 0.0001)
	assert_almost_eq(tint.g, 1.0, 0.0001)
	assert_almost_eq(tint.b, 1.0, 0.0001)
	layer.free()


func test_ridge_bottom_matches_fill_during_day_and_night() -> void:
	var layer = MountainsLayer.new()
	var base := Color(0.55, 0.62, 0.75)
	for day in [0.0, 0.4, 1.0]:
		var tint: Color = layer._texture_tint(base, day, Color(0.04, 0.05, 0.12))
		var fill: Color = layer._atmos(base, day, Color(0.04, 0.05, 0.12))
		var actual: Color = base * tint
		assert_almost_eq(actual.r, fill.r, 0.0001)
		assert_almost_eq(actual.g, fill.g, 0.0001)
		assert_almost_eq(actual.b, fill.b, 0.0001)
	layer.free()


func test_forest_and_mountain_heights_wrap_without_a_cliff() -> void:
	for style in ["mountain", "forest"]:
		for seed_value in [1001, 1018, 1035]:
			var heights: Array = MountainsArt._profile_for_style(style, 1280, seed_value)
			assert_almost_eq(float(heights[0]), float(heights[-1]), 0.0001)


func test_mountain_bottom_row_keeps_unshaded_base_color() -> void:
	var base := Color8(140, 158, 191)
	var img: Image = MountainsArt.generate_biome_ridge(128, 64, "mountain", base, false, 42).get_image()
	for x in img.get_width():
		assert_eq(img.get_pixel(x, 63), base)


func test_crowns_are_broad_and_leave_room_for_trunks() -> void:
	for kind in WorldGenerator._CANOPY_REACH:
		var offsets: Array = WorldGenerator._canopy_offsets(kind)
		var left := 99
		var right := -99
		for offset: Vector2i in offsets:
			left = mini(left, offset.x)
			right = maxi(right, offset.x)
			assert_lte(absi(offset.x), 4, "树冠必须在新区块安全边距内")
			assert_gte(offset.y, -int(WorldGenerator._CANOPY_REACH[kind]))
		assert_gte(right - left + 1, 7, "横向至少七格，不再画成窄箭头")
		assert_false(offsets.has(Vector2i.ZERO), "不能覆盖树干顶帽")


func test_solid_rim_fades_without_lighting_sealed_air() -> void:
	var world = autofree(SolidTestWorld.new())
	var grid := PackedByteArray()
	grid.resize(5 * 7)
	grid[1 * 5 + 2] = 11
	LightGrid._shade_solid_edges(world, 0, 0, 5, 7, grid)
	assert_eq(grid[2 * 5 + 2], 7, "第二层土仍可见")
	assert_eq(grid[3 * 5 + 2], 3, "第三层渐暗")
	assert_eq(grid[4 * 5 + 2], 0, "深处仍然黑暗")
	for y in 7:
		assert_eq(grid[y * 5 + 4], 0, "补光不从土石透到背后的空气")


func test_canopy_connects_to_the_trunk_cap_without_a_hole() -> void:
	var chunk = WorldGenerator.empty_chunk(0, 64)
	chunk.tiles[20][20] = Tiles.LOG_TOP
	WorldGenerator._place_canopy_chunk(chunk, 20, 20, "oak_cloud_med", Tiles.LEAVES, 0, 64, 64)
	assert_eq(chunk.tiles[20][19], Tiles.LEAVES, "顶帽上必须有树叶，不应留一个方形天窗")
	assert_eq(chunk.tiles[20][20], Tiles.LOG_TOP, "树冠不能覆盖顶帽")


func test_redrawn_patterns_have_no_missing_palette_pixels() -> void:
	for tid in [BlocksArt.DIRT, BlocksArt.LOG, BlocksArt.LEAVES]:
		var img: Image = BlocksArt.get_texture(tid).get_image()
		assert_eq(img.get_size(), Vector2i(16, 16))
		var holes := 0
		for y in 16:
			for x in 16:
				if img.get_pixel(x, y).a < 0.99:
					holes += 1
		assert_eq(holes, 0, "完整材质不应因为字符缺失漏成透明")


func test_spawn_uses_its_actual_height_as_the_fall_origin() -> void:
	var player = load("res://scenes/player/player.tscn").instantiate()
	player.position = Vector2(126, 1380)
	add_child_autofree(player)
	player.set_physics_process(false)
	assert_almost_eq(float(player._fall_peak_y), 1380.0, 0.01, "不能把出生误算成从地图顶部跌落")
