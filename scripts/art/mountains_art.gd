# 远山纹理程序生成. 3 种颜色 (远/中/近) + 雪顶选项.
# 用 1D Perlin 噪声生成高度曲线, 然后在 ImageTexture 上画出山的剪影.
extends RefCounted

# 大气透视: 越远越浅 + 偏冷
const COLOR_FAR := Color(0.55, 0.62, 0.75)   # 远山 蓝灰
const COLOR_MID := Color(0.40, 0.50, 0.55)   # 中山
const COLOR_NEAR := Color(0.30, 0.40, 0.30)  # 近丘 深绿
const SNOW_COLOR := Color(0.95, 0.96, 0.98)  # 雪顶


# 生成一张山脊纹理.
# width / height: 像素尺寸
# peaks: 大致山峰数 (噪声频率比例)
# jaggedness: [0..1] 山尖锋利程度 (越大越尖)
# color: 山的填充色
# snow_cap: 是否给山尖 (top 8%) 涂雪色
# seed_val: 噪声种子, 不同层用不同 seed 让山形不重复
static func generate_ridge(
	width: int,
	height: int,
	peaks: int,
	jaggedness: float,
	color: Color,
	snow_cap: bool,
	seed_val: int
) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var heights := _height_profile(width, peaks, jaggedness, seed_val)
	# 找前 8% 高度阈值, 用于雪顶
	var snow_threshold: float = INF
	if snow_cap:
		var sorted_heights: Array = heights.duplicate()
		sorted_heights.sort()
		var idx: int = int(sorted_heights.size() * 0.92)
		snow_threshold = sorted_heights[idx]
	# 一列列画山
	for x in width:
		var h_ratio: float = heights[x]
		var fill_top_px: int = int(h_ratio * height)
		var y_top: int = height - fill_top_px
		for y in range(y_top, height):
			img.set_pixel(x, y, color)
		# 山尖雪 (前 8% 高度) — 顶部 5 像素涂白
		if snow_cap and h_ratio >= snow_threshold:
			for y in range(y_top, min(y_top + 5, height)):
				img.set_pixel(x, y, SNOW_COLOR)
	return ImageTexture.create_from_image(img)


# 生成 [0..1] 高度数组. 用 FastNoiseLite 1D Perlin + 高频抖动模拟锯齿.
static func _height_profile(
	width: int, peaks: int, jaggedness: float, seed_val: int
) -> Array:
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	# peaks 越多频率越高
	noise.frequency = 0.0015 * float(peaks)
	var heights: Array = []
	heights.resize(width)
	for x in width:
		var n: float = noise.get_noise_1d(float(x))  # [-1, 1]
		var v: float = (n + 1.0) * 0.5  # [0, 1]
		# 高频小幅噪声 → 让山尖更尖
		if jaggedness > 0.0:
			var n2: float = noise.get_noise_1d(float(x) * 9.0)
			v += n2 * jaggedness * 0.18
		v = clamp(v, 0.0, 1.0)
		# 山高度范围 [0.30, 0.85] 让山占纹理高度的 30-85%
		v = 0.30 + v * 0.55
		heights[x] = v
	return heights


