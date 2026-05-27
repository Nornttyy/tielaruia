# 箱子面板: open(tile_coord) 时显示, 24 格 chest + 27 格玩家主背包 (非 hotbar).
# 点击任意格 → 把整堆移到另一边的第一个空槽 (shift-click 风).
# 玩家走远 / ESC / 关闭按钮 / 再次右键 → 关.
# UI 全在代码里建, 没有专门 tscn.
extends CanvasLayer

const InventoryCursor = preload("res://scripts/items/inventory_cursor.gd")

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
var _cursor_icon: TextureRect = null
var _cursor_count: Label = null


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
	# Cursor icon: 跟鼠标飘的物品
	_cursor_icon = TextureRect.new()
	_cursor_icon.custom_minimum_size = Vector2(32, 32)
	_cursor_icon.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_cursor_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_icon.z_index = 100
	_cursor_icon.visible = false
	add_child(_cursor_icon)
	_cursor_count = Label.new()
	_cursor_count.add_theme_font_size_override("font_size", 12)
	_cursor_count.add_theme_color_override("font_color", Color.WHITE)
	_cursor_count.add_theme_color_override("font_outline_color", Color.BLACK)
	_cursor_count.add_theme_constant_override("outline_size", 2)
	_cursor_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cursor_count.z_index = 101
	add_child(_cursor_count)


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
	# 长按 → transfer (用户要求, 短按只是看清楚)
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.set_meta("idx", idx)
	btn.set_meta("is_chest", is_chest)
	btn.set_meta("hold_timer", 0.0)
	btn.set_meta("hold_fired", false)
	btn.button_down.connect(_on_slot_button_down.bind(btn))
	btn.button_up.connect(_on_slot_button_up.bind(btn))
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


# 长按 0.3s 触发. 短按不动 (用户要求).
const _HOLD_THRESHOLD := 0.3

func _on_slot_button_down(btn: Button) -> void:
	btn.set_meta("hold_timer", 0.0)
	btn.set_meta("hold_fired", false)

func _on_slot_button_up(btn: Button) -> void:
	# Up 之前已 fire (hold 完) → 啥都不做; 没 fire → 短按, 啥都不做
	pass

# 在主 _process 里调
func _process_hold_buttons(delta: float) -> void:
	if not _is_open:
		return
	for slot_arr in [_chest_slots_ui, _player_slots_ui]:
		for slot_ui in slot_arr:
			var btn := slot_ui.get_child(slot_ui.get_child_count() - 1) as Button
			if btn == null:
				continue
			if not btn.button_pressed:
				continue
			if btn.get_meta("hold_fired", false):
				continue
			var t: float = btn.get_meta("hold_timer", 0.0) + delta
			btn.set_meta("hold_timer", t)
			if t >= _HOLD_THRESHOLD:
				btn.set_meta("hold_fired", true)
				_fire_slot_move(btn)


func _fire_slot_move(btn: Button) -> void:
	if _player_inv == null or _player_inv.inventory == null:
		return
	var idx: int = btn.get_meta("idx", 0)
	var is_chest: bool = btn.get_meta("is_chest", false)
	if is_chest:
		InventoryCursor.click_slot(_player_inv, ChestStorage.get_slots(_chest_tile), idx)
	else:
		InventoryCursor.click_slot(_player_inv, _player_inv.inventory.slots, 9 + idx)
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
	# 关时鼠标剩物品回 inv (空格 / 合并)
	if _player_inv != null and _player_inv.inventory != null:
		InventoryCursor.return_cursor_to_inv(_player_inv, _player_inv.inventory.slots)
		if _player_inv.has_signal("inventory_changed"):
			_player_inv.inventory_changed.emit()
	visible = false
	_is_open = false


func _process(delta: float) -> void:
	# Hold-to-move 长按定时
	_process_hold_buttons(delta)
	# Cursor icon 跟鼠标
	if not _is_open or _cursor_icon == null or _player_inv == null:
		return
	var cs = _player_inv.cursor_slot
	if cs == null:
		_cursor_icon.visible = false
		if _cursor_count != null:
			_cursor_count.text = ""
		return
	_cursor_icon.visible = true
	_cursor_icon.texture = ArtCache.get_inventory_icon(String(cs.item_id))
	_cursor_icon.global_position = get_viewport().get_mouse_position() - Vector2(16, 16)
	if _cursor_count != null:
		_cursor_count.text = str(int(cs.count)) if int(cs.count) > 1 else ""
		_cursor_count.global_position = _cursor_icon.global_position + Vector2(16, 14)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			close()
			get_viewport().set_input_as_handled()
