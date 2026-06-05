# 程序化世界生成。给定种子产生确定性的 2D tile 数组。
# 返回 dict: {"tiles": Array[Array[int]], "spawn_point": Vector2i,
#            "seed": int, "width": int, "height": int}
# tiles[x][y] = TileData 常量
extends RefCounted

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

const SURFACE_BASE := 0.45       # 地表平均高度 (相对世界 0..1)
const SURFACE_AMP := 0.11        # 地表起伏振幅 (大丘大谷但顺滑; 山高主要靠 MOUNTAIN_BOOST 撑)
const DIRT_DEPTH := 6            # 地表下泥土层厚度
# 山区 noise: 低频 → 宽山区, max(0, n) 作为山高度系数 (实测 Perlin max ~0.31)
# MOUNTAIN_BOOST 对世界高度的比例: 0.80 × 0.31 × 256 = 最高峰比平均地表再高 ~63 格 (大山)
const MOUNTAIN_NOISE_FREQ := 0.008
const MOUNTAIN_BOOST := 0.80     # 0.40→0.80: 山明显更高更壮观 (用户嫌山矮)
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
const _BIOME_SLOT_HALF_WIDTH := 100  # 每个 biome 半宽 (= 200 列宽). 用户要求平原 GRASS 多, 其他 biome 缩小.
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
const HELL_THRESHOLD := 0.40     # 地狱晶体: 阈值放低一点 (0.55 → 0.40), 让地狱里有得挖
# 矿层深度边界 (y - surf), 单位 tile
const ORE_DEPTH_SHALLOW_MAX := 50   # 铜锡浅层上限
const ORE_DEPTH_MID_MIN := 40       # 金矿起始深度
const ORE_DEPTH_DEEP_MIN := 80      # 钻石起始深度
const ORE_DEPTH_HELL_MIN := 100     # 地狱晶体起始深度 (256 高世界, 地狱 y>220, surf~115 → depth 105)

# Perlin Worms 洞穴系统 (细隧道网 + 分叉 + 死路, 按深度分层: 表少 / 深密)
const WORM_SPAWN_GRID := 14      # 每 14×14 tile 一个候选 worm 起点 (密)
const WORM_LEN_MIN := 25         # worm 短一点 → 形成自然死路
const WORM_LEN_MAX := 70
const WORM_RADIUS_MIN := 1.2     # 加宽: ≈2.5 tile 宽, 玩家舒服走 (老值 0.8 太挤)
const WORM_RADIUS_MAX := 2.0     # 老值 1.3
const WORM_BRANCH_CHANCE := 0.025  # 每步 2.5% 派子 worm → 分叉
# 小室: 主 worm 沿途偶发开个圆室 (节奏点 + 给后续放宝箱/水晶留地方)
const CHAMBER_STEP_INTERVAL := 15   # 每 15 步检查 (老 25 太稀)
const CHAMBER_CHANCE := 0.65        # 65% 实际开
const CHAMBER_RADIUS_MIN := 3.0     # 6 tile 宽
const CHAMBER_RADIUS_MAX := 5.0     # 10 tile 宽
const CHAMBER_CHEST_CHANCE := 0.55  # 55% 小室放宝箱 (老 30%)
const CHAMBER_MUSHROOM_CHANCE := 0.20  # 20% 蘑菇地 (与宝箱互斥), 老 25%
const CHAMBER_LIFE_CRYSTAL_CHANCE := 0.12  # 12% 小室放生命水晶 (跟前两个互斥)
const CHAMBER_MANA_CRYSTAL_CHANCE := 0.10  # 10% 小室放魔力水晶 (Phase 7 完善)
const CHEST_MIN_DEPTH := 15         # 浅一点也能出 (用户要更多木宝箱), 原 30
const MUSHROOM_MIN_DEPTH := 20      # 蘑菇地浅一点也行
const LIFE_CRYSTAL_MIN_DEPTH := 25  # 生命水晶 25 格深起 (新手探索一下能找到)
const MANA_CRYSTAL_MIN_DEPTH := 35  # 魔力水晶: 比生命水晶深一点 (更稀有, 玩到中期遇到)
const WORM_BRANCH_MAX_DEPTH := 2   # 分叉递归最大深度
const WORM_BRANCH_RADIUS_SCALE := 0.6  # 子 worm 半径系数 (孙再叠加 → 越细)
const WORM_DIR_FREQUENCY := 0.025  # 方向噪声频率
const WORM_Y_SQUASH := 0.5         # Y 方向步进系数 (X=1.0 不变, Y=0.5 → 矿洞偏横向, 像泰拉瑞亚)
const WORM_SEARCH_PAD_CELLS := 7   # 邻 chunk 搜索半径
# 深度分层生成概率: depth = sy - surf
const WORM_CHANCE_SHALLOW := 0.10  # 浅层 worm: 老 2% 太少, 10% 让浅木宝箱有出处
const WORM_CHANCE_MID := 0.25      # 中层零散通道, 玩家挖才会遇到
const WORM_CHANCE_DEEP := 0.92     # 深层密如蛛网 (玩家"主动下矿"区)
const WORM_DEPTH_SHALLOW_MAX := 40  # 地表 40 格内安全, 不会"踩进去"
const WORM_DEPTH_MID_MAX := 110     # surf+110 起密集
const WORM_SURFACE_BUFFER := 20     # worm 路径距地表至少 20 格 (走近就 break, 防止深层 worm 窜到地表)

# 大洞厅 (Terraria cavern): 深层用一张低频噪声, 超过阈值的连片格挖成 AIR → 大开阔洞.
const CAVERN_NOISE_FREQ := 0.05    # 越小洞越大块 (波长 ~20 → 12-25 格宽洞)
const CAVERN_THRESHOLD := 0.33     # noise > 此 → 挖空 (越低洞越多; 实测 Perlin 多在 ±0.5)
const CAVERN_MIN_DEPTH := 45       # 地表下 ≥45 才挖大洞 (浅层留给 worm, 不戳穿地表)

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
const WATER_POOL_CHANCE := 0.6        # 洼地填水概率 (45%→60% 更密)
const WATER_FILL_LEVEL := 8           # 水池高 (从洼地底起填; 6→8 加大)
const WATER_BASIN_MAX_SIZE := 120     # BFS 单池最多格数 (60→120 允许更大池)
const OCEAN_DEPTH := 200              # y > 200 (接近基岩) AIR 强制水 = 地下海洋
const OASIS_CHANCE := 0.035           # 沙漠列长绿洲概率 (2%→3.5% 更密)
const OASIS_WIDTH_MIN := 8            # 绿洲宽 (加大 4→8)
const OASIS_WIDTH_MAX := 16           # 绿洲宽 (加大 8→16)
const OASIS_DEPTH := 5                # 绿洲深 (3→5)
# 地表水塘 (forest/jungle/swamp 挖碗填群系色水; 雪原不放, 沙漠走绿洲)
const POND_CHANCE := 0.02             # 草地列当塘中心的概率 (1%→2%, 出生点看得到但不淹成水世界)
const POND_WIDTH_MIN := 12            # 塘宽 (加大)
const POND_WIDTH_MAX := 24
const POND_DEPTH := 6                 # 塘最深 (中心)
const POND_MAX_SLOPE := 6             # 塘宽内地表高差 ≤ 此值才开 (2→6 放宽, 否则起伏地形全毙)
const WATERFALL_CHANCE := 0.08        # 崖唇列放瀑布水源的概率 (0.22→0.08: 用户嫌密, 调成偶尔遇到的景观)
const WATERFALL_MIN_DROP := 8         # 崖唇到崖底落差 ≥ 这么多 tile 才放
const WATERFALL_SPAN := 4             # 在 ±这么多列内看落差 (= 崖陡不陡)


