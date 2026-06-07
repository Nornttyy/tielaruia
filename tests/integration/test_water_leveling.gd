# 水找平回归测试.
# 锁两件事:
#  1) 找平"位置确定" — 同一摊水不管水从左来还是右来, 水面凸起落在同一处 (修"活水抽搐").
#  2) 连通水池会流平且流稳 — 水面高度差 ≤ ~0.2 格, 稳定后不再变 (不抖).
extends GutTest

const WaterSim = preload("res://scripts/world/water_sim.gd")

class FakeCM:
	var grid := {}
	var solid := {}
	func get_tile(x: int, y: int) -> int:
		var k := Vector2i(x, y)
		if solid.has(k):
			return Tiles.STONE
		return grid.get(k, Tiles.AIR)

class FakeWorld:
	extends Node2D
	var chunk_manager
	func _set_water_tile_fast(x: int, y: int, t: int) -> void:
		var k := Vector2i(x, y)
		if t == Tiles.AIR:
			chunk_manager.grid.erase(k)
		else:
			chunk_manager.grid[k] = t
	func _set_tile(x: int, y: int, t: int, _a = false, _b = false) -> void:
		_set_water_tile_fast(x, y, t)

var _world: FakeWorld
var _cm: FakeCM
var _sim

func _make(width: int, floor_y: int) -> void:
	_cm = FakeCM.new()
	_world = FakeWorld.new()
	_world.chunk_manager = _cm
	add_child_autofree(_world)
	_sim = WaterSim.new()
	_sim.world = _world
	add_child_autofree(_sim)
	_sim.set_process(false)
	for x in range(0, width + 2):
		_cm.solid[Vector2i(x, floor_y)] = true
	for y in range(0, floor_y + 1):
		_cm.solid[Vector2i(0, y)] = true
		_cm.solid[Vector2i(width + 1, y)] = true

func _run_until_quiet(maxt: int) -> int:
	var ticks := 0
	while not _sim._dirty.is_empty() and ticks < maxt:
		_sim._run_tick()
		ticks += 1
	return ticks

# 每列水面"真实世界高度" (y 越小越高); 顶水格在 row Y、水位 L → Y+1-L/8. 没水=INF.
func _surface_heights(width: int, max_y: int) -> Array:
	var hs := []
	for x in range(1, width + 1):
		var sh := INF
		for y in range(0, max_y):
			var t: int = _cm.get_tile(x, y)
			if _sim.is_liquid(t):
				sh = float(y) + 1.0 - float(_sim._level_of(t)) / 8.0
				break
		hs.append(sh)
	return hs

func _surface_spread(width: int, max_y: int) -> float:
	var lo := INF
	var hi := -INF
	for sh in _surface_heights(width, max_y):
		if sh == INF:
			continue
		lo = minf(lo, sh)
		hi = maxf(hi, sh)
	return 0.0 if lo == INF else (hi - lo)

func _grid_hash() -> String:
	var keys := _cm.grid.keys()
	keys.sort_custom(func(a, b): return (a.y * 100000 + a.x) < (b.y * 100000 + b.x))
	var s := ""
	for k in keys:
		s += "%d,%d=%d;" % [k.x, k.y, _cm.grid[k]]
	return s

# --- 1) 找平位置确定: 水从哪边来都一样 (修抽搐) ---
func _setup_odd_row(W: int) -> void:
	_make(W, 10)
	for x in range(1, W + 1):
		_cm.grid[Vector2i(x, 9)] = _sim._tile_for_level("water", 3)
	_cm.grid[Vector2i(1, 9)] = _sim._tile_for_level("water", 5)   # +2 余量, 制造凸起

func test_leveling_is_position_deterministic() -> void:
	var W := 12
	_setup_odd_row(W)
	_sim._level_bodies_from([Vector2i(1, 9)])     # 从左端洪泛
	var from_left: Array = _surface_heights(W, 10)
	_setup_odd_row(W)
	_sim._level_bodies_from([Vector2i(W, 9)])     # 从右端洪泛
	var from_right: Array = _surface_heights(W, 10)
	assert_eq(from_left, from_right,
		"同一摊水从左/右洪泛找平结果必须一致 (否则活水时水面凸起会随水流方向乱跳=抽搐)")

# --- 2) 连通水池流平 + 流稳 ---
func test_pool_flattens_and_stops() -> void:
	var W := 9
	_make(W, 10)
	# 中间堆 5 格满水 (40 单位), 应铺平到全宽
	for i in range(5):
		_cm.grid[Vector2i(5, 5 + i)] = Tiles.WATER
		_sim.mark_dirty(5, 5 + i)
	_run_until_quiet(2000)
	var spread := _surface_spread(W, 11)
	gut.p("[平整] 连通池水面高度差 %.3f 格" % spread)
	assert_lt(spread, 0.2, "连通水池水面应基本一样高 (差 < 0.2 格)")
	# 稳定后不再抖
	var h0 := _grid_hash()
	var changed := 0
	for i in range(60):
		_sim._run_tick()
		if _grid_hash() != h0:
			changed += 1
		h0 = _grid_hash()
	assert_eq(changed, 0, "水池流平后必须彻底安静 (60 tick 内不再变 = 不抖)")

# 偏一边倒水也要铺平到全宽 (凸起居中, 不随方向乱跳)
func test_offset_pour_flattens() -> void:
	var W := 11
	_make(W, 10)
	for i in range(6):
		_cm.grid[Vector2i(2, 4 + i)] = Tiles.WATER
		_sim.mark_dirty(2, 4 + i)
	_run_until_quiet(2000)
	assert_lt(_surface_spread(W, 11), 0.2, "偏置倒水也应铺平 (差 < 0.2 格)")
