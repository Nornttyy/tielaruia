# 流水模拟. 4 水位 (WATER_L1..WATER 表示 1..4 体积). dirty 列表驱动:
# 外部 (挖方块/放水/下雨) 标 dirty, 下次 tick 重新计算重力 + 横向均衡. 体积守恒.
extends Node

const TICK_INTERVAL := 0.02         # 流速: 每 0.02s 流一步 (0.12→0.05→0.03→0.02; 用户要更快)
const MAX_TILES_PER_TICK := 300     # 保留 300/tick 上限防 web 单帧爆
const LAVA_TICK_DIVISOR := 8        # 岩浆每 8 tick 才流 (≈0.16s, 维持慢吞吞 — 基准tick变快后补偿)
const SOURCE_TICK_DIVISOR := 1      # 水源块每拍都灌 (2→1, 跟上更快的水流)
const TILE_SIZE := 12               # 本项目格子像素尺寸 (蒸汽特效定位用)

@export var world: Node2D            # 父 World (有 chunk_manager + _set_tile)

var _dirty: Dictionary = {}          # Vector2i -> true
var _t: float = 0.0
var _tick_n: int = 0
var _in_settle: bool = false         # settle_now (chunk加载瞬间找平) 期间不喷水花


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
	if L > 0 and L < 8:   # 水满档=8
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


# 水 8 档 (满=8), 岩浆 4 档 (满=4). 数值 = 体积单位.
func _level_of(tid: int) -> int:
	# 满水 (含 3 个群系水) = 8
	if tid == Tiles.WATER \
			or tid == Tiles.WATER_DESERT or tid == Tiles.WATER_JUNGLE or tid == Tiles.WATER_SWAMP:
		return 8
	if tid == Tiles.WATER_L7: return 7
	if tid == Tiles.WATER_L6: return 6
	if tid == Tiles.WATER_L5: return 5
	if tid == Tiles.WATER_L4: return 4
	if tid == Tiles.WATER_L3: return 3
	if tid == Tiles.WATER_L2: return 2
	if tid == Tiles.WATER_L1: return 1
	# 岩浆 4 档
	if tid == Tiles.LAVA: return 4
	if tid == Tiles.LAVA_L3: return 3
	if tid == Tiles.LAVA_L2: return 2
	if tid == Tiles.LAVA_L1: return 1
	return 0


# 某液种的满档数: 水 8, 岩浆 4.
func _max_level(kind: String) -> int:
	return 8 if kind == "water" else 4


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
	# 水 8 档
	if L >= 8: return Tiles.WATER
	if L == 7: return Tiles.WATER_L7
	if L == 6: return Tiles.WATER_L6
	if L == 5: return Tiles.WATER_L5
	if L == 4: return Tiles.WATER_L4
	if L == 3: return Tiles.WATER_L3
	if L == 2: return Tiles.WATER_L2
	if L == 1: return Tiles.WATER_L1
	return Tiles.AIR


# === 连通水域整体找平 — 让一池水水面真正一样高 (像真水), 不只是逐格斜坡 ===
# 设计要点 (历史踩过"孤儿水/震荡"坑, 这里逐条防):
#  1. 只在【现有水格】里重排水量, 绝不凭空往新格灌 → 不会造孤儿水/凭空冒水.
#  2. 从底 (y 大) 往上灌, 低格先满 → 写回后每个有水的格下面必是水/实心 → 不悬空.
#  3. 总水量守恒 (重排不增不减).
#  4. 已经平的水体写回时 want==cur → 不动 → 不发 dirty → 幂等 → 不会无限抖.
#  5. 只找平水, 岩浆不找平 (保持黏稠手感).
#  6. 单个水体超 _LEVEL_BODY_CAP 格直接跳过 (大海不找平, 防一帧卡) — 交给逐格.
# 配合逐格横流: 铺开→找平→边缘冒落差→再铺开→再找平, 收敛到整片纯平.
const _LEVEL_BODY_CAP := 6000

# 找平 cells 里每个尚未处理的连通水体. 返回是否有任何改动.
func _level_bodies_from(cells: Array) -> bool:
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var visited: Dictionary = {}
	var changed: bool = false
	for c in cells:
		if visited.has(c):
			continue
		if _liquid_kind(cm.get_tile(c.x, c.y)) != "water":
			continue
		if _level_body(cm, c.x, c.y, visited):
			changed = true
	return changed


