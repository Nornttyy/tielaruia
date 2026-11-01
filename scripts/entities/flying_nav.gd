# 飞行怪遇到地形时绕行；路径有计算上限和冷却，不每帧重新搜索。
extends RefCounted
const Grid = preload("res://scripts/entities/mob_pathfinder.gd")
const TILE := 12.0
const MAX_NODES := 256
var _timer := 0.0
var _path: Array[Vector2i] = []
var _last_goal := Vector2i(-99999, -99999)
var _cm: Node

func steer(mob: CharacterBody2D, target: Vector2, desired: Vector2, delta: float) -> Vector2:
	if desired.length_squared() < 0.01: return desired
	_timer -= delta
	var collision := mob.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var offset := Vector2(0, -8)
	var half := Vector2(8, 8)
	if collision != null and collision.shape != null:
		offset = collision.position
		half = collision.shape.get_rect().size * collision.scale / 2.0
	var center := mob.global_position + offset
	var goal := target - Vector2(0, 12)
	if not mob.test_move(mob.global_transform, goal - center):
		_path.clear()
		return desired
	if _cm == null or not is_instance_valid(_cm):
		_cm = mob.get_tree().get_first_node_in_group("chunk_manager")
	if _cm == null: return desired
	var from_cell := Vector2i((center / TILE).floor())
	var goal_cell := Vector2i((goal / TILE).floor())
	if _timer <= 0.0 or goal_cell.distance_squared_to(_last_goal) > 16:
		_timer = 0.6
		_last_goal = goal_cell
		_path = find_path(_cm, from_cell, goal_cell, half)
	while not _path.is_empty() and center.distance_to((Vector2(_path[0]) + Vector2.ONE * 0.5) * TILE) < 5.0:
		_path.pop_front()
	if _path.is_empty():
		# 搜索预算耗尽或目标被封闭也要沿空闲方向飞；真实碰撞仍由物理体阻挡。
		# 先检查直线短步，再尝试上绕/下绕，避免站在障碍前永久停机。
		var forward := (goal - center).normalized()
		for direction in [forward, Vector2.UP, Vector2(forward.x, -1).normalized(), Vector2.DOWN, Vector2(-forward.x, 0)]:
			if direction.length_squared() > 0.01 and not mob.test_move(mob.global_transform, direction * 18.0):
				return direction * desired.length()
		return Vector2.ZERO
	var waypoint := (Vector2(_path[0]) + Vector2.ONE * 0.5) * TILE
	return (waypoint - center).normalized() * desired.length()

static func clear_at(cm: Object, cell: Vector2i, half: Vector2) -> bool:
	var center := (Vector2(cell) + Vector2.ONE * 0.5) * TILE
	var first := Vector2i(((center - half + Vector2.ONE * 0.1) / TILE).floor())
	var last := Vector2i(((center + half - Vector2.ONE * 0.1) / TILE).floor())
	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			if Grid._solid(cm, x, y): return false
	return true

static func find_path(cm: Object, start: Vector2i, goal: Vector2i, half: Vector2) -> Array[Vector2i]:
	if not clear_at(cm, goal, half):
		var best := INF
		var found := false
		var original := goal
		for dy in range(-3, 4):
			for dx in range(-3, 4):
				var c := original + Vector2i(dx, dy)
				var cost := c.distance_squared_to(original) + c.distance_to(start) * 0.01
				if cost < best and clear_at(cm, c, half):
					found = true
					best = cost
					goal = c
		if not found: return []
	var open := {start: start.distance_to(goal)}
	var costs := {start: 0.0}
	var parents: Dictionary = {}
	var closest := start
	var closest_distance := start.distance_squared_to(goal)
	for _step in MAX_NODES:
		if open.is_empty(): break
		var cur: Vector2i = Grid._pop_min(open)
		if cur.distance_squared_to(goal) < closest_distance:
			closest = cur
			closest_distance = cur.distance_squared_to(goal)
		if cur == goal:
			var result: Array[Vector2i] = []
			while parents.has(cur):
				result.push_front(cur)
				cur = parents[cur]
			return result
		for d in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cur + d
			if absi(next.x - start.x) > 28 or absi(next.y - start.y) > 24: continue
			if not clear_at(cm, next, half): continue
			var cost: float = costs[cur] + 1.0
			if cost >= costs.get(next, INF): continue
			costs[next] = cost
			parents[next] = cur
			open[next] = cost + next.distance_to(goal)
	# 给远处/封闭目标一条已验证安全的接近路线；下一次从新位置继续寻路。
	var partial: Array[Vector2i] = []
	while parents.has(closest):
		partial.push_front(closest)
		closest = parents[closest]
	return partial