# 某列是不是"崖唇": 往右 (或左) span 列内地表掉 ≥ min_drop. 返回掉落方向 (+1右 / -1左 / 0 不是).
# heights = world_x → surf_y 的 Dictionary (y 越大越低); 邻列缺失 (chunk 边界) → 安全跳过.
static func _is_cliff(heights: Dictionary, x: int, span: int, min_drop: int) -> int:
	if not heights.has(x):
		return 0
	var here: int = heights[x]
	if heights.has(x + span) and heights[x + span] - here >= min_drop:
		return 1
	if heights.has(x - span) and heights[x - span] - here >= min_drop:
		return -1
	return 0

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
		"trunk_range": [8, 16],  # TILE_SIZE 16→12 后, 树要更多 tile 才像原来高度
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
	noise.fractal_octaves = 2   # 2 层 → 地表顺滑 (3 层细节多=尖刺). 注意: worm/露天矿洞/瀑布
	                            # 里复制的 surf_noise 也必须 octaves=2 (同一地表公式), 否则洞口对不齐=歪七扭八.

	var sand_noise := FastNoiseLite.new()
	sand_noise.seed = world_seed + 1
	sand_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	sand_noise.frequency = 0.05

	var coal_noise := FastNoiseLite.new()
	coal_noise.seed = world_seed + 3
	coal_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	coal_noise.frequency = 0.095   # 矿脉(常见矿不连巨块)

	var iron_noise := FastNoiseLite.new()
	iron_noise.seed = world_seed + 4
	iron_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	iron_noise.frequency = 0.085   # 矿脉

	# 银矿 noise (跟 gold 一档深, 但用独立 seed → 不跟 gold 重叠)
	var silver_noise := FastNoiseLite.new()
	silver_noise.seed = world_seed + 15
	silver_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	silver_noise.frequency = 0.05  # 降频成矿脉

	# 新矿噪声 (T26): 每种独立 seed, 不同 frequency 让斑块大小有差异
	var copper_noise := FastNoiseLite.new()
	copper_noise.seed = world_seed + 10
	copper_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	copper_noise.frequency = 0.075  # 矿脉

	var tin_noise := FastNoiseLite.new()
	tin_noise.seed = world_seed + 11
	tin_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	tin_noise.frequency = 0.075   # 矿脉

	var gold_noise := FastNoiseLite.new()
	gold_noise.seed = world_seed + 12
	gold_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	gold_noise.frequency = 0.05   # 降频成矿脉

	var diamond_noise := FastNoiseLite.new()
	diamond_noise.seed = world_seed + 13
	diamond_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	diamond_noise.frequency = 0.05  # 降频成矿脉

	var hell_noise := FastNoiseLite.new()
	hell_noise.seed = world_seed + 14
	hell_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	hell_noise.frequency = 0.05   # 降频成矿脉
	# 地狱合金矿 noise: 独立种子, 跟 hell_crystal 不重叠
	var hell_alloy_noise := FastNoiseLite.new()
	hell_alloy_noise.seed = world_seed + 19
	hell_alloy_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	hell_alloy_noise.frequency = 0.05  # 降频成矿脉

	# 山区 noise: 低频, 决定哪些列是高山 (factor>0) 哪些是平地 (factor=0)
	var mountain_noise := FastNoiseLite.new()
	mountain_noise.seed = world_seed + 5
	mountain_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	mountain_noise.frequency = MOUNTAIN_NOISE_FREQ

	# Biome centers: 4 个 biome 用 seed shuffle 分到 _BIOME_SLOTS, 每个 +- jitter
	var biome_centers: Dictionary = _build_biome_centers(world_seed)
	# 地狱矩形 x 范围 (hoist 出 loop, 每 cell 都查)
	var hell_zone_x: Vector2i = _hell_zone_x(world_seed)
	# tier 保底: 给本 chunk 按 seed 计算 "本 chunk 第一个 chest 强制升 tier".
	# 4% shadow / 8% diamond / 15% gold / 73% 不强制 (走深度规则).
	# 让玩家无论运气好坏, 每世界基本都有金/钻/阴影箱可挖.
	c.guaranteed_tier = _guaranteed_tier_for_chunk(world_seed, chunk_x)

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
				var sn: float = silver_noise.get_noise_2d(float(world_x), float(y))
				# 地狱晶体: 严格只在地狱矩形 (y > HELL_DEPTH + x 在 zone). 不放浅 deep_stone.
				var an: float = hell_alloy_noise.get_noise_2d(float(world_x), float(y))
				if y > HELL_DEPTH and hn > HELL_THRESHOLD \
						and world_x >= hell_zone_x.x and world_x <= hell_zone_x.y:
					tid = Tiles.HELL_CRYSTAL
				elif y > HELL_DEPTH and an > 0.40 \
						and world_x >= hell_zone_x.x and world_x <= hell_zone_x.y:
					tid = Tiles.HELL_ALLOY_ORE
				elif depth >= ORE_DEPTH_DEEP_MIN and dn > DIAMOND_THRESHOLD:
					tid = Tiles.DIAMOND_ORE
				elif depth >= ORE_DEPTH_MID_MIN and gn > GOLD_THRESHOLD:
					tid = Tiles.GOLD_ORE
				elif depth >= ORE_DEPTH_MID_MIN and sn > 0.38:   # 银: 跟金同深, 稍稀
					tid = Tiles.SILVER_ORE
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

	# 大洞厅: 深层用低频噪声挖大块开阔洞 (泰拉瑞亚 cavern 味, 跟 worm 连通). 不碰地狱.
	_carve_caverns_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 露天矿洞: 漏斗坑 (pit) 或 窄缝 (crack) 直通地表, 玩家能跳下去
	_carve_open_pits_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 地狱: y > HELL_DEPTH 区域换成 HELL_STONE + 散布 LAVA 池 + 周围 OBSIDIAN 环 + 火果挂顶
	_apply_hell_biome_chunk(c, world_seed, chunk_x, chunk_width, height)

	# 火山口: 偶发 (1/4 chunk 一个) 在地狱区凿垂直竖井, 黑曜石包边 + 底部岩浆池 + 顶岩浆源
	# (chunk 加载时顶部 LAVA 会被 water_sim 流下来, 形成"瀑布"动画 → 流完后底池子保留)
	_place_volcano_crater_chunk(c, world_seed, chunk_x, chunk_width, height)

	# 沙漠金字塔: 2-3 个/世界, 沙漠 chunk 上盖 25 宽 13 层台阶金字塔 + 内部走廊 + 2-3 宝箱
	_place_pyramid_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height, biome_centers)

	# 沙漠地下保护: 把 SAND 邻 AIR 的 tile 改 STONE (防沙崩塌填满矿洞)
	_protect_sand_caves(c, chunk_heights, chunk_width, height)

	# 水: 矿洞洼地 + 沙漠绿洲 + 地下海洋. 先于树, 这样:
	# - 树 _place_trees_chunk 检测 surf 是 WATER 时自动跳过 (既不是 GRASS 也不是 SAND)
	# - 仙人掌不会长在绿洲水里
	_fill_water_pools_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 树: 树根只在本 chunk [chunk_start, chunk_end) 内决定 — canopy 越界部分裁掉.
	# 在 water 之后: 绿洲水替换了 SAND 地表, 树/仙人掌不会长在水上.
	_place_trees_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 世纪树已删 (用户要求)

	# 废弃矿井: 2-3 个/中世界, 地下深层 30 格水平木走廊 + 木支柱 + 1-2 宝箱 + 蜘蛛.
	_place_mineshaft_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 装饰小草: GRASS 上方 AIR + 15% 概率长 PLANT_GRASS (用户要求草地点缀)
	_place_grass_decor_chunk(c, chunk_heights, world_seed, chunk_x, chunk_width, height)

	# 空岛: 天空层浮岛 (云底+草顶+小水池+树+钻石宝箱), 数量按世界大小. 在 walls 前 (天空层不填墙).
	_place_sky_island_chunk(c, world_seed, chunk_x, chunk_width, height)

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
	# 用户要求: 地底所有方块后面都有墙 (不论 AIR 还是 SOLID)
	# 唯一例外: 浅层 (surf + WALL_HIDE_TOP_TILES 之上) 仍无墙 — 这样地表才能透天空
	for local_x in chunk_width:
		var world_x: int = chunk_start_x + local_x
		var surf: int = chunk_heights[world_x]
		var wall_start: int = surf + WALL_HIDE_TOP_TILES
		for y in height:
			if y < wall_start:
				continue
			c.walls[local_x][y] = _wall_for_depth(y, surf)


static func _wall_for_depth(y: int, surf: int) -> int:
	if y < surf + DIRT_DEPTH:
		return Tiles.DIRT_WALL
	return Tiles.STONE_WALL


