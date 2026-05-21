extends GutTest

const SkyLightGridClass = preload("res://scripts/world/sky_light_grid.gd")

var grid
var mock_cm: Node


class MockChunkManager extends Node:
	# 简单 mock: tiles[Vector2i(x, y)] = tile_id; 未设 → AIR
	var tiles: Dictionary = {}

	func _enter_tree() -> void:
		add_to_group("chunk_manager")

	func get_tile(x: int, y: int) -> int:
		return tiles.get(Vector2i(x, y), Tiles.AIR)


func before_each():
	mock_cm = MockChunkManager.new()
	add_child_autofree(mock_cm)
	grid = SkyLightGridClass.new()
	add_child_autofree(grid)
	# 清掉 autoload SkyLightGrid 的缓存 (本测试 grid 是本地实例, 不污染 autoload)


func test_pure_air_is_all_lit():
	# 没设任何 tile → 全 AIR → 所有 y 都 exposed (top = WORLD_HEIGHT-1)
	for y in [0, 50, 100, 200]:
		assert_true(grid.is_sky_exposed(0, y), "(0, %d) 应有天光" % y)


func test_solid_blocks_light():
	mock_cm.tiles[Vector2i(3, 4)] = Tiles.STONE
	# (3, 4) 本身实心 → top_solid_y = 3 → exposed if y <= 3
	# 注意: is_sky_exposed(3, 4) = (4 <= 3) = false ✓
	assert_false(grid.is_sky_exposed(3, 4))
	# (3, 5) 被遮挡
	assert_false(grid.is_sky_exposed(3, 5))
	# (3, 3) 在 stone 上方一格 → exposed
	assert_true(grid.is_sky_exposed(3, 3))
	# 邻列 (2, 5) 不受影响 (邻列空气 → 全 exposed)
	assert_true(grid.is_sky_exposed(2, 5))


func test_invalidate_column_updates():
	mock_cm.tiles[Vector2i(2, 3)] = Tiles.STONE
	assert_false(grid.is_sky_exposed(2, 5))
	# 移除遮挡
	mock_cm.tiles.erase(Vector2i(2, 3))
	grid.invalidate_column(2)
	assert_true(grid.is_sky_exposed(2, 5))


func test_out_of_bounds_returns_false():
	# y 越界
	assert_false(grid.is_sky_exposed(0, -1))
	assert_false(grid.is_sky_exposed(0, 256))


func test_non_solid_tile_does_not_block():
	mock_cm.tiles[Vector2i(1, 3)] = Tiles.LEAVES  # leaves 不实心
	# leaves 不挡光: 下方仍亮
	assert_true(grid.is_sky_exposed(1, 5))
