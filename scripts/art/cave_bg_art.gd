# 矿洞远景背景图程序生成. 3 种纹理:
#   rocks       — 棕褐渐变远岩壁 + 蘑菇 🍄 + 化石 💀
#   stalactites — 钟乳石灰黑剪影
#   crystals    — 静态水晶点 (cyan/紫/绿)
extends RefCounted

const ROCK_DARK := Color(0.10, 0.06, 0.04)   # 矿洞深处暗色
const ROCK_MID := Color(0.28, 0.18, 0.13)    # 中
const ROCK_LIGHT := Color(0.42, 0.30, 0.22)  # 顶部浅一点
const MUSHROOM_STALK := Color(0.92, 0.88, 0.78)
const MUSHROOM_CAP := Color(0.55, 0.30, 0.65)     # 紫蘑菇
const MUSHROOM_CAP2 := Color(0.30, 0.65, 0.40)    # 绿蘑菇
const MUSHROOM_GLOW := Color(0.65, 0.45, 0.85, 0.35)
const FOSSIL_COLOR := Color(0.88, 0.85, 0.78)


# 远岩壁纹理: 棕褐渐变 + 不规则边缘 + 散落蘑菇/化石
static func rocks(width: int = 1024, height: int = 400, seed_val: int = 7) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	# 全图先填深棕渐变 (顶浅底深)
	for y in height:
		var t: float = float(y) / float(height)
		var col: Color = ROCK_LIGHT.lerp(ROCK_DARK, t)
		for x in width:
			img.set_pixel(x, y, col)
	# 不规则顶部边缘 (用 1D noise 雕掉一些 → 模拟石壁起伏)
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.015
	for x in width:
		var n: float = noise.get_noise_1d(float(x))
		var dent: int = int((n + 1.0) * 12.0)  # 0..24 px
		for y in dent:
			img.set_pixel(x, y, Color(0, 0, 0, 0))
	# 撒一些深色块状斑点 → 岩石纹理
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	for _i in 80:
		var bx: int = rng.randi_range(0, width - 1)
		var by: int = rng.randi_range(30, height - 1)
		var r: int = rng.randi_range(3, 8)
		var dark: Color = ROCK_MID.darkened(rng.randf_range(0.1, 0.4))
		_paint_blob(img, bx, by, r, dark)
	# 蘑菇丛 (~12 个)
	for _i in 12:
		var mx: int = rng.randi_range(20, width - 20)
		var my: int = rng.randi_range(height / 2, height - 20)
		var cap_color: Color = MUSHROOM_CAP if rng.randf() < 0.6 else MUSHROOM_CAP2
		_paint_mushroom(img, mx, my, cap_color, rng.randi_range(3, 5))
	# 化石 (3-5 个嵌入岩壁)
	for _i in 4:
		var fx: int = rng.randi_range(40, width - 40)
		var fy: int = rng.randi_range(height / 3, height - 30)
		_paint_fossil(img, fx, fy, rng)
	return ImageTexture.create_from_image(img)


# 钟乳石纹理: 从顶部下垂的灰黑三角剪影, 随机间隔
static func stalactites(width: int = 1024, height: int = 200, count: int = 14, seed_val: int = 11) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var col := Color(0.08, 0.06, 0.05, 0.95)
	for _i in count:
		var sx: int = rng.randi_range(20, width - 20)
		var sw: int = rng.randi_range(8, 24)         # 宽
		var sh: int = rng.randi_range(60, height - 20)  # 高
		for y in sh:
			# 半宽随高度递减 (尖端向下)
			var ratio: float = 1.0 - float(y) / float(sh)
			var hw: int = max(1, int(sw * ratio * 0.5))
			for dx in range(-hw, hw + 1):
				var px: int = sx + dx
				if px < 0 or px >= width:
					continue
				img.set_pixel(px, y, col)
	return ImageTexture.create_from_image(img)


