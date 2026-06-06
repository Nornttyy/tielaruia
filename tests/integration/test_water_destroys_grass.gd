# 水冲毁草须: 水横向流进 / 落到草须上 → 草被水覆盖销毁 (用户要"草碰到水会被破坏").
# 用隔离假世界 (不启动整个游戏), 只喂 water_sim 需要的 get_tile + _set_water_tile_fast.
extends GutTest


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


func _t(fw, x, y) -> int:
	return fw.tiles.get(Vector2i(x, y), Tiles.AIR)


# 横向: 水左边堵死, 右边是草须 → 水只能往草那格流 → 草被冲毁变水.
func test_water_flows_sideways_into_grass_destroys_it() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER          # 满水
	fw.tiles[Vector2i(0, 1)] = Tiles.STONE          # 下方堵 → 逼横向
	fw.tiles[Vector2i(-1, 0)] = Tiles.STONE         # 左边堵 → 只能往右
	fw.tiles[Vector2i(1, 0)] = Tiles.PLANT_GRASS    # 右边是草须
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(2, 0)] = Tiles.STONE          # 再右也堵死 → 水留在草那格不流走
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 8:
		sim._run_tick()
	assert_ne(_t(fw, 1, 0), Tiles.PLANT_GRASS, "草须该被冲毁 (不再是草)")
	assert_true(Tiles.is_water(_t(fw, 1, 0)), "草那格该变成水")


# 下落: 水正下方是草须 → 水落下来盖掉草.
func test_water_falls_onto_grass_destroys_it() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 1)] = Tiles.PLANT_GRASS    # 水正下方是草须
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE         # 两侧封住, 只直落
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_ne(_t(fw, 0, 1), Tiles.PLANT_GRASS, "草须该被落水冲毁")
	assert_true(Tiles.is_water(_t(fw, 0, 1)), "草那格该变成水")


# 反例: 岩浆落到草须上不冲毁 (本次只做水, 岩浆维持原样, 守住范围别误扩).
func test_lava_does_not_destroy_grass() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.LAVA
	fw.tiles[Vector2i(0, 1)] = Tiles.PLANT_GRASS
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 8:
		sim._run_tick()
	assert_eq(_t(fw, 0, 1), Tiles.PLANT_GRASS, "岩浆不该冲毁草 (本次范围只水)")
