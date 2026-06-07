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


# stage 0..3：裂纹由少到多
const _CRACK_PATTERNS := [
	# Stage 0: 一条短裂纹
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7)],
	# Stage 1: 加一根分叉
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7)],
	# Stage 2: 再加一条
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11)],
	# Stage 3: 大面积裂
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11),
	 Vector2i(3, 6), Vector2i(4, 7), Vector2i(11, 11), Vector2i(12, 12), Vector2i(2, 11)],
]


static func get_crack_stage(stage: int) -> ImageTexture:
	stage = clampi(stage, 0, 3)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var crack_color := Color(0.05, 0.05, 0.05, 0.85)
	for p in _CRACK_PATTERNS[stage]:
		if p.x >= 0 and p.x < 16 and p.y >= 0 and p.y < 16:
			img.set_pixel(p.x, p.y, crack_color)
	return ImageTexture.create_from_image(img)


# 火花粒子: 2x2 实心暖色块。TorchSparkParticle 用此纹理作为单帧 sprite。
static func get_torch_spark(color: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# 3x3 圆润水珠: 白底 (中心实, 四角淡), 靠 modulate 染成群系水色。静态缓存只建一次。
static var _water_drop_cache: ImageTexture = null
static func get_water_drop() -> ImageTexture:
	if _water_drop_cache != null:
		return _water_drop_cache
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 十字 + 中心 = 圆润点; 四角留空显得圆
	img.set_pixel(1, 0, Color(1, 1, 1, 0.85))
	img.set_pixel(0, 1, Color(1, 1, 1, 0.85))
	img.set_pixel(1, 1, Color(1, 1, 1, 1.0))
	img.set_pixel(2, 1, Color(1, 1, 1, 0.85))
	img.set_pixel(1, 2, Color(1, 1, 1, 0.85))
	_water_drop_cache = ImageTexture.create_from_image(img)
	return _water_drop_cache
