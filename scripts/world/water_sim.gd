# 流水模拟. 4 水位 (WATER_L1..WATER 表示 1..4 体积). dirty 列表驱动:
# 外部 (挖方块/放水/下雨) 标 dirty, 下次 tick 重新计算重力 + 横向均衡. 体积守恒.
extends Node

const TICK_INTERVAL := 0.12         # 用户要求流速快 (0.35→0.12 = 3x 更快)
const MAX_TILES_PER_TICK := 300     # 保留 300/tick 上限防 web 单帧爆
const LAVA_TICK_DIVISOR := 3        # 岩浆每 3 个 tick 才流一步 (≈ 0.36s, 慢吞吞)
const SOURCE_TICK_DIVISOR := 2      # 水源块每 2 拍灌一次 (温柔水流 + 省 CPU)
const TILE_SIZE := 12               # 本项目格子像素尺寸 (蒸汽特效定位用)

@export var world: Node2D            # 父 World (有 chunk_manager + _set_tile)

var _dirty: Dictionary = {}          # Vector2i -> true
var _t: float = 0.0
var _tick_n: int = 0


func _ready() -> void:
	set_process(true)


func _process(delta: float) -> void:
	if world == null:
		return
	# 联机时只在 host 跑 simulation (client 收 host 的 tile_change 广播应用)
	if NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host:
		_dirty.clear()
		return
	_t += delta
	if _t >= TICK_INTERVAL:
		_t = 0.0
		_run_tick()


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
		world._set_water_tile_fast(x, y, Tiles.WATER_L1)
		notify_tile_changed(x, y)
		return true
	var L: int = _level_of(tid)
	if L > 0 and L < 4:
		world._set_water_tile_fast(x, y, _tile_for_level("water", L + 1))
		notify_tile_changed(x, y)
		return true
	return false


# 内部 ----

# 液种: "water" / "lava" / "" (非流体). 群系水 (沙漠/丛林/沼泽) 也算 water.
func _liquid_kind(tid: int) -> String:
	if Tiles.is_water(tid):
		return "water"
	if tid == Tiles.LAVA or tid == Tiles.LAVA_L1 or tid == Tiles.LAVA_L2 or tid == Tiles.LAVA_L3:
		return "lava"
	return ""


func _level_of(tid: int) -> int:
	# 满水 (含 3 个群系水) + 满岩浆 = 4
	if tid == Tiles.WATER or tid == Tiles.LAVA \
			or tid == Tiles.WATER_DESERT or tid == Tiles.WATER_JUNGLE or tid == Tiles.WATER_SWAMP:
		return 4
	if tid == Tiles.WATER_L3 or tid == Tiles.LAVA_L3: return 3
	if tid == Tiles.WATER_L2 or tid == Tiles.LAVA_L2: return 2
	if tid == Tiles.WATER_L1 or tid == Tiles.LAVA_L1: return 1
	return 0


# chunk 加载唤醒用 ----
# 是不是液体 (水或岩浆任意 level)
func is_liquid(tid: int) -> bool:
	return _liquid_kind(tid) != ""


# chunk 加载时该不该唤醒这个 tile: 流动液体 + 水源块都要醒 (水源不是 liquid, 不特判就冻崖顶不流).
func wakes_on_chunk_load(tid: int) -> bool:
	return is_liquid(tid) or tid == Tiles.WATER_SOURCE


# 这个液体 tile 还能不能流 (chunk 加载时判断该不该唤醒).
# 之前世界生成的悬空岩浆源没人叫醒 → 瀑布冻在空中; 现在水和岩浆一视同仁.
# neighbors = 4 邻居 tile id (顺序无所谓); 越界邻居传 -1 (chunk 边界开口, 保守唤醒).
# 能流 = 旁边有空气 / chunk 边界 / 同种更低液位 (要往低处均衡).
func tile_can_still_flow(tid: int, neighbors: Array) -> bool:
	var kind: String = _liquid_kind(tid)
	if kind == "":
		return false
	var L: int = _level_of(tid)
	for nt in neighbors:
		if nt == -1 or nt == Tiles.AIR:
			return true
		if _liquid_kind(nt) == kind and _level_of(nt) < L:
			return true
	return false


