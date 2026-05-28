# 魔力 HUD: 长方形条 + 数字. 显示在 HealthHUD 下方.
# 蓝紫色条, 用色跟魔晶呼应.
extends Control

const BAR_WIDTH := 120.0
const BAR_HEIGHT := 12.0
const BORDER_PX := 1.0
const TEXT_FONT_SIZE := 12
const PAD := 8

const COLOR_BORDER := Color8(20, 15, 45)
const COLOR_EMPTY := Color8(35, 25, 75)
const COLOR_FILL := Color8(110, 90, 220)
const COLOR_HIGHLIGHT := Color8(180, 165, 255)

var _cur: int = 100
var _max: int = 100
var _mana_label: Label


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + PAD * 2, BAR_HEIGHT + 20.0)
	_mana_label = Label.new()
	_mana_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_mana_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	_mana_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_mana_label.add_theme_constant_override("shadow_offset_x", 1)
	_mana_label.add_theme_constant_override("shadow_offset_y", 1)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mana_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mana_label.offset_left = -120.0
	_mana_label.offset_right = -PAD
	_mana_label.offset_top = 0.0
	_mana_label.offset_bottom = 16.0
	add_child(_mana_label)
	_update_label()


func bind(mana_node: Node) -> void:
	if mana_node == null:
		return
	if mana_node.has_signal("mana_changed"):
		mana_node.mana_changed.connect(_on_changed)
	_on_changed(mana_node.current_mana, mana_node.MAX_MANA)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	_update_label()
	queue_redraw()


func _update_label() -> void:
	if _mana_label != null:
		_mana_label.text = "%d / %d" % [_cur, _max]


func _draw() -> void:
	var bar_x: float = PAD
	var bar_y: float = 16.0   # label 在上, 条在下
	# 边框
	draw_rect(Rect2(bar_x - BORDER_PX, bar_y - BORDER_PX, BAR_WIDTH + BORDER_PX * 2, BAR_HEIGHT + BORDER_PX * 2), COLOR_BORDER)
	# 空底
	draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH, BAR_HEIGHT), COLOR_EMPTY)
	# 填充
	var frac: float = 0.0
	if _max > 0:
		frac = clamp(float(_cur) / float(_max), 0.0, 1.0)
	if frac > 0.0:
		draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH * frac, BAR_HEIGHT), COLOR_FILL)
		# 顶部 2px 高光
		draw_rect(Rect2(bar_x, bar_y, BAR_WIDTH * frac, 2.0), COLOR_HIGHLIGHT)
