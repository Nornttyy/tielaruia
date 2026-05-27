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

# Biome (生态群系) — 泰拉瑞亚风: 每种 biome 全世界只有一块, 固定方位.
# 雪原+沙漠 在左远处, 丛林+沼泽 在右远处, spawn 周围是森林.
# 各 biome 中心 X + 半宽 (世界坐标 tile). 中心位置加 seed jitter.
const BIOME_FOREST := 0
const BIOME_DESERT := 1
const BIOME_SNOW := 2
const BIOME_JUNGLE := 3
const BIOME_SWAMP := 4
# 4 个固定 "槽位" (中心 X), 4 个 biome 用 seed shuffle 分到槽位.
# 槽位都距 spawn>=300 列, 保证 spawn 周围是 forest. 槽位间距 600 防重叠.
const _BIOME_SLOTS := [-1200, -600, 600, 1200]
const _BIOME_SLOT_HALF_WIDTH := 175  # 每个 biome 半宽 (= 350 列宽)
const _BIOME_CENTER_JITTER := 80     # 中心额外随机 ±80 列

const BEDROCK_ROWS := 2          # 基岩占最底几行
const SAND_THRESHOLD := 0.4      # sand_noise 超过此阈值的列为沙列
const TREE_MIN_SPACING := 8      # 相邻两棵树/仙人掌之间最少 N 列间距 (越大越稀)
const TREE_CHANCE := 0.30        # 候选格子里实际长树的概率 (越小越稀)
const CACTUS_CHANCE := 0.30      # 沙漠候选格子里实际长仙人掌的概率
const CACTUS_HEIGHT_MIN := 1     # 仙人掌最矮 1 格
const CACTUS_HEIGHT_MAX := 3     # 最高 3 格

const DEEP_STONE_RATIO := 0.5    # 地表往下 (height-surf)*0.5 处起为 DEEP_STONE
const COAL_THRESHOLD := 0.30     # 降低 → 煤矿更密
const IRON_THRESHOLD := 0.30     # 铁矿密度 (DEEP_STONE 用此, STONE 用 IRON_SHALLOW_THRESHOLD)
const IRON_SHALLOW_THRESHOLD := 0.55  # 浅 STONE 里铁矿也能出, 但稀
# 新矿 (T26):
const COPPER_THRESHOLD := 0.30   # 铜矿: 浅层 STONE 常见
const TIN_THRESHOLD := 0.35      # 锡矿: 浅层 STONE 稍稀
const GOLD_THRESHOLD := 0.40     # 金矿: 深度 > 40 (相对 surf), 中等
const DIAMOND_THRESHOLD := 0.50  # 钻石: 深度 > 80, 较稀
const HELL_THRESHOLD := 0.55     # 地狱晶体: 深度 > 150, 很稀
# 矿层深度边界 (y - surf), 单位 tile
const ORE_DEPTH_SHALLOW_MAX := 50   # 铜锡浅层上限
const ORE_DEPTH_MID_MIN := 40       # 金矿起始深度
const ORE_DEPTH_DEEP_MIN := 80      # 钻石起始深度
const ORE_DEPTH_HELL_MIN := 150     # 地狱晶体起始深度

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
const WORM_Y_SQUASH := 0.5         # Y 方向步进系数 (X=1.0 不变, Y=0.5 → 矿洞偏横向, 像泰拉瑞亚)
const WORM_SEARCH_PAD_CELLS := 7   # 邻 chunk 搜索半径
# 深度分层生成概率: depth = sy - surf
const WORM_CHANCE_SHALLOW := 0.02  # 表层近乎实心, 只 2% 概率出"山头洞口"
const WORM_CHANCE_MID := 0.25      # 中层零散通道, 玩家挖才会遇到
const WORM_CHANCE_DEEP := 0.92     # 深层密如蛛网 (玩家"主动下矿"区)
const WORM_DEPTH_SHALLOW_MAX := 40  # 地表 40 格内安全, 不会"踩进去"
const WORM_DEPTH_MID_MAX := 110     # surf+110 起密集
const WORM_SURFACE_BUFFER := 20     # worm 路径距地表至少 20 格 (走近就 break, 防止深层 worm 窜到地表)

