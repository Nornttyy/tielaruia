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
# i18n: 缓存切语言时要刷新的 label / button
var _title_label: Label = null
var _take_all_btn: Button = null
var _inv_hint_label: Label = null
var _close_btn: Button = null


func _ready() -> void:
	layer = 50
	add_to_group("chest_panel")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	# i18n: 切语言时刷文字
	if Locale != null and not Locale.language_changed.is_connected(_refresh_i18n):
		Locale.language_changed.connect(_refresh_i18n)


func _refresh_i18n(_new_lang: String) -> void:
	if _title_label != null:
		_title_label.text = Locale.t("chest_title")
	if _take_all_btn != null:
		_take_all_btn.text = Locale.t("chest_take_all")
	if _inv_hint_label != null:
		_inv_hint_label.text = Locale.t("chest_inv_hint")
	if _close_btn != null:
		_close_btn.text = Locale.t("chest_close")


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

	# 标题: 箱子 (i18n: 切语言时刷新)
	_title_label = Label.new()
	_title_label.text = Locale.t("chest_title")
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 18)
	_title_label.add_theme_color_override("font_color", Color(0.949, 0.761, 0.396))
	vbox.add_child(_title_label)

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

	# "全拿" 按钮: 把箱子所有物品送进玩家 inventory (一键清箱)
	_take_all_btn = Button.new()
	_take_all_btn.text = Locale.t("chest_take_all")
	_take_all_btn.custom_minimum_size = Vector2(0, 26)
	_take_all_btn.pressed.connect(take_all_from_chest)
	vbox.add_child(_take_all_btn)

	# 分隔
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# 标题: 你的背包
	_inv_hint_label = Label.new()
	_inv_hint_label.text = Locale.t("chest_inv_hint")
	_inv_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_inv_hint_label.add_theme_font_size_override("font_size", 14)
	_inv_hint_label.add_theme_color_override("font_color", Color(0.831, 0.71, 0.541))
	vbox.add_child(_inv_hint_label)

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
	_close_btn = Button.new()
	_close_btn.text = Locale.t("chest_close")
	_close_btn.custom_minimum_size = Vector2(0, 32)
	_close_btn.pressed.connect(close)
	vbox.add_child(_close_btn)
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
	# 拖动: press 立刻拿起 / 放下, release 在不同 slot 上 → 落点
	var btn := Button.new()
	btn.flat = true
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	btn.set_meta("idx", idx)
	btn.set_meta("is_chest", is_chest)
	btn.button_down.connect(_on_slot_button_down.bind(btn))
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


# 拖动状态: 严格"按住拖" — press 只拿起 / release 才放下, 没有 click-click
var _drag_active: bool = false           # 当前是否在 drag 中 (press 后 release 前)
var _drag_picked_up_this_press: bool = false  # 这次 press 是不是从空 cursor 拿起的
var _drag_press_idx: int = -1
var _drag_press_is_chest: bool = false


func _on_slot_button_down(btn: Button) -> void:
	if _player_inv == null or _player_inv.inventory == null:
		return
	var idx: int = btn.get_meta("idx", 0)
	var is_chest: bool = btn.get_meta("is_chest", false)
	# Shift+左键 = 单槽 transfer (送到另一边 inventory 第一个空/合并槽).
	# 跟 Minecraft 一致: shift+click 单槽快速移动.
	if Input.is_key_pressed(KEY_SHIFT) and _player_inv.cursor_slot == null:
		_shift_transfer(idx, is_chest)
		return
	_drag_press_idx = idx
	_drag_press_is_chest = is_chest
	if _player_inv.cursor_slot == null:
		# cursor 空 → 尝试拿起 (click_slot 在空 slot 上是无操作)
		_apply_click(idx, is_chest)
		if _player_inv.cursor_slot != null:
			_drag_active = true
			_drag_picked_up_this_press = true
		else:
			_drag_active = false
			_drag_picked_up_this_press = false
	else:
		# cursor 已有 (上次 swap 留下来的) → 不在 press 上放下, 等 release 落点
		_drag_active = true
		_drag_picked_up_this_press = false


# 全局监听鼠标松开 → 决定 drop / cancel / no-op
func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _drag_active:
		return
	var found := _find_slot_under_mouse()
	if found.idx < 0:
		# 松手在 slot 外: 如果本次拿起的, 取消放回原位; 否则 cursor 保留
		if _drag_picked_up_this_press:
			_apply_click(_drag_press_idx, _drag_press_is_chest)
		_drag_active = false
		return
	if found.idx == _drag_press_idx and found.is_chest == _drag_press_is_chest:
		# 同 slot 松手 (没拖动): 取消拿起 (放回原位), 或 cursor 已经在拿则保持
		if _drag_picked_up_this_press:
			_apply_click(_drag_press_idx, _drag_press_is_chest)
		_drag_active = false
		return
	# 拖到不同 slot → 放下/合并/交换 (click_slot 处理 4 种情况)
	_apply_click(found.idx, found.is_chest)
	_drag_active = false


