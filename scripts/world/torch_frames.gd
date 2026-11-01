# Torch attachment is derived from world data, so loading and multiplayer use
# the same orientation without adding a new tile ID or changing old saves.
extends RefCounted

const UPRIGHT := 0
const LEFT_WALL := 1
const RIGHT_WALL := 2

static func floor_support(tid: int) -> bool:
	return (Tiles.is_solid(tid) and not Tiles.is_slope(tid)) or tid == Tiles.WOOD_PLATFORM

static func side_support(tid: int, left: bool) -> bool:
	if Tiles.is_slope(tid):
		return tid == (Tiles.GRASS_SLOPE_R if left else Tiles.GRASS_SLOPE_L)
	return Tiles.is_solid(tid) or tid in [Tiles.LOG, Tiles.LOG_TOP, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R, Tiles.WOOD_PLATFORM]

static func attachment(pos: Vector2i, grid: Object) -> int:
	if grid == null: return -1
	if floor_support(grid.get_tile(pos.x, pos.y + 1)): return UPRIGHT
	if side_support(grid.get_tile(pos.x - 1, pos.y), true): return LEFT_WALL
	if side_support(grid.get_tile(pos.x + 1, pos.y), false): return RIGHT_WALL
	if grid.get_wall(pos.x, pos.y) != Tiles.AIR: return UPRIGHT
	return -1

static func frame(pos: Vector2i, grid: Object) -> Vector2i:
	return Vector2i(maxi(0, attachment(pos, grid)), 0)