func _tile_for_level(kind: String, L: int) -> int:
	if kind == "lava":
		if L >= 4: return Tiles.LAVA
		if L == 3: return Tiles.LAVA_L3
		if L == 2: return Tiles.LAVA_L2
		if L == 1: return Tiles.LAVA_L1
		return Tiles.AIR
	if L >= 4: return Tiles.WATER
	if L == 3: return Tiles.WATER_L3
	if L == 2: return Tiles.WATER_L2
	if L == 1: return Tiles.WATER_L1
	return Tiles.AIR


# 立刻把当前所有 dirty 液体一口气流到稳定 (chunk 加载时调: 出现即最终形态, 不看流动过程).
# 反复跑 tick 直到没有待流的, 或撞到安全上限 (防超大水体卡死加载帧, 剩下的留给实时 sim).
const SETTLE_MAX_TICKS := 240
func settle_now() -> void:
	if world == null or world.get("chunk_manager") == null:
		return
	# 联机 client 不模拟液体 (host 权威): 否则 client 每次加载 chunk 都本地流 + 把 tile 改动乱发给 host
	if NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host:
		_dirty.clear()
		return
	var guard: int = 0
	while not _dirty.is_empty() and guard < SETTLE_MAX_TICKS:
		_run_tick()
		guard += 1


func _run_tick() -> void:
	_tick_n += 1   # 先自增, 岩浆判 _tick_n % LAVA_TICK_DIVISOR 用它
	var cm = world.get("chunk_manager")
	if cm == null:
		return
	var working: Array = _dirty.keys()
	_dirty.clear()
	# 联机: 本 tick 所有 tile 变化打包一条消息发, 防 PeerJS data channel 一帧几百小消息丢
	if world.has_method("begin_tile_batch"):
		world.begin_tile_batch()
	var count: int = 0
	for p in working:
		if count >= MAX_TILES_PER_TICK:
			_dirty[p] = true   # 推迟到下 tick
			continue
		_step_tile(cm, p.x, p.y)
		count += 1
	if world.has_method("end_tile_batch"):
		world.end_tile_batch()


