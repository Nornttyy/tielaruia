# 水碰小草总闸: 小草碰水直接被破坏 (不记录、不复原); 走 world._set_water_tile_fast 真路径。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_water_destroys_grass_not_restored() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	# 在一个已加载的地下格放一株小草 (出生点 0 号区块已加载)
	var x: int = 3
	var y: int = 120
	cm.set_tile(x, y, Tiles.PLANT_GRASS)
	# 进水: 草被冲掉 (不记录, 因为没有植物可淹)
	world._set_water_tile_fast(x, y, Tiles.WATER)
	assert_eq(cm.get_tile(x, y), Tiles.WATER, "水盖上小草那格 = 水")
	assert_eq(cm.get_submerged(x, y), -1, "小草不记录 (被破坏, 不是泡水)")
	# 退水: 还是空气 —— 草已被破坏, 不复原
	world._set_water_tile_fast(x, y, Tiles.AIR)
	assert_eq(cm.get_tile(x, y), Tiles.AIR, "退水后是空气 (小草已被破坏, 不复原)")


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
