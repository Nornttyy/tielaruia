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


func test_out_of_bounds():
	# 世界顶之上 (y<0) = 开阔天空, 有天光 (修"飞高头顶黑墙"); 世界底之下 (y>=256) = 地底, 无天光
	assert_true(grid.is_sky_exposed(0, -1), "世界顶之上是开阔天空, 该有天光")
	assert_false(grid.is_sky_exposed(0, 256))


func test_non_solid_tile_does_not_block():
	mock_cm.tiles[Vector2i(1, 3)] = Tiles.LEAVES  # leaves 不实心
	# leaves 不挡光: 下方仍亮
	assert_true(grid.is_sky_exposed(1, 5))


func test_floating_island_does_not_shadow_to_ground():
	# 空岛 (浮岛): 高空一薄层实心 (y 5..7), 下面一大段空气, y 90 才是真地面.
	# 阳光该绕过空岛 → 空岛和地面之间仍有天光, 不该一路黑到底.
	for y in range(5, 8):
		mock_cm.tiles[Vector2i(10, y)] = Tiles.STONE
	mock_cm.tiles[Vector2i(10, 90)] = Tiles.STONE  # 真地面
	# 空岛正上方 → 有天光
	assert_true(grid.is_sky_exposed(10, 2), "空岛上方该有天光")
	# 空岛和地面之间 (y 40) → 阳光绕过空岛, 该有天光 (修复前这里会是黑的)
	assert_true(grid.is_sky_exposed(10, 40), "空岛下方、地面上方该被阳光照到")
	# 真地面下方 (y 95) → 仍该是黑 (地下)
	assert_false(grid.is_sky_exposed(10, 95), "真地面下方该是黑的")


func test_real_ground_with_cave_below_still_shadows():
	# 保险: 真地面 (y 90 起一层土) 下面有个浅洞 (y 92 空气), 不能被误判成浮岛.
	# 地面在 y<50 之外 → 不进浮岛判断 → 地表下方照常变黑.
	mock_cm.tiles[Vector2i(20, 90)] = Tiles.DIRT
	mock_cm.tiles[Vector2i(20, 91)] = Tiles.DIRT
	# y 92 起是空气 (洞) → 但这不是高空浮岛, 不能让阳光灌进洞
	assert_false(grid.is_sky_exposed(20, 93), "地表下的洞仍该是黑的")
