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
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.clip_contents = true   # 防溢出影响相邻槽
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.4)
	style.border_color = Color(0.4, 0.4, 0.4, 1.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	panel.add_theme_stylebox_override("panel", style)
	# 用一个 Control 作为绝对定位容器，所有 child 用 anchors
	var layout := Control.new()
	layout.name = "Layout"
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.add_child(layout)
	# Icon 居中
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	layout.add_child(icon)
	# 计数右下
	var count := Label.new()
	count.name = "Count"
	count.add_theme_font_size_override("font_size", 10)
	count.add_theme_color_override("font_color", Color.WHITE)
	count.add_theme_color_override("font_outline_color", Color.BLACK)
	count.add_theme_constant_override("outline_size", 2)
	count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	count.position = Vector2(-18, -16)
	count.size = Vector2(16, 14)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	layout.add_child(count)
	# 编号左上
	var idx_label := Label.new()
	idx_label.name = "IndexLabel"
	idx_label.add_theme_font_size_override("font_size", 9)
	idx_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	idx_label.add_theme_color_override("font_outline_color", Color.BLACK)
	idx_label.add_theme_constant_override("outline_size", 2)
	idx_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	idx_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	idx_label.position = Vector2(2, 0)
	idx_label.size = Vector2(12, 12)
	layout.add_child(idx_label)
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
		var icon: TextureRect = panel.get_node("Layout/Icon")
		var count_label: Label = panel.get_node("Layout/Count")
		var idx_label: Label = panel.get_node("Layout/IndexLabel")
		idx_label.text = str(i + 1)  # 显示 1..9 编号
		if slot_data == null:
			icon.texture = null
			count_label.text = ""
		else:
			icon.texture = ArtCache.get_inventory_icon(slot_data.item_id)
			count_label.text = "" if slot_data.count <= 1 else str(slot_data.count)
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		var is_selected: bool = (i == _player_inv.hotbar_selected)
		style.border_color = Color(1, 1, 0.4, 1) if is_selected else Color(0.4, 0.4, 0.4, 1)
		style.border_width_left = 2 if is_selected else 1
		style.border_width_top = 2 if is_selected else 1
		style.border_width_right = 2 if is_selected else 1
		style.border_width_bottom = 2 if is_selected else 1
