# 箱子面板: open(tile_coord) 时显示, 24 格 chest + 27 格玩家主背包 (非 hotbar).
# 点击任意格 → 把整堆移到另一边的第一个空槽 (shift-click 风).
# 玩家走远 / ESC / 关闭按钮 / 再次右键 → 关.
# UI 全在代码里建, 没有专门 tscn.
extends CanvasLayer

const SLOT_SIZE := 40
const COLS_CHEST := 8
const ROWS_CHEST := 3
const COLS_PLAYER := 9
const ROWS_PLAYER := 3

@onready var _root: Control = null
var _chest_slots_ui: Array = []          # 24 个 PanelContainer (用 update_slot 刷)
var _player_slots_ui: Array = []         # 27 个 PanelContainer

var _chest_tile: Vector2i = Vector2i.ZERO
var _is_open: bool = false
var _player_inv: Node = null    # 玩家 PlayerInventory


func _ready() -> void:
	layer = 50
	add_to_group("chest_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false


func _build_ui() -> void:
	# 半透明黑遮罩
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(dim)

	_root = PanelContainer.new()
	_root.set_anchors_preset(Control.PRESET_CENTER)
	_root.custom_minimum_size = Vector2(SLOT_SIZE * COLS_PLAYER + 32, SLOT_SIZE * (ROWS_CHEST + ROWS_PLAYER) + 96)
	# 居中
	_root.position = Vector2(-_root.custom_minimum_size.x / 2, -_root.custom_minimum_size.y / 2)
	add_child(_root)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	_root.add_child(vbox)

	# 标题: 箱子
	var title := Label.new()
	title.text = "箱子"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396))
	vbox.add_child(title)

	# 箱子 3x8 grid
	var chest_grid := GridContainer.new()
	chest_grid.columns = COLS_CHEST
	chest_grid.add_theme_constant_override("h_separation", 2)
	chest_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(chest_grid)
	for i in COLS_CHEST * ROWS_CHEST:
		var slot := _make_slot(i, true)
		chest_grid.add_child(slot)
		_chest_slots_ui.append(slot)

	# 分隔
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 标题: 你的背包
	var p_title := Label.new()
	p_title.text = "你的背包 (点格子转移)"
	p_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	p_title.add_theme_font_size_override("font_size", 14)
	p_title.add_theme_color_override("font_color", Color(0.831, 0.71, 0.541))
	vbox.add_child(p_title)

	# 玩家主背包 3x9 grid (不含 hotbar, hotbar 是 inv.slots[0..8])
	var p_grid := GridContainer.new()
	p_grid.columns = COLS_PLAYER
	p_grid.add_theme_constant_override("h_separation", 2)
	p_grid.add_theme_constant_override("v_separation", 2)
	vbox.add_child(p_grid)
	for i in COLS_PLAYER * ROWS_PLAYER:
		var slot := _make_slot(i, false)
		p_grid.add_child(slot)
		_player_slots_ui.append(slot)

	# 关按钮
	var close_btn := Button.new()
	close_btn.text = "关闭 (ESC / 右键)"
	close_btn.custom_minimum_size = Vector2(0, 32)
	close_btn.pressed.connect(close)
	vbox.add_child(close_btn)


func _make_slot(idx: int, is_chest: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	# 背景: 暗灰
	var bg := ColorRect.new()
	bg.color = Color(0.18, 0.18, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(bg)
	# icon
	var icon := TextureRect.new()
	icon.name = "Icon"
	icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(icon)
	# count label
	var lbl := Label.new()
	lbl.name = "Count"
	lbl.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	lbl.position = Vector2(-22, -16)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 1, 1))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(lbl)
	# 点击 → transfer
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.pressed.connect(_on_slot_pressed.bind(idx, is_chest))
	p.add_child(btn)
	return p


func _refresh_slot(slot_ui: PanelContainer, slot_data) -> void:
	var icon: TextureRect = slot_ui.get_node("Icon")
	var count: Label = slot_ui.get_node("Count")
	if slot_data == null:
		icon.texture = null
		count.text = ""
	else:
		icon.texture = ArtCache.get_inventory_icon(slot_data.item_id)
		count.text = str(slot_data.count) if slot_data.count > 1 else ""


func _refresh_all() -> void:
	var chest_arr: Array = ChestStorage.get_slots(_chest_tile)
	for i in _chest_slots_ui.size():
		_refresh_slot(_chest_slots_ui[i], chest_arr[i])
	# 玩家主背包: slots[9..35] (前 9 是 hotbar)
	if _player_inv != null and _player_inv.inventory != null:
		var p_slots: Array = _player_inv.inventory.slots
		for i in _player_slots_ui.size():
			var idx: int = 9 + i
			var data = p_slots[idx] if idx < p_slots.size() else null
			_refresh_slot(_player_slots_ui[i], data)


# 点击格子 → 把这堆转到另一边的第一个空格
func _on_slot_pressed(idx: int, is_chest: bool) -> void:
	if _player_inv == null or _player_inv.inventory == null:
		return
	var chest_arr: Array = ChestStorage.get_slots(_chest_tile)
	var p_slots: Array = _player_inv.inventory.slots
	if is_chest:
		var src = chest_arr[idx]
		if src == null:
			return
		# 找玩家主背包 (idx 9..35) 第一个空槽
		var dst_idx: int = _find_first_empty(p_slots, 9, p_slots.size())
		if dst_idx == -1:
			return
		p_slots[dst_idx] = src
		chest_arr[idx] = null
		if _player_inv.has_signal("inventory_changed"):
			_player_inv.inventory_changed.emit()
	else:
		var src2 = p_slots[9 + idx]
		if src2 == null:
			return
		var dst_idx2: int = _find_first_empty(chest_arr, 0, chest_arr.size())
		if dst_idx2 == -1:
			return
		chest_arr[dst_idx2] = src2
		p_slots[9 + idx] = null
		if _player_inv.has_signal("inventory_changed"):
			_player_inv.inventory_changed.emit()
	_refresh_all()


func _find_first_empty(arr: Array, start: int, end: int) -> int:
	for i in range(start, end):
		if arr[i] == null:
			return i
	return -1


# 由 player_action 调: 右键箱子打开
func open(tile_coord: Vector2i, player_inv: Node) -> void:
	_chest_tile = tile_coord
	_player_inv = player_inv
	visible = true
	_is_open = true
	_refresh_all()


func close() -> void:
	visible = false
	_is_open = false


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
