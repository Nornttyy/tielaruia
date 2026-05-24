# 彩虹 + 极光 罕见全屏 overlay 纹理.
extends RefCounted


# 半圆彩虹 7 色弧 (红橙黄绿青蓝紫), 外缘软 alpha
static func rainbow(width: int = 800, height: int = 400) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var cx: float = width * 0.5
	var cy: float = float(height)  # 圆心在底
	# 半径从 outer 到 inner, 7 条带
	var outer_r: float = float(height) * 0.95
	var inner_r: float = float(height) * 0.65
	var band_thickness: float = (outer_r - inner_r) / 7.0
	var colors: Array = [
		Color(1.00, 0.20, 0.20),  # 红
		Color(1.00, 0.55, 0.15),  # 橙
		Color(1.00, 0.95, 0.20),  # 黄
		Color(0.30, 0.85, 0.30),  # 绿
		Color(0.30, 0.85, 0.95),  # 青
		Color(0.25, 0.40, 1.00),  # 蓝
		Color(0.70, 0.30, 0.95),  # 紫
	]
	for y in height:
		for x in width:
			var dx: float = float(x) - cx
			var dy: float = float(y) - cy
			var d: float = sqrt(dx * dx + dy * dy)
			if d < inner_r or d > outer_r:
				continue
			if dy > 0:
				continue  # 只画上半圆
			var band_idx: int = int((outer_r - d) / band_thickness)
			if band_idx < 0 or band_idx >= colors.size():
				continue
			# 边缘 alpha 软化
			var ed: float = min(d - inner_r, outer_r - d)
			var a: float = clamp(ed / 4.0, 0.0, 1.0) * 0.55  # 整体半透
			var c: Color = colors[band_idx]
			c.a = a
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


# 极光: 3-4 条波浪绿色光带 (水平方向 sin 摆动, 垂直方向 alpha 渐变)
static func aurora(width: int = 1280, height: int = 300) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var band_count: int = 4
	for b in band_count:
		var amp: float = rng.randf_range(20.0, 50.0)
		var freq: float = rng.randf_range(0.005, 0.012)
		var phase: float = rng.randf() * TAU
		var y_base: float = rng.randf_range(30.0, height - 80.0)
		var thickness: float = rng.randf_range(30.0, 55.0)
		var hue: int = rng.randi() % 3  # 0=绿, 1=青, 2=紫
		var base_color: Color
		match hue:
			0: base_color = Color(0.40, 1.00, 0.55)
			1: base_color = Color(0.30, 0.95, 0.95)
			_: base_color = Color(0.75, 0.45, 1.00)
		for x in width:
			var y_center: float = y_base + sin(x * freq + phase) * amp
			for dy in range(-int(thickness), int(thickness) + 1):
				var y: int = int(y_center) + dy
				if y < 0 or y >= height:
					continue
				# alpha 高斯 (中心强, 边缘弱)
				var t: float = float(abs(dy)) / thickness
				var a: float = (1.0 - t * t) * 0.45
				if a <= 0.0:
					continue
				var c: Color = base_color
				c.a = a
				# 跟已有像素叠加 (alpha 加和)
				var old: Color = img.get_pixel(x, y)
				if old.a > 0.0:
					c = c.lerp(old, 0.4)
					c.a = min(1.0, old.a + a * 0.7)
				img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
