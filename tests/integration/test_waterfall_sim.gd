# 水源块发射: 往下灌水、自己不变少、挖掉就停. (用 FakeWorld 套路, 仿 test_liquid_flow.gd)
extends GutTest

class FakeWorld:
	extends Node2D
	var tiles := {}
	var chunk_manager = null
	func _init(): chunk_manager = FakeCM.new(tiles)
	func _set_water_tile_fast(x, y, tid): tiles[Vector2i(x, y)] = tid
class FakeCM:
	var tiles
	func _init(t): tiles = t
	func get_tile(x, y): return tiles.get(Vector2i(x, y), Tiles.AIR)


func _make_sim(fake) -> Node:
	var WaterSim = load("res://scripts/world/water_sim.gd")
	var sim = WaterSim.new()
	sim.world = fake
	add_child_autofree(sim)
	return sim


func _t(fw, x, y) -> int:
	return fw.tiles.get(Vector2i(x, y), Tiles.AIR)


func test_source_emits_water_below():
	# 水源在 (0,0), 下方 (0,1) AIR, 再下 (0,2) STONE 接住
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_SOURCE
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_true(sim.is_liquid(_t(fw, 0, 1)), "水源下方该冒出水, 实际 tid=%d" % _t(fw, 0, 1))


func test_source_not_depleted():
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER_SOURCE
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_eq(_t(fw, 0, 0), Tiles.WATER_SOURCE, "水源自己永不变少")


func test_dug_source_stops():
	# 挖掉水源 (→AIR) 后, 不再冒水
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0, 0)] = Tiles.AIR
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_false(sim.is_liquid(_t(fw, 0, 1)), "没水源 → 下方不该有水")
