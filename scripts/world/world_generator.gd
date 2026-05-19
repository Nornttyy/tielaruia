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

# 各树种参数: [min_h, max_h, leaves_tile, canopy_kind]
# canopy_kind: "round_3x3" / "tall_3x5" / "wide_5x3"
const _SPECIES_PARAMS := {
	_SPECIES_OAK:    [4, 6, Tiles.LEAVES,        "round_3x3"],
	_SPECIES_PINE:   [5, 8, Tiles.LEAVES_PINE,   "tall_3x5"],
	_SPECIES_AUTUMN: [3, 5, Tiles.LEAVES_AUTUMN, "wide_5x3"],
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
		# 随机选树种
		var species: int = rng.randi_range(_SPECIES_OAK, _SPECIES_AUTUMN)
		var params: Array = _SPECIES_PARAMS[species]
		var min_h: int = params[0]
		var max_h: int = params[1]
		var leaves_tile: int = params[2]
		var canopy_kind: String = params[3]
		var trunk_height: int = rng.randi_range(min_h, max_h)
		var trunk_top: int = surf - trunk_height
		# 树冠所需的最高 y 取决于形状
		var canopy_top: int = trunk_top
		match canopy_kind:
			"round_3x3": canopy_top = trunk_top - 1
			"tall_3x5":  canopy_top = trunk_top - 3
			"wide_5x3":  canopy_top = trunk_top - 1
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


# 按形状画树冠。坐标 (trunk_x, trunk_top) 是树干顶部所在格。
static func _place_canopy(tiles: Array, trunk_x: int, trunk_top: int, kind: String,
		leaves_tile: int, width: int, height: int) -> void:
	# 偏移列表：相对树干顶 (dx, dy) 都填 leaves_tile (限于 AIR)
	var offsets: Array = []
	match kind:
		"round_3x3":
			# 3x3 中心在 (0, 0)
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					offsets.append(Vector2i(dx, dy))
		"tall_3x5":
			# 5 高 3 宽,顶上 1 个尖 (松树锥形)
			# 行 dy=-3: 仅中心
			offsets.append(Vector2i(0, -3))
			# 行 dy=-2..0: 全 3 宽
			for dy in range(-2, 1):
				for dx in range(-1, 2):
					offsets.append(Vector2i(dx, dy))
		"wide_5x3":
			# 5 宽 3 高,中间一行最宽,上下行收一格 (秋树扁阔)
			# dy=-1: dx -1..1 (3 wide)
			for dx in range(-1, 2):
				offsets.append(Vector2i(dx, -1))
			# dy=0: dx -2..2 (5 wide)
			for dx in range(-2, 3):
				offsets.append(Vector2i(dx, 0))
			# dy=1: dx -1..1 (3 wide)
			for dx in range(-1, 2):
				offsets.append(Vector2i(dx, 1))
	for off in offsets:
		var cx: int = trunk_x + off.x
		var cy: int = trunk_top + off.y
		if cx < 0 or cx >= width or cy < 0 or cy >= height:
			continue
		if tiles[cx][cy] == Tiles.AIR:
			tiles[cx][cy] = leaves_tile
