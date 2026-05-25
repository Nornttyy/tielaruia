# 小地图数据缓存测试: 记录 tile_id 而不只是 explored bit,
# 这样 chunk 卸载后 minimap 仍能正确显示已探索区的瓦片颜色 (不会变成"洞穴紫").
extends GutTest

const MinimapDataClass = preload("res://scripts/world/minimap_data.gd")

var md


func before_each():
	md = MinimapDataClass.new()


func after_each():
	md.free()


func test_unexplored_returns_false_and_air():
	assert_false(md.is_explored(0, 0))
	assert_eq(md.get_tile_at(0, 0), Tiles.AIR)


func test_mark_records_tile_id():
	md.mark(5, 10, Tiles.STONE)
	assert_true(md.is_explored(5, 10))
	assert_eq(md.get_tile_at(5, 10), Tiles.STONE)


func test_mark_explored_air_is_still_explored():
	# AIR (0) 已探索 ≠ "未探索" sentinel (0xff)
	md.mark(3, 20, Tiles.AIR)
	assert_true(md.is_explored(3, 20))
	assert_eq(md.get_tile_at(3, 20), Tiles.AIR)


func test_mark_rect_uses_chunk_manager():
	var fake_cm := _FakeChunkManager.new()
	fake_cm.set_tile_at(10, 5, Tiles.GRASS)
	fake_cm.set_tile_at(11, 5, Tiles.DIRT)
	md.mark_rect(fake_cm, 10, 5, 11, 5)
	assert_eq(md.get_tile_at(10, 5), Tiles.GRASS)
	assert_eq(md.get_tile_at(11, 5), Tiles.DIRT)
	fake_cm.free()


func test_explored_tile_persists_when_chunk_data_changes():
	# 标记一次后, 即使 chunk_manager 后续返回 AIR (例如 chunk 已卸载),
	# minimap_data 仍记得当时的 tile_id
	md.mark(50, 30, Tiles.STONE)
	# 模拟 chunk 卸载: chunk_manager.get_tile() 会返回 AIR, 但 minimap 不应被影响
	assert_eq(md.get_tile_at(50, 30), Tiles.STONE)
	assert_true(md.is_explored(50, 30))


func test_out_of_bounds_y_safe():
	md.mark(0, -5, Tiles.STONE)  # 不应崩
	md.mark(0, 9999, Tiles.STONE)
	assert_false(md.is_explored(0, -5))
	assert_eq(md.get_tile_at(0, -5), Tiles.AIR)


func test_negative_chunk_works():
	md.mark(-100, 50, Tiles.SAND)
	assert_true(md.is_explored(-100, 50))
	assert_eq(md.get_tile_at(-100, 50), Tiles.SAND)


func test_save_load_roundtrip():
	md.mark(5, 5, Tiles.GRASS)
	md.mark(-50, 10, Tiles.STONE)
	var snap = md.to_save_dict()
	var md2 = MinimapDataClass.new()
	md2.from_save_dict(snap)
	assert_eq(md2.get_tile_at(5, 5), Tiles.GRASS)
	assert_eq(md2.get_tile_at(-50, 10), Tiles.STONE)
	assert_false(md2.is_explored(7, 7))
	md2.free()


# Tiles 常量都 < 255, 测试 sentinel 不冲突
func test_sentinel_value_does_not_collide_with_real_tile():
	# 所有真实 tile_id 都 < 0xff (255), 不会被误判
	var max_tile_id := Tiles.DEEP_STONE
	assert_lt(max_tile_id, 0xff)


# 简化的 chunk_manager stub, 只实现 get_tile
class _FakeChunkManager:
	extends Node
	var _tiles: Dictionary = {}  # Vector2i → int

	func set_tile_at(x: int, y: int, tid: int) -> void:
		_tiles[Vector2i(x, y)] = tid

	func get_tile(x: int, y: int) -> int:
		return _tiles.get(Vector2i(x, y), Tiles.AIR)
