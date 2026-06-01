# 一次性: 渲染 蓝史莱姆 idle/hop + 新床, 放大存 PNG 供目视.
extends SceneTree
const PixelArt = preload("res://scripts/art/pixel_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const Z := 10

func _init() -> void:
	var imgs: Array = []
	# 史莱姆 idle + hop 两帧 (用 SlimeArt 内部 build)
	var sf: SpriteFrames = SlimeArt.build_sprite_frames()
	imgs.append(["slime_idle", sf.get_frame_texture("idle", 0).get_image()])
	imgs.append(["slime_hop", sf.get_frame_texture("hop", 2).get_image()])
	imgs.append(["bed", BlocksArt.get_texture(BlocksArt.BED).get_image()])
	var pad := 8
	var cellw := 16 * Z
	var sheet := Image.create(imgs.size() * (cellw + pad) + pad, cellw + pad * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(60, 64, 72))
	for i in imgs.size():
		var src: Image = imgs[i][1]
		src.resize(src.get_width() * Z, src.get_height() * Z, Image.INTERPOLATE_NEAREST)
		var x := pad + i * (cellw + pad)
		sheet.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, pad))
		print("[%d] %s  %dx%d" % [i, imgs[i][0], imgs[i][1].get_width(), imgs[i][1].get_height()])
	sheet.save_png("/tmp/art_preview/verify.png")
	print("saved /tmp/art_preview/verify.png")
	quit()
