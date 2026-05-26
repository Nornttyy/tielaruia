# 共享 "鼠标手持" 状态 (Terraria/Minecraft 风): 点 slot 拾起, 点别的 slot 放下/交换/合并.
# 由 player_inventory 持有 (open/close 跨面板 持续), 由 crafting_panel + chest_panel 调.
extends RefCounted


# slot 数据格式: { "item_id": String, "count": int } 或 null
static func make_slot(item_id: String, count: int) -> Dictionary:
	return {"item_id": item_id, "count": count}


# 在两个 slot array 间做一次 "点击" 交互. cursor 由 holder.cursor_slot 持有.
# - 鼠标空 + slot 有 -> 拿起整摞
# - 鼠标有 + slot 空 -> 放下
# - 鼠标有 + slot 同 id -> 合并 (上限 max_stack), 多余留鼠标
# - 鼠标有 + slot 不同 id -> 交换
# arr: target 数组 (chest_slots 或 inv.slots)
# idx: target 数组的下标
# holder: 持有 cursor_slot 字段的对象 (player_inventory)
static func click_slot(holder, arr: Array, idx: int) -> void:
	var cursor = holder.cursor_slot
	var target = arr[idx] if idx < arr.size() else null
	# 鼠标空
	if cursor == null:
		if target == null:
			return
		holder.cursor_slot = target
		arr[idx] = null
		return
	# 鼠标有, slot 空 -> 直接放
	if target == null:
		arr[idx] = cursor
		holder.cursor_slot = null
		return
	# 同 id -> 合并
	if String(cursor.item_id) == String(target.item_id):
		var max_n: int = ItemDB.max_stack(cursor.item_id)
		var total: int = int(target.count) + int(cursor.count)
		if total <= max_n:
			arr[idx] = make_slot(cursor.item_id, total)
			holder.cursor_slot = null
		else:
			arr[idx] = make_slot(cursor.item_id, max_n)
			holder.cursor_slot = make_slot(cursor.item_id, total - max_n)
		return
	# 不同 id -> 交换 (target 上鼠标, cursor 落 slot)
	arr[idx] = cursor
	holder.cursor_slot = target


# 关面板时把鼠标剩的物品放回 inv 第一个空格. inv 满 -> 留着, 等下次开面板再拿.
# (避免直接丢地上, 玩家容易丢丢)
static func return_cursor_to_inv(holder, inv_slots: Array) -> void:
	if holder.cursor_slot == null:
		return
	for i in inv_slots.size():
		if inv_slots[i] == null:
			inv_slots[i] = holder.cursor_slot
			holder.cursor_slot = null
			return
	# 实在没格 -> 试合并到 same-id
	for i in inv_slots.size():
		var s = inv_slots[i]
		if s == null:
			continue
		if String(s.item_id) != String(holder.cursor_slot.item_id):
			continue
		var max_n: int = ItemDB.max_stack(s.item_id)
		var room: int = max_n - int(s.count)
		if room <= 0:
			continue
		var take: int = min(room, int(holder.cursor_slot.count))
		inv_slots[i] = make_slot(s.item_id, int(s.count) + take)
		holder.cursor_slot.count = int(holder.cursor_slot.count) - take
		if holder.cursor_slot.count <= 0:
			holder.cursor_slot = null
			return
