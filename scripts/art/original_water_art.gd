# 原图第 0 格为静水，第 1–16 格为连续动画；第二行只放水体，不重复画水面。
extends RefCounted
const FRAMES := 16
const FRAME_SECONDS := 0.10
static func atlas(level: int = 8, style: int = 0) -> ImageTexture:
	var texture: Texture2D = load("res://assets/terraria_1449/Liquid_%d.png" % style)
	var source := texture.get_image()
	source.convert(Image.FORMAT_RGBA8)
	var result := Image.create(FRAMES * 16, 32, false, Image.FORMAT_RGBA8)
	var height := clampi(level, 1, 8) * 2
	for f in FRAMES:
		for y in height:
			for x in 16:
				var surface := source.get_pixel((f + 1) * 18 + x, y)
				surface.a *= 0.58
				result.set_pixel(f * 16 + x, 16 - height + y, surface)
				var body := source.get_pixel((f + 1) * 18 + x, 12)
				body.a *= 0.58
				result.set_pixel(f * 16 + x, 32 - height + y, body)
	return ImageTexture.create_from_image(result)
