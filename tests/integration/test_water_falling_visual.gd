# 下落水视觉: 瀑布下落时, sim 应持续标记竖井里被流过的空格 → 画面层连成连续水帘.
# (修"瀑布一段段往下掉、看不到连续水流".)
extends GutTest

const WaterSim = preload("res://scripts/world/water_sim.gd")
const MainScene = preload("res://scenes/main.tscn")

class FakeCM:
	var grid := {}
	var solid := {}
	func get_tile(x: int, y: int) -> int:
		var k := Vector2i(x, y)
		if solid.has(k):
			return Tiles.STONE
		return grid.get(k, Tiles.AIR)

class FakeWorld:
	extends Node2D
	var chunk_manager
	var falls := {}        # cell -> 被标记次数 (note_falling_water 累计)
	func _set_water_tile_fast(x: int, y: int, t: int) -> void:
		var k := Vector2i(x, y)
		if t == Tiles.AIR:
			chunk_manager.grid.erase(k)
		else:
			chunk_manager.grid[k] = t
	func _set_tile(x: int, y: int, t: int, _a = false, _b = false) -> void:
		_set_water_tile_fast(x, y, t)
	func note_falling_water(x: int, y: int, _tid: int) -> void:
		var k := Vector2i(x, y)
		falls[k] = falls.get(k, 0) + 1

var _world: FakeWorld
var _cm: FakeCM
var _sim

func before_each() -> void:
	_cm = FakeCM.new()
	_world = FakeWorld.new()
	_world.chunk_manager = _cm
	add_child_autofree(_world)
	_sim = WaterSim.new()
	_sim.world = _world
	add_child_autofree(_sim)
	_sim.set_process(false)

func test_waterfall_marks_continuous_shaft() -> void:
	# 高台水池 (x=1..3) 溢出右沿, 沿 x=4 竖井往下掉到底.
	var W := 8
	var H := 12
	for x in range(0, W):
		_cm.solid[Vector2i(x, 11)] = true
	for y in range(0, 12):
		_cm.solid[Vector2i(0, y)] = true
	for x in range(1, 4):
		for y in range(6, 11):
			_cm.solid[Vector2i(x, y)] = true
	# 持续补水: 模拟有源头, 不然池子一下漏光看不出连续
	for f in range(60):
		# 每帧给高台顶补满 (模拟水源)
		for x in range(1, 4):
			if _cm.get_tile(x, 2) == Tiles.AIR:
				_cm.grid[Vector2i(x, 2)] = Tiles.WATER
				_sim.mark_dirty(x, 2)
		_sim._run_tick()
	# 竖井 x=4 的 y=6..9 (落差段) 应都被标记过 → 能连成水帘
	var shaft_rows_marked := 0
	for y in range(6, 10):
		if _world.falls.get(Vector2i(4, y), 0) > 0:
			shaft_rows_marked += 1
	gut.p("[下落] 竖井 x=4 被标记的行: %d/4; 各行次数 %s" % [
		shaft_rows_marked,
		str([_world.falls.get(Vector2i(4,6),0), _world.falls.get(Vector2i(4,7),0),
			_world.falls.get(Vector2i(4,8),0), _world.falls.get(Vector2i(4,9),0)])])
	assert_gte(shaft_rows_marked, 3, "竖井大部分行都该被标记过 (连续水帘, 不是一段段)")
	# 且被反复标记 (持续水流 → 视觉不会过期断流)
	var total_marks := 0
	for y in range(6, 10):
		total_marks += _world.falls.get(Vector2i(4, y), 0)
	assert_gt(total_marks, 6, "竖井被反复标记 (水流持续, 视觉残留连成线)")


# 真游戏端到端: world.note_falling_water 真把视觉 tile 画到 FallingWaterLayer, 超时清掉.
func test_world_renders_and_expires_falling() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(3)
	var world = main.get_node("World")
	var player = world.get_player()
	var ptx: int = int(floor(player.global_position.x / 12.0))
	var pty: int = int(floor(player.global_position.y / 12.0))
	var cell := Vector2i(ptx, pty - 30)   # 头顶上方 30 格 = 天空, 肯定空气
	var fl: TileMapLayer = world.get_node("FallingWaterLayer")
	assert_not_null(fl, "应有 FallingWaterLayer")
	world.note_falling_water(cell.x, cell.y, Tiles.WATER)
	assert_ne(fl.get_cell_source_id(cell), -1, "下落水视觉应画上一个水 tile")
	# 等过期 (>0.3s) → 自动清掉
	await wait_frames(45)
	assert_eq(fl.get_cell_source_id(cell), -1, "超时没再被流过 → 视觉淡出清掉")
