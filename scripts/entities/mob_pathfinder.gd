# 平台跳跃 A* 寻路 (怪物用)。节点 = 一个"站立格"(脚所在的空气格, 脚下是实心地、头顶也空);
# 边 = 怪能做的动作: 走一格 / 跳上(≤JUMP_H 格) / 跨 1 格坑 / 走下边沿掉落(≤MAX_DROP 格)。
# find_path 返回站立格路点 (start→goal, 不含 start, 含 goal); 找不到/太远返回空数组 → 怪退回反应式追击。
#
# 性能: MAX_NODES 封顶展开数 (超了放弃), 怪那边再节流 (每 ~0.6s 才算一次), 多怪也不卡死。
# 测试可注入 stub (有 get_tile 的对象 + Tiles), 不依赖真世界。
extends RefCounted

const JUMP_H := 2        # 怪能跳上几格 (zombie 跳高 ≈ 2.3 格)
const MAX_DROP := 6      # 怪能安全下落几格 (再高也敢跳, 反正落地)
const MAX_NODES := 320   # A* 展开上限, 超了认定"太远/太复杂"放弃
const SEARCH_GOAL_SCAN := 4   # 目标点不可站时, 往下扫几格找最近可站格


static func _solid(cm, x: int, y: int) -> bool:
	var t: int = cm.get_tile(x, y)
	return t != Tiles.AIR and Tiles.is_solid(t)


# 可通过 (非实心: 空气/水/植物都算能穿过去)
static func _pass(cm, x: int, y: int) -> bool:
	return not _solid(cm, x, y)


# 能站: 本格 + 头顶空 (2 格高), 脚下实心
static func _standable(cm, x: int, y: int) -> bool:
	return _pass(cm, x, y) and _pass(cm, x, y - 1) and _solid(cm, x, y + 1)


# 把一个点吸附到"最近的可站格"(本格不行就往下找地面). 找不到返回 null。
static func snap_to_ground(cm, x: int, y: int) -> Variant:
	for dy in range(0, SEARCH_GOAL_SCAN + 1):
		if _standable(cm, x, y + dy):
			return Vector2i(x, y + dy)
	return null


# 站立格 c 的所有可达邻居 [[cell, cost], ...]
static func _neighbors(cm, c: Vector2i) -> Array:
	var out: Array = []
	var x: int = c.x
	var y: int = c.y
	for dir in [-1, 1]:
		# 1) 平走一格
		if _standable(cm, x + dir, y):
			out.append([Vector2i(x + dir, y), 1.0])
		# 2) 跳上 (1..JUMP_H 格): 起跳列要空 (能升上去), 落点可站 (_standable 已含落点+头顶空、脚下实心)
		for h in range(1, JUMP_H + 1):
			if not _pass(cm, x, y - h):
				break   # 头顶被堵, 跳不上去
			if _standable(cm, x + dir, y - h):
				out.append([Vector2i(x + dir, y - h), 1.0 + float(h) * 0.6])
		# 3) 跨 1 格坑: (x+dir,y) 是坑 (能过且脚下空), (x+2dir,y) 可站
		if _pass(cm, x + dir, y) and _pass(cm, x + dir, y + 1) and _standable(cm, x + dir * 2, y):
			out.append([Vector2i(x + dir * 2, y), 2.0])
		# 4) 走下边沿掉落: (x+dir,y) 能过但脚下空 → 往下找第一个可站格
		if _pass(cm, x + dir, y) and _pass(cm, x + dir, y + 1):
			for d in range(2, MAX_DROP + 1):
				if not _pass(cm, x + dir, y + d - 1):
					break
				if _standable(cm, x + dir, y + d):
					out.append([Vector2i(x + dir, y + d), 1.0 + float(d) * 0.2])
					break
	return out


static func _heur(a: Vector2i, b: Vector2i) -> float:
	return float(abs(a.x - b.x) + abs(a.y - b.y))


# A* 从 start 到 goal (世界格坐标). 返回路点数组 (不含 start, 含 goal); 无路/太远返回 []。
static func find_path(cm, start: Vector2i, goal: Vector2i) -> Array:
	if cm == null:
		return []
	var s: Variant = snap_to_ground(cm, start.x, start.y)
	var g: Variant = snap_to_ground(cm, goal.x, goal.y)
	if s == null or g == null:
		return []
	var start_c: Vector2i = s
	var goal_c: Vector2i = g
	if start_c == goal_c:
		return []
	var came: Dictionary = {}
	var gscore: Dictionary = {start_c: 0.0}
	var open: Dictionary = {start_c: _heur(start_c, goal_c)}   # cell → f
	var expanded: int = 0
	while not open.is_empty():
		# 取 f 最小的 (open 受 MAX_NODES 限制, 线性扫够用)
		var cur: Vector2i = _pop_min(open)
		if cur == goal_c:
			return _rebuild(came, cur)
		expanded += 1
		if expanded > MAX_NODES:
			return []   # 太远/太复杂 → 放弃, 怪退回反应式
		var cg: float = float(gscore.get(cur, 1e20))
		for nb in _neighbors(cm, cur):
			var ncell: Vector2i = nb[0]
			var tentative: float = cg + float(nb[1])
			if tentative < float(gscore.get(ncell, 1e20)):
				came[ncell] = cur
				gscore[ncell] = tentative
				open[ncell] = tentative + _heur(ncell, goal_c)
	return []


static func _pop_min(open: Dictionary) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var best_f: float = 1e30
	for cell in open.keys():
		var f: float = float(open[cell])
		if f < best_f:
			best_f = f
			best = cell
	open.erase(best)
	return best


static func _rebuild(came: Dictionary, end_c: Vector2i) -> Array:
	var path: Array = [end_c]
	var c: Vector2i = end_c
	while came.has(c):
		c = came[c]
		path.push_front(c)
	path.pop_front()   # 去掉 start 自身
	return path