# ===== 水池 + 沙漠绿洲 + 地下海洋 =====
# 矿洞洼地 BFS flood fill: 找连通 AIR 区域底部填 WATER_FILL_LEVEL 格水, 像真湖.
# 沙漠绿洲: 沙地表稀疏长大水池.
# (旧"地下海洋 y>OCEAN_DEPTH 全填水"已删 — 它会淹掉地狱 + 挖到底一片水, 用户要去掉.)
static func _fill_water_pools_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start_x: int = chunk_x * chunk_width
	var centers: Dictionary = _build_biome_centers(world_seed)  # 按 x 取群系 → 水色

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
					c.tiles[tx][ty] = Tiles.WATER_DESERT   # 绿洲在沙漠 = 青绿松石

	# === 2.5) 地表水塘: forest/jungle/swamp 平地挖碗填群系色水 (雪原跳过; 沙漠走绿洲) ===
	for lx in range(chunk_width):
		var wx: int = chunk_start_x + lx
		var biome: int = _biome_at_x(wx, centers)
		if biome != BIOME_FOREST and biome != BIOME_JUNGLE and biome != BIOME_SWAMP:
			continue
		var psurf: int = chunk_heights[wx]
		# 中心列必须是该群系的草地表 (避开已是水/沙/结构)
		if c.tiles[lx][psurf] != _biome_surface_tile(biome, false):
			continue
		var pond_roll: float = float(_hash3(world_seed, wx, 7777) & 0xffff) / 65535.0
		if pond_roll >= POND_CHANCE:
			continue
		var pw: int = (_hash3(world_seed, wx, 7778) & 0xff) % (POND_WIDTH_MAX - POND_WIDTH_MIN + 1) + POND_WIDTH_MIN
		var phalf: int = pw / 2
		# 平地检查: 塘宽内地表高差 ≤ POND_MAX_SLOPE 才开 (太斜水会顺坡流走)
		var smin: int = 99999
		var smax: int = -99999
		for dxf in range(-phalf, phalf + 1):
			var txf: int = lx + dxf
			if txf < 0 or txf >= chunk_width:
				continue
			var sf: int = chunk_heights[chunk_start_x + txf]
			smin = mini(smin, sf)
			smax = maxi(smax, sf)
		if smax - smin > POND_MAX_SLOPE:
			continue
		var water_tile: int = _biome_water_tile(biome)
		# 贴地填: 从每列自己的地表往下挖碗填水 → 水永远坐在实地上, 不会悬空 (悬空水的根源).
		# 起伏由加载时 settle 自动找平成水塘.
		for dx in range(-phalf, phalf + 1):
			var tx2: int = lx + dx
			if tx2 < 0 or tx2 >= chunk_width:
				continue
			var s2: int = chunk_heights[chunk_start_x + tx2]
			var dxa: int = absi(dx)
			var ratio2: float = 1.0 - float(dxa) / float(phalf + 1)
			var pdepth: int = int(float(POND_DEPTH) * (0.35 + 0.65 * ratio2))
			pdepth += (_hash3(world_seed, chunk_start_x + tx2, 7779) & 3) - 1
			if pdepth < 1:
				continue
			for dy in range(pdepth):
				var ty2: int = s2 + dy
				if ty2 >= 0 and ty2 < height - BEDROCK_ROWS:
					c.tiles[tx2][ty2] = water_tile

	# === 2.6) 瀑布: forest/jungle 陡崖唇稀有放水源, 水顺崖面流下 ===
	for wflx in range(chunk_width):
		var wfx: int = chunk_start_x + wflx
		var wfbiome: int = _biome_at_x(wfx, centers)
		if wfbiome != BIOME_FOREST and wfbiome != BIOME_JUNGLE:
			continue
		var wf_dir: int = _is_cliff(chunk_heights, wfx, WATERFALL_SPAN, WATERFALL_MIN_DROP)
		if wf_dir == 0:
			continue
		var wf_roll: float = float(_hash3(world_seed, wfx, 7790) & 0xffff) / 65535.0
		if wf_roll >= WATERFALL_CHANCE:
			continue
		var lip_surf: int = chunk_heights[wfx]
		# 从崖唇朝低边扫, 找第一列"崖面" (崖唇高度处已是 AIR = 该列地表更低)
		var edge_lx: int = -1
		for step in range(1, WATERFALL_SPAN + 1):
			var clx: int = wflx + wf_dir * step
			if clx < 0 or clx >= chunk_width:
				break
			if lip_surf >= 0 and lip_surf < c.tiles[clx].size() and c.tiles[clx][lip_surf] == Tiles.AIR:
				edge_lx = clx
				break
		if edge_lx < 0:
			continue
		# 水源放崖面上沿: 脚下 (lip_surf) 是崖面 AIR → 水能直落到崖底积潭
		var wf_sy: int = lip_surf - 1
		if wf_sy >= 1 and c.tiles[edge_lx][wf_sy] == Tiles.AIR and c.tiles[edge_lx][lip_surf] == Tiles.AIR:
			c.tiles[edge_lx][wf_sy] = Tiles.WATER_SOURCE

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
		# 从下往上扫 (skip 海洋层 + 地狱层 — 地狱区不放水, 那里是岩浆世界)
		var max_y_water: int = min(OCEAN_DEPTH - 1, height - BEDROCK_ROWS - 1)
		if max_y_water >= HELL_DEPTH:
			max_y_water = HELL_DEPTH - 1
		for y in range(max_y_water, surf2 + WATER_MIN_DEPTH, -1):
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
					# 洞穴水按列上方群系上色
					c.tiles[cell.x][cell.y] = _biome_water_tile(_biome_at_x(chunk_start_x + cell.x, centers))


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
	surf_noise.fractal_octaves = 2

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
		# 小室: 仅主 worm (depth=0) 沿程偶发开圆室, 子 worm 不开 (防嵌套)
		if depth == 0 and step > 0 and step % CHAMBER_STEP_INTERVAL == 0 and rng.randf() < CHAMBER_CHANCE:
			var chamber_r: float = rng.randf_range(CHAMBER_RADIUS_MIN, CHAMBER_RADIUS_MAX)
			_carve_circle(c, pos, chamber_r, chunk_start, chunk_end, height)
			# 小室随机内容 (互斥): roll < 0.30 宝箱, < 0.55 蘑菇地, 其余空房间
			# (surf_at 是上面 worm 终止检查算的, 此处复用)
			var roll: float = rng.randf()
			var depth_here: int = int(pos.y) - surf_at
			if roll < CHAMBER_CHEST_CHANCE and depth_here >= CHEST_MIN_DEPTH:
				# 死人箱概率: 浅 (30-69) 15%, 深 (≥70) 25%. 任何深度都可能中招.
				var mimic_chance: float = 0.25 if depth_here >= 70 else 0.15
				# 按"距地表深度"选 tier (256 高世界, surf~115):
				# depth<40 木, 40-69 金, 70+ 钻石, 地狱区 (y>HELL_DEPTH=220) 阴影
				# (老阈值 pos.y>=115 是按 128 高世界算的, 在 256 世界 = 几乎全 shadow, bug)
				var ct_chamber: int = Tiles.CHEST
				if int(pos.y) > HELL_DEPTH:
					ct_chamber = Tiles.SHADOW_CHEST
				elif depth_here >= 70:
					ct_chamber = Tiles.DIAMOND_CHEST
				elif depth_here >= 40:
					ct_chamber = Tiles.GOLD_CHEST
				_try_place_chest(c, int(round(pos.x)), int(round(pos.y)), int(chamber_r) + 2, chunk_start, chunk_end, height, mimic_chance, rng, ct_chamber)
			elif roll < CHAMBER_CHEST_CHANCE + CHAMBER_MUSHROOM_CHANCE and depth_here >= MUSHROOM_MIN_DEPTH:
				_try_place_mushroom_patch(c, int(round(pos.x)), int(round(pos.y)), int(chamber_r), chunk_start, chunk_end, height, rng)
			elif roll < CHAMBER_CHEST_CHANCE + CHAMBER_MUSHROOM_CHANCE + CHAMBER_LIFE_CRYSTAL_CHANCE and depth_here >= LIFE_CRYSTAL_MIN_DEPTH:
				_try_place_life_crystal(c, int(round(pos.x)), int(round(pos.y)), int(chamber_r) + 2, chunk_start, chunk_end, height)
			elif roll < CHAMBER_CHEST_CHANCE + CHAMBER_MUSHROOM_CHANCE + CHAMBER_LIFE_CRYSTAL_CHANCE + CHAMBER_MANA_CRYSTAL_CHANCE and depth_here >= MANA_CRYSTAL_MIN_DEPTH:
				_try_place_mana_crystal(c, int(round(pos.x)), int(round(pos.y)), int(chamber_r) + 2, chunk_start, chunk_end, height)
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
			if Tiles.is_ore(t):   # 所有矿石别被挖洞吞 (以前只护煤/铁, 铜锡银金钻被吃掉)
				continue
			if t == Tiles.GRASS:
				continue  # 不破坏地表 (避免随机竖井裸露)
			if t == Tiles.CHEST or t == Tiles.GOLD_CHEST or t == Tiles.DIAMOND_CHEST \
					or t == Tiles.SHADOW_CHEST or t == Tiles.MIMIC_CHEST or t == Tiles.MUSHROOM:
				continue  # 矿洞各种宝箱/蘑菇 (前一步刚放) 不要被后续 worm 步覆盖
			c.tiles[lx][wy] = Tiles.AIR


# 小室中心朝下找第一个 STONE/DEEP_STONE 当地板, 在它上面那一格放 CHEST + 记下世界坐标.
# 找不到 (例: 落入老 chamber 间穿连接处, 下面也都是 AIR) → 放弃, 不强求.
# mimic_chance > 0 时按概率改成 MIMIC_CHEST.
# tile_override > 0 时直接用指定 chest tile (用来按 caller 算出的 tier 选金/钻石宝箱).
static func _try_place_chest(c: Chunk, world_x: int, start_y: int, max_scan: int,
		chunk_start: int, chunk_end: int, height: int,
		mimic_chance: float = 0.0, rng: RandomNumberGenerator = null,
		tile_override: int = -1) -> void:
	if world_x < chunk_start or world_x >= chunk_end:
		return
	var lx: int = world_x - chunk_start
	# 从 start_y 往下扫, 找第一个 STONE/DEEP_STONE (跳过 AIR/矿石/其他)
	var floor_y: int = -1
	for dy in range(0, max_scan + 1):
		var wy: int = start_y + dy
		if wy < 0 or wy >= height:
			break
		var t: int = c.tiles[lx][wy]
		if t == Tiles.STONE or t == Tiles.DEEP_STONE:
			floor_y = wy
			break
	if floor_y <= 0:
		return
	var chest_y: int = floor_y - 1
	# chest 头顶那一格必须是 AIR (不然箱子嵌石头里看不到)
	if c.tiles[lx][chest_y] != Tiles.AIR:
		return
	var is_mimic: bool = mimic_chance > 0.0 and rng != null and rng.randf() < mimic_chance
	if is_mimic:
		c.tiles[lx][chest_y] = Tiles.MIMIC_CHEST
		# 死人箱不加 treasure_spots — 没储物, ChestStorage 不被填战利品
		return
	# tile_override > 0 直接用 (caller 已按深度/类别选好 tier);
	# 否则按绝对 y 选 (兼容老 caller)
	var chest_tile: int = tile_override
	if chest_tile <= 0:
		chest_tile = Tiles.CHEST
		if chest_y >= 100:
			chest_tile = Tiles.DIAMOND_CHEST
		elif chest_y >= 75:
			chest_tile = Tiles.GOLD_CHEST
	# 保底: 本 chunk 第一个 chest, 如果 guaranteed_tier > 当前自然 tier, 升级.
	# (shadow 只在地狱 y >= 119 才生效, 不然普通箱区放 shadow 视觉不搭)
	if not c._first_chest_placed and c.guaranteed_tier > 0:
		var natural_tier: int = 0
		match chest_tile:
			Tiles.GOLD_CHEST: natural_tier = 1
			Tiles.DIAMOND_CHEST: natural_tier = 2
			Tiles.SHADOW_CHEST: natural_tier = 3
			_: natural_tier = 0
		if c.guaranteed_tier > natural_tier:
			match c.guaranteed_tier:
				1: chest_tile = Tiles.GOLD_CHEST
				2: chest_tile = Tiles.DIAMOND_CHEST
				3:
					if chest_y >= 119:
						chest_tile = Tiles.SHADOW_CHEST
					else:
						chest_tile = Tiles.DIAMOND_CHEST   # 浅区给不了 shadow, 给 diamond
		c._first_chest_placed = true
	c.tiles[lx][chest_y] = chest_tile
	c.treasure_spots.append(Vector2i(world_x, chest_y))


# 跟 _try_place_chest 同款 (找小室底 STONE 上面 AIR 那格), 但放 LIFE_CRYSTAL.
# 不进 treasure_spots — 水晶不是宝箱, 没储物. 右键吃直接消耗 tile.
static func _try_place_life_crystal(c: Chunk, world_x: int, start_y: int, max_scan: int,
		chunk_start: int, chunk_end: int, height: int) -> void:
	if world_x < chunk_start or world_x >= chunk_end:
		return
	var lx: int = world_x - chunk_start
	var floor_y: int = -1
	for dy in range(0, max_scan + 1):
		var wy: int = start_y + dy
		if wy < 0 or wy >= height:
			break
		var t: int = c.tiles[lx][wy]
		if t == Tiles.STONE or t == Tiles.DEEP_STONE:
			floor_y = wy
			break
	if floor_y <= 0:
		return
	var crystal_y: int = floor_y - 1
	if c.tiles[lx][crystal_y] != Tiles.AIR:
		return
	c.tiles[lx][crystal_y] = Tiles.LIFE_CRYSTAL