# 洪水填充 (sx,sy) 所在连通水体, 把总水量从底往上重灌使水面找平. 返回是否改了格子.
func _level_body(cm, sx: int, sy: int, visited: Dictionary) -> bool:
	var stack: Array = [Vector2i(sx, sy)]
	var body: Array = []
	var total: int = 0
	var full_tile: int = Tiles.WATER   # 默认蓝水; 群系满水沿用其颜色 (沙漠/丛林/沼泽)
	while not stack.is_empty():
		var c: Vector2i = stack.pop_back()
		if visited.has(c):
			continue
		var t: int = cm.get_tile(c.x, c.y)
		if _liquid_kind(t) != "water":
			continue   # 非水: 不标 visited, 让别的方向还能从这继续 (但水才入体)
		visited[c] = true
		body.append(c)
		if body.size() > _LEVEL_BODY_CAP:
			return false   # 超大水体放弃找平 (防卡), 留给逐格
		total += _level_of(t)
		if t == Tiles.WATER_DESERT or t == Tiles.WATER_JUNGLE or t == Tiles.WATER_SWAMP:
			full_tile = t
		stack.append(Vector2i(c.x - 1, c.y))
		stack.append(Vector2i(c.x + 1, c.y))
		stack.append(Vector2i(c.x, c.y - 1))
		stack.append(Vector2i(c.x, c.y + 1))
	if body.size() <= 1:
		return false   # 单格无需找平
	# 从底往上灌: 同一行均分剩余水量 → 顶层水面差 ≤ 1, 下面整齐满格.
	body.sort_custom(func(a, b): return a.y > b.y)
	var changed: bool = false
	var i: int = 0
	var n: int = body.size()
	while i < n:
		var row_y: int = body[i].y
		var row: Array = []
		while i < n and body[i].y == row_y:
			row.append(body[i])
			i += 1
		# 按 x 排序 → 余数凸起放固定位置 (跟 flood 方向无关). 不排序的话凸起会落在
		# "stack 先访问到的格", 水从左来 vs 从右来结果不同 → 活水时水面凸起乱跳 = 抽搐.
		row.sort_custom(func(a, b): return a.x < b.x)
		var rn: int = row.size()
		var give: Array = []
		if total >= rn * 8:
			for k in range(rn): give.append(8)
			total -= rn * 8
		elif total <= 0:
			for k in range(rn): give.append(0)
		else:
			var base: int = total / rn
			var extra: int = total % rn   # 余数 (差 ≤ 1) 放正中间几格 → 对称 + 确定 (不抖)
			var start: int = (rn - extra) / 2
			for k in range(rn): give.append(base + (1 if (k >= start and k < start + extra) else 0))
			total = 0
		for k in range(rn):
			var cell: Vector2i = row[k]
			var want_L: int = give[k]
			if want_L == _level_of(cm.get_tile(cell.x, cell.y)):
				continue   # 没变 → 不动 (幂等)
			var new_tile: int
			if want_L >= 8:
				new_tile = full_tile
			elif want_L <= 0:
				new_tile = Tiles.AIR
			else:
				new_tile = _tile_for_level("water", want_L)
			world._set_water_tile_fast(cell.x, cell.y, new_tile)
			notify_tile_changed(cell.x, cell.y)
			changed = true
	return changed


# 立刻把当前所有 dirty 液体一口气流到稳定 (chunk 加载时调: 出现即最终形态, 不看流动过程).
# 反复跑 tick 直到没有待流的, 或撞到安全上限 (防极端情况卡死加载帧, 剩下的留给实时 sim).
const SETTLE_MAX_TICKS := 1200   # 加载时一次性流到稳的预算 (400→1200): 修时序bug后初始区块的水
                                 # 终于会苏醒流动, 400 拍排不完会留下水在玩家眼前流; 加载是同步一次性, 宁可稍慢
