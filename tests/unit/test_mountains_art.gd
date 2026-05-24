extends GutTest

const MountainsArt = preload("res://scripts/art/mountains_art.gd")


func test_generate_ridge_returns_image_texture():
	var tex := MountainsArt.generate_ridge(
		256, 64, 5, 0.5, MountainsArt.COLOR_FAR, false, 42
	)
	assert_not_null(tex, "应返回 ImageTexture")
	assert_eq(tex.get_width(), 256)
	assert_eq(tex.get_height(), 64)


func test_generate_ridge_has_non_empty_pixels():
	# 生成后图像下半部应该至少有一些非透明像素 (山身)
	var tex := MountainsArt.generate_ridge(
		128, 64, 5, 0.5, MountainsArt.COLOR_MID, false, 1
	)
	var img: Image = tex.get_image()
	# 检查最底行: 必有像素 (山一直延伸到底)
	var bottom_row_filled: int = 0
	for x in 128:
		if img.get_pixel(x, 63).a > 0.5:
			bottom_row_filled += 1
	assert_gt(bottom_row_filled, 100, "最底一行应几乎全是山身像素")


func test_snow_cap_paints_white():
	# snow_cap=true 时山尖应有白色像素
	var tex := MountainsArt.generate_ridge(
		512, 128, 4, 0.5, MountainsArt.COLOR_FAR, true, 7
	)
	var img: Image = tex.get_image()
	var white_pixels: int = 0
	for y in 64:  # 上半部
		for x in 512:
			var c: Color = img.get_pixel(x, y)
			if c.r > 0.9 and c.g > 0.9 and c.b > 0.9 and c.a > 0.5:
				white_pixels += 1
	assert_gt(white_pixels, 5, "应有至少几个雪顶白像素")


func test_no_snow_cap_no_white():
	# snow_cap=false 时不应有白色
	var tex := MountainsArt.generate_ridge(
		256, 64, 5, 0.5, MountainsArt.COLOR_NEAR, false, 3
	)
	var img: Image = tex.get_image()
	for y in 64:
		for x in 256:
			var c: Color = img.get_pixel(x, y)
			if c.a > 0.5:
				# 不应纯白
				assert_false(
					c.r > 0.9 and c.g > 0.9 and c.b > 0.9,
					"snow_cap=false 不应出现白像素"
				)
				return


func test_all_colors_returns_three():
	var colors: Array = MountainsArt.all_colors()
	assert_eq(colors.size(), 3, "应有 3 种颜色 (FAR/MID/NEAR)")