# 跟 _try_place_life_crystal 同款: 找小室底 STONE 上 AIR 那格, 放 MANA_CRYSTAL.
static func _try_place_mana_crystal(c: Chunk, world_x: int, start_y: int, max_scan: int,
		chunk_start: int, chunk_end: int, height: int) -> void:
	if world_x < chunk_start or world_x >= chunk_end:
		return
	var lx: int = world_x - chunk_start
	var floor_y: int = -1
	for dy in range(0, max_scan + 1):
		var wy: int = start_y + dy
		if wy < 0 or wy >= height:
			break
		var t: int = c.tiles[lx][wy]
		if t == Tiles.STONE or t == Tiles.DEEP_STONE:
			floor_y = wy
			break
	if floor_y <= 0:
		return
	var crystal_y: int = floor_y - 1
	if c.tiles[lx][crystal_y] != Tiles.AIR:
		return
	c.tiles[lx][crystal_y] = Tiles.MANA_CRYSTAL


# 蘑菇小室: 在小室中心 ±x_radius 列里, 把第一个 STONE/DEEP_STONE floor 改 MUD,
# MUD 上的 AIR 格 60% 概率长 MUSHROOM. 没找到 floor (悬空小室连通处) → 跳过那列.
static func _try_place_mushroom_patch(c: Chunk, world_x_center: int, start_y: int,
		x_radius: int, chunk_start: int, chunk_end: int, height: int, rng: RandomNumberGenerator) -> void:
	for dx in range(-x_radius, x_radius + 1):
		var wx: int = world_x_center + dx
		if wx < chunk_start or wx >= chunk_end:
			continue
		var lx: int = wx - chunk_start
		# 朝下找第一个 STONE/DEEP_STONE 当 floor (最多扫 x_radius+3 格)
		var floor_y: int = -1
		for dy in range(0, x_radius + 3):
			var wy: int = start_y + dy
			if wy < 0 or wy >= height:
				break
			var t: int = c.tiles[lx][wy]
			if t == Tiles.STONE or t == Tiles.DEEP_STONE:
				floor_y = wy
				break
		if floor_y <= 0:
			continue
		# floor 改 MUD
		c.tiles[lx][floor_y] = Tiles.MUD
		# floor 上方那格如果是 AIR, 60% 长 MUSHROOM
		var top_y: int = floor_y - 1
		if top_y >= 0 and c.tiles[lx][top_y] == Tiles.AIR and rng.randf() < 0.60:
			c.tiles[lx][top_y] = Tiles.MUSHROOM


# ===== 大洞厅 (Terraria cavern) =====
# 深层用一张低频 2D 噪声, 阈值以上的连片格挖成 AIR → 大块开阔洞 (能在里面跑).
# 只挖石头/矿 (不动基岩/地狱/水/已空), 地表下 CAVERN_MIN_DEPTH 起 (浅层留 worm, 不戳地表).
static func _carve_caverns_chunk(c: Chunk, chunk_heights: Dictionary, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	var cavern_noise := FastNoiseLite.new()
	cavern_noise.seed = world_seed + 71
	cavern_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	cavern_noise.frequency = CAVERN_NOISE_FREQ
	var chunk_start: int = chunk_x * chunk_width
	var bottom: int = mini(height - BEDROCK_ROWS, HELL_DEPTH)   # 不挖地狱区
	for lx in chunk_width:
		var wx: int = chunk_start + lx
		var top: int = chunk_heights[wx] + CAVERN_MIN_DEPTH
		if top >= bottom:
			continue
		var col: Array = c.tiles[lx]
		for y in range(top, bottom):
			var t: int = col[y]
			# 只挖石头/矿 (深层这一段就只有这些; 别动 bedrock/特殊/已空)
			if not _is_cavern_carveable(t):
				continue
			if cavern_noise.get_noise_2d(float(wx), float(y)) > CAVERN_THRESHOLD:
				col[y] = Tiles.AIR


# 大洞厅能挖掉的 tile: 石头 + 各种矿 (挖了露出洞壁, 矿脉留在洞边).
static func _is_cavern_carveable(t: int) -> bool:
	return t == Tiles.STONE or t == Tiles.DEEP_STONE \
			or t == Tiles.COAL_ORE or t == Tiles.IRON_ORE or t == Tiles.COPPER_ORE \
			or t == Tiles.TIN_ORE or t == Tiles.GOLD_ORE or t == Tiles.SILVER_ORE \
			or t == Tiles.DIAMOND_ORE


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
	surf_noise.fractal_octaves = 2

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
				if t == Tiles.BEDROCK or Tiles.is_ore(t):   # 矿石别被吞 (以前只护煤/铁)
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


# ===== 地狱 (Phase 1) =====
# y > HELL_DEPTH 是地狱区: 把 STONE/DEEP_STONE 换 HELL_STONE,
# AIR 底部偶发填 LAVA 池, 池四周 HELL_STONE 换 OBSIDIAN, HELL_STONE 顶 5% 长 HELL_FRUIT.
# 矿石 (COAL/IRON/...) 保留, 让矿洞探险还能挖到原矿.
const HELL_DEPTH := 220            # y > 此处算地狱区. 世界 256 高 (ChunkConstants.WORLD_HEIGHT),
                                   # 地狱在最底 ~34 行. 之前 118 是按 128 算错了 → 地表就能看到地狱.
const HELL_HALF_WIDTH := 250       # 地狱矩形 x 半宽 (总宽 500 tile)
# 地狱中心: 世界中心 (世界宽 1024 → 中心 512) ± 100 (按 seed 偏移). 保证玩家从 spawn 走得到.
const HELL_CENTER_BASE := 512
const HELL_CENTER_JITTER := 100
# 地狱边界波浪: 不再直线, 顶/侧用 noise 抖动. 用户要求"有点斜坡".
const HELL_TOP_WAVE_AMP := 8       # 顶部 y 方向波浪 ±8 tile
const HELL_SIDE_WAVE_AMP := 6      # 侧面 x 方向波浪 ±6 tile


# 地狱矩形 x 范围. 中心在 world 中心 (512) ± seed-derived jitter, 半宽 250.
static func _hell_zone_x(world_seed: int) -> Vector2i:
	var jitter: int = (_hash3(world_seed, 0, 0xdeadbeef) & 0xff) - 128   # -128..127
	jitter = clampi(jitter, -HELL_CENTER_JITTER, HELL_CENTER_JITTER)
	var center: int = HELL_CENTER_BASE + jitter
	return Vector2i(center - HELL_HALF_WIDTH, center + HELL_HALF_WIDTH)


# 保底 tier: 按 seed+chunk_x 给 chunk 算 "本 chunk 第一个 chest 强制升级"
# 0=不强制 / 1=gold / 2=diamond / 3=shadow (要在地狱区才生效)
static func _guaranteed_tier_for_chunk(world_seed: int, chunk_x: int) -> int:
	var v: int = _hash3(world_seed, chunk_x, 0xc4e57711) % 100
	if v < 4: return 3   # 4% shadow
	if v < 12: return 2  # 8% diamond
	if v < 27: return 1  # 15% gold
	return 0
const LAVA_CHUNK_PROB := 0.85      # 每 chunk 85% 试一次放岩浆池
const LAVA_POOL_MIN_SIZE := 4      # 至少 4 格才算池子
const HELL_FRUIT_CHANCE := 0.07    # HELL_STONE 顶 7% 长火果

static func _apply_hell_biome_chunk(c: Chunk, world_seed: int, chunk_x: int,
		chunk_width: int, height: int) -> void:
	# 地狱在 world_x 范围 [hell_zone.x, hell_zone.y] 内, 但边界用 noise 抖出波浪.
	var hell_zone: Vector2i = _hell_zone_x(world_seed)
	var chunk_start: int = chunk_x * chunk_width
	# 本 chunk 跟地狱矩形大致有交集? (留 amp buffer 因为波浪会突出)
	var buf: int = HELL_SIDE_WAVE_AMP + 2
	if chunk_start > hell_zone.y + buf or chunk_start + chunk_width - 1 < hell_zone.x - buf:
		return
	# 边界 noise: 顶部 y 抖, 侧面 x 抖. 用 FastNoiseLite 平滑波浪 (不是抖一格抖一格).
	var top_noise := FastNoiseLite.new()
	top_noise.seed = world_seed + 7777
	top_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	top_noise.frequency = 0.04   # 慢起伏 (每 ~25 格一个山头/山谷)
	var side_noise := FastNoiseLite.new()
	side_noise.seed = world_seed + 8888
	side_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	side_noise.frequency = 0.06
	# 预算: 每个 world_y 的左右边界 offset (按 y 共用, 不必每 (x,y) 重算)
	var left_offsets: PackedInt32Array = PackedInt32Array()
	var right_offsets: PackedInt32Array = PackedInt32Array()
	left_offsets.resize(height)
	right_offsets.resize(height)
	for y in height:
		left_offsets[y] = int(side_noise.get_noise_1d(float(y) + 0.5) * HELL_SIDE_WAVE_AMP)
		right_offsets[y] = int(side_noise.get_noise_1d(float(y) + 100.5) * HELL_SIDE_WAVE_AMP)
	# 1) 替换 STONE/DEEP_STONE → HELL_STONE, 边界按 noise 走波浪
	for lx in chunk_width:
		var world_x: int = chunk_start + lx
		# 顶部 y 边界 (由 world_x 决定的 noise)
		var top_offset: int = int(top_noise.get_noise_1d(float(world_x)) * HELL_TOP_WAVE_AMP)
		var hell_top_at_x: int = HELL_DEPTH + top_offset
		for y in range(hell_top_at_x + 1, height):
			var hell_x_min: int = hell_zone.x + left_offsets[y]
			var hell_x_max: int = hell_zone.y + right_offsets[y]
			if world_x < hell_x_min or world_x > hell_x_max:
				continue
			var t: int = c.tiles[lx][y]
			if t == Tiles.STONE or t == Tiles.DEEP_STONE:
				c.tiles[lx][y] = Tiles.HELL_STONE
	# 2) 岩浆池: BFS 找 AIR 连通区域底部 1-2 行填 LAVA
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0xfa11c123)
	if rng.randf() < LAVA_CHUNK_PROB:
		_fill_lava_pools_chunk(c, chunk_width, height, rng, hell_zone, chunk_start)
	# 3) OBSIDIAN 环: LAVA 邻 HELL_STONE 的 → OBSIDIAN
	_ring_obsidian_around_lava(c, chunk_width, height)
	# 4) 火果: HELL_STONE 顶下方是 AIR → 偶发挂 HELL_FRUIT
	_place_hell_fruit_chunk(c, chunk_width, height, rng)


