extends GutTest

const CelestialLayer = preload("res://scripts/world/celestial_layer.gd")


func test_ready_creates_stars():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_gt(cl.star_count(), 10, "应至少生成几十颗星")


func test_canvas_layer_is_minus_8():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl.layer, -8, "CanvasLayer.layer 应 = -8")


func test_noon_sun_visible_moon_hidden():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	TimeOfDay.time = 0.5  # 正午
	cl.update_celestial(0.016)  # 直接调更新 (绕过帧 _process 调度)
	assert_true(cl.sun_visible(), "中午太阳应可见")
	assert_false(cl.moon_visible(), "中午月亮应隐藏")


func test_midnight_moon_visible_sun_hidden():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	TimeOfDay.time = 0.0  # 深夜
	cl.update_celestial(0.016)
	assert_false(cl.sun_visible(), "深夜太阳应隐藏")
	assert_true(cl.moon_visible(), "深夜月亮应可见")


func test_noon_stars_dim():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	TimeOfDay.time = 0.5  # 中午
	cl.update_celestial(0.016)
	# 中午 day_factor=1, 星 alpha ~ 0
	assert_lt(cl.stars_root_alpha(), 0.05, "中午星星几乎隐形")


func test_midnight_stars_visible():
	var cl = CelestialLayer.new()
	add_child_autofree(cl)
	await wait_frames(1)
	TimeOfDay.time = 0.0  # 深夜
	cl.update_celestial(0.016)
	assert_gt(cl.stars_root_alpha(), 0.1, "深夜星星应能看见")
