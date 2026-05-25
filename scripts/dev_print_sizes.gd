extends SceneTree

const LpcLoader = preload("res://scripts/art/lpc_loader.gd")

func _init() -> void:
	for entry in [
		{"name": "cow", "path": "res://assets/animals/cow_lpc.png", "scale": 0.6},
		{"name": "sheep", "path": "res://assets/animals/sheep_lpc.png", "scale": 0.6},
		{"name": "pig", "path": "res://assets/animals/pig_lpc.png", "scale": 0.55},
	]:
		var scale: float = entry.get("scale", 1.0)
		var frames = LpcLoader.load_side_frames(entry.path, scale)
		if frames.size() > 0:
			var tex: Texture2D = frames[0]
			print("%s: %dx%d  (half_w=%d, neg_h=%d)" % [entry.name, tex.get_width(), tex.get_height(), tex.get_width() / 2, -tex.get_height()])
	quit()