# 岩浆 BFS: 找 y > HELL_DEPTH 的 AIR 连通区域, 底部 1-2 格填 LAVA. 重用 _bfs_basin 逻辑.
static func _fill_lava_pools_chunk(c: Chunk, chunk_width: int, height: int,
		rng: RandomNumberGenerator,
		hell_zone: Vector2i = Vector2i(-99999, 99999),
		chunk_start: int = 0) -> void:
	# 短世界 (height ≤ HELL_DEPTH+3) 没地狱区, 直接返回 — 防 randi_range 反向 + OOB
	if height <= HELL_DEPTH + 3:
		return
	var visited: Array = []
	visited.resize(chunk_width)
	for lx in chunk_width:
		var col: Array = []
		col.resize(height)
		col.fill(false)
		visited[lx] = col
	# 多次尝试找池子起点 (随机起 air cell)
	var attempts: int = 0
	var pools_made: int = 0
	while attempts < 8 and pools_made < 3:
		attempts += 1
		var lx: int = rng.randi() % chunk_width
		# 跳过不在地狱矩形 x 范围内的列
		var world_x_check: int = chunk_start + lx
		if world_x_check < hell_zone.x or world_x_check > hell_zone.y:
			continue
		var sy: int = rng.randi_range(HELL_DEPTH + 2, height - 3)
		if visited[lx][sy] or c.tiles[lx][sy] != Tiles.AIR:
			continue
		# BFS 找 basin (跟 _bfs_basin 思路同, 这里复用简化版)
		var basin: Array = []
		var max_y: int = sy
		var queue: Array = [Vector2i(lx, sy)]
		visited[lx][sy] = true
		while not queue.is_empty():
			var p: Vector2i = queue.pop_back()
			if p.y > max_y: max_y = p.y
			basin.append(p)
			if basin.size() > 80:
				break  # 太大, 放弃
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = p.x + d.x
				var ny: int = p.y + d.y
				if nx < 0 or nx >= chunk_width or ny <= HELL_DEPTH or ny >= height - 1:
					continue
				if visited[nx][ny]:
					continue
				if c.tiles[nx][ny] != Tiles.AIR:
					continue
				visited[nx][ny] = true
				queue.append(Vector2i(nx, ny))
		if basin.size() < LAVA_POOL_MIN_SIZE:
			continue
		# 填 LAVA: 池底 2 行 (max_y 和 max_y - 1) 的所有 basin cells
		for p in basin:
			if p.y >= max_y - 1:
				c.tiles[p.x][p.y] = Tiles.LAVA
		pools_made += 1


# OBSIDIAN 环: LAVA 紧邻 HELL_STONE → 改 OBSIDIAN. 像火山岩遇水降温.
static func _ring_obsidian_around_lava(c: Chunk, chunk_width: int, height: int) -> void:
	for lx in chunk_width:
		for y in range(HELL_DEPTH, height):
			if c.tiles[lx][y] != Tiles.LAVA:
				continue
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var nx: int = lx + d.x
				var ny: int = y + d.y
				if nx < 0 or nx >= chunk_width or ny < 0 or ny >= height:
					continue
				if c.tiles[nx][ny] == Tiles.HELL_STONE:
					c.tiles[nx][ny] = Tiles.OBSIDIAN


# 火山口: 在地狱区凿一个 5-7 宽 × 8-12 高的垂直竖井, 壁黑曜石,
# 底 LAVA 池 (3 行), 顶有 LAVA 源 (1 列 4 高). 加载时源处 LAVA 顺壁流下 → 视觉"瀑布".
# 每 chunk 25% 概率出 1 个 (太密则不像奇景).
const VOLCANO_CHUNK_PROB := 0.25
static func _place_volcano_crater_chunk(c: Chunk, world_seed: int, chunk_x: int,
		chunk_width: int, height: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0x5f81a30c)
	if rng.randf() > VOLCANO_CHUNK_PROB:
		return
	# 检查本 chunk 是否跟地狱矩形有交集
	var hell_zone: Vector2i = _hell_zone_x(world_seed)
	var chunk_start: int = chunk_x * chunk_width
	if chunk_start > hell_zone.y or chunk_start + chunk_width - 1 < hell_zone.x:
		return
	# 选位置: chunk 中间一带 x, y 在 HELL_DEPTH+1 ~ height-12 之间
	var crater_w: int = rng.randi_range(5, 8)         # 宽度
	var crater_h: int = rng.randi_range(8, 14)        # 高度 (含池). 256 高世界, 地狱 ~34 行能塞大火山
	# x_center 必须落在地狱矩形 (世界坐标) 跟本 chunk 的交集里
	var x_min_world: int = max(chunk_start + crater_w / 2 + 2, hell_zone.x + crater_w / 2)
	var x_max_world: int = min(chunk_start + chunk_width - crater_w / 2 - 3, hell_zone.y - crater_w / 2)
	if x_min_world > x_max_world:
		return  # 这 chunk 跟地狱矩形交集太小, 放不下火山
	var x_center_local: int = rng.randi_range(x_min_world, x_max_world) - chunk_start
	# y_top 范围: HELL_DEPTH+1 起到 (基岩前 crater_h 格). 地狱厚度紧凑.
	var y_top_max: int = height - 2 - crater_h - 1     # height=128, bedrock=2, 留 1 格底
	var y_top_min: int = HELL_DEPTH + 1
	if y_top_max < y_top_min:
		return   # 地狱太薄, 这次不生成
	var y_top: int = rng.randi_range(y_top_min, y_top_max)
	var y_bottom: int = y_top + crater_h - 1
	# 1) 凿竖井 (核心 AIR), 壁外 1 圈 OBSIDIAN 锁 lava
	for dx in range(-crater_w / 2, crater_w / 2 + 1):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		# 是边缘列? 用 OBSIDIAN 包边
		var is_edge_x: bool = (dx == -crater_w / 2) or (dx == crater_w / 2)
		for wy in range(y_top, y_bottom + 1):
			if is_edge_x or wy == y_bottom:
				# 边或底: 黑曜石 (lava 容器)
				c.tiles[lx][wy] = Tiles.OBSIDIAN
			else:
				c.tiles[lx][wy] = Tiles.AIR
	# 2) 底部 3 行 LAVA 池 (在内部 AIR 区), 池底是 OBSIDIAN 撑住
	for dx in range(-crater_w / 2 + 1, crater_w / 2):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		for dy in range(0, 3):
			var wy: int = y_bottom - 1 - dy
			if wy <= y_top:
				break
			c.tiles[lx][wy] = Tiles.LAVA
	# 3) 顶部 LAVA 源: 中央 1 列 4 高 (从 y_top+1 往下 4 格), 加载时会瀑布下来
	var src_x: int = x_center_local
	if src_x >= 0 and src_x < chunk_width:
		for dy in range(0, 4):
			var wy: int = y_top + 1 + dy
			if wy >= height:
				break
			c.tiles[src_x][wy] = Tiles.LAVA
	# 4) 火山口"嘴": 在 y_top 往上 1-2 格挖出一个略宽的"漏斗口" (3-5 宽 AIR + OBSIDIAN 边)
	# 让玩家从上方能看到火山口, 视觉提示
	var lip_w: int = crater_w + 2
	for dy in range(1, 3):
		var wy: int = y_top - dy
		if wy < HELL_DEPTH:
			break
		for dx in range(-lip_w / 2, lip_w / 2 + 1):
			var lx: int = x_center_local + dx
			if lx < 0 or lx >= chunk_width:
				continue
			var is_lip_edge: bool = (dx == -lip_w / 2) or (dx == lip_w / 2)
			if c.tiles[lx][wy] == Tiles.HELL_STONE or c.tiles[lx][wy] == Tiles.OBSIDIAN:
				if is_lip_edge:
					c.tiles[lx][wy] = Tiles.OBSIDIAN
				else:
					c.tiles[lx][wy] = Tiles.AIR


# 火果: HELL_STONE 块下方是 AIR → 7% 长一个 HELL_FRUIT 挂在下方那格.
# 玩家从下方仰望能看到红果挂在天花板下.
static func _place_hell_fruit_chunk(c: Chunk, chunk_width: int, height: int, rng: RandomNumberGenerator) -> void:
	for lx in chunk_width:
		for y in range(HELL_DEPTH + 1, height - 2):
			if c.tiles[lx][y] != Tiles.HELL_STONE:
				continue
			if c.tiles[lx][y + 1] != Tiles.AIR:
				continue
			if rng.randf() < HELL_FRUIT_CHANCE:
				c.tiles[lx][y + 1] = Tiles.HELL_FRUIT


# ===== 沙漠金字塔 =====
# 用户要求: 典典台阶 13 层, 基底 25 宽, 顶 1 宽. 2-3 个/世界, 沙漠区随机出.
# 内部: 底层走廊 (高 3) 横穿 + 2 个垂直入口 + 沿走廊 2-3 个 chest.
const PYRAMID_BASE_WIDTH := 41   # 加大 (原 25): 41 宽 × 21 层的大金字塔
const PYRAMID_LAYERS := 21       # (原 13) 跟 half_base=20 配套, 顶刚好收成尖
const PYRAMID_ROOM_HEIGHT := 5   # 内部大厅高 5 格 (原 3), 更宽敞放宝藏 + 怪

