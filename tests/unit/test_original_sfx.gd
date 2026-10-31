extends GutTest

const Original = preload("res://scripts/audio/original_sfx.gd")
var played: Array = []

func before_each():
	played.clear()
	for player in SfxBank._players: player.stop()
	SfxBank.sound_played.connect(_record)

func after_each():
	SfxBank.sound_played.disconnect(_record)
	for player in SfxBank._players: player.stop()

func _record(event: String, source: String):
	played.append([event, source])

func test_original_events_have_all_decodable_source_variants():
	for event in Original.EVENTS:
		var streams := Original.streams(event)
		assert_eq(streams.size(), Original.EVENTS[event].size(), "不能静默丢失音效变体：" + event)
		assert_true(SfxBank._original_events.has(event))
		for stream in streams:
			assert_gt(stream.get_length(), 0.01)
			assert_gt(stream.data.size(), 100)
			assert_true(stream.resource_path.begins_with(Original.BASE))

func test_bow_pickup_and_drink_are_distinct_original_samples():
	for event in ["bow", "pickup", "drink", "eat"]: SfxBank.play(event)
	assert_eq(played.size(), 4)
	assert_true(played[0][1].ends_with("Item_5.wav"), "射箭不能播破方块声")
	assert_true(played[1][1].ends_with("Grab.wav"))
	assert_true(played[2][1].ends_with("Item_3.wav"))
	assert_true(played[3][1].ends_with("Item_2.wav"))

func test_tile_contacts_choose_soil_metal_and_plant_sounds():
	SfxBank.play_tile_hit(Tiles.DIRT)
	SfxBank.play_tile_hit(Tiles.IRON_ORE)
	SfxBank.play_tile_hit(Tiles.PLANT_GRASS)
	assert_eq(played[0][0], "dig")
	assert_eq(played[1][0], "tink")
	assert_eq(played[2][0], "grass")

func test_original_pitch_is_not_changed_by_old_placeholder_arguments():
	SfxBank.play("menu_open", 0.9)
	var found := false
	for player in SfxBank._players:
		if player.playing:
			found = true
			assert_almost_eq(player.pitch_scale, 1.0, 0.00001)
	assert_true(found)