# 露天矿洞 (Terraria 山坡侧面洞穴): 山坡侧面挖个洞口, 朝左/右开, 不是天坑.
# 在斜坡 (terrain slope) 上找一个低边, 朝高边方向挖横向隧道进山 + 工程师分叉.
# 山区 (mountain_factor > MOUNTAIN_PIT_THRESHOLD) 不生成.
# 跨 chunk 一致: 用 _hash3 派生 RNG. 邻 chunk 搜索 ±OPEN_WORM_PAD_CELLS.
const OPEN_PIT_SPACING := 50         # 1/50 = 2% 概率/列, 但还要过斜坡过滤
const OPEN_SLOPE_CHECK_DX := 6       # 检查 ±6 列内 surf 高度差 (= 斜坡探测半径)
const OPEN_SLOPE_MIN_DIFF := 3       # 至少 3 格高度差才算斜坡 (= 不在平地刷)
const OPEN_TUNNEL_LEN_MIN := 4       # 横向隧道长度 (玩家看到的入口段)
const OPEN_TUNNEL_LEN_MAX := 8
const OPEN_TUNNEL_HEIGHT := 3        # 隧道高 (= 玩家能站直 + 一格余地)
const OPEN_CHAMBER_RADIUS := 3.0     # 隧道尽头小室
const OPEN_WORM_COUNT_MIN := 2       # 小室派出的 worm 数 (= 分叉数)
const OPEN_WORM_COUNT_MAX := 3
const OPEN_WORM_LEN_MIN := 50
const OPEN_WORM_LEN_MAX := 100
const OPEN_WORM_RADIUS_SCALE := 1.4  # worm 半径系数 (实际 1.1-1.8)
const OPEN_WORM_SURFACE_BUFFER := 3  # worm 距地表 ≥ 3, 不会再戳破地表
const OPEN_WORM_PAD_CELLS := 100     # 邻 chunk 搜索 pad

# 水池: 矿洞洼地 BFS flood fill 填水. 沙漠列稀疏长绿洲.
const WATER_MIN_DEPTH := 60           # 矿洞水池: surf 下 ≥60 格才算"深矿洞"
const WATER_POOL_CHANCE := 0.45       # 洼地填水概率 (35→45%, 多点水)
const WATER_FILL_LEVEL := 6           # 水池高 (从洼地底起填到 6 格)
const WATER_BASIN_MAX_SIZE := 60      # BFS 单池最多 60 格 (防大房间整个变水缸)
const OCEAN_DEPTH := 200              # y > 200 (接近基岩) AIR 强制水 = 地下海洋
const OASIS_CHANCE := 0.012           # 沙漠列 1.2% 概率长绿洲
const OASIS_WIDTH_MIN := 4            # 绿洲宽 (3→4 大点)
const OASIS_WIDTH_MAX := 8            # 绿洲宽 (6→8 大点)
const OASIS_DEPTH := 3                # 绿洲深 (2→3)

# 树种枚举 (内部 idx) — 现在只剩 OAK (T-tree 重做)
const _SPECIES_OAK := 0

# 每个 canopy_kind 向上伸的最大格数 (用于检查是否出界)
# 全部改成"云朵分层"形状: 多个 3 宽 puff 上下错位叠加
const _CANOPY_REACH := {
	"oak_cloud_small": 2,    # 2 层云朵 puff
	"oak_cloud_med": 3,      # 3 层蘑菇头
	"oak_cloud_large": 4,    # 4 层大云朵
	"oak_cloud_huge": 5,     # 5 层超大云朵
}