# 世纪树常量已删 (用户要求)

# 废弃矿井 (Minecraft mineshaft 风): 地下深层水平走廊 + 木支柱 + 偶发竖井 + 蜘蛛 + 宝箱.
const MINESHAFT_DEPTH_OFFSET := 30      # surf + 30 tile 深 (地下深层, 远离 surface 矿)
const MINESHAFT_LENGTH := 36            # 走廊长度 (tile)
const MINESHAFT_HEIGHT := 3             # 走廊内部高 (3 tile = 玩家 + 头顶)
const MINESHAFT_PILLAR_SPACING := 5     # 木支柱间距 (每 5 tile 1 柱)
const MINESHAFT_SHAFT_CHANCE := 0.4     # 40% 概率出垂直竖井
const MINESHAFT_SHAFT_MIN_LEN := 6
const MINESHAFT_SHAFT_MAX_LEN := 12

# 给定 world_seed, 返回 2-3 个 chunk_x (有金字塔的, 都在沙漠区).
# 先扫所有 chunk 找沙漠的, 再从中随机选 2-3 个. 保证每世界都有金字塔.
static func _pyramid_chunks(world_seed: int) -> Array:
	# 同 world_seed 结果确定, 缓存避免每 chunk 重算 (老 bug: 28-90 chunk 扫 + 洗牌)
	if _pyramid_chunks_cache_valid and _pyramid_chunks_cache_seed == world_seed:
		return _pyramid_chunks_cache
	var centers: Dictionary = _build_biome_centers(world_seed)
	# 扫 chunk 范围按 world_size scale: 小 -10..+18, 中 -20..+36, 大 -32..+58
	var scan_range: Array = _scan_chunk_range()
	var desert_chunks: Array = []
	for cx in range(scan_range[0], scan_range[1]):
		var chunk_center_x: int = cx * 64 + 32
		if _biome_at_x(chunk_center_x, centers) == BIOME_DESERT:
			desert_chunks.append(cx)
	if desert_chunks.is_empty():
		return []
	# 数量由 world_size 控: 小 1, 中 2-3, 大 3-5
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 0xa1b2c3
	var count_range: Array = [2, 3]
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null:
		count_range = GameSettings.pyramid_count_range()
	var target_count: int = rng.randi_range(count_range[0], count_range[1])
	var num: int = min(target_count, desert_chunks.size())
	# Shuffle 选前 num 个
	var pool: Array = desert_chunks.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	_pyramid_chunks_cache = pool.slice(0, num)
	_pyramid_chunks_cache_seed = world_seed
	_pyramid_chunks_cache_valid = true
	return _pyramid_chunks_cache


static func _place_pyramid_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int, biome_centers: Dictionary) -> void:
	var pyramid_chunks: Array = _pyramid_chunks(world_seed)
	if not pyramid_chunks.has(chunk_x):
		return
	var chunk_start: int = chunk_x * chunk_width
	# 选中心 x (chunk 中部, 留 PYRAMID_BASE_WIDTH/2 + 2 边)
	var half_base: int = PYRAMID_BASE_WIDTH / 2   # 12
	var x_center_local: int = chunk_width / 2     # 32
	var world_x_center: int = chunk_start + x_center_local
	# 必须落在沙漠 biome (不然金字塔长在草地上不合理)
	if _biome_at_x(world_x_center, biome_centers) != BIOME_DESERT:
		return
	# 基底 y: 用中心列的 surf
	if not chunk_heights.has(world_x_center):
		return
	var base_y: int = chunk_heights[world_x_center]
	# 顶 y = base_y - 12. 检查不顶天
	var top_y: int = base_y - (PYRAMID_LAYERS - 1)
	if top_y < 2:
		return
	# 1) 实心塔身: 每层 SANDSTONE, 半宽递减
	for layer in PYRAMID_LAYERS:
		var y: int = base_y - layer
		var half_w_layer: int = half_base - layer
		if half_w_layer < 0:
			break
		for dx in range(-half_w_layer, half_w_layer + 1):
			var lx: int = x_center_local + dx
			if lx < 0 or lx >= chunk_width:
				continue
			c.tiles[lx][y] = Tiles.SANDSTONE
	# 2) 凿内部走廊 (底 3 行 AIR, 横穿基底)
	#    y_corridor_bot = base_y - 1 (脚踏 y), y_corridor_top = base_y - 3 (头顶上)
	var corridor_half: int = half_base - 2   # 走廊比塔窄 2 格 (留 2 格墙)
	for dy in range(0, PYRAMID_ROOM_HEIGHT):
		var y: int = base_y - 1 - dy
		for dx in range(-corridor_half, corridor_half + 1):
			var lx: int = x_center_local + dx
			if lx < 0 or lx >= chunk_width:
				continue
			c.tiles[lx][y] = Tiles.AIR
	# 3) 2-3 个宝箱沿走廊摆 (用 chunk-deterministic RNG 选具体几个)
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0xfeed5cab)
	var chest_count: int = rng.randi_range(3, 5)   # 大金字塔多放宝箱
	var chest_xs: Array = []
	for _i in chest_count:
		var dx: int = rng.randi_range(-corridor_half + 1, corridor_half - 1)
		var attempt: int = 0
		while chest_xs.has(dx) and attempt < 10:
			dx = rng.randi_range(-corridor_half + 1, corridor_half - 1)
			attempt += 1
		chest_xs.append(dx)
	# 宝箱 tier: 第 1 个 gold, 第 2 个 diamond, 第 3 个 shadow (递增惊喜)
	var chest_tiers: Array = [Tiles.GOLD_CHEST, Tiles.DIAMOND_CHEST, Tiles.SHADOW_CHEST, Tiles.DIAMOND_CHEST, Tiles.GOLD_CHEST]
	for i in chest_xs.size():
		var dx: int = chest_xs[i]
		var lx: int = x_center_local + dx
		var chest_y: int = base_y - 1   # 走廊底 (脚边)
		if lx < 0 or lx >= chunk_width:
			continue
		var ct: int = chest_tiers[i]
		c.tiles[lx][chest_y] = ct
		c.treasure_spots.append(Vector2i(chunk_start + lx, chest_y))
	# 4) 顶部入口 (中央竖井): 从 y=base_y-PYRAMID_ROOM_HEIGHT 到 y=top_y+1, 1 列宽 AIR
	var shaft_x: int = x_center_local
	for y in range(top_y + 1, base_y - PYRAMID_ROOM_HEIGHT + 1):
		if shaft_x >= 0 and shaft_x < chunk_width:
			c.tiles[shaft_x][y] = Tiles.AIR
	# 5) 守卫木乃伊: 走廊里记 2-3 spawn 点, chunk_manager 加载时召 mummy
	var mummy_count: int = rng.randi_range(4, 6)   # 大金字塔更多木乃伊守卫
	for _i in mummy_count:
		var mdx: int = rng.randi_range(-corridor_half + 1, corridor_half - 1)
		var mummy_x: int = chunk_start + x_center_local + mdx
		var mummy_y: int = base_y - 1   # 走廊地面
		c.mummy_spawn_spots.append(Vector2i(mummy_x, mummy_y))


# 世纪树已删 (用户要求)


# ===== 装饰小草 =====
# 草地表面 (GRASS + 上方 AIR) 偶发长 PLANT_GRASS. 用户要求 "增大平原 + 加小草".
# 概率: 每列 15%. 挖掉: 80% 啥都没 / 20% wheat_seed (tile_data PROPS 已配)
static func _place_grass_decor_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int) -> void:
	var chunk_start: int = chunk_x * chunk_width
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0x91a55ded)   # "grass seed" 派生
	for local_x in chunk_width:
		var world_x: int = chunk_start + local_x
		var surf: int = chunk_heights.get(world_x, -1)
		if surf < 1:
			continue
		# 必须是 GRASS 地表 (沙漠 / 雪原 / 丛林 不长小草)
		if c.tiles[local_x][surf] != Tiles.GRASS:
			continue
		# 上方必须 AIR (避开树干 / 仙人掌 / 花)
		var above_y: int = surf - 1
		if above_y < 0 or c.tiles[local_x][above_y] != Tiles.AIR:
			continue
		if rng.randf() < 0.15:
			c.tiles[local_x][above_y] = Tiles.PLANT_GRASS


# ===== 废弃矿井 (Mineshaft) =====
# Minecraft 风: 地下深层水平走廊 + 木支柱 + 偶发竖井 + 蜘蛛 + 宝箱.
# 跟金字塔 / 世纪树同样 chunk-selection 模式.
static func _mineshaft_chunks(world_seed: int) -> Array:
	# 同 world_seed 结果确定, 缓存避免每 chunk 重算
	if _mineshaft_chunks_cache_valid and _mineshaft_chunks_cache_seed == world_seed:
		return _mineshaft_chunks_cache
	var scan_range: Array = _scan_chunk_range()
	var candidates: Array = []
	for cx in range(scan_range[0], scan_range[1]):
		# 离 spawn (chunk 0) ≥ 1 远 (不要长 spawn 脚下), 但不限 biome (地下不分群系)
		if abs(cx) < 1:
			continue
		candidates.append(cx)
	if candidates.is_empty():
		return []
	var count_range: Array = [2, 3]
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null:
		count_range = GameSettings.mineshaft_count_range()
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 0x319e54af   # mineshaft 派生 magic
	var target_count: int = rng.randi_range(count_range[0], count_range[1])
	var num: int = min(target_count, candidates.size())
	# Fisher-Yates shuffle 选前 num
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	_mineshaft_chunks_cache = candidates.slice(0, num)
	_mineshaft_chunks_cache_seed = world_seed
	_mineshaft_chunks_cache_valid = true
	return _mineshaft_chunks_cache


