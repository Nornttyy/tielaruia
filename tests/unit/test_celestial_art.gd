extends GutTest

const CelestialArt = preload("res://scripts/art/celestial_art.gd")


func test_sun_returns_image_texture():
	var tex := CelestialArt.sun(20)
	assert_not_null(tex)
	# size = (radius + glow_pad=12) * 2 = (20+12)*2 = 64
	assert_eq(tex.get_width(), 64)
	assert_eq(tex.get_height(), 64)


func test_sun_has_bright_center():
	# 中心应是亮黄色
	var tex := CelestialArt.sun(20)
	var img: Image = tex.get_image()
	var center: Color = img.get_pixel(32, 32)
	assert_gt(center.r, 0.8, "中心 R 应高")
	assert_gt(center.g, 0.8, "中心 G 应高")
	assert_gt(center.a, 0.8, "中心不透明")


func test_moon_returns_image_texture():
	var tex := CelestialArt.moon(16)
	assert_not_null(tex)
	# size = (16+8)*2 = 48
	assert_eq(tex.get_width(), 48)


func test_moon_has_gray_center():
	var tex := CelestialArt.moon(16)
	var img: Image = tex.get_image()
	# 中心 (24, 24) 附近, 但可能正好被陨石坑命中. 检查 (24, 16) (上方非坑位)
	var p: Color = img.get_pixel(24, 16)
	assert_gt(p.a, 0.5, "月亮上方应不透明")


func test_star_returns_3x3():
	var tex := CelestialArt.star()
	assert_eq(tex.get_width(), 3)
	assert_eq(tex.get_height(), 3)
	var img: Image = tex.get_image()
	# 中心应是白色不透明
	assert_gt(img.get_pixel(1, 1).a, 0.8)
	# 四角应透明
	assert_lt(img.get_pixel(0, 0).a, 0.1)
	assert_lt(img.get_pixel(2, 2).a, 0.1)
