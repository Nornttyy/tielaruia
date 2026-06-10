# 起床战争地图: 每座岛有平台 + 床; 返回出生点/铁点/商店点。
extends GutTest

const BedwarsArena = preload("res://scripts/world/bedwars_arena.gd")


func test_arena_builds_islands_with_beds() -> void:
	var main = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var cm = world.chunk_manager
	var bw: Dictionary = BedwarsArena.build(world)
	await wait_frames(1)
	# 返回了每座岛的出生点 + 铁点 + 商店点
	assert_eq(bw["spawns"].size(), BedwarsArena.N_ISLANDS, "每座岛一个出生点")
	assert_eq(bw["iron_points"].size(), BedwarsArena.N_ISLANDS, "每座岛一个铁点")
	assert_true(bw.has("gold_point"), "有中央金点")
	# 第一座岛: 平台是石头 + 有床
	var p0: Vector2 = bw["spawns"][0]
	var ix: int = int(floor(p0.x / BedwarsArena.TILE_SIZE))
	assert_eq(cm.get_tile(ix, BedwarsArena.FLOOR_Y), Tiles.STONE, "岛面是石头")
	# 床头/床尾在平台上 (出生点列附近找 BED)
	var found_bed := false
	for dx in range(-1, 3):
		if cm.get_tile(ix + dx, BedwarsArena.FLOOR_Y - 1) == Tiles.BED:
			found_bed = true
	assert_true(found_bed, "岛上有床 (BED)")