func settle_now() -> void:
	if world == null or world.get("chunk_manager") == null:
		return
	# 联机 client 不模拟液体 (host 权威): 否则 client 每次加载 chunk 都本地流 + 把 tile 改动乱发给 host
	if NetworkManager != null and NetworkManager.connected() and not NetworkManager.is_host:
		_dirty.clear()
		return
	var guard: int = 0
	_in_settle = true   # 瞬间找平, 不喷水花 (一次性 spawn 几百粒子)
	var touched: Dictionary = {}   # 这次 settle 碰过的所有格 → 找平时当种子
	# 逐格流到稳定, 再整片找平; 找平会让边缘冒落差 → 再流再找平, 几轮收敛到纯平.
	var rounds: int = 0
	while rounds < 30 and guard < SETTLE_MAX_TICKS:
		while not _dirty.is_empty() and guard < SETTLE_MAX_TICKS:
			for k in _dirty.keys():
				touched[k] = true
			_run_tick()
			guard += 1
		# 稳定了 → 整片找平连通水域. 没改动 = 已经平 → 收工.
		if not _level_bodies_from(touched.keys()):
			break
		rounds += 1
	_in_settle = false


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
	# 实时模式下: 这批水刚流到安静 (dirty 空了) → 整片找平它们所在水域 (单个种子即可洪泛整片连通水).
	# 找平若挪了水会重新标 dirty → 下拍继续铺/找平, 直到纯平才彻底安静 (幂等不抖).
	# settle 期间不在这做 (settle_now 自己分轮找平). 大水体 _level_body 会自动跳过.
	if not _in_settle and _dirty.is_empty() and not working.is_empty():
		_level_bodies_from(working)


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


# 水把空格 + 装饰小草当可流入: 小草碰水直接被冲掉 (覆盖即销毁, 用户要求)。
# 别的植物 (树/仙人掌/蘑菇/庄稼...) 不在此列 → 挡水, 水绕开, 一直看得见。
# (is_submersible_plant 现返 false → 没有植物会被"记元数据复原", 即小草是真销毁不是泡水。)
func _water_enterable(tid: int) -> bool:
	return tid == Tiles.AIR or tid == Tiles.PLANT_GRASS


# 水源块: 每 N 拍往正下方灌一格满水, 自己永不变少. 下方满/堵 → 不灌不重标 = 歇着 (self-limiting).
func _step_source(cm, x: int, y: int) -> void:
	if _tick_n % SOURCE_TICK_DIVISOR != 0:
		mark_dirty(x, y)   # 非本拍: 保活, 不灌
		return
	var below: int = cm.get_tile(x, y + 1)
	var can_fill: bool = _water_enterable(below) \
			or (_liquid_kind(below) == "water" and _level_of(below) < 8)   # 水满档=8
	if can_fill:
		world._set_water_tile_fast(x, y + 1, Tiles.WATER)
		notify_tile_changed(x, y + 1)
		mark_dirty(x, y)   # 还有活, 继续醒着
		# 活水颗粒: 瀑布源往下灌时冒水珠。settle 不冒。
		if not _in_settle:
			Effects.spawn_water_grains(Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE), Vector2(0, 70), Tiles.WATER, 1)
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
	var maxlv: int = _max_level(kind)   # 水 8 / 岩浆 4
	# 重力: 下方 (水落到草须上 → 冲毁草; 岩浆维持原样只认空气)
	var below_tid: int = cm.get_tile(x, y + 1)
	if below_tid == Tiles.AIR or (kind == "water" and below_tid == Tiles.PLANT_GRASS):
		world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, L))
		world._set_water_tile_fast(x, y, Tiles.AIR)
		notify_tile_changed(x, y + 1)
		# 源变空 → 还要叫醒源正上方的液体 (x,y-1): notify_tile_changed(x,y) 会标到它.
		# 否则它下面刚空出来却没人重标 dirty → 悬空不流 (修 test_water_settles, 跟横向流分支对称).
		notify_tile_changed(x, y)
		# 下落水视觉: 标记刚空出来的格还在"流" → 短时残留连成连续水帘 (纯画面; 水不岩浆, settle 不画).
		if kind == "water" and not _in_settle and world.has_method("note_falling_water"):
			world.note_falling_water(x, y, tid)
		# 落水溅花: 实时(非settle) + 桌面 + 限频; 落点正下方是实心/液体 = 砸到底了
		if kind == "water" and not _in_settle and _tick_n % 4 == 0 and not OS.has_feature("web"):
			if cm.get_tile(x, y + 2) != Tiles.AIR:
				Effects.spawn_splash(Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE))
		# 活水颗粒: 下落的水冒水珠 (含网页, 靠 Effects 全局上限控量)。settle 不冒。
		# 限频 _tick_n % 3: 跟上面溅花同思路, 防一道高瀑布每 tick 把 250 名额占满、饿死别处水珠。
		if kind == "water" and not _in_settle and _tick_n % 3 == 0:
			Effects.spawn_water_grains(Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE), Vector2(0, 60), tid, 1)
		return
	if _liquid_kind(below_tid) == kind:
		var below_L: int = _level_of(below_tid)
		if below_L < maxlv:
			var xfer: int = mini(L, maxlv - below_L)
			world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, below_L + xfer))
			var new_L: int = L - xfer
			if new_L > 0:
				world._set_water_tile_fast(x, y, _tile_for_level(kind, new_L))
				mark_dirty(x, y)
			else:
				world._set_water_tile_fast(x, y, Tiles.AIR)
			notify_tile_changed(x, y + 1)
			return
	# 下方堵 → 横向. 水: 找平 (摊平铺开像真水); 岩浆: 黏稠 (慢慢挪 1 格, 不像水那样快铺).
	if kind == "water":
		_step_water_lateral(cm, x, y, L, maxlv)
	else:
		_step_lava_lateral(cm, x, y, L)


