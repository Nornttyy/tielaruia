# 程序化世界生成。给定种子产生确定性的 2D tile 数组。
# 返回 dict: {"tiles": Array[Array[int]], "spawn_point": Vector2i,
#            "seed": int, "width": int, "height": int}
# tiles[x][y] = TileData 常量
extends RefCounted

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

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


# 生成一柱地形。world_x = chunk_x * CHUNK_WIDTH + local_x。
# 同 seed + chunk_x → 同结果 (deterministic)。
static func generate_chunk(world_seed: int, chunk_x: int, height: int = ChunkConstants.WORLD_HEIGHT) -> Chunk:
	var chunk_width := ChunkConstants.CHUNK_WIDTH
	var c := Chunk.new(chunk_x)
	c.init_empty()
	# 若 height 与默认 WORLD_HEIGHT 不同 (例如测试用 128), 重置每列长度
	if height != ChunkConstants.WORLD_HEIGHT:
		for lx in chunk_width:
			var col: Array = []
			col.resize(height)
			col.fill(Tiles.AIR)
			c.tiles[lx] = col

	var noise := FastNoiseLite.new()
	noise.seed = world_seed
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	noise.fractal_octaves = 3

	var sand_noise := FastNoiseLite.new()
	sand_noise.seed = world_seed + 1
	sand_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	sand_noise.frequency = 0.05

	# 计算本 chunk 范围内 + ±2 buffer 列的 heights (供树木使用)
	var ext_start := chunk_x * chunk_width - 2
	var ext_end := chunk_x * chunk_width + chunk_width + 2
	var ext_heights := {}  # world_x → surf_y
	for wx in range(ext_start, ext_end):
		var n: float = noise.get_noise_1d(float(wx))
		var h: int = int(height * (SURFACE_BASE + n * SURFACE_AMP))
		ext_heights[wx] = clampi(h, 4, height - BEDROCK_ROWS - 1)

	# 填本 chunk 64 列
	for local_x in chunk_width:
		var world_x: int = chunk_x * chunk_width + local_x
		var surf: int = ext_heights[world_x]
		var is_sand_col := sand_noise.get_noise_1d(float(world_x)) > SAND_THRESHOLD
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
				tid = Tiles.STONE
			c.tiles[local_x][y] = tid

	# 树: 在 ext range 内决定树根 x, 但只画本 chunk 范围内
	_place_trees_chunk(c, ext_heights, world_seed, chunk_x, chunk_width, height)
	return c


# Chunk 版本树木放置: ext_heights 包含 ±2 buffer 列, 树根可在 buffer 内 (canopy 伸入本 chunk).
static func _place_trees_chunk(c: Chunk, ext_heights: Dictionary, world_seed: int,
		chunk_x: int, chunk_width: int, height: int) -> void:
	var rng := RandomNumberGenerator.new()
	# 基于 (world_seed, chunk_x) 派生子种子, 同 chunk 同结果
	rng.seed = world_seed * 1000003 + chunk_x * 31 + 17
	var chunk_start: int = chunk_x * chunk_width
	var chunk_end: int = chunk_start + chunk_width
	var last_tree_x: int = -1000
	# 扫 ext 范围 (±2 buffer)
	var ext_start: int = chunk_start - 2
	var ext_end: int = chunk_end + 2
	for world_x in range(ext_start, ext_end):
		var surf: int = ext_heights.get(world_x, -1)
		if surf < 0:
			continue
		# 必须是 grass (用本 chunk tile 查; buffer 列不在 chunk 内则跳过 grass 检查 — buffer 假设 grass)
		if world_x >= chunk_start and world_x < chunk_end:
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
		# 放树干 (只在 chunk 内)
		if world_x >= chunk_start and world_x < chunk_end:
			var lx: int = world_x - chunk_start
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
		# 树冠: 偏移到 chunk 内的 cells 才画
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
