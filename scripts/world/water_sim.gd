# 流水模拟. 4 水位 (WATER_L1..WATER 表示 1..4 体积). dirty 列表驱动:
# 外部 (挖方块/放水/下雨) 标 dirty, 下次 tick 重新计算重力 + 横向均衡. 体积守恒.
extends Node

const TICK_INTERVAL := 0.18         # 每 0.18s 跑一次 (流速看着不太慢)
const MAX_TILES_PER_TICK := 2000    # 防卡, 单 tick 上限

# 下雨累水
const RAIN_TICK := 0.8              # 每 0.8s 处理一次雨水
const RAIN_COLS_PER_TICK := 4       # 每 tick 在玩家附近 N 列尝试放水
const RAIN_COL_RADIUS := 30         # 玩家 ±N 列范围内

@export var world: Node2D            # 父 World (有 chunk_manager + _set_tile)

var _dirty: Dictionary = {}          # Vector2i -> true
var _t: float = 0.0
var _rain_t: float = 0.0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if world == null:
		return
	_t += delta
	if _t >= TICK_INTERVAL:
		_t = 0.0
		_run_tick()
	_rain_t += delta
	if _rain_t >= RAIN_TICK:
		_rain_t = 0.0
		_run_rain()


# 外部 API ----

func mark_dirty(x: int, y: int) -> void:
	_dirty[Vector2i(x, y)] = true


# tile 在 (x, y) 改变了 -> 标 (x,y) 和 4 邻居为 dirty (它们可能要重新流)
func notify_tile_changed(x: int, y: int) -> void:
	mark_dirty(x, y)
	mark_dirty(x - 1, y)
	mark_dirty(x + 1, y)
	mark_dirty(x, y - 1)
	mark_dirty(x, y + 1)


# 在 (x, y) 加 1 个水位 (用于下雨累水). 成功返回 true.
func add_water(x: int, y: int) -> bool:
	if world == null:
		return false
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var tid: int = cm.get_tile(x, y)
	if tid == Tiles.AIR:
		world._set_tile(x, y, Tiles.WATER_L1)
		notify_tile_changed(x, y)
		return true
	var L: int = _level_of(tid)
	if L > 0 and L < 4:
		world._set_tile(x, y, _tile_for_level(L + 1))
		notify_tile_changed(x, y)
		return true
	return false


# 内部 ----

func _level_of(tid: int) -> int:
	if tid == Tiles.WATER: return 4
	if tid == Tiles.WATER_L3: return 3
	if tid == Tiles.WATER_L2: return 2
	if tid == Tiles.WATER_L1: return 1
	return 0


func _tile_for_level(L: int) -> int:
	if L >= 4: return Tiles.WATER
	if L == 3: return Tiles.WATER_L3
	if L == 2: return Tiles.WATER_L2
	if L == 1: return Tiles.WATER_L1
	return Tiles.AIR


# 下雨累水: 在玩家 ±RAIN_COL_RADIUS 列内, 随机选 N 列, 在该列地表上方 1 格加 L1.
# 已是水的格子直接 add_water (level + 1). 顶部找第一个非 AIR.
func _run_rain() -> void:
	if world == null:
		return
	var weather = world.get("weather")
	if weather == null or not weather.is_raining():
		return
	var player = world.get_player()
	if player == null:
		return
	var cm = world.get("chunk_manager")
	if cm == null:
		return
	var pt: Vector2i = Vector2i(int(player.global_position.x / 16), int(player.global_position.y / 16))
	for _i in RAIN_COLS_PER_TICK:
		var rx: int = pt.x + randi_range(-RAIN_COL_RADIUS, RAIN_COL_RADIUS)
		var top_y: int = 0
		# 从 y=0 向下扫到第一个非 AIR (是表面或水面)
		while top_y < 200:
			var t: int = cm.get_tile(rx, top_y)
			if t != Tiles.AIR:
				break
			top_y += 1
		if top_y >= 200:
			continue
		var hit: int = cm.get_tile(rx, top_y)
		if _level_of(hit) > 0:
			# 表层是水 → 直接 level+1
			add_water(rx, top_y)
		elif top_y - 1 >= 0:
			# 实心地面 → 在它上面那格 AIR 加 L1
			add_water(rx, top_y - 1)


func _run_tick() -> void:
	var cm = world.get("chunk_manager")
	if cm == null:
		return
	var working: Array = _dirty.keys()
	_dirty.clear()
	var count: int = 0
	for p in working:
		if count >= MAX_TILES_PER_TICK:
			_dirty[p] = true   # 推迟到下 tick
			continue
		_step_tile(cm, p.x, p.y)
		count += 1


# 单 tile 一步: 优先重力下流, 否则横向往低 level 邻居均衡
func _step_tile(cm, x: int, y: int) -> void:
	var tid: int = cm.get_tile(x, y)
	var L: int = _level_of(tid)
	if L == 0:
		return  # 不是水
	# 重力: 看 (x, y+1)
	var below_tid: int = cm.get_tile(x, y + 1)
	if below_tid == Tiles.AIR:
		# 全水下流
		world._set_tile(x, y + 1, _tile_for_level(L))
		world._set_tile(x, y, Tiles.AIR)
		notify_tile_changed(x, y + 1)
		return
	var below_L: int = _level_of(below_tid)
	if below_L > 0 and below_L < 4:
		# 转给下面
		var xfer: int = mini(L, 4 - below_L)
		world._set_tile(x, y + 1, _tile_for_level(below_L + xfer))
		var new_L: int = L - xfer
		if new_L > 0:
			world._set_tile(x, y, _tile_for_level(new_L))
			mark_dirty(x, y)
		else:
			world._set_tile(x, y, Tiles.AIR)
		notify_tile_changed(x, y + 1)
		return
	# 下方堵 → 横向均衡 (L >= 2 才溢, L=1 当残留)
	if L < 2:
		return
	var lx_tid: int = cm.get_tile(x - 1, y)
	var rx_tid: int = cm.get_tile(x + 1, y)
	var lx_blocked: bool = lx_tid != Tiles.AIR and _level_of(lx_tid) == 0
	var rx_blocked: bool = rx_tid != Tiles.AIR and _level_of(rx_tid) == 0
	var lx_L: int = _level_of(lx_tid)
	var rx_L: int = _level_of(rx_tid)
	var candidates: Array = []
	if not lx_blocked and lx_L < L:
		candidates.append([x - 1, lx_L])
	if not rx_blocked and rx_L < L:
		candidates.append([x + 1, rx_L])
	if candidates.is_empty():
		return
	# 选 level 最低的邻居
	candidates.sort_custom(func(a, b): return a[1] < b[1])
	var target: Array = candidates[0]
	var tx: int = int(target[0])
	var tL: int = int(target[1])
	world._set_tile(tx, y, _tile_for_level(tL + 1))
	var new_L: int = L - 1
	if new_L > 0:
		world._set_tile(x, y, _tile_for_level(new_L))
		mark_dirty(x, y)
	else:
		world._set_tile(x, y, Tiles.AIR)
	notify_tile_changed(tx, y)
