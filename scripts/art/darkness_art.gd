# 黑暗瓦片图集: 8 个 16x16 不同 alpha 的纯黑方块, 给 DarknessLayer 用。
# level 0 = 全黑 (alpha 1.0), level 7 = 透明 (不画 = 满亮)。
# 调用方按 light_value (0..7) 选对应的纹理。
extends RefCounted

# alpha 阶梯: 0 = 满黑, 15 = 全透。16 级让暗→亮过渡更顺滑。
const LEVELS := 16


static func get_texture(level: int) -> ImageTexture:
	var clamped: int = clampi(level, 0, LEVELS - 1)
	var alpha: float = 1.0 - float(clamped) / float(LEVELS - 1)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, alpha))
	return ImageTexture.create_from_image(img)


# 返回 8 个等级的纹理数组. index 0 = 全黑, 7 = 透明.
static func all_textures() -> Array:
	var out: Array = []
	for i in LEVELS:
		out.append(get_texture(i))
	return out
