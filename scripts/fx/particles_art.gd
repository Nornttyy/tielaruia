# 粒子贴图程序生成。所有方法 static，返回 ImageTexture。
extends RefCounted


# 3x3 实心小方块，单色
static func get_block_chip(color: Color) -> ImageTexture:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# 5x5 半透明圆点 puff，从中心 alpha=1 → 边缘 alpha=0
static func get_dust_puff(color: Color = Color(0.9, 0.85, 0.7, 1.0)) -> ImageTexture:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	var center := Vector2(2.0, 2.0)
	for y in 5:
		for x in 5:
			var d: float = Vector2(x, y).distance_to(center)
			var a: float = clamp(1.0 - d / 2.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	return ImageTexture.create_from_image(img)
