# 鸟 / 蝠 剪影纹理. 用于 FlockLayer 飞过屏幕的小群.
extends RefCounted


# 鸟: 8x6 V 形剪影, 黑灰色 (远处看就是黑点)
static func bird_silhouette() -> ImageTexture:
	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.10, 0.10, 0.12, 0.95)
	# V 形: 两条对角线 + 身体一点
	# 左翼
	img.set_pixel(0, 2, col)
	img.set_pixel(1, 1, col)
	img.set_pixel(2, 0, col)
	img.set_pixel(3, 1, col)
	# 身体
	img.set_pixel(4, 1, col)
	img.set_pixel(4, 2, col)
	# 右翼 (镜像)
	img.set_pixel(5, 1, col)
	img.set_pixel(6, 0, col)
	img.set_pixel(7, 1, col)
	return ImageTexture.create_from_image(img)


# 蝠: 8x6 弧形翅膀剪影, 比鸟更"尖", 黑色 + 微紫
static func bat_silhouette() -> ImageTexture:
	var img := Image.create(8, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var col := Color(0.06, 0.04, 0.10, 0.95)  # 黑微紫
	# 翅膀像 W (上下都尖)
	# 上方弧 (翅膀展开)
	img.set_pixel(0, 1, col)
	img.set_pixel(1, 0, col)
	img.set_pixel(2, 1, col)
	img.set_pixel(3, 2, col)
	# 身体
	img.set_pixel(4, 2, col)
	img.set_pixel(4, 3, col)
	# 右翅
	img.set_pixel(5, 2, col)
	img.set_pixel(6, 1, col)
	img.set_pixel(7, 0, col)
	# 下方尖 (翅膀下沿)
	img.set_pixel(2, 3, col)
	img.set_pixel(6, 3, col)
	return ImageTexture.create_from_image(img)
