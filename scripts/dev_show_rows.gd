extends SceneTree

func _init() -> void:
	var tex: Texture2D = load("res://assets/animals/cow_lpc.png")
	var src: Image = tex.get_image()
	# 把 4 行各取第 1 帧, 横向拼起来
	var w := 128 * 4 + 9
	var combined := Image.create(w, 128, false, Image.FORMAT_RGBA8)
	combined.fill(Color(0.6, 0.7, 0.5, 1))
	for row in 4:
		var cell := src.get_region(Rect2i(0, row * 128, 128, 128))
		combined.blit_rect(cell, Rect2i(0, 0, 128, 128), Vector2i(row * (128 + 3), 0))
	combined.resize(combined.get_width() * 2, combined.get_height() * 2, Image.INTERPOLATE_NEAREST)
	combined.save_png("/tmp/lpc_rows.png")
	print("saved")
	quit()
