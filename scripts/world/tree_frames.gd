# 树干连接帧由现有邻格决定；不修改存档中的方块编号。
extends RefCounted

const PARTS := [Tiles.LOG, Tiles.LOG_TOP, Tiles.BRANCH_L, Tiles.BRANCH_R, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R]

static func frame(pos: Vector2i, tile_id: int, world: Object = null) -> Vector2i:
	var variant := posmod(pos.x * 73856093 + pos.y * 19349663, 3)
	var joint := 0
	if tile_id == Tiles.LOG and world != null:
		var left: int = world.get_tile(pos.x - 1, pos.y)
		var right: int = world.get_tile(pos.x + 1, pos.y)
		if left == Tiles.BRANCH_L: joint |= 1
		if right == Tiles.BRANCH_R: joint |= 2
		if left == Tiles.LOG_ROOT_L or right == Tiles.LOG_ROOT_R:
			joint = 4 + (1 if left == Tiles.LOG_ROOT_L else 0) + (2 if right == Tiles.LOG_ROOT_R else 0)
	return Vector2i(variant, joint)
