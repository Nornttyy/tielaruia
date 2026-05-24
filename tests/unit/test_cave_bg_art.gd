extends GutTest

const CaveBgArt = preload("res://scripts/art/cave_bg_art.gd")


func test_rocks_returns_image_texture():
	var tex := CaveBgArt.rocks(256, 128, 1)
	assert_not_null(tex)
	assert_eq(tex.get_width(), 256)
	assert_eq(tex.get_height(), 128)


func test_rocks_has_brown_gradient():
	var tex := CaveBgArt.rocks(64, 64, 1)
	var img: Image = tex.get_image()
	# 顶部偏浅, 底部偏深 (取靠中间列, 避开蘑菇/化石/边缘起伏)
	var top: Color = img.get_pixel(32, 50)   # 略往下, 避开边缘起伏
	var bottom: Color = img.get_pixel(32, 62)
	# 都是棕色: R > G > B
	if top.a > 0.5 and bottom.a > 0.5:
		assert_gt(top.r, top.b, "顶部应偏暖色 (R>B)")
		# 底部应比顶部暗
		assert_lte(bottom.r, top.r + 0.05, "底部应不比顶部亮")


func test_stalactites_returns_texture():
	var tex := CaveBgArt.stalactites(256, 64, 5, 2)
	assert_not_null(tex)
	# 应该有一些暗像素 (钟乳石本身)
	var img: Image = tex.get_image()
	var dark_pixels: int = 0
	for y in 64:
		for x in 256:
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5 and c.r < 0.2:
				dark_pixels += 1
	assert_gt(dark_pixels, 50, "应有钟乳石暗像素")


func test_crystals_returns_texture():
	var tex := CaveBgArt.crystals(128, 64, 8, 3)
	assert_not_null(tex)
	# 应该有一些彩色发光点
	var img: Image = tex.get_image()
	var colored_pixels: int = 0
	for y in 64:
		for x in 128:
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				colored_pixels += 1
	assert_gt(colored_pixels, 10, "应有水晶像素")


func test_rocks_has_mushroom_purple_or_green():
	# rocks 内嵌蘑菇, 应能找到至少一个紫色或绿色 cap 像素
	var tex := CaveBgArt.rocks(512, 200, 5)
	var img: Image = tex.get_image()
	var found: bool = false
	for y in 200:
		for x in 512:
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.5:
				continue
			# 紫 (R>0.5, B>0.5, G<0.5) 或 绿 (G>0.5, R<0.5, B<0.5)
			if (c.r > 0.5 and c.b > 0.5 and c.g < 0.5) \
					or (c.g > 0.5 and c.r < 0.5 and c.b < 0.5):
				found = true
				break
		if found:
			break
	assert_true(found, "rocks 应嵌入至少一个紫色或绿色蘑菇")
