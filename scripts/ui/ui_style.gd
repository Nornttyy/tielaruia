# 统一蓝色 UI 皮肤 (用户要求全界面蓝色圆角). 各面板共用 → 改一处全局一致.
# 用法: const UIStyle = preload("res://scripts/ui/ui_style.gd"); UIStyle.slot() / UIStyle.panel() / UIStyle.style_button(btn)
extends RefCounted

const SLOT_BG := Color(0.07, 0.125, 0.227, 0.80)
const SLOT_BORDER := Color(0.275, 0.47, 0.706, 1.0)
const PANEL_BG := Color(0.055, 0.10, 0.18, 0.94)
const PANEL_BORDER := Color(0.28, 0.47, 0.71, 1.0)
const C_BTN := Color(0.135, 0.23, 0.39)        # 普通按钮蓝
const C_BTN_HOVER := Color(0.21, 0.38, 0.61)   # 悬停亮蓝
const C_BTN_PRESS := Color(0.09, 0.16, 0.29)   # 按下暗
const C_BTN_SEL := Color(0.30, 0.55, 0.85)     # 选中 (toggle 按下) 高亮蓝
const C_TEXT := Color(0.75, 0.88, 0.99)
const C_TEXT_HI := Color(0.95, 0.98, 1.0)


static func _sb(bg: Color, border: Color, radius: int, bw: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.border_width_left = bw
	s.border_width_top = bw
	s.border_width_right = bw
	s.border_width_bottom = bw
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	return s


# 蓝色圆角槽 (背包/箱子/合成格)
static func slot(bg: Color = SLOT_BG, border: Color = SLOT_BORDER) -> StyleBoxFlat:
	return _sb(bg, border, 7, 2)


# 蓝色圆角面板背景 (合成/箱子/暂停/对话框)
static func panel() -> StyleBoxFlat:
	var s := _sb(PANEL_BG, PANEL_BORDER, 12, 2)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 14
	s.content_margin_bottom = 14
	return s


static func _btn_box(bg: Color, radius: int = 10) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 7
	s.content_margin_bottom = 7
	return s


# 普通动作按钮: 蓝, 悬停亮, 按下暗 (无边框圆角)
static func style_button(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn_box(C_BTN))
	btn.add_theme_stylebox_override("hover", _btn_box(C_BTN_HOVER))
	btn.add_theme_stylebox_override("pressed", _btn_box(C_BTN_PRESS))
	btn.add_theme_stylebox_override("focus", _btn_box(C_BTN_HOVER))
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TEXT_HI)
	btn.add_theme_color_override("font_pressed_color", C_TEXT)


# 开关按钮 (难度/模式选中态用 button_pressed): 选中=亮蓝高亮
static func style_toggle(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _btn_box(C_BTN, 8))
	btn.add_theme_stylebox_override("hover", _btn_box(C_BTN_HOVER, 8))
	# 选中 (toggle on) = pressed stylebox → 用高亮亮蓝, 一眼看出选了哪个
	var sel := _btn_box(C_BTN_SEL, 8)
	sel.border_color = C_TEXT_HI
	sel.border_width_left = 2
	sel.border_width_top = 2
	sel.border_width_right = 2
	sel.border_width_bottom = 2
	btn.add_theme_stylebox_override("pressed", sel)
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TEXT_HI)
	btn.add_theme_color_override("font_pressed_color", C_TEXT_HI)


static func _input_box(bg: Color, border: Color) -> StyleBoxFlat:
	var s := _sb(bg, border, 7, 2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


# 输入框 (名字/种子/房间码): 蓝色圆角 + 聚焦亮边
static func style_line_edit(le: LineEdit) -> void:
	le.add_theme_stylebox_override("normal", _input_box(SLOT_BG, SLOT_BORDER))
	le.add_theme_stylebox_override("focus", _input_box(Color(0.10, 0.18, 0.30, 0.92), C_BTN_SEL))
	le.add_theme_color_override("font_color", C_TEXT_HI)
	le.add_theme_color_override("font_placeholder_color", Color(0.5, 0.62, 0.78))
	le.add_theme_color_override("caret_color", C_TEXT_HI)


# 滑条 (音量/镜头): 轨道蓝色 (grabber 保留默认圆点)
static func style_slider(sl: Control) -> void:
	sl.add_theme_stylebox_override("slider", _sb(SLOT_BG, SLOT_BORDER, 4, 1))


# 小提示框 ("按 E" 那种世界跟随提示): 蓝色圆角小底
static func prompt_box() -> StyleBoxFlat:
	var s := _sb(Color(0.06, 0.10, 0.18, 0.85), PANEL_BORDER, 7, 2)
	s.content_margin_left = 8
	s.content_margin_right = 8
	s.content_margin_top = 3
	s.content_margin_bottom = 3
	return s
