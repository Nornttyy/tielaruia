# 程序化世界生成。给定种子产生确定性的 2D tile 数组。
# 返回 dict: {"tiles": Array[Array[int]], "spawn_point": Vector2i,
#            "seed": int, "width": int, "height": int}
# tiles[x][y] = TileData 常量
extends RefCounted

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

const SURFACE_BASE := 0.45       # 地表平均高度 (相对世界 0..1)
const SURFACE_AMP := 0.10        # 地表小起伏振幅 (普通山丘)
const DIRT_DEPTH := 6            # 地表下泥土层厚度
# 山区 noise: 低频 → 30-60 列宽的山区, max(0, n) 作为山高度系数 (实测 Perlin max ~0.31)
# MOUNTAIN_BOOST 对世界高度的比例: 0.40 × 0.31 × 256 = 最高峰比平均地表再高 ~32 格
const MOUNTAIN_NOISE_FREQ := 0.008
const MOUNTAIN_BOOST := 0.40
const MOUNTAIN_PIT_THRESHOLD := 0.12  # mountain_factor > 0.12 = 山区 (实测约占 16% 列)
const BEDROCK_ROWS := 2          # 基岩占最底几行
const SAND_THRESHOLD := 0.4      # sand_noise 超过此阈值的列为沙列
const TREE_MIN_SPACING := 5      # 相邻两棵树之间最少 N 列间距
const TREE_CHANCE := 0.45        # 候选格子里实际长树的概率

const DEEP_STONE_RATIO := 0.5    # 地表往下 (height-surf)*0.5 处起为 DEEP_STONE
const COAL_THRESHOLD := 0.30     # 降低 → 煤矿更密
const IRON_THRESHOLD := 0.40     # 降低 → 铁矿更多 (仅深石层有效)

# Perlin Worms 洞穴系统 (细隧道网 + 分叉 + 死路, 按深度分层: 表少 / 深密)
const WORM_SPAWN_GRID := 14      # 每 14×14 tile 一个候选 worm 起点 (密)
const WORM_LEN_MIN := 25         # worm 短一点 → 形成自然死路
const WORM_LEN_MAX := 70
const WORM_RADIUS_MIN := 0.8     # 窄隧道: 1-2 tile 宽
const WORM_RADIUS_MAX := 1.3
const WORM_BRANCH_CHANCE := 0.025  # 每步 2.5% 派子 worm → 分叉
const WORM_BRANCH_MAX_DEPTH := 2   # 分叉递归最大深度
const WORM_BRANCH_RADIUS_SCALE := 0.6  # 子 worm 半径系数 (孙再叠加 → 越细)
const WORM_DIR_FREQUENCY := 0.025  # 方向噪声频率
const WORM_SEARCH_PAD_CELLS := 7   # 邻 chunk 搜索半径
# 深度分层生成概率: depth = sy - surf
const WORM_CHANCE_SHALLOW := 0.02  # 表层近乎实心, 只 2% 概率出"山头洞口"
const WORM_CHANCE_MID := 0.25      # 中层零散通道, 玩家挖才会遇到
const WORM_CHANCE_DEEP := 0.92     # 深层密如蛛网 (玩家"主动下矿"区)
const WORM_DEPTH_SHALLOW_MAX := 40  # 地表 40 格内安全, 不会"踩进去"
const WORM_DEPTH_MID_MAX := 110     # surf+110 起密集
const WORM_SURFACE_BUFFER := 20     # worm 路径距地表至少 20 格 (走近就 break, 防止深层 worm 窜到地表)

# 露天矿洞 (Terraria 风表面洞穴): 平地小坡上有小开口, 下面是分叉迷宫 + 死路.
# 山区不生成 (用户要求: 不在山上面). 平均每 OPEN_PIT_SPACING 列一个.
# 结构: 1) 表面小开口 (2-3 宽×3-5 深) 2) 起始室 (3 半径圆) 3) 派 2-3 worm 散开
# 跨 chunk 一致: 用 _hash3 派生 RNG. 邻 chunk 搜索 ±OPEN_WORM_PAD_CELLS.
const OPEN_PIT_SPACING := 60         # 1/60 ≈ 1.67% 概率/列 (非山区 ≈ 85% × 1.67% ≈ 1.4%/列)
const OPEN_OPENING_WIDTH_MIN := 2    # 表面开口最窄
const OPEN_OPENING_WIDTH_MAX := 3    # 表面开口最宽 (玩家能看见的洞口)
const OPEN_OPENING_DEPTH_MIN := 3
const OPEN_OPENING_DEPTH_MAX := 5
const OPEN_CHAMBER_RADIUS := 3.0     # 开口底下的小起始室
const OPEN_WORM_COUNT_MIN := 2       # 起始室派出的 worm 数 (= 分叉数)
const OPEN_WORM_COUNT_MAX := 3
const OPEN_WORM_LEN_MIN := 50        # 每条 worm 长度 (= 路径深度)
const OPEN_WORM_LEN_MAX := 100
const OPEN_WORM_RADIUS_SCALE := 1.4  # worm 半径系数 (默认 0.8-1.3 × 1.4 = 1.1-1.8 实际)
const OPEN_WORM_SURFACE_BUFFER := 3  # worm 距地表 ≥ 3, 不会再戳破地表
const OPEN_WORM_PAD_CELLS := 100     # 邻 chunk 搜索 pad (= 最远 worm 可达)

