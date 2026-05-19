# 程序化世界生成。给定种子产生确定性的 2D tile 数组。
# 返回 dict: {"tiles": Array[Array[int]], "spawn_point": Vector2i,
#            "seed": int, "width": int, "height": int}
# tiles[x][y] = TileData 常量
extends RefCounted

const SURFACE_BASE := 0.45       # 地表平均高度 (相对世界 0..1)
const SURFACE_AMP := 0.10        # 地表起伏振幅
const DIRT_DEPTH := 6            # 地表下泥土层厚度
const BEDROCK_ROWS := 2          # 基岩占最底几行
const SAND_THRESHOLD := 0.4      # sand_noise 超过此阈值的列为沙列
const TREE_MIN_SPACING := 5      # 相邻两棵树之间最少 N 列间距
const TREE_CHANCE := 0.45        # 候选格子里实际长树的概率

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


static func generate(world_seed: int, width: int = 1024, height: int = 256) -> Dictionary:
	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3

	# 决定地表高度（每列一个）
	var heights := PackedInt32Array()
	heights.resize(width)
	for x in width:
		var n := noise.get_noise_1d(float(x))  # -1..1
		var h := int(height * (SURFACE_BASE + n * SURFACE_AMP))
		heights[x] = clampi(h, 4, height - BEDROCK_ROWS - 1)

	# 二级噪声决定沙子斑块（独立种子避免与高度纠缠）
	var sand_noise := FastNoiseLite.new()
	sand_noise.seed = world_seed + 1
	sand_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	sand_noise.frequency = 0.05

	var tiles := []
	tiles.resize(width)
	for x in width:
		var col := []
		col.resize(height)
		var surface_y: int = heights[x]
		var is_sand_column := sand_noise.get_noise_1d(float(x)) > SAND_THRESHOLD
		for y in height:
			if y < surface_y:
				col[y] = Tiles.AIR
			elif y == surface_y:
				col[y] = Tiles.SAND if is_sand_column else Tiles.GRASS
			elif y < surface_y + DIRT_DEPTH:
				col[y] = Tiles.SAND if is_sand_column else Tiles.DIRT
			elif y >= height - BEDROCK_ROWS:
				col[y] = Tiles.BEDROCK
			else:
				col[y] = Tiles.STONE
		tiles[x] = col

	# 长树：在草地上随机间隔放树
	_place_trees(tiles, heights, world_seed, width, height)

	# 出生点：地图中央附近第一个非沙、上方 3 格空气的地表 (避免出生在树里)
	var spawn_x: int = width / 2
	var search_offsets: Array[int] = [0, 4, -4, 8, -8, 12, -12, 16, -16, 20, -20, 24, -24]
	for offset in search_offsets:
		var candidate_x: int = spawn_x + offset
		if candidate_x < 0 or candidate_x >= width:
			continue
		var surf: int = heights[candidate_x]
		if tiles[candidate_x][surf] != Tiles.GRASS:
			continue
		# 头顶 3 格必须是空气，防止落在树干或树冠里
		if surf - 3 < 0 \
				or tiles[candidate_x][surf - 1] != Tiles.AIR \
				or tiles[candidate_x][surf - 2] != Tiles.AIR \
				or tiles[candidate_x][surf - 3] != Tiles.AIR:
			continue
		spawn_x = candidate_x
		break
	# spawn_y 是脚底所在 tile 的 y (= 地表上方一格 = AIR)
	var spawn_y: int = heights[spawn_x] - 1

	return {
		"tiles": tiles,
		"spawn_point": Vector2i(spawn_x, spawn_y),
		"seed": world_seed,
		"width": width,
		"height": height,
	}


# 在 grass 地表种树。3 种树:橡木 (3x3 圆冠) / 松树 (3x5 高瘦) / 秋树 (5x3 宽矮)。
# LOG 不实心,玩家可穿过;LEAVES 用 3 个变种 (橡/松/秋) 分别掉自己的物品。
# 用 seeded RNG 保证同种子同结果。
static func _place_trees(tiles: Array, heights: PackedInt32Array, world_seed: int, width: int, height: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 1000003 + 17
	var last_tree_x: int = -1000
	var x: int = 2
	while x < width - 2:
		var surf: int = heights[x]
		if tiles[x][surf] != Tiles.GRASS:
			x += 1
			continue
		if x - last_tree_x < TREE_MIN_SPACING:
			x += 1
			continue
		if rng.randf() > TREE_CHANCE:
			x += 1
			continue
		# 随机选树种 + 该树种的随机 canopy 变体
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
			x += 1
			continue
		# 检查整个树干列空间是否 AIR
		var all_clear: bool = true
		for ty in range(canopy_top, surf):
			if tiles[x][ty] != Tiles.AIR:
				all_clear = false
				break
		if not all_clear:
			x += 1
			continue
		# 按 canopy_kind 放树冠
		_place_canopy(tiles, x, trunk_top, canopy_kind, leaves_tile, width, height)
		# 树干 (覆盖叶子)
		for ty in range(trunk_top, surf):
			tiles[x][ty] = Tiles.LOG
		last_tree_x = x
		x += TREE_MIN_SPACING


# 按形状画树冠。坐标 (trunk_x, trunk_top) 是树干顶部。
# dy <=0 在树干顶部及上方; dy=+1 是树干第二节,leaves 在两侧 (中柱被 LOG 覆盖)。
# 树叶下方不能是地形 (grass/dirt/stone), 否则短树会"脚底长叶"。
static func _place_canopy(tiles: Array, trunk_x: int, trunk_top: int, kind: String,
		leaves_tile: int, width: int, height: int) -> void:
	var offsets: Array = _canopy_offsets(kind)
	for off in offsets:
		var cx: int = trunk_x + off.x
		var cy: int = trunk_top + off.y
		if cx < 0 or cx >= width or cy < 0 or cy >= height:
			continue
		if tiles[cx][cy] != Tiles.AIR:
			continue
		# 防"贴地叶": 下方一格必须是 AIR/叶子/树干, 不能是地表方块
		if cy + 1 < height:
			var below: int = tiles[cx][cy + 1]
			if below != Tiles.AIR and below != Tiles.LOG \
					and below != Tiles.LEAVES and below != Tiles.LEAVES_PINE \
					and below != Tiles.LEAVES_AUTUMN:
				continue
		tiles[cx][cy] = leaves_tile


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
