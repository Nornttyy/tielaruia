extends GutTest

const WorldGenerator = preload("res://scripts/world/world_generator.gd")


func _gen(world_seed: int = 42) -> Dictionary:
	return WorldGenerator.generate(world_seed, 256, 128)


func test_size_matches():
	var w = _gen()
	assert_eq(w.tiles.size(), 256, "宽度匹配")
	assert_eq((w.tiles[0] as Array).size(), 128, "高度匹配")


func test_same_seed_produces_same_world():
	var a = _gen(123)
	var b = _gen(123)
	for x in 256:
		assert_eq(a.tiles[x], b.tiles[x], "列 %d 不一致" % x)


func test_different_seed_produces_different_world():
	var a = _gen(1)
	var b = _gen(2)
	var diff_count := 0
	for x in 256:
		for y in 128:
			if a.tiles[x][y] != b.tiles[x][y]:
				diff_count += 1
	assert_gt(diff_count, 1000, "不同种子至少差 1000 tile")


func test_bedrock_at_bottom():
	var w = _gen()
	for x in 256:
		assert_eq(w.tiles[x][127], Tiles.BEDROCK, "最底行全是基岩 (列 %d)" % x)
		assert_eq(w.tiles[x][126], Tiles.BEDROCK, "倒数第二行全是基岩 (列 %d)" % x)


func test_air_above_surface():
	var w = _gen()
	var spawn: Vector2i = w.spawn_point
	assert_eq(w.tiles[spawn.x][spawn.y - 1], Tiles.AIR, "出生点上方是空气")
	assert_eq(w.tiles[spawn.x][spawn.y - 2], Tiles.AIR, "出生点上方再上一格也是空气")


func test_spawn_point_on_surface():
	var w = _gen()
	var spawn: Vector2i = w.spawn_point
	assert_true(spawn.x >= 0 and spawn.x < 256, "出生点 x 在范围内")
	assert_true(spawn.y >= 0 and spawn.y < 128, "出生点 y 在范围内")
	# spawn.y 表示"玩家脚底所在 tile"，应是空气
	assert_eq(w.tiles[spawn.x][spawn.y], Tiles.AIR, "出生点本格是空气 (脚踏)")


func test_grass_on_surface_dirt_below():
	var w = _gen()
	for x in [10, 50, 100, 150, 200]:
		for y in 128:
			var t = w.tiles[x][y]
			# 跳过空气、树身/树叶/树枝/树顶/树根、仙人掌、装饰小草, 找首个地面 tile
			if t == Tiles.AIR \
					or t == Tiles.LOG or t == Tiles.LOG_TOP \
					or t == Tiles.LOG_ROOT_L or t == Tiles.LOG_ROOT_R \
					or t == Tiles.BRANCH_L or t == Tiles.BRANCH_R \
					or t == Tiles.LEAVES or t == Tiles.LEAVES_PINE \
					or t == Tiles.LEAVES_AUTUMN \
					or t == Tiles.CACTUS or t == Tiles.CACTUS_BODY \
					or t == Tiles.PLANT_GRASS:
				continue
			assert_true(
				t == Tiles.GRASS or t == Tiles.SAND \
					or t == Tiles.SNOW or t == Tiles.JUNGLE_GRASS or t == Tiles.SWAMP_GRASS,
				"列 %d 的地表 tile 应是 grass/sand/snow/jungle_grass/swamp_grass，实际 %d" % [x, t]
			)
			break


func test_world_has_trees():
	# Pine 和 Autumn 故意不长 (设计选择), 不强求.
	var w = WorldGenerator.generate(42, 256, 128)
	var log_count := 0
	var leaves_total := 0
	for x in 256:
		for y in 128:
			var t = w.tiles[x][y]
			if t == Tiles.LOG:
				log_count += 1
			elif t == Tiles.LEAVES or t == Tiles.LEAVES_PINE or t == Tiles.LEAVES_AUTUMN:
				leaves_total += 1
	assert_gt(log_count, 10, "应有至少 10 个 LOG (树干)")
	assert_gt(leaves_total, 10, "应有至少 10 个树叶 (任意品种)")


# 锁住 "树要高" — 至少一棵树的连续 LOG 柱 >= 6 格 (trunk_range[0]=6).
func test_world_trees_are_tall():
	var w = WorldGenerator.generate(42, 256, 128)
	var max_trunk := 0
	for x in 256:
		var run := 0
		for y in 128:
			if w.tiles[x][y] == Tiles.LOG:
				run += 1
				if run > max_trunk:
					max_trunk = run
			else:
				run = 0
	assert_gte(max_trunk, 6, "最高树干应 >=6 格 (trunk_range[0]=6). 实际 %d" % max_trunk)