# 在该 chunk 地下 (surf + 30) 凿 36 tile 水平走廊 + 偶发竖井.
# 顶部 PLANKS, 木 LOG 支柱每 5 tile 1 根, 走廊 3 高 AIR. 走廊里 1-2 chest + 2-3 蜘蛛 spawn.
static func _place_mineshaft_chunk(c: Chunk, chunk_heights: Dictionary,
		world_seed: int, chunk_x: int, chunk_width: int, height: int) -> void:
	if not _mineshaft_chunks(world_seed).has(chunk_x):
		return
	var chunk_start: int = chunk_x * chunk_width
	var x_center_local: int = chunk_width / 2
	var world_x_center: int = chunk_start + x_center_local
	if not chunk_heights.has(world_x_center):
		return
	var surf: int = chunk_heights[world_x_center]
	var corridor_floor_y: int = surf + MINESHAFT_DEPTH_OFFSET
	# 边界检查: 走廊 + 顶 + 留 1 格余量 不能超 height
	if corridor_floor_y + 2 >= height - 2:
		return
	var half_len: int = MINESHAFT_LENGTH / 2
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0xc0a1bea7)
	# 1) 水平走廊: -half_len..+half_len. 内部 3 高 AIR, 顶 PLANKS, 地 PLANKS
	# corridor_floor_y = 脚踏 cell (玩家站这, 注意 GDScript y 向下增大)
	#   y = corridor_floor_y      → 脚踏 AIR
	#   y = corridor_floor_y - 1  → 腰 AIR
	#   y = corridor_floor_y - 2  → 头 AIR
	#   y = corridor_floor_y + 1  → 地板 PLANKS (玩家踩这)
	#   y = corridor_floor_y - 3  → 顶 PLANKS
	for dx in range(-half_len, half_len + 1):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		# 内部 AIR
		for dy in range(0, MINESHAFT_HEIGHT):
			c.tiles[lx][corridor_floor_y - dy] = Tiles.AIR
		# 地板 PLANKS (玩家踩)
		if corridor_floor_y + 1 < height:
			c.tiles[lx][corridor_floor_y + 1] = Tiles.PLANKS
		# 顶 PLANKS
		var ceil_y: int = corridor_floor_y - MINESHAFT_HEIGHT
		if ceil_y >= 0:
			c.tiles[lx][ceil_y] = Tiles.PLANKS
	# 2) 木支柱: 每 PILLAR_SPACING tile 1 根 LOG 柱, 高度 = 走廊高 (从顶 PLANKS 到地板 PLANKS 之间)
	var pillar_top_y: int = corridor_floor_y - MINESHAFT_HEIGHT + 1   # 顶 PLANKS 下一格
	var pillar_bot_y: int = corridor_floor_y                          # 脚踏 cell (柱底)
	for dx in range(-half_len, half_len + 1, MINESHAFT_PILLAR_SPACING):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		for y in range(pillar_top_y, pillar_bot_y + 1):
			c.tiles[lx][y] = Tiles.LOG
	# 3) 1-2 个宝箱 (CHEST 或 GOLD_CHEST), 摆在地板上 (= corridor_floor_y, AIR 行最底)
	# 避开支柱位置 (dx % PILLAR_SPACING != 0)
	var chest_count: int = rng.randi_range(1, 2)
	var chest_xs: Array = []
	for _i in chest_count:
		var attempt: int = 0
		var dx: int = rng.randi_range(-half_len + 2, half_len - 2)
		while (dx % MINESHAFT_PILLAR_SPACING == 0 or chest_xs.has(dx)) and attempt < 10:
			dx = rng.randi_range(-half_len + 2, half_len - 2)
			attempt += 1
		chest_xs.append(dx)
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		var ct: int = Tiles.GOLD_CHEST if rng.randf() < 0.35 else Tiles.CHEST
		c.tiles[lx][corridor_floor_y] = ct
		c.treasure_spots.append(Vector2i(chunk_start + lx, corridor_floor_y))
	# 4) 蜘蛛 spawn: 2-3 个, 随机走廊位置 (避开支柱 + chest)
	var spider_count: int = rng.randi_range(2, 3)
	for _i in spider_count:
		var attempt2: int = 0
		var sdx: int = rng.randi_range(-half_len + 1, half_len - 1)
		while (sdx % MINESHAFT_PILLAR_SPACING == 0 or chest_xs.has(sdx)) and attempt2 < 10:
			sdx = rng.randi_range(-half_len + 1, half_len - 1)
			attempt2 += 1
		var spider_lx: int = x_center_local + sdx
		if spider_lx < 0 or spider_lx >= chunk_width:
			continue
		c.mineshaft_spider_spots.append(Vector2i(chunk_start + spider_lx, corridor_floor_y))
	# 5) 偶发竖井 (40% 概率): 走廊中段开一个洞向下 6-12 格 + WOOD_PLATFORM 楼梯
	if rng.randf() < MINESHAFT_SHAFT_CHANCE:
		var shaft_dx: int = rng.randi_range(-half_len / 2, half_len / 2)
		# 避开支柱 + chest
		var attempt3: int = 0
		while (shaft_dx % MINESHAFT_PILLAR_SPACING == 0 or chest_xs.has(shaft_dx)) and attempt3 < 10:
			shaft_dx = rng.randi_range(-half_len / 2, half_len / 2)
			attempt3 += 1
		var shaft_lx: int = x_center_local + shaft_dx
		if shaft_lx >= 0 and shaft_lx < chunk_width:
			var shaft_len: int = rng.randi_range(MINESHAFT_SHAFT_MIN_LEN, MINESHAFT_SHAFT_MAX_LEN)
			# 凿地板 + 向下 shaft_len 格 AIR
			c.tiles[shaft_lx][corridor_floor_y + 1] = Tiles.AIR
			for d in range(1, shaft_len + 1):
				var y: int = corridor_floor_y + 1 + d
				if y >= height - 1:
					break
				c.tiles[shaft_lx][y] = Tiles.AIR
				# 旁边一格 WOOD_PLATFORM (玩家踩着下楼梯)
				if d % 2 == 0:
					var step_lx: int = shaft_lx + (1 if d % 4 == 0 else -1)
					if step_lx >= 0 and step_lx < chunk_width and c.tiles[step_lx][y] != Tiles.AIR:
						c.tiles[step_lx][y] = Tiles.WOOD_PLATFORM


# ===== 瀑布矿洞 =====
# 跟 generate_chunk 里 surf 公式一致: 用主 noise 的种子重算单列 surf.
# 这里独立算一遍, 不依赖传入的 chunk_heights (worm 起点可能落在邻 chunk).
static func _estimate_surf(world_x: int, world_seed: int, height: int) -> int:
	var n := FastNoiseLite.new()
	n.seed = world_seed
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.frequency = 0.015
	n.fractal_octaves = 2
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
# 性能: scenic_director 每帧调这个 (~60Hz) 跟玩家 biome tint. 缓存 centers 防每帧
# Fisher-Yates 洗牌 + RNG 分配. 同 world_seed 结果是确定的, 复用 OK.
static var _biome_centers_cache_seed: int = 0
static var _biome_centers_cache: Dictionary = {}
# 金字塔 / 废弃矿井 chunk 列表也按 world_seed 缓存. 老版每 chunk 加载重算
# (扫 28-90 chunk + biome 判断 + Fisher-Yates), 每 chunk ~0.5-2ms 浪费.
static var _pyramid_chunks_cache_seed: int = 0
static var _pyramid_chunks_cache: Array = []
static var _pyramid_chunks_cache_valid: bool = false
static var _mineshaft_chunks_cache_seed: int = 0
static var _mineshaft_chunks_cache: Array = []
static var _mineshaft_chunks_cache_valid: bool = false


# 清掉所有"按 seed 缓存"的结构选址 + biome 中心. 它们其实也依赖 world_size, 但只用 seed 当 key,
# 所以同种子不同大小的世界 (同进程不重启) 会命中旧缓存 → 金字塔/矿井/空岛/biome 位置错位.
# 换世界 (chunk_manager.setup) 时调一次, 强制按当前 world_size 重算.
static func clear_structure_caches() -> void:
	_pyramid_chunks_cache_valid = false
	_mineshaft_chunks_cache_valid = false
	_sky_island_chunks_cache_valid = false
	_biome_centers_cache.clear()


static func _biome_at(world_x: int, world_seed: int) -> int:
	if _biome_centers_cache.is_empty() or _biome_centers_cache_seed != world_seed:
		_biome_centers_cache = _build_biome_centers(world_seed)
		_biome_centers_cache_seed = world_seed
	return _biome_at_x(world_x, _biome_centers_cache)


# 内联版: chunk_gen 提前算好 centers 不再每列重建
static func _biome_at_x(world_x: int, biome_centers: Dictionary) -> int:
	for biome_id in biome_centers.keys():
		var cx: int = biome_centers[biome_id]
		if absi(world_x - cx) <= _BIOME_SLOT_HALF_WIDTH:
			return biome_id
	return BIOME_FOREST


# 找 biome / 金字塔 / 世纪树扫的 chunk 范围. 跟着 world_size 走 (大世界扫更宽).
# 返回 [start_cx, end_cx] (exclusive end), 默认覆盖 -20..36 (1 chunk = 64 tile).
static func _scan_chunk_range() -> Array:
	var scale: float = 1.0
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null:
		scale = GameSettings.world_size_scale()
	# 默认 -20..36 = 56 chunk 宽. scale 后比例同步.
	var half_left: int = int(round(20.0 * scale))
	var half_right: int = int(round(36.0 * scale))
	return [-half_left, half_right]


# 用 seed shuffle 4 个槽位给 4 个 biome, 每个加 jitter
# 槽位按 GameSettings.current_world_size 缩放: 小 0.5x / 中 1.0x / 大 1.6x
static func _build_biome_centers(world_seed: int) -> Dictionary:
	var scale: float = 1.0
	if Engine.has_singleton("GameSettings") or (Engine.get_main_loop() != null and Engine.get_main_loop().has_method("get_root") and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null):
		scale = GameSettings.world_size_scale()
	# Fisher-Yates shuffle slots (scale 后)
	var slots: Array = []
	for s in _BIOME_SLOTS:
		slots.append(int(round(float(s) * scale)))
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


