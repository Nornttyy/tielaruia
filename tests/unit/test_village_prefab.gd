extends GutTest

const VillagePrefab = preload("res://scripts/world/village_prefab.gd")


func test_load_default_has_2_houses():
	var prefab = VillagePrefab.load_default()
	assert_true(prefab.has("houses"))
	assert_eq(prefab.houses.size(), 2, "spec 要求 2 间小屋")


func test_each_house_5x4():
	var prefab = VillagePrefab.load_default()
	for house in prefab.houses:
		assert_eq(house.grid.size(), 4, "高 4 行")
		for row in house.grid:
			assert_eq(row.length(), 5, "宽 5 列")


func test_house_has_door():
	var prefab = VillagePrefab.load_default()
	for house in prefab.houses:
		var found_door := false
		for row in house.grid:
			if row.contains("D"):
				found_door = true
				break
		assert_true(found_door, "每间屋应有门")


func test_first_house_has_villager_offset():
	var prefab = VillagePrefab.load_default()
	var h0 = prefab.houses[0]
	assert_ne(h0.villager_offset, null, "房 1 应有 villager_offset")
	assert_eq(h0.villager_offset.size(), 2, "offset 是 [col, row]")


func test_second_house_no_villager():
	var prefab = VillagePrefab.load_default()
	var h1 = prefab.houses[1]
	assert_eq(h1.villager_offset, null, "房 2 无 villager (M2 预留)")


func test_char_to_tile_P_is_planks():
	assert_eq(VillagePrefab.char_to_tile("P"), Tiles.PLANKS)


func test_char_to_tile_D_is_door():
	assert_eq(VillagePrefab.char_to_tile("D"), Tiles.DOOR)


func test_char_to_tile_dot_is_skip():
	assert_eq(VillagePrefab.char_to_tile("."), -1, ". 表示跳过")
