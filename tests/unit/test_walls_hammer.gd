# 背景墙铺满 (植物除外) + 锤子 验收.
extends GutTest

const WG = preload("res://scripts/world/world_generator.gd")


func test_is_plant_basic() -> void:
	assert_true(Tiles.is_plant(Tiles.PLANT_GRASS), "小草=植物")
	assert_true(Tiles.is_plant(Tiles.LEAVES), "树叶=植物")
	assert_true(Tiles.is_plant(Tiles.CACTUS), "仙人掌=植物")
	assert_true(Tiles.is_plant(Tiles.MUSHROOM), "蘑菇=植物")
	assert_false(Tiles.is_plant(Tiles.STONE), "石头≠植物")
	assert_false(Tiles.is_plant(Tiles.DIRT), "土≠植物")


func test_wall_drop_mapping() -> void:
	assert_eq(Tiles.wall_drop_item(Tiles.DIRT_WALL), "dirt_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.STONE_WALL), "stone_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.GRASS_WALL), "grass_wall")
	assert_eq(Tiles.wall_drop_item(Tiles.WOOD_WALL), "wood_wall")
	assert_true(Tiles.is_wall_tile(Tiles.DIRT_WALL))
	assert_false(Tiles.is_wall_tile(Tiles.STONE))


func test_surface_blocks_have_walls_sky_does_not() -> void:
	var c = WG.generate_chunk(4242, 0, 256)
	var surf_with_wall := 0
	var sky_with_wall := 0
	var plant_with_wall := 0
	var plant_seen := 0
	for lx in 64:
		var surf: int = c.surfaces[lx]
		if surf < 5 or surf > 250:
			continue
		# 地表块背后该有墙 (除非地表那格是植物)
		if not Tiles.is_plant(c.tiles[lx][surf]) and c.walls[lx][surf] != Tiles.AIR:
			surf_with_wall += 1
		# 天空 (surf 上方 3 格) 不该有墙
		if c.walls[lx][surf - 3] != Tiles.AIR:
			sky_with_wall += 1
		# 任何植物格背后不该有墙
		for y in range(surf, 256):
			if Tiles.is_plant(c.tiles[lx][y]):
				plant_seen += 1
				if c.walls[lx][y] != Tiles.AIR:
					plant_with_wall += 1
	gut.p("[墙] 地表有墙列=%d 天空有墙=%d 植物格=%d 植物背后有墙=%d" % [surf_with_wall, sky_with_wall, plant_seen, plant_with_wall])
	assert_gt(surf_with_wall, 40, "大部分地表块背后该有墙 (64 列)")
	assert_eq(sky_with_wall, 0, "天空不该有墙")
	assert_eq(plant_with_wall, 0, "植物格背后不该有墙")
