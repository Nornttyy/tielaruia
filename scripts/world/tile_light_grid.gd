# 瓦片级光照: 两套 BFS 扩散 (Terraria 风).
#   Pass 1 (天光): 高衰减 — 挖个洞不会让天光灌满深处. ATTEN_AIR=3.
#   Pass 2 (火把+玩家): 低衰减 — 火把照亮一片. ATTEN_AIR=1.
# 最终每 tile 取两 pass 的 max.
#
# 光值 0..15. 数值越大越亮.
extends RefCounted

const MAX_LIGHT := 15
const PLAYER_LIGHT := 5
const TORCH_LIGHT := 14

# 天光: 穿空气衰减很大, 模拟"洞穴里没几格就黑"
const SKY_ATTEN_AIR := 3
const SKY_ATTEN_SOLID := 4

# 火把/玩家: 穿空气慢衰减, 火把能照亮一圈
const PT_ATTEN_AIR := 1
const PT_ATTEN_SOLID := 3


static func compute_region(chunk_manager: Node, x0: int, y0: int, x1: int, y1: int,
		player_tile: Vector2i, torch_tiles: Array) -> Dictionary:
	var sky_light: int = TimeOfDay.sky_light_level()
	# Pass 1: 天光. 所有 sky_exposed tile 作为源, 高衰减扩散.
	var sky_grid: Dictionary = {}
	var sky_queue: Array = []
	for x in range(x0, x1):
		for y in range(y0, y1):
			if SkyLightGrid.is_sky_exposed(x, y):
				var p := Vector2i(x, y)
				sky_grid[p] = sky_light
				sky_queue.append(p)
	_bfs(chunk_manager, x0, y0, x1, y1, sky_grid, sky_queue, SKY_ATTEN_AIR, SKY_ATTEN_SOLID)

	# Pass 2: 火把 + 玩家. 独立 BFS, 低衰减.
	var pt_grid: Dictionary = {}
	var pt_queue: Array = []
	for t in torch_tiles:
		var tp: Vector2i = t
		if tp.x < x0 or tp.x >= x1 or tp.y < y0 or tp.y >= y1:
			continue
		pt_grid[tp] = TORCH_LIGHT
		pt_queue.append(tp)
	if player_tile.x >= x0 and player_tile.x < x1 and player_tile.y >= y0 and player_tile.y < y1:
		if int(pt_grid.get(player_tile, 0)) < PLAYER_LIGHT:
			pt_grid[player_tile] = PLAYER_LIGHT
			pt_queue.append(player_tile)
	_bfs(chunk_manager, x0, y0, x1, y1, pt_grid, pt_queue, PT_ATTEN_AIR, PT_ATTEN_SOLID)

	# 合并: 每 tile 取两 pass 的 max
	var out: Dictionary = sky_grid
	for k in pt_grid.keys():
		var v: int = int(pt_grid[k])
		if int(out.get(k, 0)) < v:
			out[k] = v
	return out


# BFS 内部. 把 queue 里的 tile 按衰减规则扩散到邻居.
# 性能: 用 pop_back() (O(1)) 不用 pop_front() (O(n)). max-decrement 算法跟顺序无关,
# DFS/BFS 顺序换都 OK; 但 pop_front 在 Godot Array 上每次平移整个数组, 万级 tile 时
# 是 perf 杀手 (jump/fall 时大卡顿主因).
static func _bfs(chunk_manager: Node, x0: int, y0: int, x1: int, y1: int,
		grid: Dictionary, queue: Array, atten_air: int, atten_solid: int) -> void:
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var pos: Vector2i = queue.pop_back()
		var cur: int = int(grid[pos])
		if cur <= 1:
			continue
		for d in dirs:
			var np: Vector2i = pos + d
			if np.x < x0 or np.x >= x1 or np.y < y0 or np.y >= y1:
				continue
			var tid: int = chunk_manager.get_tile(np.x, np.y)
			var is_wall: bool = tid != Tiles.AIR and Tiles.is_solid(tid)
			var atten: int = atten_solid if is_wall else atten_air
			var nv: int = cur - atten
			if nv > 0 and int(grid.get(np, 0)) < nv:
				grid[np] = nv
				queue.append(np)
