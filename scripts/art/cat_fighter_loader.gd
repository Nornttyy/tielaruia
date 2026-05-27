# Cat Fighter sprite loader (用作 jaguar 的视觉).
# 来源: opengameart.org/content/cat-fighter-sprite-sheet by dogchicken (CC-BY 3.0)
# 见 LICENSES.md.
#
# 原图: 500×500, 10×10 grid 50×50 每帧. 行布局:
#   row 0: idle (静止)
#   row 1: walk (4 帧)
#   ... (其它行: jump/attack/death, 暂不用)
#
# 实际行可能不完全对, 用户看到不对再调.
extends RefCounted

const SHEET_PATH := "res://assets/animals/cat_fighter.png"
const CELL := 50


static func build_sprite_frames(scale: float = 0.4) -> SpriteFrames:
	var tex: Texture2D = load(SHEET_PATH)
	if tex == null:
		push_error("CatFighter load failed: %s" % SHEET_PATH)
		return null
	var img: Image = tex.get_image()
	if img == null:
		return null
	var sf := SpriteFrames.new()
	# idle: 第 0 行第 0 帧 (单帧)
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", _make_frame(img, 0, 0, scale))
	# walk: 第 1 行 4 帧
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_loop("walk", true)
	for col in 4:
		sf.add_frame("walk", _make_frame(img, col, 1, scale))
	# hurt: 复用 idle (短期占位)
	sf.add_animation("hurt")
	sf.set_animation_speed("hurt", 5.0)
	sf.set_animation_loop("hurt", true)
	sf.add_frame("hurt", _make_frame(img, 0, 0, scale))
	return sf


# 从 sheet 取 (col, row) 那一帧, autocrop + scale
static func _make_frame(img: Image, col: int, row: int, scale: float) -> ImageTexture:
	var cell := img.get_region(Rect2i(col * CELL, row * CELL, CELL, CELL))
	cell = _autocrop(cell)
	if scale != 1.0 and cell.get_width() > 0:
		var nw: int = max(1, int(round(float(cell.get_width()) * scale)))
		var nh: int = max(1, int(round(float(cell.get_height()) * scale)))
		cell.resize(nw, nh, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(cell)


# 去掉四周透明边
static func _autocrop(src: Image) -> Image:
	var w: int = src.get_width()
	var h: int = src.get_height()
	var min_x: int = w; var min_y: int = h
	var max_x: int = -1; var max_y: int = -1
	for y in h:
		for x in w:
			if src.get_pixel(x, y).a > 0.01:
				if x < min_x: min_x = x
				if y < min_y: min_y = y
				if x > max_x: max_x = x
				if y > max_y: max_y = y
	if max_x < 0:
		return src   # 全透明, 返回原图
	var bw: int = max_x - min_x + 1
	var bh: int = max_y - min_y + 1
	var out := Image.create(bw, bh, false, Image.FORMAT_RGBA8)
	out.blit_rect(src, Rect2i(min_x, min_y, bw, bh), Vector2i.ZERO)
	return out
