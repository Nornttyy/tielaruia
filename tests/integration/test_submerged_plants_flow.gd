# 水下植物总闸: 进水记植物、退水复原 (走 world._set_water_tile_fast 真路径)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_water_submerges_then_restores_plant() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	# 在一个已加载的地下格放一株草 (出生点 0 号区块已加载)
	var x: int = 3
	var y: int = 120
	cm.set_tile(x, y, Tiles.PLANT_GRASS)
	# 进水: 该格变水, 草被记进 _submerged
	world._set_water_tile_fast(x, y, Tiles.WATER)
	assert_eq(cm.get_tile(x, y), Tiles.WATER, "进水后该格显示水")
	assert_eq(cm.get_submerged(x, y), Tiles.PLANT_GRASS, "草被记进水下植物层")
	# 退水: 写空气 → 应复原成草, 记录清掉
	world._set_water_tile_fast(x, y, Tiles.AIR)
	assert_eq(cm.get_tile(x, y), Tiles.PLANT_GRASS, "退水后草复原 (不是空气)")
	assert_eq(cm.get_submerged(x, y), -1, "复原后水下植物记录清掉")


func test_water_over_air_no_phantom_plant() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	var x: int = 4
	var y: int = 121
	cm.set_tile(x, y, Tiles.AIR)
	world._set_water_tile_fast(x, y, Tiles.WATER)
	assert_eq(cm.get_submerged(x, y), -1, "空气进水不该记植物")
	world._set_water_tile_fast(x, y, Tiles.AIR)
	assert_eq(cm.get_tile(x, y), Tiles.AIR, "退水还是空气")
