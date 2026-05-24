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


# 给 3 个 layer 用的颜色列表 (FAR / MID / NEAR)
static func all_colors() -> Array[Color]:
	return [COLOR_FAR, COLOR_MID, COLOR_NEAR]
