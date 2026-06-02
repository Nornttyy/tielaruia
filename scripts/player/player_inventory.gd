# 玩家库存节点。挂在 Player 下，作为唯一的 Inventory 持有者。
extends Node

signal inventory_changed
signal hotbar_selection_changed(index: int)
signal armor_changed   # 盔甲槽变化, HUD 跟着重渲

var inventory: Inventory
var hotbar_selected: int = 0  # 0..8
# 鼠标手持物品 (Terraria 风背包拖动用). null = 空; { item_id, count } = 持有
var cursor_slot: Variant = null
# 盔甲: 3 个槽位 (helmet/chest/pants). null 或 {"item_id": String, "count": 1}
var armor_helmet: Variant = null
var armor_chest: Variant = null
var armor_pants: Variant = null


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


# === 盔甲槽 ===
# 拿指定槽位的盔甲 slot. 返回 null 或 {"item_id", "count"}.
func get_armor(slot: String) -> Variant:
	match slot:
		"helmet": return armor_helmet
		"chest":  return armor_chest
		"pants":  return armor_pants
	return null


# 设盔甲槽 (装备 / 卸下). val null = 卸下. 不验证 — caller 自己确保 item_id 是对的 slot 类型.
func set_armor(slot: String, val: Variant) -> void:
	match slot:
		"helmet": armor_helmet = val
		"chest":  armor_chest = val
		"pants":  armor_pants = val
	armor_changed.emit()


# 背包 (含 hotbar) 里有没有某物品 (持有即生效类装备用, 如云靴二段跳)
func has_item(item_id: String) -> bool:
	for s in inventory.slots:
		if s != null and s.item_id == item_id:
			return true
	return false


# 总防御值 (sum of 3 slots)
func total_defense() -> int:
	var d: int = 0
	for slot_data in [armor_helmet, armor_chest, armor_pants]:
		if slot_data != null:
			d += ItemDB.defense(slot_data.item_id)
	return d


# 装备盔甲: 把 hotbar/inv 里某槽的物品移到对应盔甲槽, 旧装备返回到原槽.
# 返回 true = 成功 (该物品是合法盔甲且槽匹配).
func equip_armor_from_slot(inv_idx: int) -> bool:
	if inv_idx < 0 or inv_idx >= inventory.slots.size():
		return false
	var s = inventory.slots[inv_idx]
	if s == null:
		return false
	var slot_kind: String = ItemDB.armor_slot(s.item_id)
	if slot_kind == "":
		return false   # 不是盔甲
	var prev = get_armor(slot_kind)
	set_armor(slot_kind, {"item_id": s.item_id, "count": 1})
	inventory.slots[inv_idx] = prev   # 旧装备塞回原槽 (null 也行 = 清空)
	inventory_changed.emit()
	return true


# 卸下: 把盔甲槽的物品塞回 hotbar/inv 第一个空槽. 没空槽就什么都不做.
func unequip_armor(slot: String) -> bool:
	var equipped = get_armor(slot)
	if equipped == null:
		return false
	# 找空槽
	for i in inventory.slots.size():
		if inventory.slots[i] == null:
			inventory.slots[i] = equipped
			set_armor(slot, null)
			inventory_changed.emit()
			return true
	return false   # 背包满


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
