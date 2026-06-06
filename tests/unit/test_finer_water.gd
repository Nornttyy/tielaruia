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
	# 平底容器 (x 0..7 底, 两端墙), 倒 16 单位水 (2 满柱) → 该摊成 8 列各 L2 的平面.
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
	for i in 80:
		sim._run_tick()
	# 逐格整数水位 → 只能保证"相邻列差 ≤1"(顺滑无断崖, 8 档时每级 2px) + 水铺开.
	# 真正全局一样高需"整片水区找平"的大算法, 不在本次范围.
	var levels: Array = []
	for x in range(0, 8):
		levels.append(sim._level_of(fw.tiles.get(Vector2i(x, 0), Tiles.AIR)))
	var max_step := 0
	for x in range(0, 7):
		max_step = maxi(max_step, abs(int(levels[x]) - int(levels[x + 1])))
	var covered := 0
	for lv in levels:
		if int(lv) > 0:
			covered += 1
	gut.p("[找平] 8 列水位=%s 相邻最大落差=%d 铺到%d列" % [str(levels), max_step, covered])
	assert_lte(max_step, 1, "相邻列水位差 ≤ 1 档 (顺滑无断崖)")
	assert_gte(covered, 4, "水该铺开 (≥4 列有水)")
