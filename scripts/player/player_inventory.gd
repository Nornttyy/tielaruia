# 玩家库存节点。挂在 Player 下，作为唯一的 Inventory 持有者。
extends Node

signal inventory_changed
signal hotbar_selection_changed(index: int)

var inventory: Inventory
var hotbar_selected: int = 0  # 0..8
# 鼠标手持物品 (Terraria 风背包拖动用). null = 空; { item_id, count } = 持有
var cursor_slot: Variant = null


func _ready() -> void:
	inventory = Inventory.new()


func _unhandled_input(event: InputEvent) -> void:
	# 数字键 1-9 选热键 (直接读 keycode 比 Input.is_action_just_pressed 稳)
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.keycode
		if key >= KEY_1 and key <= KEY_9:
			set_hotbar_selection(key - KEY_1)
			get_viewport().set_input_as_handled()
			return
	# 滚轮切换
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			set_hotbar_selection((hotbar_selected - 1 + 9) % 9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			set_hotbar_selection((hotbar_selected + 1) % 9)


func set_hotbar_selection(idx: int) -> void:
	idx = clampi(idx, 0, 8)
	if idx == hotbar_selected:
		return
	hotbar_selected = idx
	hotbar_selection_changed.emit(idx)


# 给 ItemDrop 调。返回还塞不下的数量。
func pickup(item_id: String, count: int) -> int:
	var leftover: int = inventory.add(item_id, count)
	if leftover != count:
		inventory_changed.emit()
	return leftover


func current_hotbar_slot() -> Variant:
	return inventory.slots[hotbar_selected]


func current_tool_kind() -> String:
	var s = current_hotbar_slot()
	if s == null:
		return ""
	var def = ItemDB.get_def(s.item_id)
	if def == null:
		return ""
	return def.tool_kind


func current_tool_tier() -> int:
	var s = current_hotbar_slot()
	if s == null:
		return 0
	var def = ItemDB.get_def(s.item_id)
	return 0 if def == null else def.tool_tier


# 消耗当前 hotbar 槽 n 个
func consume_current(n: int = 1) -> int:
	var taken: int = inventory.remove(hotbar_selected, n)
	if taken > 0:
		inventory_changed.emit()
	return taken


# 在 36 槽里找第一个 item_id 槽, 消耗 n 个. 返回 true = 全部消耗成功.
# 弓发箭等场景用 (玩家持弓时, 箭可能不在 hotbar 当前槽).
func consume_first(item_id: String, n: int = 1) -> bool:
	# 用 slots.size() 而非 Inventory.TOTAL — 避免 const-via-instance 访问问题
	for i in inventory.slots.size():
		var s = inventory.slots[i]
		if s == null or s.item_id != item_id:
			continue
		var taken: int = inventory.remove(i, n)
		if taken > 0:
			inventory_changed.emit()
		return taken >= n
	return false
