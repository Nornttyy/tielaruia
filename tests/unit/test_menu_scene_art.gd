extends GutTest

const MenuSceneArt = preload("res://scripts/art/menu_scene_art.gd")


func test_make_cloud_returns_texture():
	var tex = MenuSceneArt.make_cloud()
	assert_not_null(tex)
	assert_true(tex is ImageTexture)
	assert_gt(tex.get_width(), 8)


func test_make_hill_returns_texture():
	var tex = MenuSceneArt.make_hill()
	assert_not_null(tex)
	assert_gt(tex.get_width(), 32)


func test_make_tree_returns_texture():
	var tex = MenuSceneArt.make_tree()
	assert_not_null(tex)
	assert_gt(tex.get_height(), 8)


func test_make_ground_noise_returns_texture():
	var tex = MenuSceneArt.make_ground_noise()
	assert_not_null(tex)
	assert_gt(tex.get_width(), 8)
