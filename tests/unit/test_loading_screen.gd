extends GutTest

const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")


func _make() -> CanvasLayer:
	var ls: CanvasLayer = LoadingScreenScene.instantiate()
	add_child_autofree(ls)
	return ls


func test_instantiate_does_not_crash():
	var ls = _make()
	await get_tree().process_frame
	assert_not_null(ls)
	assert_true(ls.visible)


func test_layer_is_50():
	var ls = _make()
	await get_tree().process_frame
	assert_eq(ls.layer, 50, "LoadingScreen layer 应为 50 (在 world 与 HUD 之上)")
