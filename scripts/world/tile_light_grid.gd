# 瓦片级光照: BFS 扩散 (Terraria 风).
# 光值 0..MAX_LIGHT (15). 来源:
#   - 天空暴露 tile: TimeOfDay.sky_light_level() (15 白天 / 4 夜间 lerp)
#   - 火把 tile: TORCH_LIGHT 14
#   - 玩家 tile: PLAYER_LIGHT 5 (小范围辅助光)
#
# 扩散: 每往邻居走一步, 空气 -1, 实心墙 -3. 光自然被墙挡住.
# 入口: compute_region(chunk_manager, x0, y0, x1, y1, player_tile, torch_tiles) → Dict {Vector2i: int}
extends RefCounted

const MAX_LIGHT := 15
const PLAYER_LIGHT := 5
const TORCH_LIGHT := 14
const ATTEN_AIR := 1
const ATTEN_SOLID := 3   # 墙吃光更多, 但不至于一格全挡死


# 计算 [x0, x1) × [y0, y1) 区域每个 tile 的光值. BFS 起点 = 区域内所有源点.
# chunk_manager 用于查 tile 类型 (判断墙 vs 空气).
static func compute_region(chunk_manager: Node, x0: int, y0: int, x1: int, y1: int,
		player_tile: Vector2i, torch_tiles: Array) -> Dictionary:
	var grid: Dictionary = {}
	var queue: Array = []
	var sky_light: int = TimeOfDay.sky_light_level()
	# 1. 天空暴露 tile 直接置为 sky_light + 入队作为扩散源
	for x in range(x0, x1):
		for y in range(y0, y1):
			if SkyLightGrid.is_sky_exposed(x, y):
				var p := Vector2i(x, y)
				grid[p] = sky_light
				queue.append(p)
	# 2. 火把源
	for t in torch_tiles:
		var tp: Vector2i = t
		if tp.x < x0 or tp.x >= x1 or tp.y < y0 or tp.y >= y1:
			continue
		if int(grid.get(tp, 0)) < TORCH_LIGHT:
			grid[tp] = TORCH_LIGHT
			queue.append(tp)
	# 3. 玩家源
	if player_tile.x >= x0 and player_tile.x < x1 and player_tile.y >= y0 and player_tile.y < y1:
		if int(grid.get(player_tile, 0)) < PLAYER_LIGHT:
			grid[player_tile] = PLAYER_LIGHT
			queue.append(player_tile)
	# 4. BFS 扩散
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_front()
		var cur: int = int(grid[pos])
		if cur <= 1:
			continue
		for d in dirs:
			var np: Vector2i = pos + d
			if np.x < x0 or np.x >= x1 or np.y < y0 or np.y >= y1:
				continue
			var tid: int = chunk_manager.get_tile(np.x, np.y)
			var is_wall: bool = tid != Tiles.AIR and Tiles.is_solid(tid)
			var atten: int = ATTEN_SOLID if is_wall else ATTEN_AIR
			var nv: int = cur - atten
			if nv > 0 and int(grid.get(np, 0)) < nv:
				grid[np] = nv
				queue.append(np)
	return grid
