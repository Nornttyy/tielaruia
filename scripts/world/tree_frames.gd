# 树干连接帧由现有邻格决定；不修改存档中的方块编号。
extends RefCounted

const PARTS := [Tiles.LOG, Tiles.LOG_TOP, Tiles.BRANCH_L, Tiles.BRANCH_R, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R]

static func frame(pos: Vector2i, tile_id: int, world: Object = null) -> Vector2i:
	var variant := posmod(pos.x * 73856093 + pos.y * 19349663, 3)
	var joint := 0
	if tile_id == Tiles.LOG and world != null:
		var left: int = _tree_tile(world, pos.x - 1, pos.y)
		var right: int = _tree_tile(world, pos.x + 1, pos.y)
		if left == Tiles.BRANCH_L: joint |= 1
		if right == Tiles.BRANCH_R: joint |= 2
		if left == Tiles.LOG_ROOT_L or right == Tiles.LOG_ROOT_R:
			joint = 4 + (1 if left == Tiles.LOG_ROOT_L else 0) + (2 if right == Tiles.LOG_ROOT_R else 0)
	var style := _root_style(pos, tile_id, world)
	return Vector2i(variant, joint + style * (8 if tile_id == Tiles.LOG else 1))

static func _tree_tile(world: Object, x: int, y: int) -> int:
	var tid: int = world.get_tile(x, y)
	if Tiles.is_water(tid) and world.has_method("get_submerged"):
		var plant: int = world.get_submerged(x, y)
		if plant >= 0: return plant
	return tid

static func _root_style(pos: Vector2i, tile_id: int, world: Object) -> int:
	if world == null: return 0
	var x := pos.x
	if tile_id in [Tiles.BRANCH_L, Tiles.LOG_ROOT_L]: x += 1
	elif tile_id in [Tiles.BRANCH_R, Tiles.LOG_ROOT_R]: x -= 1
	for y in range(pos.y + 1, mini(pos.y + 55, 256)):
		var ground := _tree_tile(world, x, y)
		if ground in PARTS: continue
		match ground:
			Tiles.SNOW, Tiles.ICE: return 1
			Tiles.JUNGLE_GRASS, Tiles.JUNGLE_DIRT, Tiles.MUD: return 2
			Tiles.CORRUPT_GRASS, Tiles.EBONSTONE: return 3
			Tiles.CRIMSON_GRASS, Tiles.CRIMSTONE: return 4
		return 0
	return 0
