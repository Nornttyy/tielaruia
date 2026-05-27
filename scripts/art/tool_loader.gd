# 通用 tool sprite loader. 共享 base PNG, 按 tier 染色 (sword / pickaxe / axe).
# Sword: opengameart.org/content/pixel-sword-1 (CC-BY 3.0)
# Pickaxe: opengameart.org/content/tools-icons-0 (CC0)
# 见 LICENSES.md.
#
# 染色策略 (同 sword_loader):
# - "金属头" (浅色, RGB 接近且亮) → luminance × tier 色重染
# - "把手" (其它色, 通常褐色木把) → 保留原色
extends RefCounted

const SWORD_PATH := "res://assets/items/sword_base.png"
const PICKAXE_PATH := "res://assets/items/pickaxe_base.png"

# 6 tier 的金属头色 (新加 copper)
const TIER_COLORS := {
	"wood":    Color8(170, 120, 75),
	"stone":   Color8(155, 155, 155),
	"copper":  Color8(210, 120, 60),   # 铜橙红
	"iron":    Color8(210, 215, 225),
	"gold":    Color8(240, 215, 90),
	"diamond": Color8(140, 230, 255),
}


# tool_kind: "sword" or "pickaxe" (后续可加 axe)
static func build_icon(tool_kind: String, tier: String) -> ImageTexture:
	var path: String
	match tool_kind:
		"sword": path = SWORD_PATH
		"pickaxe": path = PICKAXE_PATH
		_:
			push_error("unknown tool_kind: %s" % tool_kind)
			return null
	var tex: Texture2D = load(path)
	if tex == null:
		push_error("tool sheet missing: %s" % path)
		return null
	var img: Image = tex.get_image().duplicate()
	var head_color: Color = TIER_COLORS.get(tier, Color.WHITE)
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			# 判 "金属头": 浅色 + 三通道接近 (灰白系)
			var max_rgb: float = max(c.r, max(c.g, c.b))
			var min_rgb: float = min(c.r, min(c.g, c.b))
			var is_head: bool = (max_rgb - min_rgb < 0.25) and (max_rgb > 0.55)
			if is_head:
				var lum: float = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114)
				img.set_pixel(x, y, Color(head_color.r * lum, head_color.g * lum, head_color.b * lum, c.a))
	return ImageTexture.create_from_image(img)
