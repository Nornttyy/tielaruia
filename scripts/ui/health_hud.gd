# 经典生命显示：原版 22×22 心形，10 颗一行，部分生命缩放并变暗。
extends Control
const UI = preload("res://scripts/ui/classic_ui.gd")
const HEARTS_PER_ROW := 10
const HP_PER_HEART := 20
const HEART_SLOT_PX := 22
const HEART_SPACING := 4
var _cur := 100
var _max := 100
var _hp_label: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_hp_label = Label.new()
	UI.label(_hp_label)
	_hp_label.position = Vector2(0, -4)
	_hp_label.size = Vector2(260, 22)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_hp_label)
	_update_label()
	_update_min_size()

func bind(health_node: Node) -> void:
	if health_node == null: return
	if not health_node.health_changed.is_connected(_on_changed): health_node.health_changed.connect(_on_changed)
	_on_changed(health_node.current_health, health_node.MAX_HEALTH)

func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	_update_min_size()
	_update_label()
	queue_redraw()

func _heart_count() -> int:
	return ceili(float(_max) / HP_PER_HEART)

func _update_label() -> void:
	if _hp_label != null: _hp_label.text = "生命：%d/%d" % [_cur, _max]

func _update_min_size() -> void:
	custom_minimum_size = Vector2(260, 22 + 26 * ceili(float(_heart_count()) / HEARTS_PER_ROW))

func _draw() -> void:
	for i in _heart_count():
		var fraction := clampf(float(_cur - i * HP_PER_HEART) / HP_PER_HEART, 0.0, 1.0)
		var scale_value := 0.75 if fraction <= 0 else 0.5 + 0.5 * fraction
		var brightness := 0.18 if fraction <= 0 else 0.5 + 0.5 * fraction
		var center := Vector2(11 + (i % 10) * 26, 32 + (i / 10) * 26)
		var extent := Vector2(22, 22) * scale_value
		draw_texture_rect(UI.texture("Heart"), Rect2(center - extent * 0.5, extent), false, Color(brightness, brightness, brightness))
