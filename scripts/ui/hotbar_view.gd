# 9 格热键栏视图。从 PlayerInventory 读 slots[0..8]，监听信号刷新。
extends HBoxContainer

const SLOT_SIZE := 36

var _player_inv: Node = null
var _slot_nodes: Array = []
# perf: 缓存 panel ref 防每帧 2 次 group 查找
var _cached_crafting_panel: Node = null
var _cached_chest_panel: Node = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP   # 整条 hotbar 收点击/触摸 → 选格子 (手机切快捷栏)
	for i in 9:
		var slot := _make_slot()
		add_child(slot)
		_slot_nodes.append(slot)
	add_theme_constant_override("separation", 4)


# 点/触屏点 hotbar → 按横坐标算出点了第几格并选中 (手机没数字键; 桌面点也能选)。
# 在容器层统一收, 比每个小格子单独收更稳 (嵌套容器的触摸拾取有时会漏)。
func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
			or (event is InputEventScreenTouch and event.pressed)
	if not pressed or _player_inv == null or not _player_inv.has_method("set_hotbar_selection"):
		return
	var step: float = float(SLOT_SIZE) + 4.0   # 槽宽 + separation
	var idx: int = clampi(int(event.position.x / step), 0, 8)
	_player_inv.set_hotbar_selection(idx)
	accept_event()


# UI (背包/合成/箱子) 打开时隐藏 hotbar — 用户要求
func _process(_delta: float) -> void:
	# panel 一旦 queue_free 引用就 invalid; 失效就重查
	if _cached_crafting_panel == null or not is_instance_valid(_cached_crafting_panel):
		_cached_crafting_panel = get_tree().get_first_node_in_group("crafting_panel")
	if _cached_chest_panel == null or not is_instance_valid(_cached_chest_panel):
		_cached_chest_panel = get_tree().get_first_node_in_group("chest_panel")
	var c: Node = _cached_crafting_panel
	var ch: Node = _cached_chest_panel
	var ui_open: bool = (c != null and c.has_method("is_open") and c.is_open()) \
			or (ch != null and ch.has_method("is_open") and ch.is_open())
	visible = not ui_open


func _make_slot() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # 格子不抢输入, 交给整条 hotbar 的 _gui_input
	panel.clip_contents = true   # 防溢出影响相邻槽
	# 蓝色圆角槽 (用户要求): 深蓝半透底 + 中蓝边 + 圆角
	var style := StyleBoxFlat.new()
	style.bg_color = Color8(18, 32, 58, 205)
	style.border_color = Color8(70, 120, 180)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 9
	style.corner_radius_top_right = 9
	style.corner_radius_bottom_left = 9
	style.corner_radius_bottom_right = 9
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
		# 选中: 亮青蓝边 + 更亮的蓝底 (一眼看出拿的哪个); 没选: 中蓝边
		style.border_color = Color8(110, 205, 255) if is_selected else Color8(70, 120, 180)
		style.bg_color = Color8(34, 64, 108, 225) if is_selected else Color8(18, 32, 58, 205)
		style.border_width_left = 3 if is_selected else 2
		style.border_width_top = 3 if is_selected else 2
		style.border_width_right = 3 if is_selected else 2
		style.border_width_bottom = 3 if is_selected else 2
