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
			# 跳过空气和树（LOG/各种 LEAVES），找首个地面 tile
			if t == Tiles.AIR or t == Tiles.LOG \
					or t == Tiles.LEAVES or t == Tiles.LEAVES_PINE \
					or t == Tiles.LEAVES_AUTUMN:
				continue
			assert_true(
				t == Tiles.GRASS or t == Tiles.SAND,
				"列 %d 的地表 tile 应是 grass/sand，实际 %d" % [x, t]
			)
			break


func test_world_has_trees():
	var w = WorldGenerator.generate(42, 256, 128)
	var log_count := 0
	var leaves_count := 0
	var pine_count := 0
	var autumn_count := 0
	for x in 256:
		for y in 128:
			var t = w.tiles[x][y]
			if t == Tiles.LOG:
				log_count += 1
			elif t == Tiles.LEAVES:
				leaves_count += 1
			elif t == Tiles.LEAVES_PINE:
				pine_count += 1
			elif t == Tiles.LEAVES_AUTUMN:
				autumn_count += 1
	assert_gt(log_count, 10, "应有至少 10 个 LOG (树干)")
	assert_gt(leaves_count + pine_count + autumn_count, 10, "应有至少 10 个树叶 (任意品种)")
	assert_gt(pine_count, 0, "应至少长出 1 棵松树")
	assert_gt(autumn_count, 0, "应至少长出 1 棵秋树")
