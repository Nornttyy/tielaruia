extends GutTest

const RareOverlayArt = preload("res://scripts/art/rare_overlay_art.gd")


func test_rainbow_returns_image_texture():
	var tex := RareOverlayArt.rainbow(200, 100)
	assert_not_null(tex)
	assert_eq(tex.get_width(), 200)
	assert_eq(tex.get_height(), 100)


func test_rainbow_has_colored_pixels():
	var tex := RareOverlayArt.rainbow(400, 200)
	var img: Image = tex.get_image()
	var colored: int = 0
	for y in 200:
		for x in 400:
			if img.get_pixel(x, y).a > 0.05:
				colored += 1
	assert_gt(colored, 1000, "彩虹应有 >1000 个彩色像素")


func test_aurora_returns_texture():
	var tex := RareOverlayArt.aurora(400, 150)
	assert_not_null(tex)
	var img: Image = tex.get_image()
	var glowing: int = 0
	for y in 150:
		for x in 400:
			if img.get_pixel(x, y).a > 0.05:
				glowing += 1
	assert_gt(glowing, 500, "极光应有 >500 个发光像素")
