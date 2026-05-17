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
