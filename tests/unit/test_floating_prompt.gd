extends GutTest

const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")


func _make() -> CanvasLayer:
	var fp = FloatingPromptScene.instantiate()
	add_child_autofree(fp)
	return fp


func test_initially_hidden():
	var fp = _make()
	assert_false(fp.is_showing())
	assert_false(fp.visible)


func test_show_makes_visible():
	var fp = _make()
	fp.show_prompt(Vector2(100, 100), "按 E")
	assert_true(fp.is_showing())
	assert_true(fp.visible)


func test_show_updates_text():
	var fp = _make()
	fp.show_prompt(Vector2.ZERO, "拿起")
	assert_eq(fp.label.text, "拿起")


func test_hide():
	var fp = _make()
	fp.show_prompt(Vector2.ZERO, "x")
	fp.hide_prompt()
	assert_false(fp.is_showing())
	assert_false(fp.visible)
