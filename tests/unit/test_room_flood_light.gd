extends GutTest

# 用户要的: 围起来的密闭空间=黑, 留个开口=天光从那灌满整个房间。
# 房间放在 y≈60 (过 SkyLightGrid 的 FLOATING_MAX_TOP_Y=50 浮岛阈值, 否则薄屋顶被当空岛绕过)。
const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")
const ROOF_Y := 60


class MockCM extends Node:
	var tiles: Dictionary = {}
	func _enter_tree() -> void:
		add_to_group("chunk_manager")
	func get_tile(x: int, y: int) -> int:
		return tiles.get(Vector2i(x, y), Tiles.AIR)


# 房间: 屋顶 ROOF_Y (x1..5) + 地板 ROOF_Y+4 + 左墙 x1 + 右墙 x5; 内部 x2..4 空气。
# open=true → 屋顶 (3,ROOF_Y) 留个洞 → 天光灌入。
func _build_room(open: bool) -> MockCM:
	var cm := MockCM.new()
	var floor_y := ROOF_Y + 4
	for x in range(1, 6):
		cm.tiles[Vector2i(x, ROOF_Y)] = Tiles.STONE
		cm.tiles[Vector2i(x, floor_y)] = Tiles.STONE
	for y in range(ROOF_Y, floor_y + 1):
		cm.tiles[Vector2i(1, y)] = Tiles.STONE
		cm.tiles[Vector2i(5, y)] = Tiles.STONE
	if open:
		cm.tiles.erase(Vector2i(3, ROOF_Y))
	return cm


func _room_corner_light(open: bool) -> int:
	var cm := _build_room(open)
	add_child_autofree(cm)
	SkyLightGrid.recompute_from([])
	var prev_t = TimeOfDay.time
	TimeOfDay.time = 0.5
	var y0 := ROOF_Y - 5
	var region: PackedByteArray = TileLightGrid.compute_region(cm, 0, y0, 6, ROOF_Y + 6, Vector2i(999, 999), [])
	TimeOfDay.time = prev_t
	SkyLightGrid.recompute_from([])
	# 房间内部远角 (4, ROOF_Y+3): index = (y-y0)*w + (x-0), w=6
	return region[(ROOF_Y + 3 - y0) * 6 + 4]


func test_room_with_opening_is_lit():
	assert_gt(_room_corner_light(true), 0, "屋顶有开口 → 天光灌进房间, 远角也亮")


func test_sealed_room_is_dark():
	assert_eq(_room_corner_light(false), 0, "完全围起来 → 房间内部全黑 (要火把)")
