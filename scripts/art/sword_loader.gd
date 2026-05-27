# Sword sprite loader. 共享一张 base PNG (120×120), 不同 tier 染不同色.
# 来源: opengameart.org/content/pixel-sword-1 (CC-BY 3.0). 见 LICENSES.md.
#
# 染色策略:
# - 红色 (R 远大于 G+B) → 把手, 各 tier 都保留红 (统一外观)
# - 白/浅色 (RGB 高且相近) → 刀刃, 按 tier 替换
extends RefCounted

const SHEET_PATH := "res://assets/items/sword_base.png"

# 各 tier 的"刀刃"色 (蒸发原色亮度后用此色 multiply)
const TIER_COLORS := {
	"wood": Color8(170, 120, 75),     # 棕木刃
	"stone": Color8(155, 155, 155),   # 石灰
	"iron": Color8(210, 215, 225),    # 银白 (近原色)
	"gold": Color8(240, 215, 90),     # 金黄
	"diamond": Color8(140, 230, 255), # 钻石冰蓝
}


static func build_icon(tier: String) -> ImageTexture:
	var tex: Texture2D = load(SHEET_PATH)
	if tex == null:
		push_error("sword base sheet missing: %s" % SHEET_PATH)
		return null
	var img: Image = tex.get_image().duplicate()
	var blade_color: Color = TIER_COLORS.get(tier, Color.WHITE)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			# 判断是不是 "刀刃" (白/浅色, R≈G≈B 且都 >0.55)
			var max_rgb: float = max(c.r, max(c.g, c.b))
			var min_rgb: float = min(c.r, min(c.g, c.b))
			var is_blade: bool = (max_rgb - min_rgb < 0.25) and (max_rgb > 0.55)
			if is_blade:
				# 用 luminance × blade_color 替换 (保留明暗)
				var lum: float = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
				img.set_pixel(x, y, Color(blade_color.r * lum, blade_color.g * lum, blade_color.b * lum, c.a))
			# 红色 (把手) 保持
	return ImageTexture.create_from_image(img)
