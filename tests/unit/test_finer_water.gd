# 细水位 (8 档) 验收: tile/贴图存在 + 档位换算 (水8/岩浆4) + 找平 + 岩浆仍4档.
extends GutTest

const WaterSim = preload("res://scripts/world/water_sim.gd")


class FakeWorld:
	extends Node2D
	var tiles := {}
	var chunk_manager = null
	func _init():
		chunk_manager = FakeCM.new(tiles)
	func _set_water_tile_fast(x, y, tid):
		tiles[Vector2i(x, y)] = tid
class FakeCM:
	var tiles
	func _init(t): tiles = t
	func get_tile(x, y):
		return tiles.get(Vector2i(x, y), Tiles.AIR)


func _make_sim(fw) -> Node:
	var sim = WaterSim.new()
	sim.world = fw
	add_child_autofree(sim)
	return sim


func test_finer_water_tiles_exist() -> void:
	assert_eq(Tiles.WATER_L4, 88)
	assert_eq(Tiles.WATER_L7, 91)
	for t in [Tiles.WATER_L4, Tiles.WATER_L5, Tiles.WATER_L6, Tiles.WATER_L7]:
		assert_true(Tiles.is_water(t), "L4-7 该算水")
		assert_false(Tiles.is_solid(t), "L4-7 非实心")
		assert_not_null(ArtCache.block_textures.get(t), "L4-7 该有世界贴图")


func test_level_math_water8_lava4() -> void:
	var sim = _make_sim(FakeWorld.new())
	# 水 8 档
	assert_eq(sim._level_of(Tiles.WATER), 8, "满水=8")
	assert_eq(sim._level_of(Tiles.WATER_L5), 5)
	assert_eq(sim._level_of(Tiles.WATER_L1), 1)
	assert_eq(sim._tile_for_level("water", 8), Tiles.WATER)
	assert_eq(sim._tile_for_level("water", 6), Tiles.WATER_L6)
	# 岩浆仍 4 档
	assert_eq(sim._level_of(Tiles.LAVA), 4, "满岩浆=4")
	assert_eq(sim._tile_for_level("lava", 4), Tiles.LAVA)
	assert_eq(sim._max_level("water"), 8)
	assert_eq(sim._max_level("lava"), 4)


func test_water_levels_out_flat() -> void:
	# 平底容器 (x 0..7 底, 两端墙), 倒 16 单位水 (2 满柱) → 整片找平后该摊成 8 列各 L2 的纯平面.
	var fw = FakeWorld.new()
	for x in range(0, 8):
		fw.tiles[Vector2i(x, 1)] = Tiles.STONE   # 底
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE
	fw.tiles[Vector2i(8, 0)] = Tiles.STONE
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER       # 8
	fw.tiles[Vector2i(1, 0)] = Tiles.WATER       # 8 → 共 16 单位
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	sim.notify_tile_changed(1, 0)
	for i in 120:
		sim._run_tick()
	var levels: Array = []
	for x in range(0, 8):
		levels.append(sim._level_of(fw.tiles.get(Vector2i(x, 0), Tiles.AIR)))
	gut.p("[找平] 8 列水位=%s (16/8=2 该全平)" % str(levels))
	for x in range(0, 8):
		assert_eq(int(levels[x]), 2, "第%d列该=2 (整片找平: 16单位÷8格)" % x)


func test_level_body_flattens_ramp_no_float() -> void:
	# 一道斜坡水 (5,4,3,2,1) 全在 y=0 靠墙容器里 → 找平后水面平 + 总量守恒 + 没有悬空水.
	var fw = FakeWorld.new()
	for x in range(0, 5):
		fw.tiles[Vector2i(x, 1)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE
	fw.tiles[Vector2i(5, 0)] = Tiles.STONE
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_L5
	fw.tiles[Vector2i(1, 0)] = Tiles.WATER_L4
	fw.tiles[Vector2i(2, 0)] = Tiles.WATER_L3
	fw.tiles[Vector2i(3, 0)] = Tiles.WATER_L2
	fw.tiles[Vector2i(4, 0)] = Tiles.WATER_L1
	var sim = _make_sim(fw)
	var before := 0
	for x in range(0, 5):
		before += sim._level_of(fw.tiles[Vector2i(x, 0)])
	sim._level_body(fw.chunk_manager, 0, 0, {})
	var after := 0
	var hi := 0
	var lo := 99
	for x in range(0, 5):
		var lv: int = sim._level_of(fw.tiles.get(Vector2i(x, 0), Tiles.AIR))
		after += lv
		hi = maxi(hi, lv)
		lo = mini(lo, lv)
	gut.p("[找平body] before=%d after=%d hi=%d lo=%d" % [before, after, hi, lo])
	assert_eq(after, before, "找平守恒 (总水量不变)")
	assert_lte(hi - lo, 1, "找平后水面差 ≤ 1")
	# 没有悬空水: 每个水格下面是水或实心 (不是空气)
	for x in range(0, 5):
		if Tiles.is_water(fw.tiles.get(Vector2i(x, 0), Tiles.AIR)):
			var below: int = fw.tiles.get(Vector2i(x, 1), Tiles.AIR)
			assert_ne(below, Tiles.AIR, "第%d列水下面不该是空气 (不悬空)" % x)


func test_level_body_idempotent() -> void:
	# 已经平的水池 → 再找平一次不该改任何格 (幂等, 不无限抖).
	var fw = FakeWorld.new()
	for x in range(0, 4):
		fw.tiles[Vector2i(x, 1)] = Tiles.STONE
		fw.tiles[Vector2i(x, 0)] = Tiles.WATER_L2
	var sim = _make_sim(fw)
	var changed: bool = sim._level_body(fw.chunk_manager, 0, 0, {})
	assert_false(changed, "已平水池找平应无改动 (幂等)")


func test_level_body_preserves_biome_color() -> void:
	# 沙漠水池有斜坡 → 找平后满格该仍是沙漠水 (不变蓝).
	var fw = FakeWorld.new()
	for x in range(0, 3):
		fw.tiles[Vector2i(x, 1)] = Tiles.STONE
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_DESERT   # 满=8 沙漠色
	fw.tiles[Vector2i(1, 0)] = Tiles.WATER_DESERT   # 8
	fw.tiles[Vector2i(2, 0)] = Tiles.WATER_L2       # 2 → 共 18, 3 格 → 6 each
	var sim = _make_sim(fw)
	sim._level_body(fw.chunk_manager, 0, 0, {})
	# 18/3=6, 没有满格 (6<8) → 这里都是 L6 普通水, 改个能产满格的例子
	# 重来: 给足水量产生满格
	var fw2 = FakeWorld.new()
	for x in range(0, 2):
		fw2.tiles[Vector2i(x, 1)] = Tiles.STONE
	fw2.tiles[Vector2i(0, 0)] = Tiles.WATER_DESERT  # 8
	fw2.tiles[Vector2i(1, 0)] = Tiles.WATER_DESERT  # 8 → 16, 2格 → 各满 8
	var sim2 = _make_sim(fw2)
	sim2._level_body(fw2.chunk_manager, 0, 0, {})
	assert_eq(fw2.tiles.get(Vector2i(0, 0)), Tiles.WATER_DESERT, "满格该保留沙漠水色")
	assert_eq(fw2.tiles.get(Vector2i(1, 0)), Tiles.WATER_DESERT, "满格该保留沙漠水色")
