extends GutTest
const Generator = preload("res://scripts/world/world_generator.gd")
const Features = preload("res://scripts/world/classic_world_features.gd")
const Materials = preload("res://scripts/world/classic_materials.gd")
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
var previous_size: int

func before_each():
	previous_size = GameSettings.current_world_size
	GameSettings.current_world_size = 0
	Generator.clear_structure_caches()

func after_each():
	GameSettings.current_world_size = previous_size
	Generator.clear_structure_caches()

func _generated_at(pos: Vector2i, world_seed: int = 42) -> Chunk:
	return Generator.generate_chunk(world_seed, Chunk.chunk_x_of(pos.x))

func _tile(c: Chunk, pos: Vector2i) -> int:
	return c.get_tile(Chunk.local_x_of(pos.x), pos.y)

func test_world_selects_only_one_evil_and_preserves_forest_spawn():
	for seed_value in [42, 43, 9876]:
		var centers := Generator._build_biome_centers(seed_value)
		assert_true(centers.has(5) != centers.has(6))
		assert_false(centers.has(4), "不再生成非原版沼泽槽位")
		for x in range(-30, 31): assert_eq(Generator._biome_at(x, seed_value), Generator.BIOME_FOREST)
		var p := Generator.classic_plan(seed_value)
		assert_gte(absi(p.living_tree.x), 100)
		assert_eq(p, Generator.classic_plan(seed_value), "选址必须跟加载顺序无关")
		for cabin in p.cabins: assert_gte(absi(cabin.x - p.mushroom.x), 85, "小屋与蘑菇洞不能重叠")

func test_new_materials_have_collision_walls_icons_and_drops():
	var ts := preload("res://scripts/world/tileset_builder.gd").build()
	for name in Materials.ITEMS:
		var tid: int = Materials.ITEMS[name]
		assert_true(ItemDB.is_available(name), name)
		assert_not_null(ArtCache.get_inventory_icon(name), name)
		assert_true(Materials.NAMES.has(name))
		assert_true(ts.has_source(tid), name)
		if tid < 148:
			assert_true(Tiles.is_solid(tid))
			assert_eq(ts.get_source(tid).get_tile_data(Vector2i.ZERO, 0).get_collision_polygons_count(0), 1)
		else:
			assert_true(Tiles.is_wall_tile(tid))
			assert_false(Tiles.is_solid(tid))
	for tid in range(131, 143): assert_true(Pack.TERRAIN.has(tid))

func test_tree_has_walkthrough_doors_and_underground_treasure():
	var p := Generator.classic_plan(42)
	var a: Vector2i = p.living_tree
	var chest := a + Vector2i(20, 33)
	var c := _generated_at(chest)
	assert_eq(_tile(c, chest), Tiles.CHEST)
	assert_eq(_tile(c, chest + Vector2i.DOWN), Tiles.LIVING_WOOD)
	assert_has(c.treasure_spots, chest)
	c = _generated_at(a)
	assert_eq(_tile(c, a + Vector2i(0, 12)), Tiles.ROPE)
	assert_eq(_tile(c, a + Vector2i(-4, -1)), Tiles.DOOR)
	assert_eq(_tile(c, a + Vector2i(4, -3)), Tiles.DOOR_TOP)

func test_structures_have_supported_treasure_and_correct_wall_materials():
	var p := Generator.classic_plan(42)
	var cases := [
		[p.pyramid + Vector2i(-4, 25), Tiles.SANDSTONE_BRICK, Tiles.SANDSTONE_WALL],
		[p.cabins[0] + Vector2i(5, -1), Tiles.PLANKS, Tiles.WOOD_WALL],
		[p.dungeon + Vector2i(36, p.dungeon_depth + 12), Tiles.DUNGEON_BRICK, Tiles.DUNGEON_WALL],
		[p.sky[0] + Vector2i(4, -1), Tiles.SUNPLATE, Tiles.SUNPLATE_WALL],
	]
	for entry in cases:
		var pos: Vector2i = entry[0]
		var c := _generated_at(pos)
		assert_eq(_tile(c, pos), Tiles.GOLD_CHEST, str(pos))
		assert_eq(_tile(c, pos + Vector2i.DOWN), entry[1], "宝箱不能悬空")
		assert_eq(c.get_wall(Chunk.local_x_of(pos.x), pos.y), entry[2])
		assert_has(c.treasure_spots, pos)

func test_cross_chunk_blueprint_stamps_match_and_player_deltas_win():
	var p := Generator.classic_plan(42)
	var a: Vector2i = p.pyramid
	var left := Chunk.chunk_x_of(a.x - 36)
	var right := Chunk.chunk_x_of(a.x + 36)
	var normal: Dictionary = {}
	for cx in range(left, right + 1): normal[cx] = Generator.generate_chunk(42, cx)
	for cx in range(right, left - 1, -1):
		var other := Generator.generate_chunk(42, cx)
		assert_eq(other.tiles, normal[cx].tiles, "不同加载顺序不能断开金字塔")
		assert_eq(other.walls, normal[cx].walls)
		var local := Vector2i(20, 150)
		other.apply_delta({local: 127})
		other.apply_wall_delta({local: Tiles.WOOD_WALL})
		assert_eq(other.get_tile(local.x, local.y), 127)
		assert_eq(other.get_wall(local.x, local.y), Tiles.WOOD_WALL)

func test_glowing_mushrooms_emit_and_remove_light():
	var p := Generator.classic_plan(42)
	var c := _generated_at(p.mushroom)
	var lights := preload("res://scripts/world/world_lighting.gd").new()
	add_child_autofree(lights)
	lights.on_chunk_loaded(c.chunk_x, 64, c.tiles)
	var crowns := 0
	for x in 64:
		for y in 256:
			if c.tiles[x][y] == Tiles.MUSHROOM_CAP:
				var pos := Vector2i(c.chunk_x * 64 + x, y)
				assert_has(lights.get_light_tiles(), pos)
				lights.on_tile_removed(pos.x, pos.y, Tiles.MUSHROOM_CAP)
				assert_false(lights.get_light_tiles().has(pos))
				crowns += 1
	assert_gt(crowns, 1)

func test_ocean_water_sits_above_sand_and_sizes_relocate_coast():
	var small := Generator.classic_plan(42)
	var pos := Vector2i(small.edge + 100, 120)
	var c := _generated_at(pos)
	assert_true(Tiles.is_water(_tile(c, pos)))
	var floor_y: int = c.surfaces[Chunk.local_x_of(pos.x)]
	assert_eq(_tile(c, Vector2i(pos.x, floor_y)), Tiles.SAND)
	GameSettings.current_world_size = 2
	Generator.clear_structure_caches()
	var large := Generator.classic_plan(42)
	assert_gt(large.edge, small.edge)
