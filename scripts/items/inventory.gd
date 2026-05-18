# 36 槽物品容器。0..8 = hotbar；9..35 = main。
# 槽位 = null 或 {"item_id": String, "count": int}。
# 合成 grid 不在这里，由 CraftingPanel 自持。
class_name Inventory extends RefCounted

const HOTBAR_SIZE := 9
const MAIN_SIZE := 27
const TOTAL := HOTBAR_SIZE + MAIN_SIZE  # 36

var slots: Array = []


func _init() -> void:
	slots.resize(TOTAL)
	slots.fill(null)


# 把 count 个 item_id 塞入 inventory。返回还没塞下的数量 (>= 0)。
func add(item_id: String, count: int) -> int:
	if count <= 0:
		return 0
	var max_per_slot: int = ItemDB.max_stack(item_id)
	if max_per_slot <= 0:
		return count
	# 先填同 id 已有的槽
	for i in TOTAL:
		if count == 0:
			break
		var s = slots[i]
		if s == null or s.item_id != item_id:
			continue
		var room: int = max_per_slot - s.count
		if room <= 0:
			continue
		var n: int = min(room, count)
		s.count += n
		count -= n
	# 再找空槽
	for i in TOTAL:
		if count == 0:
			break
		if slots[i] != null:
			continue
		var n: int = min(max_per_slot, count)
		slots[i] = {"item_id": item_id, "count": n}
		count -= n
	return count


# 从指定槽拿走至多 count 个。返回实际拿走数。槽空则置 null。
func remove(slot_idx: int, count: int) -> int:
	if slot_idx < 0 or slot_idx >= TOTAL:
		return 0
	var s = slots[slot_idx]
	if s == null:
		return 0
	var n: int = min(s.count, count)
	s.count -= n
	if s.count <= 0:
		slots[slot_idx] = null
	return n


func swap(a: int, b: int) -> void:
	if a < 0 or a >= TOTAL or b < 0 or b >= TOTAL:
		return
	var tmp = slots[a]
	slots[a] = slots[b]
	slots[b] = tmp


# 从指定槽拆走一半 (count/2)。原槽留较大的一半。空或 count==1 → null。
func split_half(slot_idx: int) -> Variant:
	if slot_idx < 0 or slot_idx >= TOTAL:
		return null
	var s = slots[slot_idx]
	if s == null or s.count <= 1:
		return null
	var half: int = s.count / 2
	s.count -= half
	return {"item_id": s.item_id, "count": half}
