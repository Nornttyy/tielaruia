extends GutTest
const WG = preload("res://scripts/world/world_generator.gd")
const Walls = preload("res://scripts/world/natural_walls.gd")

func _land(cx: int, top: int) -> Chunk:
	var c := WG.empty_chunk(cx, 40)
	for x in c.tiles.size():
		for y in range(top, 40):
			c.tiles[x][y] = Tiles.DIRT
			c.walls[x][y] = Tiles.DIRT_WALL if y < 30 else Tiles.AIR
	return c

func test_surface_and_cliff_have_a_one_tile_wall_inset():
	var c := _land(0, 10)
	for x in range(20, 40):
		for y in range(10, 17): c.tiles[x][y] = Tiles.AIR
	# 墙初填后再挖出的峡口，不可保留悬空的墙矩形。
	Walls.inset(c)
	assert_eq(c.walls[10][10], Tiles.AIR)
	assert_eq(c.walls[10][11], Tiles.DIRT_WALL)
	assert_eq(c.walls[20][14], Tiles.AIR)
	assert_eq(c.walls[19][14], Tiles.AIR, "崖边最外一列不能露土墙")
	assert_eq(c.walls[18][14], Tiles.DIRT_WALL)
	assert_eq(c.walls[20][17], Tiles.AIR)
	assert_eq(c.walls[20][18], Tiles.DIRT_WALL)

func test_closed_caves_building_walls_and_saved_player_walls_survive():
	var c := _land(0, 10)
	c.tiles[12][15] = Tiles.AIR
	c.walls[15][10] = Tiles.WOOD_WALL
	Walls.inset(c)
	assert_eq(c.walls[12][15], Tiles.DIRT_WALL, "不是把所有空洞背后的墙删掉")
	assert_eq(c.walls[15][10], Tiles.WOOD_WALL)
	c.apply_wall_delta({Vector2i(10,10): Tiles.DIRT_WALL, Vector2i(11,10): Tiles.STONE_WALL})
	assert_eq(c.walls[10][10], Tiles.DIRT_WALL)
	assert_eq(c.walls[11][10], Tiles.STONE_WALL)

func test_shared_edges_match_an_interior_cliff_and_do_not_erode_again():
	var left := _land(-1, 10)
	var right := _land(0, 17)
	Walls.inset(left)
	Walls.inset(right)
	Walls.join(left, right, {}, {})
	assert_eq(left.walls[63][14], Tiles.AIR)
	assert_eq(left.walls[62][14], Tiles.DIRT_WALL)
	assert_eq(left.walls[63][18], Tiles.DIRT_WALL)
	var before: Array = left.walls.duplicate(true)
	Walls.join(left, right, {}, {})
	assert_eq(left.walls, before, "加载/卸载相邻区块不能继续剥墙")

func test_border_completion_preserves_explicit_saved_wall_edits():
	var left := _land(-1, 10)
	var right := _land(0, 17)
	Walls.inset(left)
	Walls.inset(right)
	var edits := {Vector2i(63,14): Tiles.DIRT_WALL}
	left.apply_wall_delta(edits)
	Walls.join(left, right, edits, {})
	assert_eq(left.walls[63][14], Tiles.DIRT_WALL)
	assert_eq(left.walls[63][15], Tiles.AIR)

func test_generated_surface_is_clear_in_forest_snow_evil_and_ocean():
	var seed_value := 21031
	var p := WG.classic_plan(seed_value, 256)
	for cx in [0, -1, Chunk.chunk_x_of(p.evil_x), Chunk.chunk_x_of(p.edge + 22)]:
		var c := WG.generate_chunk(seed_value, cx, 256)
		for x in range(1,63):
			for y in 256:
				if Tiles.is_solid(c.tiles[x][y]):
					assert_false(c.walls[x][y] in Walls.NATURAL, "天然地表不能残留墙：%d,%d" % [cx*64+x,y])
					break
