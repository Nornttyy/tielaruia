extends GutTest

const FlockArt = preload("res://scripts/art/flock_art.gd")


func test_bird_silhouette_is_8x6():
	var tex := FlockArt.bird_silhouette()
	assert_eq(tex.get_width(), 8)
	assert_eq(tex.get_height(), 6)


func test_bird_has_dark_pixels():
	var tex := FlockArt.bird_silhouette()
	var img: Image = tex.get_image()
	var dark: int = 0
	for y in 6:
		for x in 8:
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.2:
				dark += 1
	assert_gt(dark, 5, "鸟剪影应至少 6 个深色像素")


func test_bat_silhouette_is_8x6():
	var tex := FlockArt.bat_silhouette()
	assert_eq(tex.get_width(), 8)
	assert_eq(tex.get_height(), 6)


func test_bat_has_pixels():
	var tex := FlockArt.bat_silhouette()
	var img: Image = tex.get_image()
	var solid: int = 0
	for y in 6:
		for x in 8:
			if img.get_pixel(x, y).a > 0.5:
				solid += 1
	assert_gt(solid, 8, "蝠剪影应至少 9 个不透明像素")