static func _px(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


# === 群系远景剪影: 真·不同形状 (不是染色) ===
# style: "mountain"(尖山) / "dune"(沙丘) / "canopy"(丛林树冠) / "deadtree"(枯树沼泽)
static func generate_biome_ridge(
	width: int, height: int, style: String, color: Color, snow_cap: bool, seed_val: int
) -> ImageTexture:
	var img := Image.create(width, height, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var heights: Array = _profile_for_style(style, width, seed_val)
	var snow_threshold: float = INF
	if snow_cap:
		var sh: Array = heights.duplicate()
		sh.sort()
		snow_threshold = sh[int(sh.size() * 0.90)]
	var crest: Color = color.lightened(0.18)
	for x in width:
		var hr: float = heights[x]
		var y_top: int = height - int(hr * height)
		for y in range(y_top, height):
			img.set_pixel(x, y, color)
		if snow_cap and hr >= snow_threshold:
			for y in range(y_top, min(y_top + 6, height)):
				img.set_pixel(x, y, SNOW_COLOR)
		elif style == "canopy" or style == "dune":
			img.set_pixel(x, y_top, crest)   # 顶缘高光 (沙丘脊/树冠受光)
	# 叠加群系标志物 (真·不同的东西)
	if style == "dune":
		_overlay_cacti(img, width, height, heights, seed_val)
	elif style == "deadtree":
		_overlay_deadtrees(img, width, height, heights, seed_val)
	return ImageTexture.create_from_image(img)


static func _profile_for_style(style: String, width: int, seed_val: int) -> Array:
	if style == "mountain":
		return _height_profile(width, 7, 0.7, seed_val)
	var noise := FastNoiseLite.new()
	noise.seed = seed_val
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.004
	var heights: Array = []
	heights.resize(width)
	for x in width:
		var v: float
		if style == "dune":
			# 平滑圆润的沙丘 (低频正弦, 不锯齿, 矮)
			var s: float = 0.5 + 0.22 * sin(x * 0.010 + seed_val) + 0.12 * sin(x * 0.004 + seed_val * 0.7)
			s += noise.get_noise_1d(float(x)) * 0.10
			v = clamp(0.18 + s * 0.22, 0.12, 0.50)
		elif style == "canopy":
			# 丛林树冠: 一条起伏树线 + 高频圆突 (树簇)
			var base: float = (noise.get_noise_1d(float(x)) + 1.0) * 0.5
			var bump: float = absf(noise.get_noise_1d(float(x) * 5.0 + 300.0))
			v = clamp(0.34 + base * 0.16 + bump * 0.16, 0.20, 0.62)
		else:
			# 沼泽: 低平地面 (枯树另叠)
			var n: float = (noise.get_noise_1d(float(x)) + 1.0) * 0.5
			v = clamp(0.12 + n * 0.06, 0.08, 0.20)
		heights[x] = v
	return heights


# 沙漠: 沙丘上几株仙人掌 (经典 saguaro: 柱身 + 两臂)
static func _overlay_cacti(img: Image, w: int, h: int, heights: Array, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 31 + 7
	var cac := Color(0.26, 0.42, 0.26)
	var cw: int = max(2, int(h * 0.012))
	for i in 4:
		var cx: int = int(rng.randf_range(0.08, 0.92) * w)
		var gy: int = h - int(heights[clampi(cx, 0, w - 1)] * h)
		var ch: int = int(rng.randf_range(0.14, 0.24) * h)
		var ty: int = gy - ch
		for yy in range(ty, gy):
			for xx in range(cx - cw / 2, cx + cw / 2 + 1):
				_px(img, xx, yy, cac)
		# 两臂 (在 ~55% 高处往上弯)
		var ay: int = gy - int(ch * 0.55)
		var arm: int = int(ch * 0.40)
		var span: int = int(h * 0.022)
		for k in span:
			_px(img, cx - cw / 2 - k, ay, cac)
			_px(img, cx + cw / 2 + k, ay, cac)
		for yy in range(ay - arm, ay):
			_px(img, cx - cw / 2 - span, yy, cac)
			_px(img, cx + cw / 2 + span, yy, cac)


# 沼泽: 一排枯树剪影 (光秃树干 + 几根枝杈)
static func _overlay_deadtrees(img: Image, w: int, h: int, heights: Array, seed_val: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val * 53 + 13
	var trunk := Color(0.17, 0.19, 0.17)
	var n := 7
	for i in n:
		var cx: int = int((float(i) / n + rng.randf_range(-0.03, 0.03)) * w)
		cx = clampi(cx, 2, w - 3)
		var gy: int = h - int(heights[cx] * h)
		var th: int = int(rng.randf_range(0.35, 0.60) * h)
		var top_y: int = gy - th
		for yy in range(top_y, gy):
			_px(img, cx, yy, trunk)
			_px(img, cx + 1, yy, trunk)
		# 几根斜枝
		for b in 3:
			var by: int = top_y + int(th * rng.randf_range(0.08, 0.5))
			var blen: int = int(rng.randf_range(0.04, 0.10) * h)
			var dir: int = 1 if rng.randf() > 0.5 else -1
			for k in blen:
				_px(img, cx + dir * k, by - k / 2, trunk)


# 给 3 个 layer 用的颜色列表 (FAR / MID / NEAR)
static func all_colors() -> Array[Color]:
	return [COLOR_FAR, COLOR_MID, COLOR_NEAR]
