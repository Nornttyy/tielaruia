# 独立脚本: godot --headless --path . -s scripts/dev_export_animals.gd
# 不依赖 GUT, 直接导出 cow/sheep/pig 像素图 PNG 到 /tmp/
extends SceneTree

const CowArt = preload("res://scripts/art/cow_art.gd")
const SheepArt = preload("res://scripts/art/sheep_art.gd")
const PigArt = preload("res://scripts/art/pig_art.gd")


func _init() -> void:
	for entry in [
		{"name": "cow", "frames": CowArt.build_sprite_frames()},
		{"name": "sheep", "frames": SheepArt.build_sprite_frames()},
		{"name": "pig", "frames": PigArt.build_sprite_frames()},
	]:
		var frames: SpriteFrames = entry.frames
		# 拼 idle 第 0 帧 + walk 两帧 → 三联图横向, 放大 4x
		var imgs: Array = []
		imgs.append(frames.get_frame_texture("idle", 0).get_image())
		var walk_count: int = frames.get_frame_count("walk")
		if walk_count > 0:
			imgs.append(frames.get_frame_texture("walk", 0).get_image())
		if walk_count > 1:
			imgs.append(frames.get_frame_texture("walk", walk_count / 2).get_image())
		var w: int = 0
		var h: int = 0
		for img in imgs:
			w += img.get_width() + 2
			h = max(h, img.get_height())
		var combined := Image.create(w, h, false, Image.FORMAT_RGBA8)
		combined.fill(Color(0.6, 0.7, 0.5, 1))  # 草绿背景方便看轮廓
		var x: int = 0
		for img in imgs:
			combined.blit_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i(x, h - img.get_height()))
			x += img.get_width() + 2
		# 放大 4 倍
		combined.resize(combined.get_width() * 4, combined.get_height() * 4, Image.INTERPOLATE_NEAREST)
		var path := "/tmp/preview_%s.png" % entry.name
		combined.save_png(path)
		print("saved %s (%dx%d)" % [path, combined.get_width(), combined.get_height()])
	quit()