# 水晶纹理: 透明背景 + 随机彩色小点 (闪烁靠节点 alpha 抖动)
static func crystals(width: int = 1024, height: int = 400, count: int = 25, seed_val: int = 23) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val
	var crystal_colors: Array = [
		Color(0.45, 0.85, 1.00),  # cyan
		Color(0.80, 0.45, 1.00),  # 紫
		Color(0.50, 1.00, 0.55),  # 绿
		Color(1.00, 0.65, 0.85),  # 粉
	]
	for _i in count:
		var cx: int = rng.randi_range(8, width - 8)
		var cy: int = rng.randi_range(20, height - 20)
		var col: Color = crystal_colors[rng.randi() % crystal_colors.size()]
		var r: int = rng.randi_range(2, 4)
		# 中心亮, 外圈柔光
		for dy in range(-r - 2, r + 3):
			for dx in range(-r - 2, r + 3):
				var d: float = sqrt(dx * dx + dy * dy)
				var px: int = cx + dx
				var py: int = cy + dy
				if px < 0 or py < 0 or px >= width or py >= height:
					continue
				if d <= r:
					img.set_pixel(px, py, col)
				elif d <= r + 2:
					var glow_t: float = (d - r) / 2.0
					img.set_pixel(px, py, Color(col.r, col.g, col.b, (1.0 - glow_t) * 0.4))
	return ImageTexture.create_from_image(img)


static func _paint_blob(img: Image, cx: int, cy: int, r: int, col: Color) -> void:
	var size := img.get_size()
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var d: float = sqrt(dx * dx + dy * dy)
			if d > r:
				continue
			var px: int = cx + dx
			var py: int = cy + dy
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			# 仅覆盖原已有像素
			if img.get_pixel(px, py).a < 0.5:
				continue
			img.set_pixel(px, py, col)


# 蘑菇: 杆 + 半圆顶 + 软光晕
static func _paint_mushroom(img: Image, cx: int, cy: int, cap_color: Color, cap_r: int) -> void:
	var size := img.get_size()
	# 杆 (2px 宽, cap_r 高)
	for sy in range(cap_r, cap_r * 2 + 2):
		var py: int = cy + sy - cap_r
		for sx in range(-1, 2):
			var px: int = cx + sx
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			img.set_pixel(px, py, MUSHROOM_STALK)
	# 帽 (半圆)
	for dy in range(-cap_r, 1):
		for dx in range(-cap_r, cap_r + 1):
			var d: float = sqrt(dx * dx + dy * dy)
			if d > cap_r:
				continue
			var px: int = cx + dx
			var py: int = cy + dy
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			img.set_pixel(px, py, cap_color)
	# 帽上的小白点 (蘑菇典型斑)
	for dot_i in 3:
		var ox: int = -cap_r / 2 + dot_i * (cap_r / 2)
		var oy: int = -cap_r / 2
		var px: int = cx + ox
		var py: int = cy + oy
		if px >= 0 and py >= 0 and px < size.x and py < size.y:
			img.set_pixel(px, py, Color(1, 1, 1, 0.85))
	# 光晕 (帽周围一圈)
	for dy in range(-cap_r - 3, 2):
		for dx in range(-cap_r - 3, cap_r + 4):
			var d: float = sqrt(dx * dx + dy * dy)
			if d <= cap_r or d > cap_r + 3:
				continue
			var px: int = cx + dx
			var py: int = cy + dy
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			# 仅替换已有岩石像素 (不创建外形)
			if img.get_pixel(px, py).a < 0.5:
				continue
			var glow_t: float = (d - cap_r) / 3.0
			var glow: Color = MUSHROOM_GLOW
			glow.a = (1.0 - glow_t) * 0.5
			img.set_pixel(px, py, img.get_pixel(px, py).lerp(glow, glow.a))


# 化石: 螺壳剪影 (从中心向外的 5-7 段弧)
static func _paint_fossil(img: Image, cx: int, cy: int, rng: RandomNumberGenerator) -> void:
	var size := img.get_size()
	var segments: int = rng.randi_range(5, 7)
	var base_r: float = rng.randf_range(8.0, 14.0)
	# 螺旋: 每段弧的角度跨度
	for s in segments:
		var ang_start: float = s * (TAU / segments)
		var ang_end: float = ang_start + (TAU / segments) * 0.9
		var r: float = base_r * (1.0 - float(s) / float(segments) * 0.7)
		var steps: int = int(r * 4)
		for st in steps:
			var t: float = float(st) / float(steps)
			var a: float = lerp(ang_start, ang_end, t)
			var px: int = cx + int(cos(a) * r)
			var py: int = cy + int(sin(a) * r)
			if px < 0 or py < 0 or px >= size.x or py >= size.y:
				continue
			# 仅在岩石上 (像素已存在) 画
			if img.get_pixel(px, py).a < 0.5:
				continue
			img.set_pixel(px, py, FOSSIL_COLOR)
