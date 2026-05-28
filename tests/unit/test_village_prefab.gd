extends GutTest

const VillagePrefab = preload("res://scripts/world/village_prefab.gd")


func test_load_default_has_houses():
	var prefab = VillagePrefab.load_default()
	assert_true(prefab.has("houses"))
	# 用户扩展村庄到 5 间不同房子 (起步小屋/工坊/铁匠铺/二层楼/石屋)
	assert_gte(prefab.houses.size(), 2, "至少 2 间")


func test_each_house_valid():
	var prefab = VillagePrefab.load_default()
	for house in prefab.houses:
		assert_gt(house.grid.size(), 0, "至少 1 行")
		var w: int = (house.grid[0] as String).length()
		assert_gt(w, 0, "至少 1 列")
		for row in house.grid:
			assert_eq(row.length(), w, "同 prefab 每行同宽")


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


func test_at_least_one_house_no_villager():
	# 部分房子无村民 (M2 预留 / 装饰房). 检查至少 1 间
	var prefab = VillagePrefab.load_default()
	var any_empty: bool = false
	for h in prefab.houses:
		if h.villager_offset == null:
			any_empty = true
			break
	assert_true(any_empty, "至少 1 间无 villager (装饰/预留)")


func test_char_to_tile_P_is_planks():
	assert_eq(VillagePrefab.char_to_tile("P"), Tiles.PLANKS)


func test_char_to_tile_D_is_door():
	assert_eq(VillagePrefab.char_to_tile("D"), Tiles.DOOR)


func test_char_to_tile_dot_is_skip():
	assert_eq(VillagePrefab.char_to_tile("."), -1, ". 表示跳过")
