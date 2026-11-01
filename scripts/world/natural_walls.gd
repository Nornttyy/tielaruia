# 天然墙比地形外轮廓内缩一格。只在生成时处理，之后挖土不会自动拆墙。
extends RefCounted

const NATURAL := [Tiles.GRASS_WALL, Tiles.DIRT_WALL, Tiles.STONE_WALL,
	Tiles.EBON_WALL, Tiles.CRIM_WALL, Tiles.DESERT_WALL, Tiles.MUSHROOM_WALL]

static func inset(c: Chunk) -> void:
	var width := c.tiles.size()
	var height: int = c.tiles[0].size()
	# 裂谷、湖岸和地形整平发生在初次填墙之后，不能留下悬在天空中的土墙。
	for x in width:
		for y in height:
			if Tiles.is_solid(c.tiles[x][y]): break
			if c.walls[x][y] in NATURAL: c.walls[x][y] = Tiles.AIR
	var original: Array = c.walls.duplicate(true)
	# 保留未内缩的边界，等相邻区块到达时只补算接缝，不能反复侵蚀。
	c.natural_wall_edges = [original[0].duplicate(), original[width - 1].duplicate()]
	for x in width:
		for y in height:
			if original[x][y] not in NATURAL: continue
			var exposed := false
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var nx := x + dx
					var ny: int = y + dy
					if nx < 0 or nx >= width: continue
					if ny < 0 or ny >= height or original[nx][ny] == Tiles.AIR:
						exposed = true
				if exposed: break
			if exposed: c.walls[x][y] = Tiles.AIR

static func join(left: Chunk, right: Chunk, left_edits: Dictionary, right_edits: Dictionary) -> void:
	if left.natural_wall_edges.size() != 2 or right.natural_wall_edges.size() != 2: return
	_trim_edge(left, left.tiles.size() - 1, right.natural_wall_edges[0], left_edits)
	_trim_edge(right, 0, left.natural_wall_edges[1], right_edits)

static func _trim_edge(c: Chunk, x: int, neighbor: Array, edits: Dictionary) -> void:
	for y in c.walls[x].size():
		if c.walls[x][y] not in NATURAL or edits.has(Vector2i(x, y)): continue
		for ny in range(maxi(0, y - 1), mini(neighbor.size(), y + 2)):
			if neighbor[ny] == Tiles.AIR:
				c.walls[x][y] = Tiles.AIR
				break
