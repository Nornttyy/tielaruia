extends GutTest

const ChunkClass = preload("res://scripts/world/chunk.gd")


func test_init_empty_fills_air():
	var c = ChunkClass.new(0)
	c.init_empty()
	assert_eq(c.tiles.size(), 64)
	assert_eq(c.tiles[0].size(), 256)
	assert_eq(c.get_tile(0, 0), Tiles.AIR)
	assert_eq(c.get_tile(63, 255), Tiles.AIR)


func test_set_get_tile():
	var c = ChunkClass.new(5)
	c.init_empty()
	c.set_tile(10, 100, Tiles.STONE)
	assert_eq(c.get_tile(10, 100), Tiles.STONE)
	assert_eq(c.chunk_x, 5)


func test_get_tile_out_of_bounds_returns_air():
	var c = ChunkClass.new(0)
	c.init_empty()
	assert_eq(c.get_tile(-1, 0), Tiles.AIR)
	assert_eq(c.get_tile(64, 0), Tiles.AIR)
	assert_eq(c.get_tile(0, -1), Tiles.AIR)
	assert_eq(c.get_tile(0, 256), Tiles.AIR)


func test_apply_delta():
	var c = ChunkClass.new(0)
	c.init_empty()
	c.apply_delta({
		Vector2i(5, 100): Tiles.STONE,
		Vector2i(7, 50): Tiles.LOG,
	})
	assert_eq(c.get_tile(5, 100), Tiles.STONE)
	assert_eq(c.get_tile(7, 50), Tiles.LOG)


func test_chunk_x_of_world_x():
	assert_eq(ChunkClass.chunk_x_of(0), 0)
	assert_eq(ChunkClass.chunk_x_of(63), 0)
	assert_eq(ChunkClass.chunk_x_of(64), 1)
	assert_eq(ChunkClass.chunk_x_of(-1), -1)
	assert_eq(ChunkClass.chunk_x_of(-64), -1)
	assert_eq(ChunkClass.chunk_x_of(-65), -2)


func test_local_x_of_world_x():
	assert_eq(ChunkClass.local_x_of(0), 0)
	assert_eq(ChunkClass.local_x_of(63), 63)
	assert_eq(ChunkClass.local_x_of(64), 0)
	assert_eq(ChunkClass.local_x_of(-1), 63)
	assert_eq(ChunkClass.local_x_of(-64), 0)
