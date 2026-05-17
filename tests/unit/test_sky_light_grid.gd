extends GutTest

const SkyLightGridClass = preload("res://scripts/world/sky_light_grid.gd")
var grid


func before_each():
	grid = SkyLightGridClass.new()
	add_child_autofree(grid)


func _make_tiles(w: int, h: int, default_id: int) -> Array:
	var t := []
	t.resize(w)
	for x in w:
		var col := []
		col.resize(h)
		col.fill(default_id)
		t[x] = col
	return t


func test_pure_air_is_all_lit():
	var tiles = _make_tiles(8, 8, Tiles.AIR)
	grid.recompute_from(tiles)
	for x in 8:
		for y in 8:
			assert_true(grid.is_sky_exposed(x, y), "(%d,%d) 应有天光" % [x, y])


func test_solid_blocks_light():
	var tiles = _make_tiles(8, 8, Tiles.AIR)
	tiles[3][4] = Tiles.STONE
	grid.recompute_from(tiles)
	# (3, 4) 本身实心，不算 sky_exposed
	assert_false(grid.is_sky_exposed(3, 4))
	# (3, 5) 及以下都被遮挡
	assert_false(grid.is_sky_exposed(3, 5))
	assert_false(grid.is_sky_exposed(3, 7))
	# 邻列不受影响
	assert_true(grid.is_sky_exposed(2, 5))


func test_invalidate_column_updates():
	var tiles = _make_tiles(8, 8, Tiles.AIR)
	tiles[2][3] = Tiles.STONE
	grid.recompute_from(tiles)
	assert_false(grid.is_sky_exposed(2, 5))
	# 移除遮挡
	tiles[2][3] = Tiles.AIR
	grid.invalidate_column(2, tiles)
	assert_true(grid.is_sky_exposed(2, 5))


func test_out_of_bounds_returns_false():
	var tiles = _make_tiles(8, 8, Tiles.AIR)
	grid.recompute_from(tiles)
	assert_false(grid.is_sky_exposed(-1, 0))
	assert_false(grid.is_sky_exposed(8, 0))
	assert_false(grid.is_sky_exposed(0, -1))
	assert_false(grid.is_sky_exposed(0, 8))


func test_non_solid_tile_does_not_block():
	var tiles = _make_tiles(8, 8, Tiles.AIR)
	tiles[1][3] = Tiles.LEAVES  # leaves 不实心
	grid.recompute_from(tiles)
	# leaves 不挡光：下方仍亮
	assert_true(grid.is_sky_exposed(1, 5))
