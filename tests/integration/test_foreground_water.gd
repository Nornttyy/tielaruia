extends GutTest
const WorldScene = preload("res://scenes/world/world.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
var world: Node2D
func before_each():
	world = WorldScene.instantiate()
	world.defer_init = true
	add_child_autofree(world)
	world.set_process(false)
	world.set_physics_process(false)
	world._step_build_tileset()
	world.chunk_manager = ChunkManager.new()
	world.add_child(world.chunk_manager)
	world.chunk_manager.setup(500)
	var c := Chunk.new(0)
	c.init_empty()
	world.chunk_manager._loaded[0] = c

func test_water_covers_entities_but_not_hud_and_does_not_duplicate_in_terrain():
	world._set_water_tile_fast(12, 70, Tiles.WATER)
	assert_eq(world.terrain_layer.get_cell_source_id(Vector2i(12, 70)), -1)
	assert_gt(world.water_layer.get_cell_source_id(Vector2i(12, 70)), -1)
	assert_gt(world.water_layer.z_index, world.entities_root.z_index)
	assert_lt(world.water_layer.z_index, world.darkness_layer.z_index)
	assert_false(world.water_layer.collision_enabled)
	assert_true(world.darkness_layer._dirty, "水的修改使照明缓存失效")
	world._set_water_tile_fast(12, 70, Tiles.AIR)
	assert_eq(world.water_layer.get_cell_source_id(Vector2i(12, 70)), -1)

func test_surface_frame_and_chunk_unload_remove_water_from_foreground():
	world._set_water_tile_fast(12, 70, Tiles.WATER)
	world._set_water_tile_fast(12, 69, Tiles.WATER)
	assert_eq(world.water_layer.get_cell_atlas_coords(Vector2i(12, 70)), Vector2i(0, 1))
	world._set_water_tile_fast(12, 69, Tiles.AIR)
	assert_eq(world.water_layer.get_cell_atlas_coords(Vector2i(12, 70)), Vector2i.ZERO)
	world._on_chunk_unloaded(0)
	assert_eq(world.water_layer.get_used_cells().size(), 0)

func test_head_submersion_uses_actual_water_surface_height():
	var player = PlayerScene.instantiate()
	world.entities_root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	player._cached_chunk_manager = world.chunk_manager
	world.chunk_manager.set_tile(12, 70, Tiles.WATER_L2)
	player.position = Vector2(12 * 12 + 6, 70 * 12 + 29 + 2)
	assert_false(player.is_head_submerged(), "头在浅水的透明部分")
	player.position.y += 8
	assert_true(player.is_head_submerged())
	world.chunk_manager.set_tile(12, 70, Tiles.AIR)
	assert_false(player.is_head_submerged())

func test_static_light_cache_reuses_result_but_water_edits_refresh_it():
	var player = PlayerScene.instantiate()
	world.entities_root.add_child(player)
	player.process_mode = Node.PROCESS_MODE_DISABLED
	world.darkness_layer._cached_player = player
	world.darkness_layer._cached_cm = world.chunk_manager
	world.darkness_layer._update_viewport()
	var count: int = world.darkness_layer.update_count
	world.darkness_layer._update_viewport()
	assert_eq(world.darkness_layer.update_count, count, "静止时不重复遍历全屏")
	world._set_water_tile_fast(0, 0, Tiles.WATER)
	world.darkness_layer._update_viewport()
	assert_eq(world.darkness_layer.update_count, count + 1, "改变水位后即使人物不动也更新照明")
