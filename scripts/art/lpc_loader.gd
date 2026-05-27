# LPC 风格动物 sprite sheet 加载器.
# 原图: 512×512 共 16 帧 (4 方向 × 4 帧), 每帧 128×128 cell.
# LPC 行布局: row 0=up, row 1=left, row 2=down, row 3=right.
# 我们只用右朝向 (row 3, y=384..511); flip_h 在 AnimatedSprite2D 处理左朝向.
#
# 思路: 对 4 帧分别 autocrop, 然后找"4 帧合集"的最大包围盒,
# 把每帧 paste 到这个统一尺寸的画布上 (居中+底对齐) → 4 帧大小一致, 无 jitter.
#
# 许可: LPC farm animals by Daniel Eddeland (opengameart.org/content/lpc-style-farm-animals)
# CC-BY 3.0. 见 LICENSES.md.
extends RefCounted


# 通用 LPC 行加载: 任意 cell_size + 任意 row + 任意 frame 数.
# 用于非标准 LPC sheet (如 lpc_animals 包 64x64 5×4 布局).
static func load_lpc_row(sheet_path: String, cell_size: int, row: int, num_frames: int, scale: float = 1.0) -> Array:
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		push_error("LPC load failed: %s" % sheet_path)
		return []
	var img: Image = tex.get_image()
	if img == null:
		return []
	var cropped: Array = []
	for i in num_frames:
		var cell := img.get_region(Rect2i(i * cell_size, row * cell_size, cell_size, cell_size))
		cropped.append(_autocrop(cell))
	var max_w := 0
	var max_h := 0
	for c in cropped:
		max_w = max(max_w, c.get_width())
		max_h = max(max_h, c.get_height())
	var frames: Array = []
	for c in cropped:
		var canvas := Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
		var dx: int = (max_w - c.get_width()) / 2
		var dy: int = max_h - c.get_height()
		canvas.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(dx, dy))
		if scale != 1.0:
			var nw: int = max(1, int(round(float(max_w) * scale)))
			var nh: int = max(1, int(round(float(max_h) * scale)))
			canvas.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		frames.append(ImageTexture.create_from_image(canvas))
	return frames


# 加载某 LPC sheet 的右朝向 4 帧, 返回 Array[ImageTexture] (4 帧大小一致).
# scale: 1.0 = 原大 (~70 px), 0.7 = 缩到 ~50 px (适合游戏 tile 16 px 比例).
static func load_side_frames(sheet_path: String, scale: float = 1.0) -> Array:
	var tex: Texture2D = load(sheet_path)
	if tex == null:
		push_error("LPC load failed: %s" % sheet_path)
		return []
	var img: Image = tex.get_image()
	if img == null:
		push_error("LPC sheet no image: %s" % sheet_path)
		return []
	# 1) 取 row 3 (右朝向) 4 帧, autocrop 每帧
	var cropped: Array = []
	for i in 4:
		var cell := img.get_region(Rect2i(i * 128, 384, 128, 128))
		cropped.append(_autocrop(cell))
	# 2) 找 max w/h
	var max_w := 0
	var max_h := 0
	for c in cropped:
		max_w = max(max_w, c.get_width())
		max_h = max(max_h, c.get_height())
	# 3) 每帧居中+底对齐到统一 max_w × max_h 画布
	var frames: Array = []
	for c in cropped:
		var canvas := Image.create(max_w, max_h, false, Image.FORMAT_RGBA8)
		var dx: int = (max_w - c.get_width()) / 2
		var dy: int = max_h - c.get_height()  # 底对齐
		canvas.blit_rect(c, Rect2i(0, 0, c.get_width(), c.get_height()), Vector2i(dx, dy))
		# 4) 缩放 (NEAREST 保像素感)
		if scale != 1.0:
			var nw: int = max(1, int(round(float(max_w) * scale)))
			var nh: int = max(1, int(round(float(max_h) * scale)))
			canvas.resize(nw, nh, Image.INTERPOLATE_NEAREST)
		frames.append(ImageTexture.create_from_image(canvas))
	return frames


# 用 walk 第 0 帧建 idle, walk 4 帧建 walk. 返回标准 SpriteFrames.
static func build_sprite_frames(sheet_path: String, scale: float = 1.0) -> SpriteFrames:
	var walk_frames := load_side_frames(sheet_path, scale)
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	if walk_frames.size() > 0:
		sf.add_frame("idle", walk_frames[0])
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_loop("walk", true)
	for tex in walk_frames:
		sf.add_frame("walk", tex)
	return sf


# 裁掉四周完全透明像素, 返回紧凑后的 Image. 全透明输入 → 返回原图.
static func _autocrop(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w; var x1 := -1; var y0 := h; var y1 := -1
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.05:
				if x < x0: x0 = x
				if x > x1: x1 = x
				if y < y0: y0 = y
				if y > y1: y1 = y
	if x1 < 0 or y1 < 0:
		return img
	return img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
