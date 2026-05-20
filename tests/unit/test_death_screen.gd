extends GutTest

const DeathScreenScene = preload("res://scenes/ui/death_screen.tscn")


func _make() -> CanvasLayer:
	var ds = DeathScreenScene.instantiate()
	add_child_autofree(ds)
	return ds


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_initially_hidden():
	var ds = _make()
	assert_false(ds.visible)


func test_show_death_makes_visible_and_pauses():
	var ds = _make()
	ds.show_death()
	assert_true(ds.visible)
	assert_true(get_tree().paused)


func test_emits_respawn_when_button_pressed_after_fade():
	var ds = _make()
	ds.show_death()
	ds.skip_fade_for_test()
	var emitted := [false]
	ds.respawn.connect(func(): emitted[0] = true)
	ds._on_respawn_pressed()
	assert_true(emitted[0])


func test_hide_unpauses_and_hides():
	var ds = _make()
	ds.show_death()
	ds.hide_death()
	assert_false(ds.visible)
	assert_false(get_tree().paused)


func test_button_disabled_during_fade():
	var ds = _make()
	ds.show_death()
	assert_true(ds._respawn_button.disabled, "淡入中按钮禁用")
	ds.skip_fade_for_test()
	assert_false(ds._respawn_button.disabled, "淡入完按钮启用")
