# 流体流动验收: 岩浆流动 + 水/岩浆=石头
extends GutTest


func test_lava_level_tiles_defined() -> void:
	assert_eq(Tiles.LAVA_L1, 71, "LAVA_L1 = 71")
	assert_eq(Tiles.LAVA_L2, 72, "LAVA_L2 = 72")
	assert_eq(Tiles.LAVA_L3, 73, "LAVA_L3 = 73")
	assert_false(Tiles.is_solid(Tiles.LAVA_L1), "LAVA_L1 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L2), "LAVA_L2 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L3), "LAVA_L3 非实心")


func test_lava_level_textures_built() -> void:
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L1), "LAVA_L1 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L2), "LAVA_L2 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L3), "LAVA_L3 该有世界贴图")


# 假世界: 不启动整个游戏, 只提供 chunk_manager.get_tile + _set_water_tile_fast
# 注意: water_sim 的 world 是 @export var world: Node2D, 所以假世界必须是 Node2D
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

func _make_sim(fake) -> Node:
	var WaterSim = load("res://scripts/world/water_sim.gd")
	var sim = WaterSim.new()
	sim.world = fake
	add_child_autofree(sim)
	return sim

func _lk(fw, x, y) -> String:
	var t = fw.tiles.get(Vector2i(x,y), Tiles.AIR)
	if t == Tiles.LAVA or t == Tiles.LAVA_L1 or t == Tiles.LAVA_L2 or t == Tiles.LAVA_L3:
		return "lava"
	if t == Tiles.WATER or t == Tiles.WATER_L1 or t == Tiles.WATER_L2 or t == Tiles.WATER_L3:
		return "water"
	return ""

func test_lava_falls_down() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	# 用石墙把竖井两侧封住, 岩浆只能直落不会横向摊开 (验证纯重力下落)
	fw.tiles[Vector2i(-1,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0,1), Tiles.AIR), Tiles.LAVA, "岩浆该落到石头上方")
	assert_eq(fw.tiles.get(Vector2i(0,0), Tiles.AIR), Tiles.AIR, "原位该空")

func test_lava_spreads_sideways() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,1)] = Tiles.STONE
	fw.tiles[Vector2i(-1,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 10:
		sim._run_tick()
	assert_true(_lk(fw,-1,0) == "lava" or _lk(fw,1,0) == "lava", "岩浆该横向摊开")
