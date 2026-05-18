# 9 格热键栏视图。从 PlayerInventory 读 slots[0..8]，监听信号刷新。
extends HBoxContainer

const SLOT_SIZE := 36

var _player_inv: Node = null
var _slot_nodes: Array = []


func _ready() -> void:
	for i in 9:
		var slot := _make_slot()
		add_child(slot)
		_slot_nodes.append(slot)
	add_theme_constant_override("separation", 4)


func _make_slot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.add_child(icon)
	var label := Label.new()
	label.name = "Count"
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.size_flags_horizontal = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	label.size_flags_vertical = Control.SIZE_SHRINK_END | Control.SIZE_FILL
	panel.add_child(label)
	return panel


func bind(player_inv: Node) -> void:
	_player_inv = player_inv
	player_inv.inventory_changed.connect(refresh)
	player_inv.hotbar_selection_changed.connect(func(_i): refresh())
	refresh()


func refresh() -> void:
	if _player_inv == null:
		return
	for i in 9:
		var slot_data = _player_inv.inventory.slots[i]
		var panel: PanelContainer = _slot_nodes[i]
		var icon: TextureRect = panel.get_node("Icon")
		var label: Label = panel.get_node("Count")
		if slot_data == null:
			icon.texture = null
			label.text = ""
		else:
			icon.texture = ArtCache.get_inventory_icon(slot_data.item_id)
			label.text = "" if slot_data.count <= 1 else str(slot_data.count)
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var is_selected: bool = (i == _player_inv.hotbar_selected)
		style.border_color = Color(1, 1, 0.4, 1) if is_selected else Color(0.4, 0.4, 0.4, 1)
		style.border_width_left = 2 if is_selected else 1
		style.border_width_top = 2 if is_selected else 1
		style.border_width_right = 2 if is_selected else 1
		style.border_width_bottom = 2 if is_selected else 1
