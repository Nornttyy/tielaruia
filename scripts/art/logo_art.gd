# teilaruia LOGO 样式: 配置 Label 的字号/颜色/描边/阴影。
# MainMenu 用两个 Label (阴影层 + 主层) 实现 LOGO 视觉。
extends RefCounted

const TEXT := "teilaruia"
const FONT_SIZE := 88
const COLOR_MAIN := Color8(255, 220, 130)       # 亮金黄
const COLOR_OUTLINE := Color8(80, 36, 16)       # 深棕描边 (略深)
const COLOR_SHADOW := Color8(0, 0, 0, 200)      # 阴影
const OUTLINE_PX := 4                            # 描边粗细
const SHADOW_OFFSET := Vector2(5, 5)             # 阴影位移


# 应用到主 Label：金黄 + 深棕描边
static func style_main_label(label: Label) -> void:
	label.text = TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_MAIN)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_PX)


# 应用到阴影 Label：黑色半透明，无描边，位置 offset
static func style_shadow_label(label: Label) -> void:
	label.text = TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_SHADOW)
