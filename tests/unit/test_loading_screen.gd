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


func test_setup_creates_sky_gradient():
	var ls = _make()
	await get_tree().process_frame
	var sky: ColorRect = ls.get_node_or_null("Sky")
	assert_not_null(sky, "Sky ColorRect 应存在")
	var grad: TextureRect = sky.get_node_or_null("SkyGradient")
	assert_not_null(grad, "SkyGradient TextureRect 应存在")
	assert_not_null(grad.texture, "SkyGradient 应有 GradientTexture2D")


func test_setup_creates_14_stars():
	var ls = _make()
	await get_tree().process_frame
	var stars_root: Control = ls.get_node_or_null("Stars")
	assert_not_null(stars_root, "Stars 容器应存在")
	assert_eq(stars_root.get_child_count(), 14, "应有 14 颗星")


func test_setup_creates_player_runner_playing_walk():
	var ls = _make()
	await get_tree().process_frame
	var runner: AnimatedSprite2D = ls.get_node_or_null("PlayerRunner")
	assert_not_null(runner, "PlayerRunner AnimatedSprite2D 应存在")
	assert_eq(runner.animation, "walk", "应播 walk 动画")
	assert_true(runner.is_playing(), "动画应在播")