# 水横向: 往最低的"低≥2 档"邻居挪 1 格 (整数水位下相邻差 1 视为已平 → 不震荡).
# 8 档 → 阶梯每级 2px, 看着接近平滑. 薄水(L1)只朝有落差的洞流 (挖洞排水, 平地不乱跑).
# 通知源+目标四邻 → 高水位邻居知道我变低了, 会继续往低处流 (尽量铺平, 不卡住).
func _step_water_lateral(cm, x: int, y: int, L: int, maxlv: int) -> void:
	var best_nx: int = -999999
	var best_nl: int = 99
	for nx in [x - 1, x + 1]:
		var nt: int = cm.get_tile(nx, y)
		var nlev: int = -1
		if _water_enterable(nt):   # 空气或草须 (横向流进草须 = 冲毁它)
			nlev = 0
		elif _liquid_kind(nt) == "water" and _level_of(nt) <= L - 2:
			nlev = _level_of(nt)
		if nlev < 0:
			continue
		if L < 2:
			var bn: int = cm.get_tile(nx, y + 1)
			if not (bn == Tiles.AIR or (_liquid_kind(bn) == "water" and _level_of(bn) < maxlv)):
				continue
		if nlev < best_nl:
			best_nl = nlev
			best_nx = nx
	if best_nx == -999999:
		return
	world._set_water_tile_fast(best_nx, y, _tile_for_level("water", best_nl + 1))
	if L - 1 > 0:
		world._set_water_tile_fast(x, y, _tile_for_level("water", L - 1))
	else:
		world._set_water_tile_fast(x, y, Tiles.AIR)
	notify_tile_changed(best_nx, y)
	notify_tile_changed(x, y)
	# 活水颗粒: 横向漫流前沿冒 1 颗 (流进空气那一步, best_nl==0 表示流进空气/草须)。settle 不冒。
	if not _in_settle and best_nl == 0:
		var grain_dir: float = 40.0 if best_nx > x else -40.0
		Effects.spawn_water_grains(Vector2((best_nx + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE), Vector2(grain_dir, 10), Tiles.WATER, 1)


# 岩浆横向: 黏稠 — 只往一个最低邻居挪 1 格 (差≥2 才溢; 薄岩浆只朝落差). 不快铺.
func _step_lava_lateral(cm, x: int, y: int, L: int) -> void:
	var best_nx: int = -999999
	var best_nl: int = 99
	for nx in [x - 1, x + 1]:
		var nt: int = cm.get_tile(nx, y)
		var nlev: int = -1
		if nt == Tiles.AIR:
			nlev = 0
		elif _liquid_kind(nt) == "lava" and _level_of(nt) <= L - 2:
			nlev = _level_of(nt)
		if nlev < 0:
			continue
		if L < 2:
			var bn: int = cm.get_tile(nx, y + 1)
			if not (bn == Tiles.AIR or (_liquid_kind(bn) == "lava" and _level_of(bn) < 4)):
				continue
		if nlev < best_nl:
			best_nl = nlev
			best_nx = nx
	if best_nx == -999999:
		return
	world._set_water_tile_fast(best_nx, y, _tile_for_level("lava", best_nl + 1))
	if L - 1 > 0:
		world._set_water_tile_fast(x, y, _tile_for_level("lava", L - 1))
		mark_dirty(x, y)
	else:
		world._set_water_tile_fast(x, y, Tiles.AIR)
	notify_tile_changed(best_nx, y)
