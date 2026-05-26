extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")


func _make_deferred() -> Node2D:
	var w: Node2D = WorldScene.instantiate()
	w.defer_init = true
	w.world_seed = 42
	add_child_autofree(w)
	return w


func test_deferred_world_has_no_chunk_manager_before_step():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.chunk_manager, null, "defer_init=true 时 _ready 不应自动建 chunk_manager")


func test_get_init_step_count_is_4():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.get_init_step_count(), 4, "world 应公开 4 个 init step")


func test_get_init_step_label_returns_chinese():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.get_init_step_label(0), "正在构建方块...")
	assert_eq(w.get_init_step_label(1), "正在生成地形...")
	assert_eq(w.get_init_step_label(2), "正在召唤天气...")
	assert_eq(w.get_init_step_label(3), "正在召唤玩家...")


func test_run_init_step_0_builds_tileset():
	var w = _make_deferred()
	await get_tree().process_frame
	w.run_init_step(0)
	assert_ne(w.terrain_layer.tile_set, null, "step 0 后 terrain_layer 应有 tile_set")
	assert_ne(w.wall_layer.tile_set, null, "step 0 后 wall_layer 应有 tile_set")


func test_run_init_step_1_builds_chunk_manager():
	var w = _make_deferred()
	await get_tree().process_frame
	w.run_init_step(0)
	w.run_init_step(1)
	assert_ne(w.chunk_manager, null, "step 1 后 chunk_manager 应已建好")


func test_run_init_step_3_spawns_player():
	var w = _make_deferred()
	await get_tree().process_frame
	for i in 4:
		w.run_init_step(i)
	await wait_frames(2)
	assert_ne(w.get_player(), null, "step 3 后 player 应已 spawn")


func test_default_ready_runs_all_steps_backwards_compat():
	# defer_init=false (default) → _ready 跑完所有 step
	var w: Node2D = WorldScene.instantiate()
	w.world_seed = 42
	add_child_autofree(w)
	await wait_frames(2)
	assert_ne(w.chunk_manager, null, "默认路径 chunk_manager 应自动建好")
	assert_ne(w.get_player(), null, "默认路径 player 应自动 spawn")
