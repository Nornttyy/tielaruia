# 经典快捷栏：选中格 52px，其余 39px；点击跟随每格真实位置。
extends Control
const UI = preload("res://scripts/ui/classic_ui.gd")
const CraftingNames = preload("res://scripts/ui/crafting_panel.gd")
const SLOT_SIZE := 44
var _player_inv: Node
var _slot_nodes: Array = []
var _selected_name: Label
var _cached_crafting_panel: Node
var _cached_chest_panel: Node

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_selected_name = Label.new()
	UI.label(_selected_name, 18)
	_selected_name.position = Vector2(0, -22)
	_selected_name.size = Vector2(440, 22)
	_selected_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_selected_name)
	for i in Inventory.HOTBAR_SIZE:
		var slot := _make_slot(i)
		add_child(slot)
		_slot_nodes.append(slot)
	_layout_slots()

func _make_slot(index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.gui_input.connect(func(event):
		var clicked: bool = event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT
		var touched: bool = event is InputEventScreenTouch and event.pressed
		if (clicked or touched) and _player_inv != null:
			_player_inv.set_hotbar_selection(index)
			panel.accept_event())
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(layout)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_child(icon)
	var count := Label.new()
	count.name = "Count"
	UI.label(count, 13)
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.offset_left = -34
	count.offset_top = -19
	count.offset_right = -3
	count.offset_bottom = -2
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	layout.add_child(count)
	var number := Label.new()
	number.name = "IndexLabel"
	number.text = str((index + 1) % 10)
	UI.label(number, 13)
	number.position = Vector2(4, 0)
	layout.add_child(number)
	return panel

func _layout_slots() -> void:
	var x := 0.0
	for i in _slot_nodes.size():
		var selected: bool = i == (_player_inv.hotbar_selected if _player_inv != null else 0)
		var extent := 52.0 if selected else 39.0
		var panel: PanelContainer = _slot_nodes[i]
		panel.position = Vector2(x, (52.0 - extent) * 0.5)
		panel.custom_minimum_size = Vector2(extent, extent)
		panel.size = Vector2(extent, extent)
		panel.add_theme_stylebox_override("panel", UI.slot("selected" if selected else "hotbar"))
		x += extent + 4.0

func bind(inv: Node) -> void:
	_player_inv = inv
	inv.inventory_changed.connect(refresh)
	inv.hotbar_selection_changed.connect(func(_i): refresh())
	refresh()

func refresh() -> void:
	if _player_inv == null: return
	var current = _player_inv.current_hotbar_slot()
	_selected_name.text = "" if current == null else CraftingNames._ZH_NAMES.get(current.item_id, current.item_id)
	for i in _slot_nodes.size():
		var item = _player_inv.inventory.slots[i]
		_slot_nodes[i].get_node("Layout/Icon").texture = null if item == null else ArtCache.get_inventory_icon(item.item_id)
		_slot_nodes[i].get_node("Layout/Count").text = "" if item == null or item.count <= 1 else str(item.count)
	_layout_slots()

func _process(_delta: float) -> void:
	if not is_instance_valid(_cached_crafting_panel): _cached_crafting_panel = get_tree().get_first_node_in_group("crafting_panel")
	if not is_instance_valid(_cached_chest_panel): _cached_chest_panel = get_tree().get_first_node_in_group("chest_panel")
	visible = not ((_cached_crafting_panel != null and _cached_crafting_panel.is_open()) or (_cached_chest_panel != null and _cached_chest_panel.is_open()))
