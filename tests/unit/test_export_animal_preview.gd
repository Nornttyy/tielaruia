# 把动物像素图导出 PNG 到 /tmp/ 用户预览 (不需要打开游戏窗口)
extends GutTest

func test_export_animal_pngs():
	for entry in [
		{"name": "cow", "frames": ArtCache.cow_frames},
		{"name": "sheep", "frames": ArtCache.sheep_frames},
		{"name": "pig", "frames": ArtCache.pig_frames},
	]:
		var frames: SpriteFrames = entry.frames
		# 导出 idle 第 0 帧
		var tex: Texture2D = frames.get_frame_texture("idle", 0)
		var img: Image = tex.get_image()
		# 放大 4 倍方便看
		img.resize(img.get_width() * 4, img.get_height() * 4, Image.INTERPOLATE_NEAREST)
		var path := "/tmp/preview_%s.png" % entry.name
		img.save_png(path)
		print("[preview] saved %s (%dx%d)" % [path, img.get_width(), img.get_height()])
	assert_true(true, "preview exported")