# 树种枚举 (内部 idx)
const _SPECIES_OAK := 0
const _SPECIES_PINE := 1
const _SPECIES_AUTUMN := 2

# 每个 canopy_kind 向上伸的最大格数 (用于检查是否出界)
const _CANOPY_REACH := {
	"oak_small": 1,
	"oak_med": 1,
	"oak_large": 2,
	"oak_tall": 3,
	"pine_small": 2,
	"pine_med": 3,
	"pine_large": 4,
	"pine_huge": 5,
	"autumn_small": 1,
	"autumn_med": 1,
	"autumn_large": 2,
	"autumn_huge": 1,
}

# 树种参数。canopies 列表中重复表示该尺寸更常见 (med x2 = 40% 概率)
const _SPECIES_PARAMS := {
	_SPECIES_OAK: {
		"trunk_range": [3, 7],
		"leaves": Tiles.LEAVES,
		"canopies": ["oak_small", "oak_med", "oak_med", "oak_large", "oak_tall"],
	},
	_SPECIES_PINE: {
		"trunk_range": [4, 9],
		"leaves": Tiles.LEAVES_PINE,
		"canopies": ["pine_small", "pine_med", "pine_med", "pine_large", "pine_huge"],
	},
	_SPECIES_AUTUMN: {
		"trunk_range": [2, 6],
		"leaves": Tiles.LEAVES_AUTUMN,
		"canopies": ["autumn_small", "autumn_med", "autumn_med", "autumn_large", "autumn_huge"],
	},
}


# 生成一柱地形。world_x = chunk_x * CHUNK_WIDTH + local_x。
# 同 seed + chunk_x → 同结果 (deterministic)。
static func generate_chunk(world_seed: int, chunk_x: int, height: int = ChunkConstants.WORLD_HEIGHT) -> Chunk:
	var chunk_width := ChunkConstants.CHUNK_WIDTH
	var c := Chunk.new(chunk_x)
	c.init_empty(height)

	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3

	var sand_noise := FastNoiseLite.new()
	sand_noise.seed = world_seed + 1
	sand_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	sand_noise.frequency = 0.05

	var coal_noise := FastNoiseLite.new()
	coal_noise.seed = world_seed + 3
	coal_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	coal_noise.frequency = 0.12

	var iron_noise := FastNoiseLite.new()
	iron_noise.seed = world_seed + 4
	iron_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	iron_noise.frequency = 0.10

	# 山区 noise: 低频, 决定哪些列是高山 (factor>0) 哪些是平地 (factor=0)
	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = world_seed + 5
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = MOUNTAIN_NOISE_FREQ

	# 计算本 chunk 范围内每列的 heights (供地形 + 树木使用)
	var chunk_start_x := chunk_x * chunk_width
	var chunk_end_x := chunk_start_x + chunk_width
	var chunk_heights := {}  # world_x → surf_y
	for wx in range(chunk_start_x, chunk_end_x):
		var n: float = noise.get_noise_1d(float(wx))
		# 山高度: noise 的正部分作为山高系数 (0=平地 1=山顶)
		var mtn: float = maxf(0.0, mountain_noise.get_noise_1d(float(wx)))
		# surf 减去山高度 (y 越小 = 越高)
		var h: int = int(float(height) * (SURFACE_BASE + n * SURFACE_AMP - mtn * MOUNTAIN_BOOST))
		chunk_heights[wx] = clampi(h, 4, height - BEDROCK_ROWS - 1)

	# 填本 chunk 64 列
	for local_x in chunk_width:
		var world_x: int = chunk_start_x + local_x
		var surf: int = chunk_heights[world_x]
		c.surfaces[local_x] = surf  # 给 ScenicDirector 等查询用
		var is_sand_col := sand_noise.get_noise_1d(float(world_x)) > SAND_THRESHOLD
		var deep_threshold: int = surf + int((height - surf) * DEEP_STONE_RATIO)
		for y in height:
			var tid: int
			if y < surf:
				tid = Tiles.AIR
			elif y == surf:
				tid = Tiles.SAND if is_sand_col else Tiles.GRASS
			elif y < surf + DIRT_DEPTH:
				tid = Tiles.SAND if is_sand_col else Tiles.DIRT
			elif y >= height - BEDROCK_ROWS:
				tid = Tiles.BEDROCK
			else:
				tid = Tiles.DEEP_STONE if y >= deep_threshold else Tiles.STONE

			# 矿石覆盖: 仅在 STONE / DEEP_STONE 上, 铁矿仅深层出现
			if tid == Tiles.STONE or tid == Tiles.DEEP_STONE:
				var cn: float = coal_noise.get_noise_2d(float(world_x), float(y))
				var inn: float = iron_noise.get_noise_2d(float(world_x), float(y))
				if cn > COAL_THRESHOLD:
					tid = Tiles.COAL_ORE
				elif tid == Tiles.DEEP_STONE and inn > IRON_THRESHOLD:
					tid = Tiles.IRON_ORE

			c.tiles[local_x][y] = tid

	# 洞穴: Perlin Worms — 隧道 + 偶发大房间, 跨 chunk 一致
	_carve_worms_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 露天矿洞: 漏斗坑 (pit) 或 窄缝 (crack) 直通地表, 玩家能跳下去
	_carve_open_pits_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 树: 树根只在本 chunk [chunk_start, chunk_end) 内决定 — canopy 越界部分裁掉
	# 邻 chunk 自己会有它的树, 不会出现"漂浮叶"。
	# (在 pits 之后: pit 把 GRASS 挖空了 → 树就不会长在 pit 边缘)
	_place_trees_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 背景墙: 按深度填 草墙 / 土墙 / 石墙 (前景方块后面始终有墙, 挖空才看得到)
	_fill_walls_chunk(c, chunk_heights, chunk_width, height)
	return c


