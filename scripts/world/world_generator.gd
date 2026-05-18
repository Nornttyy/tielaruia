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
const TREE_MIN_HEIGHT := 4       # 树干最矮（不含树冠）
const TREE_MAX_HEIGHT := 6       # 树干最高
const TREE_MIN_SPACING := 5      # 相邻两棵树之间最少 N 列间距
const TREE_CHANCE := 0.45        # 候选格子里实际长树的概率


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

	# 出生点：地图中央附近第一个非沙地表，玩家脚底在地表上方一格
	var spawn_x: int = width / 2
	var search_offsets: Array[int] = [0, 4, -4, 8, -8, 12, -12, 16, -16]
	for offset in search_offsets:
		var candidate_x: int = spawn_x + offset
		if candidate_x < 0 or candidate_x >= width:
			continue
		var surf: int = heights[candidate_x]
		if tiles[candidate_x][surf] == Tiles.GRASS:
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


# 在 grass 地表种树。树由 LOG 树干 + 树顶 3x3 LEAVES 树冠组成。
# 用 seeded RNG 保证同种子同结果。
static func _place_trees(tiles: Array, heights: PackedInt32Array, world_seed: int, width: int, height: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed * 1000003 + 17  # 派生子种子
	var last_tree_x: int = -1000
	var x: int = 2
	while x < width - 2:
		var surf: int = heights[x]
		# 仅在草地上长（不在沙、不在边角）
		if tiles[x][surf] != Tiles.GRASS:
			x += 1
			continue
		# 间距限制
		if x - last_tree_x < TREE_MIN_SPACING:
			x += 1
			continue
		# 概率判定
		if rng.randf() > TREE_CHANCE:
			x += 1
			continue
		# 树干高度
		var trunk_height: int = rng.randi_range(TREE_MIN_HEIGHT, TREE_MAX_HEIGHT)
		# 顶部位置：trunk 在 surf-trunk_height..surf-1
		var trunk_top: int = surf - trunk_height
		# 需要树冠空间 + 不出界
		if trunk_top - 1 < 0:
			x += 1
			continue
		# 检查空间是否都是 AIR
		var all_clear: bool = true
		for ty in range(trunk_top - 1, surf):
			# 树干列必须 air
			if tiles[x][ty] != Tiles.AIR:
				all_clear = false
				break
		if not all_clear:
			x += 1
			continue
		# 树冠 3x3 中心在 (x, trunk_top)
		for cy in range(trunk_top - 1, trunk_top + 2):
			for cx in range(x - 1, x + 2):
				if cx < 0 or cx >= width or cy < 0 or cy >= height:
					continue
				if tiles[cx][cy] == Tiles.AIR:
					tiles[cx][cy] = Tiles.LEAVES
		# 树干
		for ty in range(trunk_top, surf):
			tiles[x][ty] = Tiles.LOG
		last_tree_x = x
		x += TREE_MIN_SPACING
