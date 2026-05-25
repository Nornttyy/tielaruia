extends SceneTree

func _init() -> void:
	for animal in ["cow", "pig", "sheep"]:
		var src := Image.load_from_file("/tmp/lpc/%s_walk.png" % animal)
		# 第 2 行 (y=128-255), 4 帧右朝向侧视
		# 原图 32x32 大小
		var combined := Image.create(32 * 4 + 12, 32, false, Image.FORMAT_RGBA8)
		combined.fill(Color(0.6, 0.7, 0.5, 1))
		for i in 4:
			# 从 512x512 大图取每帧, 实际内容只占 32x32 (中间位置)
			# LPC 64x64 标准, 这里 512/4=128 frame, 中心 32x32 区
			var frame_x := i * 128
			var frame_y := 128  # 第 2 行
			# 取整个 128x128 cell, 自动裁透明 (内容居中后缩到 32x32)
			var sub := src.get_region(Rect2i(frame_x, frame_y, 128, 128))
			sub = _autocrop(sub)
			# 等比缩到高 32 (保留比例 — 牛/猪可能更宽)
			var ratio: float = 32.0 / float(sub.get_height())
			var nw: int = int(round(float(sub.get_width()) * ratio))
			sub.resize(nw, 32, Image.INTERPOLATE_LANCZOS)
			# 居中放到 32x32 cell
			var cell := Image.create(32, 32, false, Image.FORMAT_RGBA8)
			cell.blit_rect(sub, Rect2i(0, 0, min(nw, 32), 32), Vector2i((32 - min(nw, 32)) / 2, 0))
			sub = cell
			combined.blit_rect(sub, Rect2i(0, 0, 32, 32), Vector2i(i * (32 + 3), 0))
		combined.resize(combined.get_width() * 4, combined.get_height() * 4, Image.INTERPOLATE_NEAREST)
		combined.save_png("/tmp/lpc_%s_ingame.png" % animal)
		print("done %s" % animal)
	quit()


func _autocrop(img: Image) -> Image:
	var w := img.get_width()
	var h := img.get_height()
	var x0 := w; var x1 := 0; var y0 := h; var y1 := 0
	for y in h:
		for x in w:
			if img.get_pixel(x, y).a > 0.05:
				if x < x0: x0 = x
				if x > x1: x1 = x
				if y < y0: y0 = y
				if y > y1: y1 = y
	if x0 > x1 or y0 > y1:
		return img
	return img.get_region(Rect2i(x0, y0, x1 - x0 + 1, y1 - y0 + 1))