func test_generate_chunk_returns_64_wide():
	var c = WorldGenerator.generate_chunk(42, 0, 128)
	assert_eq(c.tiles.size(), 64, "chunk 宽 64 列")
	assert_eq(c.tiles[0].size(), 128, "高度按参数")
	assert_eq(c.chunk_x, 0)


func test_generate_chunk_deterministic():
	var a = WorldGenerator.generate_chunk(42, 3, 128)
	var b = WorldGenerator.generate_chunk(42, 3, 128)
	for lx in 64:
		assert_eq(a.tiles[lx], b.tiles[lx], "同 seed+chunk_x 同结果, 列 %d" % lx)


func test_generate_chunk_different_x_different():
	var a = WorldGenerator.generate_chunk(42, 0, 128)
	var b = WorldGenerator.generate_chunk(42, 10, 128)
	var diff: int = 0
	for lx in 64:
		for y in 128:
			if a.tiles[lx][y] != b.tiles[lx][y]:
				diff += 1
	assert_gt(diff, 400, "不同 chunk 差异 > 400 tiles")


func test_no_orphan_leaves_at_chunk_seams():
	# 跨 chunk 边界不能有"漂浮叶"(无树干的叶子)。
	# 检查每片叶子的小邻域内必须能找到 LOG。
	var w = WorldGenerator.generate(42, 256, 128)
	var leaf_tiles := [Tiles.LEAVES, Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN]
	for x in 256:
		for y in 128:
			if not w.tiles[x][y] in leaf_tiles:
				continue
			var has_log := false
			for dx in range(-3, 4):
				for dy in range(0, 10):
					var nx: int = x + dx
					var ny: int = y + dy
					if nx < 0 or nx >= 256 or ny < 0 or ny >= 128:
						continue
					if w.tiles[nx][ny] == Tiles.LOG:
						has_log = true
						break
				if has_log:
					break
			assert_true(has_log, "孤立叶 at (%d, %d) — 跨 chunk 边界树漂浮叶 bug" % [x, y])


# ===== 地底视野更新: 洞穴 / 矿石 / 深石分层 =====

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")


func test_underground_has_air_caves() -> void:
	var c = WorldGenerator.generate_chunk(54321, 0)
	var air_count = 0
	for x in c.tiles.size():
		var col: Array = c.tiles[x]
		# 跳过地表上空: 从 y = WORLD_HEIGHT/3 起开始数 (一定在地下)
		for y in range(ChunkConstants.WORLD_HEIGHT / 3, col.size()):
			if col[y] == Tiles.AIR:
				air_count += 1
	assert_gt(air_count, 20, "地下应至少有 20 个洞穴 AIR tile")


func test_has_coal_ore() -> void:
	var c = WorldGenerator.generate_chunk(54321, 0)
	var coal_count = 0
	for x in c.tiles.size():
		for y in c.tiles[x].size():
			if c.tiles[x][y] == Tiles.COAL_ORE:
				coal_count += 1
	assert_gt(coal_count, 0, "应至少有 1 个煤矿")


func test_has_iron_ore() -> void:
	# 铁矿只在 DEEP_STONE 层 + noise > IRON_THRESHOLD, 单 chunk + 单 seed 可能命中不到
	# 跨 10 个 seed × chunk_x=0 累计应远大于 0
	var iron_count = 0
	for seed_v in [1, 2, 3, 7, 11, 42, 99, 100, 500, 1000]:
		var c = WorldGenerator.generate_chunk(seed_v, 0)
		for x in c.tiles.size():
			for y in c.tiles[x].size():
				if c.tiles[x][y] == Tiles.IRON_ORE:
					iron_count += 1
	assert_gt(iron_count, 0, "10 个 seed 应至少累计出 1 个铁矿 (got %d)" % iron_count)


func test_has_deep_stone() -> void:
	var c = WorldGenerator.generate_chunk(11111, 0)
	var has_deep = false
	for x in c.tiles.size():
		for y in c.tiles[x].size():
			if c.tiles[x][y] == Tiles.DEEP_STONE:
				has_deep = true
				break
		if has_deep: break
	assert_true(has_deep, "应有 DEEP_STONE tile")


func test_bedrock_never_air() -> void:
	# 跑 3 个 seed, 断言最底 BEDROCK_ROWS 行永远不是 AIR
	for seed_v in [1, 2, 3]:
		var c = WorldGenerator.generate_chunk(seed_v, 0)
		var h = ChunkConstants.WORLD_HEIGHT
		for x in c.tiles.size():
			for y in range(h - 2, h):  # BEDROCK_ROWS = 2
				assert_ne(c.tiles[x][y], Tiles.AIR,
					"seed=%d (%d,%d) BEDROCK 不应被挖空" % [seed_v, x, y])
