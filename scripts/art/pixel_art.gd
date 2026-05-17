# 像素画工具：把 ASCII 网格 + 调色板转成 ImageTexture / SpriteFrames。
#
# 用法：
#   const P = {"G": Color8(76,175,80), ".": Color(0,0,0,0)}
#   var frames = [["GGGG", "GGGG"], ["GGGG", "....."]]  # 注意各帧宽度需一致
#   const PixelArt = preload("res://scripts/art/pixel_art.gd")
#   var sf = PixelArt.build_sprite_frames({"idle": {"frames": frames, "fps": 4.0}}, P)
extends RefCounted


static func grid_to_image(rows: Array, palette: Dictionary) -> Image:
	var h: int = rows.size()
	assert(h > 0, "rows 不能为空")
	var w: int = (rows[0] as String).length()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for y in range(h):
		var row: String = rows[y]
		assert(row.length() == w, "第 %d 行宽度 %d 与首行 %d 不一致" % [y, row.length(), w])
		for x in range(w):
			var ch: String = row.substr(x, 1)
			if palette.has(ch):
				img.set_pixel(x, y, palette[ch])
	return img


static func grid_to_texture(rows: Array, palette: Dictionary) -> ImageTexture:
	return ImageTexture.create_from_image(grid_to_image(rows, palette))


# animations: { anim_name: { "frames": [grid, grid, ...], "fps": float (optional), "loop": bool (optional) } }
static func build_sprite_frames(animations: Dictionary, palette: Dictionary, default_fps: float = 8.0) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for anim_name in animations.keys():
		var entry: Dictionary = animations[anim_name]
		var frames: Array = entry["frames"]
		var fps: float = entry.get("fps", default_fps)
		var loop: bool = entry.get("loop", true)
		sf.add_animation(anim_name)
		sf.set_animation_speed(anim_name, fps)
		sf.set_animation_loop(anim_name, loop)
		for frame_rows in frames:
			sf.add_frame(anim_name, grid_to_texture(frame_rows, palette))
	return sf


# 在像素画外加 1px 透明边框（防止 TileSet/Sprite 边缘采样溢出）。
static func pad_texture(tex: ImageTexture, pad: int = 1) -> ImageTexture:
	var src: Image = tex.get_image()
	var w := src.get_width() + pad * 2
	var h := src.get_height() + pad * 2
	var dst := Image.create(w, h, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	dst.blit_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(pad, pad))
	return ImageTexture.create_from_image(dst)
