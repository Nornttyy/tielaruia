extends GutTest

const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")


func _make() -> CanvasLayer:
	var pm = PauseMenuScene.instantiate()
	add_child_autofree(pm)
	return pm


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_initially_hidden():
	var pm = _make()
	assert_false(pm.visible)


func test_open_shows_and_pauses():
	var pm = _make()
	pm.open()
	assert_true(pm.visible)
	assert_true(get_tree().paused)


func test_close_hides_and_unpauses():
	var pm = _make()
	pm.open()
	pm.close()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_toggle_open_close():
	var pm = _make()
	assert_false(pm.visible)
	pm.toggle()
	assert_true(pm.visible)
	pm.toggle()
	assert_false(pm.visible)


func test_resume_button_closes():
	var pm = _make()
	pm.open()
	pm._on_resume_pressed()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_return_to_menu_button_emits_signal():
	var pm = _make()
	pm.open()
	var emitted := [false]
	pm.return_to_menu.connect(func(): emitted[0] = true)
	pm._on_return_to_menu_pressed()
	assert_true(emitted[0])
