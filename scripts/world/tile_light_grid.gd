# 瓦片级光照: 两套 BFS 扩散 (Terraria 风).
#   Pass 1 (天光): 高衰减 — 挖个洞不会让天光灌满深处. ATTEN_AIR=3.
#   Pass 2 (火把+玩家): 低衰减 — 火把照亮一片. ATTEN_AIR=1.
# 最终每 tile 取两 pass 的 max.
#
# 光值 0..15. 数值越大越亮.
#
# 性能: 用 PackedByteArray + 整数索引 ((y - y0) * width + (x - x0)) 替代 Vector2i dict.
# 老版每次 BFS 21k tile × 4 邻居 = 84k Vector2i alloc + hash, 60-140ms/s 主要卡顿源.
# 新版纯整数索引 + PackedByteArray 索引访问 (C-level), perf 大幅省.
extends RefCounted

const MAX_LIGHT := 15
const PLAYER_LIGHT := 5
const TORCH_LIGHT := 14

# 战斗房全亮 (用户: 战斗时光照遮挡视野). 置 true → compute_region 整片返回 MAX_LIGHT,
# 黑暗层 alpha 全 0 = 没有黑. main.gd 进/出对战房竞技场时开关. static = 全局共享 (compute_region 是 static).
static var force_full_bright: bool = false

# 天光: 沿空气低衰减 (从开口灌满整个房间), 但配合 _bfs 的 no_spread_from_solid =
# "实心块只接收光不再外传" → 围起来的密闭空间=黑, 留个开口=光从那灌满里面 (用户要的效果).
# 实心块本身仍受光 (墙面/地表会亮), SKY_ATTEN_SOLID 控它接收到多亮.
const SKY_ATTEN_AIR := 1
const SKY_ATTEN_SOLID := 4

# 火把/玩家: 穿空气慢衰减, 火把能照亮一圈
const PT_ATTEN_AIR := 1
const PT_ATTEN_SOLID := 3


# 返回 PackedByteArray (width * height), 索引 = (y - y0) * width + (x - x0).
# 值 = 该 tile 的光强 (0-15).
# x0, y0 inclusive; x1, y1 exclusive. width = x1 - x0, height = y1 - y0.
static func compute_region(chunk_manager: Node, x0: int, y0: int, x1: int, y1: int,
		player_tile: Vector2i, torch_tiles: Array) -> PackedByteArray:
	var w: int = x1 - x0
	var h: int = y1 - y0
	var size: int = w * h
	# 战斗房全亮: 整片填满最高光值 → 黑暗层 alpha 全 0, 不挡视野. (跳过两套 BFS)
	if force_full_bright:
		var bright: PackedByteArray = PackedByteArray()
		bright.resize(size)
		bright.fill(MAX_LIGHT)
		return bright
	# Pass 1: 天光.
	var sky: PackedByteArray = PackedByteArray()
	sky.resize(size)
	# PackedByteArray 默认全 0, 不用 fill.
	var sky_queue: PackedInt32Array = PackedInt32Array()
	var sky_light: int = TimeOfDay.sky_light_level()
	for x in range(x0, x1):
		for y in range(y0, y1):
			if SkyLightGrid.is_sky_exposed(x, y):
				var idx: int = (y - y0) * w + (x - x0)
				sky[idx] = sky_light
				sky_queue.append(idx)
	# 天光: no_spread_from_solid=true → 实心块接到光但不往后传 (墙挡住, 不漏进墙后的密闭空间)
	_bfs(chunk_manager, x0, y0, w, h, sky, sky_queue, SKY_ATTEN_AIR, SKY_ATTEN_SOLID, true)

	# Pass 2: 火把 + 玩家. 独立 BFS, 低衰减.
	var pt: PackedByteArray = PackedByteArray()
	pt.resize(size)
	var pt_queue: PackedInt32Array = PackedInt32Array()
	for t in torch_tiles:
		var tp: Vector2i = t
		if tp.x < x0 or tp.x >= x1 or tp.y < y0 or tp.y >= y1:
			continue
		var ti: int = (tp.y - y0) * w + (tp.x - x0)
		pt[ti] = TORCH_LIGHT
		pt_queue.append(ti)
	if player_tile.x >= x0 and player_tile.x < x1 and player_tile.y >= y0 and player_tile.y < y1:
		var pi: int = (player_tile.y - y0) * w + (player_tile.x - x0)
		if pt[pi] < PLAYER_LIGHT:
			pt[pi] = PLAYER_LIGHT
			pt_queue.append(pi)
	# 火把/玩家: 照常穿空气+少量穿墙 (no_spread_from_solid=false) → 火把放墙缝也能透一点
	_bfs(chunk_manager, x0, y0, w, h, pt, pt_queue, PT_ATTEN_AIR, PT_ATTEN_SOLID, false)

	# 合并: 每 tile 取 max(sky, pt) (合并写回 sky)
	for i in range(size):
		if pt[i] > sky[i]:
			sky[i] = pt[i]
	return sky


# BFS 内部. 把 queue 里的索引按衰减规则扩散到邻居.
# 用 pop_back() (O(1)) 不用 pop_front() (O(n)). max-decrement 算法跟顺序无关.
static func _bfs(chunk_manager: Node, x0: int, y0: int, w: int, h: int,
		grid: PackedByteArray, queue: PackedInt32Array,
		atten_air: int, atten_solid: int, no_spread_from_solid: bool = false) -> void:
	while not queue.is_empty():
		var idx: int = queue[queue.size() - 1]
		queue.remove_at(queue.size() - 1)
		var cur: int = grid[idx]
		if cur <= 1:
			continue
		# 由 idx 反推 lx, ly (区域局部坐标)
		var ly: int = idx / w
		var lx: int = idx % w
		# 天光: 实心块接到光后不再往外传 (墙挡光). 它自己保留亮度渲染, 但不把光漏给后面的格.
		if no_spread_from_solid:
			var ctid: int = chunk_manager.get_tile(x0 + lx, y0 + ly)
			if ctid != Tiles.AIR and Tiles.is_solid(ctid):
				continue
		# 4 个方向: 右 / 左 / 下 / 上 (lx+1, lx-1, ly+1, ly-1)
		# 边界检查直接用 lx, ly (省去 - x0)
		# 右
		if lx + 1 < w:
			_try_spread(chunk_manager, x0 + lx + 1, y0 + ly, idx + 1, cur, grid, queue, atten_air, atten_solid)
		# 左
		if lx > 0:
			_try_spread(chunk_manager, x0 + lx - 1, y0 + ly, idx - 1, cur, grid, queue, atten_air, atten_solid)
		# 下
		if ly + 1 < h:
			_try_spread(chunk_manager, x0 + lx, y0 + ly + 1, idx + w, cur, grid, queue, atten_air, atten_solid)
		# 上
		if ly > 0:
			_try_spread(chunk_manager, x0 + lx, y0 + ly - 1, idx - w, cur, grid, queue, atten_air, atten_solid)


# 尝试把 cur 衰减后的值塞给邻居. inline 避免函数调成本太高时改 macro.
static func _try_spread(chunk_manager: Node, wx: int, wy: int, n_idx: int, cur: int,
		grid: PackedByteArray, queue: PackedInt32Array,
		atten_air: int, atten_solid: int) -> void:
	var tid: int = chunk_manager.get_tile(wx, wy)
	var atten: int = atten_solid if (tid != Tiles.AIR and Tiles.is_solid(tid)) else atten_air
	var nv: int = cur - atten
	if nv > 0 and grid[n_idx] < nv:
		grid[n_idx] = nv
		queue.append(n_idx)