# 返回 true 表示本格已因反应被处理 (不再流动)
func _react_water_lava(cm, x: int, y: int, kind: String) -> bool:
	var neighbors := [Vector2i(x-1,y), Vector2i(x+1,y), Vector2i(x,y-1), Vector2i(x,y+1)]
	if kind == "lava":
		for n in neighbors:
			if _liquid_kind(cm.get_tile(n.x, n.y)) == "water":
				world._set_water_tile_fast(x, y, Tiles.STONE)
				_reduce_liquid(cm, n.x, n.y)
				Effects.spawn_steam_puff(Vector2((x + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE))
				notify_tile_changed(x, y)
				notify_tile_changed(n.x, n.y)
				return true
	elif kind == "water":
		for n in neighbors:
			if _liquid_kind(cm.get_tile(n.x, n.y)) == "lava":
				world._set_water_tile_fast(n.x, n.y, Tiles.STONE)
				_reduce_liquid(cm, x, y)
				Effects.spawn_steam_puff(Vector2((n.x + 0.5) * TILE_SIZE, (n.y + 0.5) * TILE_SIZE))
				notify_tile_changed(n.x, n.y)
				notify_tile_changed(x, y)
				return true
	return false


# 把 (x,y) 的水降一级 (L1 → AIR)
func _reduce_liquid(cm, x: int, y: int) -> void:
	var L: int = _level_of(cm.get_tile(x, y))
	world._set_water_tile_fast(x, y, _tile_for_level("water", L - 1))


# 水源块: 每 N 拍往正下方灌一格满水, 自己永不变少. 下方满/堵 → 不灌不重标 = 歇着 (self-limiting).
func _step_source(cm, x: int, y: int) -> void:
	if _tick_n % SOURCE_TICK_DIVISOR != 0:
		mark_dirty(x, y)   # 非本拍: 保活, 不灌
		return
	var below: int = cm.get_tile(x, y + 1)
	var can_fill: bool = below == Tiles.AIR \
			or (_liquid_kind(below) == "water" and _level_of(below) < 4)
	if can_fill:
		world._set_water_tile_fast(x, y + 1, Tiles.WATER)
		notify_tile_changed(x, y + 1)
		mark_dirty(x, y)   # 还有活, 继续醒着
	# 下方满水/实心/岩浆 → 啥也不做, dirty 不重标 → 自然歇下


# 单 tile 一步: 优先重力下流, 否则横向往同种低 level 邻居均衡.
# 水和岩浆共用同一套流动物理, 但绝不互相混合 (反应留给后续 task).
func _step_tile(cm, x: int, y: int) -> void:
	var tid: int = cm.get_tile(x, y)
	if tid == Tiles.WATER_SOURCE:
		_step_source(cm, x, y)   # 水源块: 往下灌水, 不流不耗
		return
	var kind: String = _liquid_kind(tid)
	if kind == "":
		return
	# 水 / 岩浆相邻 → 岩浆变石头, 水消耗一级 (经典 Terraria 风)
	if _react_water_lava(cm, x, y, kind):
		return
	# 岩浆慢: 非其 tick → 推迟 (重新标 dirty 保活), 本 tick 不流
	if kind == "lava" and _tick_n % LAVA_TICK_DIVISOR != 0:
		mark_dirty(x, y)
		return
	var L: int = _level_of(tid)
	# 重力: 下方
	var below_tid: int = cm.get_tile(x, y + 1)
	if below_tid == Tiles.AIR:
		world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, L))
		world._set_water_tile_fast(x, y, Tiles.AIR)
		notify_tile_changed(x, y + 1)
		return
	if _liquid_kind(below_tid) == kind:
		var below_L: int = _level_of(below_tid)
		if below_L < 4:
			var xfer: int = mini(L, 4 - below_L)
			world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, below_L + xfer))
			var new_L: int = L - xfer
			if new_L > 0:
				world._set_water_tile_fast(x, y, _tile_for_level(kind, new_L))
				mark_dirty(x, y)
			else:
				world._set_water_tile_fast(x, y, Tiles.AIR)
			notify_tile_changed(x, y + 1)
			return
	# 下方堵 → 横向溢流.
	# L>=2 (深水): 正常往低处溢, 挖开洞会涌出去铺开.
	# L==1 (薄水): 只往"能继续往下掉"的洞溢 (洞口下面是空气/未满液体), 否则平地上
	#   一格薄水会左右无限抖 (perf 灾难). 有落差才流 = 挖个通往低处的出口水就淌出去.
	var lx_tid: int = cm.get_tile(x - 1, y)
	var rx_tid: int = cm.get_tile(x + 1, y)
	var candidates: Array = []
	for nx_pair in [[x - 1, lx_tid], [x + 1, rx_tid]]:
		var nx: int = nx_pair[0]
		var nt: int = nx_pair[1]
		var nlev: int = -1
		if nt == Tiles.AIR:
			nlev = 0
		elif _liquid_kind(nt) == kind and _level_of(nt) <= L - 2:
			# 必须低 ≥2 级才横向流: 否则 L2↔L1 这种差 1 级会无限来回倒 (平地永久震荡 + 耗CPU).
			# 差 1 级视作已稳定 (整数液位下相邻差 1 是最平的可达状态).
			nlev = _level_of(nt)
		if nlev < 0:
			continue
		# 薄水防抖: 洞口下面要能落下去 (空气 / 未满同种液体) 才流, 平地不流
		if L < 2:
			var bn: int = cm.get_tile(nx, y + 1)
			var can_fall: bool = bn == Tiles.AIR or (_liquid_kind(bn) == kind and _level_of(bn) < 4)
			if not can_fall:
				continue
		candidates.append([nx, nlev])
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return a[1] < b[1])
	var target: Array = candidates[0]
	var tx: int = int(target[0])
	var tL: int = int(target[1])
	world._set_water_tile_fast(tx, y, _tile_for_level(kind, tL + 1))
	var nl: int = L - 1
	if nl > 0:
		world._set_water_tile_fast(x, y, _tile_for_level(kind, nl))
		mark_dirty(x, y)
	else:
		world._set_water_tile_fast(x, y, Tiles.AIR)
	notify_tile_changed(tx, y)
