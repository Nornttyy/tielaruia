extends GutTest
const Generator = preload("res://scripts/world/world_generator.gd")
const Frames = preload("res://scripts/world/tree_frames.gd")
const World = preload("res://scripts/world/world.gd")
class TreeMap extends RefCounted:
	var ground := Tiles.SNOW
	func get_tile(x: int, y: int) -> int:
		if x != 0: return Tiles.AIR
		return Tiles.LOG if y < 20 else ground
func test_tree_frames_take_style_from_ground_for_trunk_and_crown():
	var map := TreeMap.new()
	for pair in [[Tiles.SNOW, 1], [Tiles.JUNGLE_GRASS, 2], [Tiles.CORRUPT_GRASS, 3], [Tiles.CRIMSON_GRASS, 4]]:
		map.ground = pair[0]
		assert_eq(Frames.frame(Vector2i(0, 10), Tiles.LOG_TOP, map).y, pair[1])
		assert_eq(Frames.frame(Vector2i(0, 11), Tiles.LOG, map).y, pair[1] * 8)
func test_chasm_removes_unsupported_tree_but_keeps_rooted_tree():
	var chunk := Chunk.new(0)
	chunk.init_empty()
	for x in [10, 20]:
		chunk.tiles[x][10] = Tiles.LOG_TOP
		for y in range(11, 20): chunk.tiles[x][y] = Tiles.LOG
		chunk.tiles[x - 1][14] = Tiles.BRANCH_L
	chunk.tiles[20][20] = Tiles.GRASS
	Generator._trim_unsupported_trees(chunk)
	assert_eq(chunk.tiles[10][10], Tiles.AIR)
	assert_eq(chunk.tiles[9][14], Tiles.AIR)
	assert_eq(chunk.tiles[20][10], Tiles.LOG_TOP)
	assert_eq(chunk.tiles[19][14], Tiles.BRANCH_L)
func test_spiders_are_disabled_in_legacy_spawns_and_multiplayer():
	var world := World.new()
	# 不进入树；若旧生成入口仍实例化怪物，本测试会因 entities_root 为空报错。
	world.spawn_mineshaft_spiders_for_chunk(0, [Vector2i(10, 120)])
	assert_null(world._spawn_remote_entity("spider"))
	world.free()
