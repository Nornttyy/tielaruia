extends GutTest
const Bank = preload("res://scripts/audio/music_bank.gd")
const Storage = preload("res://scripts/autoload/chest_storage.gd")
const Controller = preload("res://scripts/player/player_controller.gd")

class SurfaceChunk extends RefCounted:
	var surfaces: Array = []
	func _init(): surfaces.resize(256); surfaces.fill(40)
class FakeWorld extends RefCounted:
	var chunk = SurfaceChunk.new()
	func get_chunk(_x): return chunk
	func get_wall(_x, _y): return 1

func test_five_looping_files_and_crossfade_does_not_restart_same_context():
	var bank = Bank.new()
	add_child_autofree(bank)
	bank.set_process(false)
	assert_eq(bank._tracks.size(), 5)
	for context in Bank.TRACK_NAMES:
		var stream = bank._tracks[context]
		assert_true(stream is AudioStreamOggVorbis)
		assert_true(stream.loop)
		assert_gt(stream.get_length(), 5.0)
	bank.set_context("day")
	bank._process(0.4)
	var active = bank._active_bgm
	bank.set_context("day")
	assert_same(bank._active_bgm, active)
	assert_almost_eq(bank._fade_t, 0.4, 0.001)
	bank._process(0.6)
	assert_true(active.playing)
	var other = bank._bgm_b if active == bank._bgm_a else bank._bgm_a
	assert_false(other.playing)
	assert_almost_eq(active.volume_db, -30.0, 0.01)
	bank.set_context("missing")
	assert_eq(bank._current_track, "day")

func test_surface_house_wall_does_not_trigger_cave_music():
	var player = Controller.new()
	# 不入场景树，避免角色启动逻辑接触世界存档。
	autofree(player)
	var fake_world = FakeWorld.new()
	player._cached_chunk_manager = fake_world
	assert_false(player._is_player_underground(5, 38))
	assert_false(player._is_player_underground(5, 50))
	assert_true(player._is_player_underground(5, 51))

func test_old_twenty_four_slot_chest_expands_and_roundtrips():
	var storage = Storage.new()
	add_child_autofree(storage)
	var old: Array = []
	old.resize(24)
	old[0] = {"item_id": "wood", "count": 7}
	old[23] = {"item_id": "stone", "count": 9}
	storage.restore({"chests": {"1,2": old}, "treasure_marked": ["1,2"]})
	var slots = storage.get_slots(Vector2i(1, 2))
	assert_eq(slots.size(), 40)
	assert_eq(slots[0].count, 7)
	assert_eq(slots[23].count, 9)
	assert_null(slots[39])
	slots[39] = {"item_id": "dirt", "count": 11}
	storage.restore(storage.dump())
	assert_eq(storage.get_slots(Vector2i(1, 2))[39].count, 11)
	assert_true(storage._treasure_marked.has(Vector2i(1, 2)))