# Biome → 水 tile (颜色按群系). 森林/雪原/默认 = 通用蓝 WATER.
static func _biome_water_tile(biome_id: int) -> int:
	match biome_id:
		BIOME_DESERT: return Tiles.WATER_DESERT  # 青绿松石
		BIOME_JUNGLE: return Tiles.WATER_JUNGLE  # 翠绿
		BIOME_SWAMP: return Tiles.WATER_SWAMP    # 浑浊墨绿
		_: return Tiles.WATER                    # FOREST / SNOW / 默认 = 蓝


# Biome → 浅地下 tile (y < surf + DIRT_DEPTH).
static func _biome_subsurface_tile(biome_id: int, is_sand_col: bool) -> int:
	if is_sand_col:
		return Tiles.SAND
	match biome_id:
		BIOME_SWAMP: return Tiles.MUD
		BIOME_JUNGLE: return Tiles.JUNGLE_DIRT  # 丛林深色泥
		BIOME_SNOW: return Tiles.SNOW_DIRT      # 雪原冻土
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
				leaves_for_biome = Tiles.JUNGLE_LEAVES  # 深湿绿
			Tiles.SWAMP_GRASS:
				leaves_for_biome = Tiles.LEAVES_AUTUMN  # 沼泽用秋叶感觉死气
			Tiles.SNOW:
				leaves_for_biome = Tiles.LEAVES_PINE    # 雪原长松针
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


# ===== 空岛 (Sky Island) =====
# 天空层浮岛: 透镜形 (中心厚边缘薄), 云块底 + 2 格土 + 草顶 + 中心小水池 + 树 + 钻石宝箱.
# 单岛装进一个 chunk (宽 ≤ 44, 居中). 数量 GameSettings.skyisland_count_range().
const SKY_ISLAND_WIDTH_MIN := 30        # 岛最窄
const SKY_ISLAND_WIDTH_MAX := 44        # 岛最宽
const SKY_ISLAND_TOP_Y_MIN := 20        # 草顶最高 (y 越小越高, 越飘)
const SKY_ISLAND_TOP_Y_MAX := 36        # 草顶最低
const SKY_ISLAND_CLOUD_DEPTH := 6       # 中心云块最厚层数 (边缘按比例减薄)
const SKY_ISLAND_DIRT_ROWS := 2         # 草下夹土层数
const SKY_ISLAND_POOL_HALF := 3         # 中心水池半宽 (= 7 格宽)
const SKY_ISLAND_TREE_MIN := 2          # 岛上最少树
const SKY_ISLAND_TREE_MAX := 4          # 最多树
const SKY_ISLAND_TREE_TRUNK := 4        # 空岛小树干高 (短, 不戳世界顶)

static var _sky_island_chunks_cache_seed: int = 0
static var _sky_island_chunks_cache: Array = []
static var _sky_island_chunks_cache_valid: bool = false


# 给定 world_seed, 返回有空岛的 chunk_x 数组. 仿 _pyramid_chunks 但不限 biome (天上哪都行).
# 数量走 GameSettings.skyisland_count_range(), 从 _scan_chunk_range() 候选里 Fisher-Yates 选.
static func _sky_island_chunks(world_seed: int) -> Array:
	if _sky_island_chunks_cache_valid and _sky_island_chunks_cache_seed == world_seed:
		return _sky_island_chunks_cache
	var scan_range: Array = _scan_chunk_range()
	var candidates: Array = []
	for cx in range(scan_range[0], scan_range[1]):
		candidates.append(cx)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed + 0x5217a1
	# 数量按世界大小 (autoload 在场才读, 不在场默认中世界 2-3)
	var count_range: Array = [2, 3]
	if Engine.get_main_loop() != null and Engine.get_main_loop().get_root().get_node_or_null("GameSettings") != null:
		count_range = GameSettings.skyisland_count_range()
	var target_count: int = rng.randi_range(count_range[0], count_range[1])
	var num: int = min(target_count, candidates.size())
	for i in range(candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp
	_sky_island_chunks_cache = candidates.slice(0, num)
	_sky_island_chunks_cache_seed = world_seed
	_sky_island_chunks_cache_valid = true
	return _sky_island_chunks_cache


# 在选中的 chunk 中部盖一块空岛. 透镜形: 中心厚边缘薄.
static func _place_sky_island_chunk(c: Chunk, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	if not _sky_island_chunks(world_seed).has(chunk_x):
		return
	var chunk_start: int = chunk_x * chunk_width
	var rng := RandomNumberGenerator.new()
	rng.seed = _hash3(world_seed, chunk_x, 0x5217a1)
	var width: int = rng.randi_range(SKY_ISLAND_WIDTH_MIN, SKY_ISLAND_WIDTH_MAX)
	var half: int = width / 2
	var top_y: int = rng.randi_range(SKY_ISLAND_TOP_Y_MIN, SKY_ISLAND_TOP_Y_MAX)
	var x_center_local: int = chunk_width / 2

	# 1) 岛体: 每列按到中心比例算云块厚度, 顶 GRASS / 下 DIRT / 再下 CLOUD
	for dx in range(-half, half + 1):
		var lx: int = x_center_local + dx
		if lx < 0 or lx >= chunk_width:
			continue
		var ratio: float = 1.0 - float(absi(dx)) / float(half + 1)   # 1 中心 .. ~0 边缘
		if ratio <= 0.05:
			continue   # 最外缘空着 → 边缘自然收窄成尖
		var cloud_thick: int = int(round(float(SKY_ISLAND_CLOUD_DEPTH) * (0.25 + 0.75 * ratio)))
		if cloud_thick < 1:
			cloud_thick = 1
		if top_y >= 0 and top_y < height:
			c.tiles[lx][top_y] = Tiles.GRASS
		for d in range(1, SKY_ISLAND_DIRT_ROWS + 1):
			var yy: int = top_y + d
			if yy >= 0 and yy < height:
				c.tiles[lx][yy] = Tiles.DIRT
		var cloud_start: int = top_y + SKY_ISLAND_DIRT_ROWS + 1
		for d2 in range(0, cloud_thick):
			var yy2: int = cloud_start + d2
			if yy2 >= 0 and yy2 < height:
				c.tiles[lx][yy2] = Tiles.CLOUD

	# 2) 中心小水池: 挖 2 格深 (top_y, top_y+1) 填 WATER, top_y+2 保持 DIRT 当池底.
	#    两侧 dx=±(POOL_HALF+1) 是 GRASS/DIRT 实心墙 → 水被围住不漏.
	for dxp in range(-SKY_ISLAND_POOL_HALF, SKY_ISLAND_POOL_HALF + 1):
		var lxp: int = x_center_local + dxp
		if lxp < 0 or lxp >= chunk_width:
			continue
		for dyw in range(0, 2):
			var yw: int = top_y + dyw
			if yw >= 0 and yw < height:
				c.tiles[lxp][yw] = Tiles.WATER

	# 3) 宝箱: 水池左边一格草地上放钻石宝箱 (先于树放, 树要避开此列). 记 treasure_spots.
	var chest_dx: int = -(SKY_ISLAND_POOL_HALF + 2)
	var chest_lx: int = x_center_local + chest_dx
	if chest_lx >= 0 and chest_lx < chunk_width:
		var chest_y: int = top_y - 1   # 草顶上方那格
		if chest_y >= 0 and c.tiles[chest_lx][top_y] == Tiles.GRASS and c.tiles[chest_lx][chest_y] == Tiles.AIR:
			c.tiles[chest_lx][chest_y] = Tiles.DIAMOND_CHEST
			c.treasure_spots.append(Vector2i(chunk_start + chest_lx, chest_y))

	# 4) 树: 草地上种 2-4 棵小树, 避开水池 + 宝箱列 (树干会覆盖宝箱)
	var tree_count: int = rng.randi_range(SKY_ISLAND_TREE_MIN, SKY_ISLAND_TREE_MAX)
	for _i in range(tree_count):
		var tdx: int = rng.randi_range(-half + 2, half - 2)
		if absi(tdx) <= SKY_ISLAND_POOL_HALF + 1 or tdx == chest_dx:
			tdx = SKY_ISLAND_POOL_HALF + 2   # 推到水池右边 (跟宝箱分两侧)
		_stamp_sky_tree(c, x_center_local + tdx, top_y, chunk_width, height)

	# 5) 哈比鸟出生点: 岛顶上方天空 (1-2 只), 记进 chunk 供 chunk_manager 召
	var harpy_count: int = rng.randi_range(1, 2)
	for hi in range(harpy_count):
		var hdx: int = rng.randi_range(-half + 3, half - 3)
		var hy: int = top_y - 6 - (hi * 2)   # 草顶上方 6+ 格的开阔天空
		if hy < 2:
			hy = 2
		c.harpy_spawn_spots.append(Vector2i(chunk_start + x_center_local + hdx, hy))


# 在草地列 lx 上盖一棵小树 (LOG 树干 + 3×3 LEAVES 团). grass_y = 草顶那行.
static func _stamp_sky_tree(c: Chunk, lx: int, grass_y: int, chunk_width: int, height: int) -> void:
	if lx < 1 or lx >= chunk_width - 1:
		return   # 太靠 chunk 边, 树冠会被裁 → 放弃
	if grass_y < 0 or grass_y >= height or c.tiles[lx][grass_y] != Tiles.GRASS:
		return
	var trunk_top: int = grass_y - SKY_ISLAND_TREE_TRUNK
	if trunk_top < 2:
		return   # 太靠世界顶 → 放弃
	for y in range(trunk_top, grass_y):
		c.tiles[lx][y] = Tiles.LOG
	for ddx in range(-1, 2):
		for ddy in range(-1, 2):
			var nx: int = lx + ddx
			var ny: int = trunk_top + ddy
			if nx < 0 or nx >= chunk_width or ny < 0 or ny >= height:
				continue
			if c.tiles[nx][ny] == Tiles.AIR:
				c.tiles[nx][ny] = Tiles.LEAVES
