extends GutTest

const CrackOverlayScene = preload("res://scenes/world/crack_overlay.tscn")


func _make_overlay() -> Node2D:
	var co = CrackOverlayScene.instantiate()
	add_child_autofree(co)
	return co


func test_set_progress_creates_sprite():
	var co = _make_overlay()
	co.set_progress(Vector2i(3, 3), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 1)


func test_set_progress_same_tile_updates_not_duplicates():
	var co = _make_overlay()
	co.set_progress(Vector2i(1, 1), 0.2)
	co.set_progress(Vector2i(1, 1), 0.7)
	await wait_frames(1)
	assert_eq(co.active_count(), 1, "同 tile 重调应只 1 个 sprite")


func test_set_progress_zero_clears():
	var co = _make_overlay()
	co.set_progress(Vector2i(2, 2), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 1)
	co.set_progress(Vector2i(2, 2), 0.0)
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_set_progress_one_clears():
	var co = _make_overlay()
	co.set_progress(Vector2i(2, 2), 0.5)
	co.set_progress(Vector2i(2, 2), 1.0)
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_clear_removes():
	var co = _make_overlay()
	co.set_progress(Vector2i(4, 4), 0.5)
	co.clear(Vector2i(4, 4))
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_multiple_tiles_independent():
	var co = _make_overlay()
	co.set_progress(Vector2i(0, 0), 0.3)
	co.set_progress(Vector2i(1, 0), 0.8)
	co.set_progress(Vector2i(2, 0), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 3)
	co.clear(Vector2i(1, 0))
	await wait_frames(1)
	assert_eq(co.active_count(), 2)
