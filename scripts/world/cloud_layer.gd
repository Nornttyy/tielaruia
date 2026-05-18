# 视差云层。挂在 World 下，3 个 ParallaxLayer (远/中/近)。
# 每个 layer 内 5-8 朵云，自滚动；出屏 wrap。
extends ParallaxBackground

const CloudsArt = preload("res://scripts/fx/clouds_art.gd")

# 每层 [motion_scale, scroll_speed, cloud_count, color_index]
const _LAYERS := [
	{"motion_scale": 0.2, "speed": 6.0,  "count": 6, "color_idx": 2},  # 远，COLOR_FAR
	{"motion_scale": 0.5, "speed": 14.0, "count": 5, "color_idx": 1},  # 中
	{"motion_scale": 0.8, "speed": 26.0, "count": 4, "color_idx": 0},  # 近
]
const WORLD_WIDTH_PX := 1024 * 16  # 16384
const SKY_Y_TOP := -200          # 云出现的 y 范围（玩家头顶之上）
const SKY_Y_BOTTOM := 200


var _cloud_data: Array = []  # 每朵 {sprite, speed, wrap_width}


func _ready() -> void:
	for layer_def in _LAYERS:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(layer_def.motion_scale, layer_def.motion_scale * 0.2)
		# 极大 mirroring 让云在任何相机位置都能见
		pl.motion_mirroring = Vector2(2000, 0)
		add_child(pl)
		for i in layer_def.count:
			var shape_options: Array = CloudsArt.all_shapes()
			var color_options: Array = CloudsArt.all_colors()
			var shape: int = shape_options[randi() % shape_options.size()]
			var color: Color = color_options[layer_def.color_idx]
			var sprite := Sprite2D.new()
			sprite.texture = CloudsArt.get_texture(shape, color)
			sprite.centered = false
			sprite.position = Vector2(
				randf_range(0, 2000),
				randf_range(SKY_Y_TOP, SKY_Y_BOTTOM)
			)
			pl.add_child(sprite)
			_cloud_data.append({
				"sprite": sprite,
				"speed": layer_def.speed,
				"wrap_width": 2000.0,
			})


func _process(delta: float) -> void:
	for c in _cloud_data:
		c.sprite.position.x += c.speed * delta
		if c.sprite.position.x > c.wrap_width:
			c.sprite.position.x -= c.wrap_width + c.sprite.texture.get_width()


func layer_count() -> int:
	# 仅算 ParallaxLayer 子节点
	var n := 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
