extends GutTest
const Prefab = preload("res://scripts/world/village_prefab.gd")
const Placer = preload("res://scripts/world/village_placer.gd")
const CM = preload("res://scripts/world/chunk_manager.gd")

func test_background_rows_match_foreground_and_doors_have_clearance():
	for house in Prefab.load_default().houses:
		assert_eq(house.walls.size(), house.grid.size())
		for y in house.grid.size():
			assert_eq(String(house.grid[y]).length(), String(house.walls[y]).length())
			for x in String(house.grid[y]).length():
				if String(house.grid[y])[x] == "D":
					assert_gte(y, 2)
					assert_eq(String(house.grid[y - 1])[x], ".")
					assert_eq(String(house.grid[y - 2])[x], ".")

func test_stamp_writes_background_and_keeps_space_between_houses():
	var cm = CM.new()
	add_child_autofree(cm)
	cm.setup(42)
	cm.ensure_loaded(0)
	var anchor := Vector2i(10, 60)
	var outside := anchor + Vector2i(29, -5)
	cm.set_tile(outside.x, outside.y, Tiles.LOG)
	Placer.place(cm, null, Prefab.load_default(), anchor)
	assert_eq(cm.get_tile(outside.x, outside.y), Tiles.LOG, "建筑之间不能整片清空")
	assert_eq(cm.get_wall(anchor.x + 9, anchor.y - 6), Tiles.GLASS_WALL)
	assert_eq(cm.get_tile(anchor.x + 5, anchor.y - 1), Tiles.DOOR)
	assert_eq(cm.get_tile(anchor.x + 5, anchor.y - 3), Tiles.DOOR_TOP)
