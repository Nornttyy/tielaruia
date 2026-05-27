# 通用 tool sprite loader. 共享 base PNG, 按 tier 染色 (sword / pickaxe / axe).
# Sword: opengameart.org/content/pixel-sword-1 (CC-BY 3.0)
# Pickaxe: opengameart.org/content/tools-icons-0 (CC0)
# Axe: opengameart.org/content/pixel-pickaxe-and-axe (CC0), 取左半 = 斧
# 见 LICENSES.md.
extends RefCounted

const SWORD_PATH := "res://assets/items/sword_base.png"
const PICKAXE_PATH := "res://assets/items/pickaxe_base.png"
const AXE_PATH := "res://assets/items/axe_and_pickaxe.png"   # 64x64, 左半=斧 右半=镐

# 6 tier 的金属头色 (新加 copper)
const TIER_COLORS := {
	"wood":    Color8(170, 120, 75),
	"stone":   Color8(155, 155, 155),
	"copper":  Color8(210, 120, 60),
	"iron":    Color8(190, 195, 205),    # 铁: 偏暗银灰 (跟 silver 区分)
	"silver":  Color8(240, 245, 255),    # 银: 亮银白 (比铁亮一档)
	"gold":    Color8(240, 215, 90),
	"diamond": Color8(140, 230, 255),
}


static func build_icon(tool_kind: String, tier: String) -> ImageTexture:
	var path: String
	var crop_left_half: bool = false   # axe: 取左半 (PNG 同时含斧+镐)
	match tool_kind:
		"sword": path = SWORD_PATH
		"pickaxe": path = PICKAXE_PATH
		"axe":
			path = AXE_PATH
			crop_left_half = true
		_:
			push_error("unknown tool_kind: %s" % tool_kind)
			return null
	var tex: Texture2D = load(path)
	if tex == null:
		push_error("tool sheet missing: %s" % path)
		return null
	var img: Image = tex.get_image().duplicate()
	if crop_left_half:
		var w: int = img.get_width()
		var h: int = img.get_height()
		var left := Image.create(w / 2, h, false, Image.FORMAT_RGBA8)
		left.blit_rect(img, Rect2i(0, 0, w / 2, h), Vector2i.ZERO)
		img = left
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