# 按深度给本 chunk 每列填背景墙. 只在"自然矿洞"里填墙 — 即原本生成的 AIR 格.
# - 玩家挖出来的洞: 背后 AIR (没墙), 看到的是天空/纯背景色
# - 自然矿洞 (worm 挖出的隧道) 里面: 有墙 (DIRT_WALL / STONE_WALL 按深度)
# - 地表上方 + 浅层 (前 WALL_HIDE_TOP_TILES 格): 仍无墙
const WALL_HIDE_TOP_TILES := 3
static func _fill_walls_chunk(c: Chunk, chunk_heights: Dictionary, chunk_width: int, height: int) -> void:
	var chunk_start_x: int = c.chunk_x * chunk_width
	for local_x in chunk_width:
		var world_x: int = chunk_start_x + local_x
		var surf: int = chunk_heights[world_x]
		var wall_start: int = surf + WALL_HIDE_TOP_TILES
		for y in height:
			if y < wall_start:
				continue
			# 只有原本就是 AIR 的格才放墙 (= 自然 worm 矿洞内部)
			if c.tiles[local_x][y] != Tiles.AIR:
				continue
			var wid: int
			if y < surf + DIRT_DEPTH:
				wid = Tiles.DIRT_WALL
			else:
				wid = Tiles.STONE_WALL
			c.walls[local_x][y] = wid


