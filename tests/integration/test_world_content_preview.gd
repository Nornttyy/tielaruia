extends GutTest
const MainScene = preload("res://scenes/main.tscn")

func test_world_preview_visits_real_sites_and_never_saves():
	var previous_creative := GameSettings.creative_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main._start_world_preview()
	await get_tree().process_frame
	var world = main.world
	var tour: Node
	for child in world.get_children():
		if child.has_method("visit"): tour = child
	assert_not_null(tour)
	assert_true(main._art_preview)
	assert_null(main._autosave_timer)
	assert_true(GameSettings.creative_mode)
	for index in range(tour.stops.size()):
		tour.visit(index)
		await get_tree().process_frame
		assert_eq(tour.current, index)
		assert_true(tour.title.text.contains(tour.stops[index].name))
		var stop: Dictionary = tour.stops[index]
		assert_not_null(world.chunk_manager.get_chunk(Chunk.chunk_x_of(stop.pos.x)))
	main._return_to_menu()
	await get_tree().process_frame
	assert_eq(main._state, "menu")
	assert_eq(TimeOfDay.time_multiplier, 1.0)
	GameSettings.creative_mode = previous_creative
