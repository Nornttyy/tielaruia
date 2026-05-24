# 太阳/月亮的圆盘纹理程序生成. 用于 CelestialLayer.
extends RefCounted


# 太阳: 中心亮黄 → 边缘暖橙, 外层柔光 (alpha 软边)
# radius: 圆盘半径 px (纹理边长 = radius*2 + glow_pad*2)
static func sun(radius: int = 28) -> ImageTexture:
	var glow_pad: int = 12  # 柔光延伸
	var size: int = (radius + glow_pad) * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(center)
			if d <= radius:
				# 圆盘内: 径向 中心白热 → 边缘橙
				var t: float = d / float(radius)  # 0..1
				var col := Color(1.0, 0.95, 0.55).lerp(Color(1.0, 0.65, 0.20), t)
				img.set_pixel(x, y, col)
			elif d <= radius + glow_pad:
				# 柔光: alpha 从 0.4 渐变到 0
				var glow_t: float = (d - radius) / float(glow_pad)
				var a: float = (1.0 - glow_t) * 0.4
				img.set_pixel(x, y, Color(1.0, 0.85, 0.45, a))
	return ImageTexture.create_from_image(img)


# 月亮: 灰白圆盘 + 几个深灰陨石坑斑点 + 边缘软光
static func moon(radius: int = 22) -> ImageTexture:
	var glow_pad: int = 8
	var size: int = (radius + glow_pad) * 2
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var center := Vector2(size / 2.0, size / 2.0)
	# 月面颜色 + 阴影色 (类似镜面凸光)
	var moon_light := Color(0.95, 0.95, 0.90)
	var moon_shadow := Color(0.65, 0.65, 0.72)
	for y in size:
		for x in size:
			var p := Vector2(x, y)
			var d: float = p.distance_to(center)
			if d <= radius:
				# 偏右下亮, 左上暗 (单向阴影模拟立体)
				var dir := (p - center).normalized()
				var shade: float = (dir.x + dir.y + 2.0) * 0.25  # 0..1
				var col: Color = moon_shadow.lerp(moon_light, shade)
				img.set_pixel(x, y, col)
			elif d <= radius + glow_pad:
				var glow_t: float = (d - radius) / float(glow_pad)
				var a: float = (1.0 - glow_t) * 0.25
				img.set_pixel(x, y, Color(0.85, 0.88, 0.95, a))
	# 加 3 个陨石坑 (深色小圆)
	_paint_crater(img, center + Vector2(-radius * 0.4, -radius * 0.3), max(2, radius / 5), Color(0.50, 0.50, 0.55))
	_paint_crater(img, center + Vector2(radius * 0.3, radius * 0.2), max(2, radius / 6), Color(0.55, 0.55, 0.60))
	_paint_crater(img, center + Vector2(0.0, radius * 0.5), max(1, radius / 7), Color(0.55, 0.55, 0.62))
	return ImageTexture.create_from_image(img)


static func _paint_crater(img: Image, pos: Vector2, r: int, col: Color) -> void:
	var size := img.get_size()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d: float = sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var px: int = int(pos.x) + dx
			var py: int = int(pos.y) + dy
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			# 只在原本不透明的位置上画 (不破坏外形)
			var old: Color = img.get_pixel(px, py)
			if old.a < 0.5:
				continue
			img.set_pixel(px, py, col)


# 单颗星星纹理 (3x3 十字小点)
static func star() -> ImageTexture:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var c := Color(1.0, 1.0, 0.95, 1.0)
	var dim := Color(0.90, 0.90, 0.95, 0.6)
	img.set_pixel(1, 1, c)
	img.set_pixel(0, 1, dim)
	img.set_pixel(2, 1, dim)
	img.set_pixel(1, 0, dim)
	img.set_pixel(1, 2, dim)
	return ImageTexture.create_from_image(img)
