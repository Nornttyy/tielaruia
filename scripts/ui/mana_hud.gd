# 经典魔力显示：使用原版 22×24 星形，按 26px 步长纵向排列。
extends Control
const UI = preload("res://scripts/ui/classic_ui.gd")
const MANA_PER_STAR := 20
const STARS_PER_COL := 10
const STAR_SLOT_PX := 24
const STAR_SPACING := 2
var _cur := 100
var _max := 100
var _mana_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_mana_label = Label.new()
	UI.label(_mana_label)
	_mana_label.position = Vector2(-10, -4)
	_mana_label.size = Vector2(42, 22)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_mana_label)
	_update_label()
	_update_min_size()

func bind(mana_node: Node) -> void:
	if mana_node == null: return
	if not mana_node.mana_changed.is_connected(_on_changed): mana_node.mana_changed.connect(_on_changed)
	_on_changed(mana_node.current_mana, mana_node.MAX_MANA)

func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	_update_label()
	_update_min_size()
	queue_redraw()

func _update_label() -> void:
	if _mana_label != null: _mana_label.text = "魔力"
	tooltip_text = "%d/%d" % [_cur, _max]

func _star_count() -> int:
	return ceili(float(_max) / MANA_PER_STAR)

func _update_min_size() -> void:
	custom_minimum_size = Vector2(26 * ceili(float(_star_count()) / 10), 22 + 26 * mini(_star_count(), 10))

func _draw() -> void:
	for i in _star_count():
		var fraction := clampf(float(_cur - i * MANA_PER_STAR) / MANA_PER_STAR, 0, 1)
		var scale_value := 0.75 if fraction <= 0 else 0.5 + 0.5 * fraction
		var brightness := 0.18 if fraction <= 0 else 0.5 + 0.5 * fraction
		var center := Vector2(11 + (i / 10) * 26, 32 + (i % 10) * 26)
		var extent := Vector2(22, 24) * scale_value
		draw_texture_rect(UI.texture("Mana"), Rect2(center - extent * 0.5, extent), false, Color(brightness, brightness, brightness))