# 树种参数. 只剩 OAK; canopies 重复表示该尺寸更常见
const _SPECIES_PARAMS := {
	_SPECIES_OAK: {
		"trunk_range": [6, 12],  # 树更高 (4-8 → 6-12, 加分支空间)
		"leaves": Tiles.LEAVES,
		"canopies": ["oak_cloud_small", "oak_cloud_med", "oak_cloud_med", "oak_cloud_large", "oak_cloud_huge"],
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

	# 新矿噪声 (T26): 每种独立 seed, 不同 frequency 让斑块大小有差异
	var copper_noise := FastNoiseLite.new()
	copper_noise.seed = world_seed + 10
	copper_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	copper_noise.frequency = 0.13

	var tin_noise := FastNoiseLite.new()
	tin_noise.seed = world_seed + 11
	tin_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tin_noise.frequency = 0.13

	var gold_noise := FastNoiseLite.new()
	gold_noise.seed = world_seed + 12
	gold_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	gold_noise.frequency = 0.09

	var diamond_noise := FastNoiseLite.new()
	diamond_noise.seed = world_seed + 13
	diamond_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	diamond_noise.frequency = 0.08

	var hell_noise := FastNoiseLite.new()
	hell_noise.seed = world_seed + 14
	hell_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	hell_noise.frequency = 0.07

	# 山区 noise: 低频, 决定哪些列是高山 (factor>0) 哪些是平地 (factor=0)
	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = world_seed + 5
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = MOUNTAIN_NOISE_FREQ

	# Biome centers: 4 个 biome 用 seed shuffle 分到 _BIOME_SLOTS, 每个 +- jitter
	var biome_centers: Dictionary = _build_biome_centers(world_seed)

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
		# Biome (5 种): 走到固定区块就变, 否则默认 FOREST.
		var biome_id: int = _biome_at_x(world_x, biome_centers)
		var is_desert: bool = biome_id == BIOME_DESERT
		# is_sand_col: 沙漠列整列沙, 或 forest 偶发零星沙窝
		var is_sand_col: bool = is_desert or (biome_id == BIOME_FOREST and sand_noise.get_noise_1d(float(world_x)) > SAND_THRESHOLD)
		var deep_threshold: int = surf + int((height - surf) * DEEP_STONE_RATIO)
		# 各 biome 地表 / 浅地下 tile
		var surf_tile: int = _biome_surface_tile(biome_id, is_sand_col)
		var sub_tile: int = _biome_subsurface_tile(biome_id, is_sand_col)
		for y in height:
			var tid: int
			if y < surf:
				tid = Tiles.AIR
			elif y == surf:
				tid = surf_tile
			elif y < surf + DIRT_DEPTH:
				tid = sub_tile
			elif y >= height - BEDROCK_ROWS:
				tid = Tiles.BEDROCK
			else:
				tid = Tiles.DEEP_STONE if y >= deep_threshold else Tiles.STONE

			# 矿石覆盖: 仅在 STONE / DEEP_STONE 上. 优先级 高 → 低:
			# 地狱晶体 > 钻石 > 金 > 铁 > 锡 > 铜 > 煤 (深度限制 + 噪声 threshold).
			# 同位置多种 noise 都过 threshold 时, 用 elif 链优先取稀有的.
			if tid == Tiles.STONE or tid == Tiles.DEEP_STONE:
				var depth: int = y - surf
				var cn: float = coal_noise.get_noise_2d(float(world_x), float(y))
				var inn: float = iron_noise.get_noise_2d(float(world_x), float(y))
				var hn: float = hell_noise.get_noise_2d(float(world_x), float(y))
				var dn: float = diamond_noise.get_noise_2d(float(world_x), float(y))
				var gn: float = gold_noise.get_noise_2d(float(world_x), float(y))
				var un: float = copper_noise.get_noise_2d(float(world_x), float(y))
				var tn: float = tin_noise.get_noise_2d(float(world_x), float(y))
				if depth >= ORE_DEPTH_HELL_MIN and hn > HELL_THRESHOLD:
					tid = Tiles.HELL_CRYSTAL
				elif depth >= ORE_DEPTH_DEEP_MIN and dn > DIAMOND_THRESHOLD:
					tid = Tiles.DIAMOND_ORE
				elif depth >= ORE_DEPTH_MID_MIN and gn > GOLD_THRESHOLD:
					tid = Tiles.GOLD_ORE
				elif tid == Tiles.DEEP_STONE and inn > IRON_THRESHOLD:
					tid = Tiles.IRON_ORE
				elif tid == Tiles.STONE and inn > IRON_SHALLOW_THRESHOLD:
					tid = Tiles.IRON_ORE
				elif depth <= ORE_DEPTH_SHALLOW_MAX and tn > TIN_THRESHOLD:
					tid = Tiles.TIN_ORE
				elif depth <= ORE_DEPTH_SHALLOW_MAX and un > COPPER_THRESHOLD:
					tid = Tiles.COPPER_ORE
				elif cn > COAL_THRESHOLD:
					tid = Tiles.COAL_ORE

			c.tiles[local_x][y] = tid

	# 洞穴: Perlin Worms — 隧道 + 偶发大房间, 跨 chunk 一致
	_carve_worms_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 露天矿洞: 漏斗坑 (pit) 或 窄缝 (crack) 直通地表, 玩家能跳下去
	_carve_open_pits_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 沙漠地下保护: 把 SAND 邻 AIR 的 tile 改 STONE (防沙崩塌填满矿洞)
	_protect_sand_caves(c, chunk_heights, chunk_width, height)

	# 水: 矿洞洼地 + 沙漠绿洲 + 地下海洋. 先于树, 这样:
	# - 树 _place_trees_chunk 检测 surf 是 WATER 时自动跳过 (既不是 GRASS 也不是 SAND)
	# - 仙人掌不会长在绿洲水里
	_fill_water_pools_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 树: 树根只在本 chunk [chunk_start, chunk_end) 内决定 — canopy 越界部分裁掉.
	# 在 water 之后: 绿洲水替换了 SAND 地表, 树/仙人掌不会长在水上.
	_place_trees_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 背景墙: 按深度填 草墙 / 土墙 / 石墙 (前景方块后面始终有墙, 挖空才看得到)
	_fill_walls_chunk(c, chunk_heights, chunk_width, height)
	return c


# 沙漠地下: 矿洞被 SAND 包着的话, 沙子物理崩塌会立刻填回去 → 把 SAND
# 邻 AIR 那些 tile 改成 STONE, 给沙漠矿洞砌一圈石头墙.
# 只处理地表下 2+ 格的 SAND (避免动到地表沙地).
static func _protect_sand_caves(c: Chunk, chunk_heights: Dictionary,
		chunk_width: int, height: int) -> void:
	var chunk_start: int = c.chunk_x * chunk_width
	for lx in range(chunk_width):
		var world_x: int = chunk_start + lx
		var surf: int = chunk_heights.get(world_x, -1)
		if surf < 0:
			continue
		for y in range(surf + 2, height - BEDROCK_ROWS):  # 地表下 2 格起
			if c.tiles[lx][y] != Tiles.SAND:
				continue
			# 检查 4 邻是否有 AIR (本 chunk 内的就够 — 跨 chunk 边界粗略, 可接受)
			var touches_air: bool = false
			for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
				var nx: int = lx + d.x
				var ny: int = y + d.y
				if nx < 0 or nx >= chunk_width or ny < 0 or ny >= height:
					continue
				if c.tiles[nx][ny] == Tiles.AIR:
					touches_air = true
					break
			if touches_air:
				c.tiles[lx][y] = Tiles.STONE


# 按深度给本 chunk 每列填背景墙. 只在"自然矿洞"里 (含周围的岩石) 填墙.
# - 矿洞 AIR 格: 直接填墙
# - 矿洞 AIR 周围 R 格内的岩石: 也填墙 (玩家挖矿洞旁边的石头仍能看到墙)
# - 玩家挖出来的孤立洞 (远离自然矿洞): 背后无墙, 看到的是天空/纯背景色
# - 地表上方 + 浅层 (前 WALL_HIDE_TOP_TILES 格): 仍无墙
const WALL_HIDE_TOP_TILES := 3
const WALL_EXTEND_RADIUS := 3   # 矿洞 AIR 外扩 R 格岩石也填墙 (像泰拉瑞亚)
static func _fill_walls_chunk(c: Chunk, chunk_heights: Dictionary, chunk_width: int, height: int) -> void:
	var chunk_start_x: int = c.chunk_x * chunk_width
	# Pass 1: 矿洞内部 (AIR 格) 填墙
	for local_x in chunk_width:
		var world_x: int = chunk_start_x + local_x
		var surf: int = chunk_heights[world_x]
		var wall_start: int = surf + WALL_HIDE_TOP_TILES
		for y in height:
			if y < wall_start:
				continue
			if c.tiles[local_x][y] != Tiles.AIR:
				continue
			c.walls[local_x][y] = _wall_for_depth(y, surf)
	# Pass 2: AIR 周围 R 格内的岩石也填墙 (圆形外扩)
	var r2: int = WALL_EXTEND_RADIUS * WALL_EXTEND_RADIUS
	for local_x in chunk_width:
		for y in height:
			if c.tiles[local_x][y] != Tiles.AIR:
				continue
			# 遍历这个 AIR 周围 R 半径的方块
			for dx in range(-WALL_EXTEND_RADIUS, WALL_EXTEND_RADIUS + 1):
				for dy in range(-WALL_EXTEND_RADIUS, WALL_EXTEND_RADIUS + 1):
					if dx * dx + dy * dy > r2:
						continue
					var nx: int = local_x + dx
					var ny: int = y + dy
					if nx < 0 or nx >= chunk_width:
						continue
					if ny < 0 or ny >= height:
						continue
					if c.walls[nx][ny] != Tiles.AIR:
						continue  # 已经有墙
					var n_surf: int = chunk_heights[chunk_start_x + nx]
					if ny < n_surf + WALL_HIDE_TOP_TILES:
						continue  # 浅层不放墙
					c.walls[nx][ny] = _wall_for_depth(ny, n_surf)


static func _wall_for_depth(y: int, surf: int) -> int:
	if y < surf + DIRT_DEPTH:
		return Tiles.DIRT_WALL
	return Tiles.STONE_WALL


# ===== 水池 + 沙漠绿洲 + 地下海洋 =====
# 矿洞洼地 BFS flood fill: 找连通 AIR 区域底部填 WATER_FILL_LEVEL 格水, 像真湖.
# 沙漠绿洲: 沙地表稀疏长大水池.
# 地下海洋: y > OCEAN_DEPTH 的 AIR 直接全填水 (深矿挖到底是大海).
static func _fill_water_pools_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start_x: int = chunk_x * chunk_width

	# === 1) 地下海洋: y > OCEAN_DEPTH 的所有 AIR 强制水 ===
	for lx in range(chunk_width):
		var col: Array = c.tiles[lx]
		for y in range(OCEAN_DEPTH, col.size() - BEDROCK_ROWS):
			if col[y] == Tiles.AIR:
				col[y] = Tiles.WATER

	# === 2) 沙漠绿洲: 沙地表稀疏长碗状水池 (中心深, 边缘浅, 边带锯齿) ===
	for lx in range(chunk_width):
		var world_x: int = chunk_start_x + lx
		var surf: int = chunk_heights[world_x]
		var col2: Array = c.tiles[lx]
		if col2[surf] != Tiles.SAND:
			continue
		var oasis_roll: float = float(_hash3(world_seed, world_x, 9001) & 0xffff) / 65535.0
		if oasis_roll >= OASIS_CHANCE:
			continue
		var ow: int = (_hash3(world_seed, world_x, 9002) & 0xff) % (OASIS_WIDTH_MAX - OASIS_WIDTH_MIN + 1) + OASIS_WIDTH_MIN
		var half: int = ow / 2
		for dx in range(-half, half + 1):
			var tx: int = lx + dx
			if tx < 0 or tx >= chunk_width:
				continue
			if c.tiles[tx][surf] != Tiles.SAND:
				continue
			# 碗状: 中心 (dx=0) 最深 OASIS_DEPTH, 边缘渐浅到 1 格
			var dx_abs: int = absi(dx)
			var ratio: float = 1.0 - float(dx_abs) / float(half + 1)
			var col_depth: int = int(float(OASIS_DEPTH) * (0.3 + 0.7 * ratio))
			# 锯齿: ±1 随机扰动让边缘不齐
			col_depth += (_hash3(world_seed, world_x + dx, 9003) & 3) - 1   # -1 .. +2
			if col_depth < 1:
				continue   # 这列没水 (边缘外侧)
			for dy in range(col_depth):
				var ty: int = surf + dy
				if ty < height - BEDROCK_ROWS:
					c.tiles[tx][ty] = Tiles.WATER

	# === 3) 矿洞洼地 BFS flood fill ===
	# 用一个 visited 数组避免重复处理同一片 AIR 区域.
	var visited: Array = []
	visited.resize(chunk_width)
	for i in range(chunk_width):
		var row: PackedByteArray = PackedByteArray()
		row.resize(height)
		visited[i] = row
	for lx in range(chunk_width):
		var world_x2: int = chunk_start_x + lx
		var surf2: int = chunk_heights[world_x2]
		var col3: Array = c.tiles[lx]
		# 从下往上扫 (skip 海洋层, 已填)
		for y in range(min(OCEAN_DEPTH - 1, height - BEDROCK_ROWS - 1), surf2 + WATER_MIN_DEPTH, -1):
			if visited[lx][y] == 1:
				continue
			if col3[y] != Tiles.AIR:
				continue
			# 这是一个未访问的 AIR. 从这里 BFS 找整个连通区域.
			var basin_cells: Array = _bfs_basin(c, lx, y, visited, chunk_width, height)
			if basin_cells.size() < 2 or basin_cells.size() > WATER_BASIN_MAX_SIZE:
				continue  # 太小 (单格) 或太大 (整个大房间)
			# 概率: 用 basin 最底点的 hash 决定 (位置确定 → deterministic)
			var bottom_y: int = 0
			for cell in basin_cells:
				if cell.y > bottom_y:
					bottom_y = cell.y
			var roll_v: float = float(_hash3(world_seed, lx + chunk_start_x, bottom_y) & 0xffff) / 65535.0
			if roll_v >= WATER_POOL_CHANCE:
				continue
			# 填: 底部 WATER_FILL_LEVEL 格 (y >= bottom_y - FILL_LEVEL + 1)
			var fill_min_y: int = bottom_y - WATER_FILL_LEVEL + 1
			for cell in basin_cells:
				if cell.y >= fill_min_y:
					c.tiles[cell.x][cell.y] = Tiles.WATER


# BFS 找一个连通 AIR 区域 (不出 chunk_width, 不穿越 solid).
# 用 4-邻居 (上下左右). 标记 visited 防止重复.
static func _bfs_basin(c: Chunk, start_lx: int, start_y: int, visited: Array,
		chunk_width: int, height: int) -> Array:
	var result: Array = []
	var queue: Array = [Vector2i(start_lx, start_y)]
	visited[start_lx][start_y] = 1
	while not queue.is_empty():
		if result.size() > WATER_BASIN_MAX_SIZE:
			return result  # 早退: 超大房间放弃
		var p: Vector2i = queue.pop_back()
		result.append(p)
		# 4 邻居
		for d in [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var nx: int = p.x + d.x
			var ny: int = p.y + d.y
			if nx < 0 or nx >= chunk_width:
				continue
			if ny < 0 or ny >= height:
				continue
			if visited[nx][ny] == 1:
				continue
			if c.tiles[nx][ny] != Tiles.AIR:
				continue
			visited[nx][ny] = 1
			queue.append(Vector2i(nx, ny))
	return result


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
			var branch_start: Vector2 = pos + Vector2(cos(branch_ang), sin(branch_ang) * WORM_Y_SQUASH)
			var sub_rng := RandomNumberGenerator.new()
			sub_rng.seed = rng.randi() ^ step
			var sub_scale: float = radius_scale * WORM_BRANCH_RADIUS_SCALE
			_carve_circle(c, branch_start, radius * WORM_BRANCH_RADIUS_SCALE,
					chunk_start, chunk_end, height)
			_simulate_worm(c, branch_start, branch_len, sub_rng,
					dir_noise, rad_noise, surf_noise, mountain_noise,
					chunk_start, chunk_end, height, depth + 1, sub_scale, surface_buffer)
		# 前进 1 tile (Y 压扁 → 矿洞更横向, 像泰拉瑞亚的洞穴蜿蜒)
		pos += Vector2(cos(ang), sin(ang) * WORM_Y_SQUASH)
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


# ===== 露天矿洞 (Terraria 山坡侧面洞穴) =====
# 洞口朝山坡的高侧开 (横向), 不是从顶部直插下去. 玩家沿地表走能看到山腰里的洞口.
# 流程: 1) spawn_x 找斜坡方向 (左/右哪边 surf 高) 2) 朝高侧挖横向隧道 (在低 surf 高度水平)
#       3) 隧道尽头小室 4) 派 2-3 worm 继续往里 + 往下分叉.
# 平地无斜坡 → 跳过. 山区也跳过 (mountain_factor > THRESHOLD).
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

	for spawn_x in range(chunk_start_x - OPEN_WORM_PAD_CELLS, chunk_end_x + OPEN_WORM_PAD_CELLS):
		var rng := RandomNumberGenerator.new()
		rng.seed = _hash3(world_seed, spawn_x, 7777)
		if rng.randf() > 1.0 / float(OPEN_PIT_SPACING):
			continue
		# 山区跳过
		var mtn: float = maxf(0.0, mountain_noise.get_noise_1d(float(spawn_x)))
		if mtn > MOUNTAIN_PIT_THRESHOLD:
			continue
		# Spawn 附近也跳过 (玩家开局不能踩进露天洞). 距 0 < 60 列.
		if absi(spawn_x) < 60:
			continue

		# === 找斜坡方向: 左/右哪边 surf 更高 (= 山坡上去的方向, 朝那里挖洞口) ===
		var entrance_surf: int = chunk_heights.get(spawn_x, -1)
		if entrance_surf < 0:
			entrance_surf = _surf_at(surf_noise, mountain_noise, spawn_x, height)
		var slope_dir: int = 0
		var slope_diff: int = 0
		for check_dx in [-OPEN_SLOPE_CHECK_DX, -OPEN_SLOPE_CHECK_DX / 2,
				OPEN_SLOPE_CHECK_DX / 2, OPEN_SLOPE_CHECK_DX]:
			var other_surf: int = _surf_at(surf_noise, mountain_noise,
					spawn_x + check_dx, height)
			var diff: int = entrance_surf - other_surf  # 正 = 那边更高 (y 更小)
			if diff > slope_diff:
				slope_diff = diff
				slope_dir = 1 if check_dx > 0 else -1
		# 没足够斜坡 → 跳过 (= 平地不刷洞)
		if slope_diff < OPEN_SLOPE_MIN_DIFF or slope_dir == 0:
			continue

		# === 1. 朝山坡方向挖横向隧道 (在低 surf 水平高度) ===
		var tunnel_len: int = rng.randi_range(OPEN_TUNNEL_LEN_MIN, OPEN_TUNNEL_LEN_MAX)
		for i in range(tunnel_len):
			var wx: int = spawn_x + i * slope_dir
			var lx: int = wx - chunk_start_x
			if lx < 0 or lx >= chunk_width:
				continue
			for dy in range(OPEN_TUNNEL_HEIGHT):
				var y: int = entrance_surf + dy
				if y < 0 or y >= height - BEDROCK_ROWS:
					continue
				var t: int = c.tiles[lx][y]
				if t == Tiles.BEDROCK or t == Tiles.COAL_ORE or t == Tiles.IRON_ORE:
					continue
				c.tiles[lx][y] = Tiles.AIR

		# === 2. 隧道尽头小室 (3 半径圆, 钻进山里的小厅) ===
		var chamber_x: int = spawn_x + tunnel_len * slope_dir
		var chamber_y: float = float(entrance_surf + 1)  # 隧道中间高度
		_carve_circle(c, Vector2(float(chamber_x), chamber_y), OPEN_CHAMBER_RADIUS,
				chunk_start_x, chunk_end_x, height)

		# === 3. 派 2-3 worm 继续往山坡里 + 往下 (角度 fan 在 in-and-down 象限) ===
		var worm_count: int = rng.randi_range(OPEN_WORM_COUNT_MIN, OPEN_WORM_COUNT_MAX)
		# 朝山的方向 = 角度 0 (右) 或 PI (左). 加 0..PI/2 = right-down 或 left-down 象限
		var bias_min: float = 0.0 if slope_dir == 1 else (PI / 2.0)
		var bias_max: float = (PI / 2.0) if slope_dir == 1 else PI
		for wi in range(worm_count):
			var worm_rng := RandomNumberGenerator.new()
			worm_rng.seed = _hash3(world_seed, spawn_x, 5000 + wi)
			var worm_len: int = worm_rng.randi_range(OPEN_WORM_LEN_MIN, OPEN_WORM_LEN_MAX)
			var bias: float = worm_rng.randf_range(bias_min, bias_max)
			_simulate_worm(c, Vector2(float(chamber_x), chamber_y), worm_len, worm_rng,
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


# 返回该列的 biome (5 种之一: BIOME_SNOW/JUNGLE/FOREST/SWAMP/DESERT).
# 4 个特殊 biome 每个全世界只有 1 块, 其余地方都是 FOREST.
static func _biome_at(world_x: int, world_seed: int) -> int:
	return _biome_at_x(world_x, _build_biome_centers(world_seed))


# 内联版: chunk_gen 提前算好 centers 不再每列重建
static func _biome_at_x(world_x: int, biome_centers: Dictionary) -> int:
	for biome_id in biome_centers.keys():
		var cx: int = biome_centers[biome_id]
		if absi(world_x - cx) <= _BIOME_SLOT_HALF_WIDTH:
			return biome_id
	return BIOME_FOREST


# 用 seed shuffle 4 个槽位给 4 个 biome, 每个加 jitter
static func _build_biome_centers(world_seed: int) -> Dictionary:
	# Fisher-Yates shuffle slots
	var slots: Array = _BIOME_SLOTS.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 1000003 + 7
	for i in range(slots.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	# 分给 4 个 biome (顺序固定, 槽位 shuffle 决定每个 biome 落哪)
	var biomes: Array = [BIOME_SNOW, BIOME_DESERT, BIOME_JUNGLE, BIOME_SWAMP]
	var centers: Dictionary = {}
	for k in biomes.size():
		var jitter: int = rng.randi_range(-_BIOME_CENTER_JITTER, _BIOME_CENTER_JITTER)
		centers[biomes[k]] = slots[k] + jitter
	return centers


# Biome → 地表 tile (y == surf 那行).
static func _biome_surface_tile(biome_id: int, is_sand_col: bool) -> int:
	if is_sand_col:
		return Tiles.SAND  # 沙漠列 or forest 零星沙窝
	match biome_id:
		BIOME_SNOW: return Tiles.SNOW
		BIOME_JUNGLE: return Tiles.JUNGLE_GRASS
		BIOME_SWAMP: return Tiles.SWAMP_GRASS
		_: return Tiles.GRASS  # FOREST 默认


# Biome → 浅地下 tile (y < surf + DIRT_DEPTH).
static func _biome_subsurface_tile(biome_id: int, is_sand_col: bool) -> int:
	if is_sand_col:
		return Tiles.SAND
	match biome_id:
		BIOME_SWAMP: return Tiles.MUD  # 沼泽底下是泥
		_: return Tiles.DIRT


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
		var top_tile: int = c.tiles[lx][surf]
		if world_x - last_tree_x < TREE_MIN_SPACING:
			continue
		# 沙漠列 (SAND 地表) → 长仙人掌, 跳过普通树
		if top_tile == Tiles.SAND:
			if rng.randf() > CACTUS_CHANCE:
				continue
			var cactus_height: int = rng.randi_range(CACTUS_HEIGHT_MIN, CACTUS_HEIGHT_MAX)
			# dy=0 是最底 (贴沙地), dy=cactus_height-1 是最顶. 顶端用 CACTUS (圆头),
			# 其它用 CACTUS_BODY (无缝身体), 让堆叠看着是连续 saguaro 而不是分段方块.
			for dy in range(cactus_height):
				var ty: int = surf - 1 - dy
				if ty < 0:
					break
				if c.tiles[lx][ty] != Tiles.AIR:
					break
				var is_top: bool = (dy == cactus_height - 1)
				c.tiles[lx][ty] = Tiles.CACTUS if is_top else Tiles.CACTUS_BODY
			last_tree_x = world_x
			continue
		# 允许在 GRASS / JUNGLE_GRASS / SWAMP_GRASS / SNOW 长树 (各自树叶不同)
		var leaves_for_biome: int = -1  # -1 = 跳过这列 (不长树)
		match top_tile:
			Tiles.GRASS:
				leaves_for_biome = Tiles.LEAVES
			Tiles.JUNGLE_GRASS:
				leaves_for_biome = Tiles.LEAVES  # TODO: 后续可换 JUNGLE_LEAVES
			Tiles.SWAMP_GRASS:
				leaves_for_biome = Tiles.LEAVES_AUTUMN  # 沼泽用秋叶感觉死气
			Tiles.SNOW:
				leaves_for_biome = Tiles.LEAVES_PINE  # 雪原长松针
			_:
				continue
		if rng.randf() > TREE_CHANCE:
			continue
		# 只剩 OAK
		var params: Dictionary = _SPECIES_PARAMS[_SPECIES_OAK]
		var trunk_range: Array = params["trunk_range"]
		var leaves_tile: int = leaves_for_biome  # 用 biome-specific 叶子覆盖 params 里的
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
		# 树干: trunk_top 用 LOG_TOP (顶帽), 中间到底用 LOG
		c.tiles[lx][trunk_top] = Tiles.LOG_TOP
		for ty in range(trunk_top + 1, surf):
			c.tiles[lx][ty] = Tiles.LOG
		# 树根: 左右侧紧贴树干底, 替换 AIR. 不出 chunk
		var root_y: int = surf - 1
		if root_y >= 0:
			if lx - 1 >= 0 and c.tiles[lx - 1][root_y] == Tiles.AIR:
				c.tiles[lx - 1][root_y] = Tiles.LOG_ROOT_L
			if lx + 1 < c.tiles.size() and c.tiles[lx + 1][root_y] == Tiles.AIR:
				c.tiles[lx + 1][root_y] = Tiles.LOG_ROOT_R
		# 侧枝: 在树干中段随机放 1-3 个 (避开树底 1 格 + 树顶)
		_place_branches(c, lx, trunk_top, surf, rng)
		# 树冠: 越出 chunk 的部分裁掉
		_place_canopy_chunk(c, world_x, trunk_top, canopy_kind, leaves_tile, chunk_start, chunk_end, height)
		last_tree_x = world_x


# 在树干中段 (trunk_top+1 .. surf-2) 随机放 1-3 个侧枝.
# 不和 ROOT_L/R 在同一 Y 冲突 (root 在 surf-1, 我们从 surf-2 开始往上).
static func _place_branches(c: Chunk, lx: int, trunk_top: int, surf: int, rng: RandomNumberGenerator) -> void:
	var min_y: int = trunk_top + 1       # 树顶下面一格起
	var max_y: int = surf - 2             # 树底上面一格止 (留 root 空间)
	if max_y < min_y:
		return
	var candidates: Array = []
	for ty in range(min_y, max_y + 1):
		candidates.append(ty)
	# Fisher-Yates with 传入的 rng — Array.shuffle() 用全局 RNG, 不 deterministic
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	var n_branches: int = rng.randi_range(1, mini(3, candidates.size()))
	var placed_ys: Array = []
	for i in n_branches:
		var ty: int = candidates[i]
		# 同 y 不放两根; 相邻 y 也避免 (太密)
		var too_close: bool = false
		for py in placed_ys:
			if abs(py - ty) < 2:
				too_close = true
				break
		if too_close:
			continue
		# 决定左/右. 50/50, 越界自动跳
		var left: bool = rng.randi() % 2 == 0
		if left:
			if lx - 1 >= 0 and c.tiles[lx - 1][ty] == Tiles.AIR:
				c.tiles[lx - 1][ty] = Tiles.BRANCH_L
				placed_ys.append(ty)
		else:
			if lx + 1 < c.tiles.size() and c.tiles[lx + 1][ty] == Tiles.AIR:
				c.tiles[lx + 1][ty] = Tiles.BRANCH_R
				placed_ys.append(ty)


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
	# 云朵分层蘑菇头 (Terraria 风): 多个 puff 上下错位叠加. 横向 ±2 内, 纵向 -REACH 到 +1
	var offs: Array = []
	match kind:
		"oak_cloud_small":
			# 2 层小蘑菇 (≈11 tile): 上层 3 宽 puff, 下层 5 宽
			# 上 puff (y=-2): 3 宽
			for dx in range(-1, 2): offs.append(Vector2i(dx, -2))
			# 中肩 (y=-1): 5 宽
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))
			# 底层 (y=0): 5 宽中间留出树干位
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))
		"oak_cloud_med":
			# 3 层中蘑菇头 (≈19 tile): puff 顶 + 肩 + 主云朵 + 底沿
			offs.append(Vector2i(0, -3))                       # 顶 puff 中
			for dx in range(-1, 2): offs.append(Vector2i(dx, -2))   # 上 puff 3
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))   # 中云朵 5
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))                       # 底沿 4 (留树干位)
			offs.append(Vector2i(-1, 1)); offs.append(Vector2i(1, 1))   # 底翼 2
		"oak_cloud_large":
			# 4 层大云朵 (≈27 tile): 顶尖 + 上肩 + 中宽 + 主云 + 底沿
			for dx in range(-1, 2): offs.append(Vector2i(dx, -4))     # 顶 puff 3
			for dx in range(-2, 3): offs.append(Vector2i(dx, -3))     # 上肩 5
			for dx in range(-2, 3): offs.append(Vector2i(dx, -2))     # 中宽 5
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))     # 主云 5
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))                            # 底沿 4
			offs.append(Vector2i(-1, 1)); offs.append(Vector2i(1, 1))   # 底翼 2
		"oak_cloud_huge":
			# 5 层超大云朵 (≈38 tile): 三个 puff 在顶 + 主厚云 + 底沿
			offs.append(Vector2i(0, -5))                                # 单顶尖
			for dx in range(-1, 2): offs.append(Vector2i(dx, -4))       # 顶 puff 3
			for dx in range(-2, 3): offs.append(Vector2i(dx, -3))       # 上肩 5
			for dx in range(-2, 3): offs.append(Vector2i(dx, -2))       # 中宽 5
			for dx in range(-2, 3): offs.append(Vector2i(dx, -1))       # 主云 5
			for dx in range(-2, 3):
				if dx == 0: continue
				offs.append(Vector2i(dx, 0))                              # 底沿 4
			offs.append(Vector2i(-2, 1)); offs.append(Vector2i(-1, 1))   # 底左翼
			offs.append(Vector2i(1, 1)); offs.append(Vector2i(2, 1))     # 底右翼
	return offs
