# 云贴图程序生成。3 种形状 × 3 种颜色 = 9 种缓存纹理。
extends RefCounted

# 颜色：白 / 浅灰 / 中灰，对应近 / 中 / 远 层
const COLOR_NEAR := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_MID  := Color(0.92, 0.94, 0.96, 0.75)
const COLOR_FAR  := Color(0.78, 0.82, 0.86, 0.55)

const SHAPE_FLAT := 0
const SHAPE_PUFF := 1
const SHAPE_LONG := 2


# 形状定义：每个 [(x, y, w, h)] 矩形列表组成一朵云的几个圆/块
# 简化做法：直接画几个 ellipse-like 矩形拼凑
const _SHAPES := {
	SHAPE_FLAT: {  # 水平拉长，8x4
		"size": Vector2i(8, 4),
		"rects": [
			Rect2i(1, 1, 6, 2),
			Rect2i(0, 2, 8, 1),
		],
	},
	SHAPE_PUFF: {  # 蓬松，12x6
		"size": Vector2i(12, 6),
		"rects": [
			Rect2i(2, 1, 8, 4),
			Rect2i(0, 3, 12, 2),
			Rect2i(4, 0, 4, 1),
		],
	},
	SHAPE_LONG: {  # 长条三段，16x5
		"size": Vector2i(16, 5),
		"rects": [
			Rect2i(0, 2, 6, 2),
			Rect2i(5, 1, 7, 3),
			Rect2i(11, 2, 5, 2),
		],
	},
}


static func get_texture(shape: int, color: Color) -> ImageTexture:
	var data: Dictionary = _SHAPES[shape]
	var size: Vector2i = data.size
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for rect in data.rects:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if x >= 0 and x < size.x and y >= 0 and y < size.y:
					img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func all_shapes() -> Array:
	return [SHAPE_FLAT, SHAPE_PUFF, SHAPE_LONG]


static func all_colors() -> Array:
	return [COLOR_NEAR, COLOR_MID, COLOR_FAR]