# ===== Perlin Worms 洞穴 =====
# 思路: 地下按 WORM_SPAWN_GRID 划格, 每格按确定性 RNG 决定是否生 worm + 起点偏移.
# 每条 worm 从起点出发, 走 60-150 步, 方向由低频 perlin 驱动 (smooth turns).
# 沿路径挖圆 (半径 ~2-3), 偶发大房间 (半径 6). 跨 chunk 时: 生成 chunk_x 会扫描
# ±WORM_SEARCH_PAD_CELLS 内的所有起点, 重新模拟整条 worm, 但只填本 chunk 内的格.
# → 同 seed 下任何 chunk 生成结果一致, 邻 chunk 边界 worm 平滑跨过.
static func _carve_worms_chunk(c: Chunk, chunk_heights: Dictionary, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start: int = chunk_x * chunk_width
	var chunk_end: int = chunk_start + chunk_width

	# 方向噪声: 低频 → 转弯平滑
	var dir_noise := FastNoiseLite.new()
	dir_noise.seed = world_seed + 100
	dir_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	dir_noise.frequency = WORM_DIR_FREQUENCY

	# 半径噪声: 让通道粗细沿程变化
	var rad_noise := FastNoiseLite.new()
	rad_noise.seed = world_seed + 200
	rad_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	rad_noise.frequency = 0.08

	# 地表噪声: 必须跟 generate_chunk 主 noise 完全同参数, 才能在 worm 路径上算出正确的 surf
	var surf_noise := FastNoiseLite.new()
	surf_noise.seed = world_seed
	surf_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	surf_noise.frequency = 0.015
	surf_noise.fractal_octaves = 3

	# 山高 noise: 同 generate_chunk, 让 _surf_at 能算出真实山头位置 (山里 worm 才贴近山头)
	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = world_seed + 5
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = MOUNTAIN_NOISE_FREQ

	# 计算 spawn 格搜索范围: 本 chunk 跨多少格 + 邻居 pad
	var first_cell_x: int = int(floor(float(chunk_start) / WORM_SPAWN_GRID)) - WORM_SEARCH_PAD_CELLS
	var last_cell_x: int = int(floor(float(chunk_end - 1) / WORM_SPAWN_GRID)) + WORM_SEARCH_PAD_CELLS
	var max_cell_y: int = int(ceil(float(height) / WORM_SPAWN_GRID))

	for cell_x in range(first_cell_x, last_cell_x + 1):
		for cell_y in range(0, max_cell_y + 1):
			# 用 (world_seed, cell_x, cell_y) 派生 RNG → 全局确定性
			var rng := RandomNumberGenerator.new()
			rng.seed = _hash3(world_seed, cell_x, cell_y)

			# 起点 = 格内随机位置
			var sx: float = float(cell_x * WORM_SPAWN_GRID) + rng.randf() * WORM_SPAWN_GRID
			var sy: float = float(cell_y * WORM_SPAWN_GRID) + rng.randf() * WORM_SPAWN_GRID

			# 起点必须在地下 ≥3 格, 且不到基岩
			if sy >= float(height - BEDROCK_ROWS - 1):
				continue
			var ix: int = int(floor(sx))
			var surf_here: int = _estimate_surf(ix, world_seed, height)
			if sy <= float(surf_here + 3):
				continue

			# 深度分层概率: 表层稀少 (山头偶有洞口) / 中层中等 / 深层密集
			var depth_below: float = sy - float(surf_here)
			var spawn_chance: float
			if depth_below < WORM_DEPTH_SHALLOW_MAX:
				spawn_chance = WORM_CHANCE_SHALLOW
			elif depth_below < WORM_DEPTH_MID_MAX:
				spawn_chance = WORM_CHANCE_MID
			else:
				spawn_chance = WORM_CHANCE_DEEP
			if rng.randf() > spawn_chance:
				continue

			# 模拟主 worm + 可能的分叉
			var worm_len: int = rng.randi_range(WORM_LEN_MIN, WORM_LEN_MAX)
			_simulate_worm(c, Vector2(sx, sy), worm_len, rng,
					dir_noise, rad_noise, surf_noise, mountain_noise,
					chunk_start, chunk_end, height, 0, 1.0)


# 沿路径挖一条 worm. depth = 当前分叉递归深度, radius_scale = 子孙 worm 半径系数.
# surface_buffer = worm 距地表最少留几格 (普通 worm 用 WORM_SURFACE_BUFFER=20,
# 露天洞的 worm 用 3 让它能贴近开口).
# initial_ang_bias = 调用方强加的初始方向偏移 (露天洞从同一起始室派多 worm 用, 让它们散开).
static func _simulate_worm(c: Chunk, start_pos: Vector2, worm_len: int,
		rng: RandomNumberGenerator, dir_noise: FastNoiseLite, rad_noise: FastNoiseLite,
		surf_noise: FastNoiseLite, mountain_noise: FastNoiseLite,
		chunk_start: int, chunk_end: int, height: int, depth: int,
		radius_scale: float, surface_buffer: int = WORM_SURFACE_BUFFER,
		initial_ang_bias: float = 0.0) -> void:
	# 每条 worm 独有的角度偏移 (避免子 worm 跟主 worm 路径重合, 因为 dir_noise 是位置决定的)
	# 主 worm depth=0 偏移小, 子/孙 worm 偏更多 → 真正岔开
	# 额外加 initial_ang_bias (露天洞主 worm 用, 让多条 worm 从同一点散开)
	var ang_bias: float = rng.randf_range(-PI, PI) * float(depth) * 0.5 + initial_ang_bias
	var pos: Vector2 = start_pos
	for step in worm_len:
		# 触及地表缓冲 → worm 终止 (避免深层 worm 窜到地表附近)
		var surf_at: int = _surf_at(surf_noise, mountain_noise, int(floor(pos.x)), height)
		if pos.y < float(surf_at + surface_buffer):
			break
		# 方向: perlin 输出 [-1,1] → angle [-PI, PI] (smooth turns) + worm 个体 bias
		var ang: float = dir_noise.get_noise_2d(pos.x, pos.y) * PI + ang_bias
		# 半径: 沿程在 [MIN, MAX] 之间慢慢变化 × 分叉缩放
		var rn: float = (rad_noise.get_noise_2d(pos.x, pos.y) + 1.0) * 0.5  # [0,1]
		var radius: float = lerp(WORM_RADIUS_MIN, WORM_RADIUS_MAX, rn) * radius_scale
		# 挖圆 (只填落入本 chunk 的)
		_carve_circle(c, pos, radius, chunk_start, chunk_end, height)
		# 分叉: 派子 worm (角度偏移 ±60°, 长度更短, 半径更细)
		if depth < WORM_BRANCH_MAX_DEPTH and rng.randf() < WORM_BRANCH_CHANCE:
			var branch_len: int = rng.randi_range(WORM_LEN_MIN / 2, WORM_LEN_MAX / 2)
			var branch_ang: float = ang + rng.randf_range(-PI / 3.0, PI / 3.0)
			var branch_start: Vector2 = pos + Vector2(cos(branch_ang), sin(branch_ang))
			var sub_rng := RandomNumberGenerator.new()
			sub_rng.seed = rng.randi() ^ step
			var sub_scale: float = radius_scale * WORM_BRANCH_RADIUS_SCALE
			_carve_circle(c, branch_start, radius * WORM_BRANCH_RADIUS_SCALE,
					chunk_start, chunk_end, height)
			_simulate_worm(c, branch_start, branch_len, sub_rng,
					dir_noise, rad_noise, surf_noise, mountain_noise,
					chunk_start, chunk_end, height, depth + 1, sub_scale, surface_buffer)
		# 前进 1 tile
		pos += Vector2(cos(ang), sin(ang))
		# 走出世界边界 / 进入基岩区 → 提前终止
		if pos.y < 0.0 or pos.y >= float(height - BEDROCK_ROWS):
			break


# 用共享 surf_noise + mountain_noise 算单列 surf (供 worm 路径检查), 避免每次 new FastNoiseLite.
# 必须跟 generate_chunk 的 surf 公式完全一致, 才能让 worm 在山里也精准贴近真实山头.
static func _surf_at(surf_noise: FastNoiseLite, mountain_noise: FastNoiseLite, world_x: int, height: int) -> int:
	var v: float = surf_noise.get_noise_1d(float(world_x))
	var mtn: float = maxf(0.0, mountain_noise.get_noise_1d(float(world_x)))
	var h: int = int(float(height) * (SURFACE_BASE + v * SURFACE_AMP - mtn * MOUNTAIN_BOOST))
	return clampi(h, 4, height - BEDROCK_ROWS - 1)


# 挖圆: 中心 center 半径 radius, 只填 [chunk_start, chunk_end) × [0, height).
# 不挖 BEDROCK / 矿石; 不挖地表上方 (保留天空).
static func _carve_circle(c: Chunk, center: Vector2, radius: float,
		chunk_start: int, chunk_end: int, height: int) -> void:
	var r2: float = radius * radius
	var x0: int = int(floor(center.x - radius))
	var x1: int = int(ceil(center.x + radius))
	var y0: int = int(floor(center.y - radius))
	var y1: int = int(ceil(center.y + radius))
	for wx in range(x0, x1 + 1):
		if wx < chunk_start or wx >= chunk_end:
			continue
		var lx: int = wx - chunk_start
		for wy in range(y0, y1 + 1):
			if wy < 0 or wy >= height:
				continue
			var dx: float = float(wx) - center.x
			var dy: float = float(wy) - center.y
			if dx * dx + dy * dy > r2:
				continue
			var t: int = c.tiles[lx][wy]
			if t == Tiles.BEDROCK or t == Tiles.AIR:
				continue
			if t == Tiles.COAL_ORE or t == Tiles.IRON_ORE:
				continue
			if t == Tiles.GRASS:
				continue  # 不破坏地表 (避免随机竖井裸露)
			c.tiles[lx][wy] = Tiles.AIR


# ===== 露天矿洞 (Terraria 表面洞穴风) =====
# 平地小坡上有小开口, 下面是 worm 分叉迷宫. 山区不生成.
# 结构: 1) 表面 2-3 宽×3-5 深小开口 2) 起始室 (3 半径圆) 3) 派 2-3 worm 散开
# worm 用 surface_buffer=3 (能贴开口但不戳破地表), 半径×1.4 比普通矿道粗.
# worm 自带分叉 (WORM_BRANCH_CHANCE) + 死路 (worm_len 跑完就停) → 自然迷宫.
# 跨 chunk 一致: 同 spawn_x 用 _hash3 派生 RNG, worm 用各自子 hash.
static func _carve_open_pits_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start_x: int = chunk_x * chunk_width
	var chunk_end_x: int = chunk_start_x + chunk_width

	# 共享 noises (worm 模拟用), 跟 _carve_worms_chunk 同 seed 偏移
	var dir_noise := FastNoiseLite.new()
	dir_noise.seed = world_seed + 100
	dir_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	dir_noise.frequency = WORM_DIR_FREQUENCY

	var rad_noise := FastNoiseLite.new()
	rad_noise.seed = world_seed + 200
	rad_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	rad_noise.frequency = 0.08

	var surf_noise := FastNoiseLite.new()
	surf_noise.seed = world_seed
	surf_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	surf_noise.frequency = 0.015
	surf_noise.fractal_octaves = 3

	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = world_seed + 5
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = MOUNTAIN_NOISE_FREQ

	# 扫描邻 chunk 边缘 (worm 最远可达 OPEN_WORM_PAD_CELLS)
	for spawn_x in range(chunk_start_x - OPEN_WORM_PAD_CELLS, chunk_end_x + OPEN_WORM_PAD_CELLS):
		var rng := RandomNumberGenerator.new()
		rng.seed = _hash3(world_seed, spawn_x, 7777)
		if rng.randf() > 1.0 / float(OPEN_PIT_SPACING):
			continue
		# 反转: 山区跳过 (用户要求 不在山上面). 平地/小坡才生成
		var mtn: float = maxf(0.0, mountain_noise.get_noise_1d(float(spawn_x)))
		if mtn > MOUNTAIN_PIT_THRESHOLD:
			continue

		# 本列地表 (邻 chunk 用 _surf_at 估算, 跟 generate_chunk 同公式)
		var col_surf: int = chunk_heights.get(spawn_x, -1)
		if col_surf < 0:
			col_surf = _surf_at(surf_noise, mountain_noise, spawn_x, height)

		# === 1. 表面小开口 (玩家能看到的洞口, 直接挖穿 GRASS) ===
		var opening_w: int = rng.randi_range(OPEN_OPENING_WIDTH_MIN, OPEN_OPENING_WIDTH_MAX)
		var opening_d: int = rng.randi_range(OPEN_OPENING_DEPTH_MIN, OPEN_OPENING_DEPTH_MAX)
		var half_w: int = opening_w / 2
		for i in range(opening_w):
			var dx: int = i - half_w
			var wx: int = spawn_x + dx
			var lx: int = wx - chunk_start_x
			if lx < 0 or lx >= chunk_width:
				continue
			for dy in range(opening_d):
				var y: int = col_surf + dy
				if y < 0 or y >= height - BEDROCK_ROWS:
					continue
				var t: int = c.tiles[lx][y]
				if t == Tiles.BEDROCK or t == Tiles.COAL_ORE or t == Tiles.IRON_ORE:
					continue
				c.tiles[lx][y] = Tiles.AIR

		# === 2. 起始室 (开口底下圆) ===
		var chamber_y: float = float(col_surf + opening_d + 2)
		_carve_circle(c, Vector2(float(spawn_x), chamber_y), OPEN_CHAMBER_RADIUS,
				chunk_start_x, chunk_end_x, height)

		# === 3. 派 2-3 worm 散开 (各带初始角度偏移, 自然 fan-out) ===
		var worm_count: int = rng.randi_range(OPEN_WORM_COUNT_MIN, OPEN_WORM_COUNT_MAX)
		for wi in range(worm_count):
			var worm_rng := RandomNumberGenerator.new()
			worm_rng.seed = _hash3(world_seed, spawn_x, 5000 + wi)
			var worm_len: int = worm_rng.randi_range(OPEN_WORM_LEN_MIN, OPEN_WORM_LEN_MAX)
			# 初始方向偏向"下方扇形" (30°-150°), 让 worm 往地下散开而不是飘空中
			var bias: float = worm_rng.randf_range(PI / 6.0, 5.0 * PI / 6.0)
			_simulate_worm(c, Vector2(float(spawn_x), chamber_y), worm_len, worm_rng,
					dir_noise, rad_noise, surf_noise, mountain_noise,
					chunk_start_x, chunk_end_x, height, 0,
					OPEN_WORM_RADIUS_SCALE, OPEN_WORM_SURFACE_BUFFER, bias)


# 跟 generate_chunk 里 surf 公式一致: 用主 noise 的种子重算单列 surf.
# 这里独立算一遍, 不依赖传入的 chunk_heights (worm 起点可能落在邻 chunk).
static func _estimate_surf(world_x: int, world_seed: int, height: int) -> int:
	var n := FastNoiseLite.new()
	n.seed = world_seed
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = 0.015
	n.fractal_octaves = 3
	var v: float = n.get_noise_1d(float(world_x))
	# 山高度系数 (跟 generate_chunk 完全一致)
	var mtn: float = _mountain_factor(world_x, world_seed)
	var h: int = int(float(height) * (SURFACE_BASE + v * SURFACE_AMP - mtn * MOUNTAIN_BOOST))
	return clampi(h, 4, height - BEDROCK_ROWS - 1)


# 山区高度系数: 0=平地, 1=山顶. 用低频 perlin 取正部分.
# 注: 每次重建 FastNoiseLite 开销小, 但相比 cache 慢 — pit 生成时 ~200 列调一次, 可接受.
static func _mountain_factor(world_x: int, world_seed: int) -> float:
	var n := FastNoiseLite.new()
	n.seed = world_seed + 5
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = MOUNTAIN_NOISE_FREQ
	return maxf(0.0, n.get_noise_1d(float(world_x)))


# 3 整数 → 64-bit 稳定 hash (worm RNG 种子). 不用内建 hash() 因为它对 int 输入返回值未指定.
static func _hash3(a: int, b: int, c: int) -> int:
	var h: int = a * 73856093
	h ^= b * 19349663
	h ^= c * 83492791
	# 混合避免低位偏差
	h ^= (h >> 16)
	h *= 0x85ebca6b
	h ^= (h >> 13)
	return h & 0x7fffffff


# Chunk 版本树木放置: 树根只在本 chunk [chunk_start, chunk_end) 内, canopy 越界部分裁掉。
# 邻 chunk 各自有树, 边界不会出现"漂浮叶"。
static func _place_trees_chunk(c: Chunk, chunk_heights: Dictionary, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	var rng := RandomNumberGenerator.new()
	# 基于 (world_seed, chunk_x) 派生子种子, 同 chunk 同结果
	rng.seed = world_seed * 1000003 + chunk_x * 31 + 17
	var chunk_start: int = chunk_x * chunk_width
	var chunk_end: int = chunk_start + chunk_width
	# canopy 横向最大 ±2 tile (oak_large / pine_huge), 留 3 格安全边距避免树冠被 chunk 边界裁掉
	const CANOPY_EDGE_MARGIN := 3
	var safe_start: int = chunk_start + CANOPY_EDGE_MARGIN
	var safe_end: int = chunk_end - CANOPY_EDGE_MARGIN
	var last_tree_x: int = -1000
	for world_x in range(safe_start, safe_end):
		var surf: int = chunk_heights.get(world_x, -1)
		if surf < 0:
			continue
		var lx: int = world_x - chunk_start
		if c.tiles[lx][surf] != Tiles.GRASS:
			continue
		if world_x - last_tree_x < TREE_MIN_SPACING:
			continue
		if rng.randf() > TREE_CHANCE:
			continue
		var species: int = rng.randi_range(_SPECIES_OAK, _SPECIES_AUTUMN)
		var params: Dictionary = _SPECIES_PARAMS[species]
		var trunk_range: Array = params["trunk_range"]
		var leaves_tile: int = params["leaves"]
		var canopies: Array = params["canopies"]
		var canopy_kind: String = canopies[rng.randi() % canopies.size()]
		var trunk_height: int = rng.randi_range(trunk_range[0], trunk_range[1])
		var trunk_top: int = surf - trunk_height
		var canopy_top: int = trunk_top - _CANOPY_REACH[canopy_kind]
		if canopy_top < 0:
			continue
		# 检查树干列空间是否 AIR
		var all_clear: bool = true
		for ty in range(canopy_top, surf):
			if c.tiles[lx][ty] != Tiles.AIR:
				all_clear = false
				break
		if not all_clear:
			continue
		# 树干
		for ty in range(trunk_top, surf):
			c.tiles[lx][ty] = Tiles.LOG
		# 树冠: 越出 chunk 的部分裁掉
		_place_canopy_chunk(c, world_x, trunk_top, canopy_kind, leaves_tile, chunk_start, chunk_end, height)
		last_tree_x = world_x


# 画树冠到 chunk 内 (out-of-chunk 的部分丢弃)
static func _place_canopy_chunk(c: Chunk, trunk_world_x: int, trunk_top: int,
		kind: String, leaves_tile: int, chunk_start: int, chunk_end: int, height: int) -> void:
	var offsets: Array = _canopy_offsets(kind)
	for off in offsets:
		var cx_world: int = trunk_world_x + off.x
		var cy: int = trunk_top + off.y
		if cx_world < chunk_start or cx_world >= chunk_end:
			continue  # buffer 区域 (邻 chunk 会单独画)
		if cy < 0 or cy >= height:
			continue
		var lx: int = cx_world - chunk_start
		if c.tiles[lx][cy] != Tiles.AIR:
			continue
		# 防贴地叶
		if cy + 1 < height:
			var below: int = c.tiles[lx][cy + 1]
			if below != Tiles.AIR and below != Tiles.LOG \
					and below != Tiles.LEAVES and below != Tiles.LEAVES_PINE \
					and below != Tiles.LEAVES_AUTUMN:
				continue
		c.tiles[lx][cy] = leaves_tile


static func generate(world_seed: int, width: int = 1024, height: int = ChunkConstants.WORLD_HEIGHT) -> Dictionary:
	var tiles: Array = []
	tiles.resize(width)
	var num_chunks: int = ceili(float(width) / float(ChunkConstants.CHUNK_WIDTH))
	for cx in num_chunks:
		var c := generate_chunk(world_seed, cx, height)
		for local_x in c.tiles.size():
			var world_x: int = cx * ChunkConstants.CHUNK_WIDTH + local_x
			if world_x < width:
				tiles[world_x] = c.tiles[local_x]
	# 出生点: 在 chunk 0 内找
	var heights := PackedInt32Array()
	heights.resize(width)
	for x in width:
		# 从 tiles 反推 height (第一个非 AIR tile 的 y)
		for y in height:
			if tiles[x][y] != Tiles.AIR:
				heights[x] = y
				break
	var center_x: int = width / 2
	var spawn_x: int = _find_spawn_x(tiles, heights, center_x, width)
	var spawn_y: int = heights[spawn_x] - 1
	return {
		"tiles": tiles,
		"spawn_point": Vector2i(spawn_x, spawn_y),
		"seed": world_seed,
		"width": width,
		"height": height,
	}


# 从 center_x 向两侧线性扩散, 返回第一个 GRASS 且头顶 3 格空气的列。
# 找不到 (理论上不会, 至少有一根草) → fallback 到 center_x。
static func _find_spawn_x(tiles: Array, heights: PackedInt32Array, center_x: int, width: int) -> int:
	for delta in range(width):
		for direction in [1, -1]:
			if delta == 0 and direction == -1:
				continue
			var cx: int = center_x + direction * delta
			if cx < 0 or cx >= width:
				continue
			var surf: int = heights[cx]
			if surf < 3 or surf >= (tiles[cx] as Array).size():
				continue
			if tiles[cx][surf] != Tiles.GRASS:
				continue
			if tiles[cx][surf - 1] != Tiles.AIR \
					or tiles[cx][surf - 2] != Tiles.AIR \
					or tiles[cx][surf - 3] != Tiles.AIR:
				continue
			return cx
	return center_x


static func _canopy_offsets(kind: String) -> Array:
	var offs: Array = []
	match kind:
		# === OAK 橡木 ===
		"oak_small":
			# 5 格小冠: 上排 3 + 两侧 2
			for dx in range(-1, 2): offs.append(Vector2i(dx, -1))
			offs.append(Vector2i(-1, 0)); offs.append(Vector2i(1, 0))
		"oak_med":
			# 经典 3x3
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					offs.append(Vector2i(dx, dy))
		"oak_large":
			# 5 宽圆冠 (rhombus)
			for dx in range(-1, 2): offs.append(Vector2i(dx, -2))
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))
			offs.append(Vector2i(-1, 1)); offs.append(Vector2i(1, 1))
		"oak_tall":
			# 3 宽 x 4 高
			offs.append(Vector2i(0, -3))
			for dy in range(-2, 2):
				for dx in range(-1, 2):
					offs.append(Vector2i(dx, dy))
		# === PINE 松树 (始终锥形) ===
		"pine_small":
			# 顶尖 + 3 宽 x 2
			offs.append(Vector2i(0, -2))
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					offs.append(Vector2i(dx, dy))
		"pine_med":
			# 顶尖 + 3 宽 x 3
			offs.append(Vector2i(0, -3))
			for dy in range(-2, 2):
				for dx in range(-1, 2):
					offs.append(Vector2i(dx, dy))
		"pine_large":
			# 双层锥
			offs.append(Vector2i(0, -4))
			for dx in range(-1, 2): offs.append(Vector2i(dx, -3))
			for dx in range(-1, 2): offs.append(Vector2i(dx, -2))
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))
			offs.append(Vector2i(-1, 1)); offs.append(Vector2i(1, 1))
		"pine_huge":
			# 5 层超高锥
			offs.append(Vector2i(0, -5))
			for dx in range(-1, 2): offs.append(Vector2i(dx, -4))
			for dx in range(-1, 2): offs.append(Vector2i(dx, -3))
			for dx in range(-2, 3): offs.append(Vector2i(dx, -2))
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))
			offs.append(Vector2i(-1, 1)); offs.append(Vector2i(1, 1))
		# === AUTUMN 秋树 (始终偏宽扁) ===
		"autumn_small":
			# 3x3 (跟 oak_med 一样但叶色不同)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					offs.append(Vector2i(dx, dy))
		"autumn_med":
			# 5 宽 x 3 高菱形
			for dx in range(-1, 2): offs.append(Vector2i(dx, -1))
			for dx in range(-2, 3): offs.append(Vector2i(dx, 0))
			for dx in range(-1, 2): offs.append(Vector2i(dx, 1))
		"autumn_large":
			# 5 宽 x 4 高
			for dx in range(-1, 2): offs.append(Vector2i(dx, -2))
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))
			for dx in range(-1, 2): offs.append(Vector2i(dx, 1))
		"autumn_huge":
			# 7 宽 x 3 高扁阔伞冠
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			for dx in range(-3, 4): offs.append(Vector2i(dx, 0))
			for dx in range(-2, 3): offs.append(Vector2i(dx, 1))
	return offs