func _apply_click(idx: int, is_chest: bool) -> void:
	if is_chest:
		InventoryCursor.click_slot(_player_inv, ChestStorage.get_slots(_chest_tile), idx)
	else:
		InventoryCursor.click_slot(_player_inv, _player_inv.inventory.slots, 9 + idx)
	if _player_inv.has_signal("inventory_changed"):
		_player_inv.inventory_changed.emit()
	_refresh_all()


# Shift+左键: 把指定槽内容 transfer 到另一边 (chest → 玩家主背包, 玩家 → chest).
# 用 Inventory.add 自动 stack + 找空槽. 来源槽空则清.
func _shift_transfer(idx: int, is_chest: bool) -> void:
	if _player_inv == null or _player_inv.inventory == null:
		return
	var src_array: Array
	if is_chest:
		src_array = ChestStorage.get_slots(_chest_tile)
	else:
		src_array = _player_inv.inventory.slots
	var src_idx: int = idx if is_chest else 9 + idx
	if src_idx < 0 or src_idx >= src_array.size():
		return
	var s = src_array[src_idx]
	if s == null:
		return
	var item_id: String = s.item_id
	var count: int = s.count
	# 加到目的 inventory
	var leftover: int = _try_add_to_other_side(item_id, count, is_chest)
	if leftover < count:
		var moved: int = count - leftover
		s.count -= moved
		if s.count <= 0:
			src_array[src_idx] = null
		if _player_inv.has_signal("inventory_changed"):
			_player_inv.inventory_changed.emit()
		_refresh_all()


# 把 item 加到另一边 inventory. 返回还塞不下的数量 (>=0).
# is_from_chest=true: 加到玩家 main inv (9..35); false: 加到 chest.
func _try_add_to_other_side(item_id: String, count: int, is_from_chest: bool) -> int:
	if is_from_chest:
		# Chest → 玩家 inv: 用现有 inventory.add (它会智能 stack + 找空槽)
		return _player_inv.inventory.add(item_id, count)
	# 玩家 → Chest: 手动塞 chest slots (没现成 add 函数)
	var chest_slots: Array = ChestStorage.get_slots(_chest_tile)
	var max_stack: int = ItemDB.max_stack(item_id)
	var remaining: int = count
	# 先填同 id 已有的槽
	for i in chest_slots.size():
		if remaining <= 0:
			break
		var slot = chest_slots[i]
		if slot == null or slot.item_id != item_id:
			continue
		var room: int = max_stack - slot.count
		if room <= 0:
			continue
		var n: int = min(room, remaining)
		slot.count += n
		remaining -= n
	# 再找空槽
	for i in chest_slots.size():
		if remaining <= 0:
			break
		if chest_slots[i] != null:
			continue
		var n: int = min(max_stack, remaining)
		chest_slots[i] = {"item_id": item_id, "count": n}
		remaining -= n
	return remaining


# 全拿: 把 chest 所有物品送进玩家 inventory. 装不下的留 chest.
func take_all_from_chest() -> void:
	if _player_inv == null or _player_inv.inventory == null:
		return
	var chest_slots: Array = ChestStorage.get_slots(_chest_tile)
	for i in chest_slots.size():
		var s = chest_slots[i]
		if s == null:
			continue
		var leftover: int = _player_inv.inventory.add(s.item_id, s.count)
		if leftover == 0:
			chest_slots[i] = null
		else:
			s.count = leftover
	if _player_inv.has_signal("inventory_changed"):
		_player_inv.inventory_changed.emit()
	_refresh_all()


# 查鼠标下是哪个 slot. 返回 {idx, is_chest}, idx=-1 表示不在任何 slot 上
func _find_slot_under_mouse() -> Dictionary:
	var mp: Vector2 = get_viewport().get_mouse_position()
	for i in _chest_slots_ui.size():
		var slot: Control = _chest_slots_ui[i]
		if slot.get_global_rect().has_point(mp):
			return {"idx": i, "is_chest": true}
	for i in _player_slots_ui.size():
		var slot: Control = _player_slots_ui[i]
		if slot.get_global_rect().has_point(mp):
			return {"idx": i, "is_chest": false}
	return {"idx": -1, "is_chest": false}


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


func _process(_delta: float) -> void:
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
