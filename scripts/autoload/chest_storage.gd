# 全局箱子存储 (autoload). tile 坐标 (Vector2i) → 24 格物品槽数组.
# 槽格式: null (空) 或 {"item_id": String, "count": int}, 跟 player_inventory 一致.
# 存档时 SaveManager 调 dump() / restore() 持久化.
extends Node

const SLOTS_PER_CHEST := 24

# tile_coord (Vector2i) → Array[24] of slot dicts
var _chests: Dictionary = {}

# 矿洞宝箱: 哪些位置已经被填过战利品 (防 chunk 重载再填一次, 让玩家拿光后还能复活).
# tile_coord (Vector2i) → true
var _treasure_marked: Dictionary = {}


# 获取某 tile 的箱子槽数组 (没有就懒创建空数组). 直接返回 reference, 改了立即生效.
func get_slots(tile_coord: Vector2i) -> Array:
	if not _chests.has(tile_coord):
		var arr: Array = []
		arr.resize(SLOTS_PER_CHEST)
		for i in SLOTS_PER_CHEST:
			arr[i] = null
		_chests[tile_coord] = arr
	return _chests[tile_coord]


# 箱子方块被破坏时调: 把里面的内容当 ItemDrop 撒出来, 删字典 entry.
func clear(tile_coord: Vector2i) -> Array:
	if not _chests.has(tile_coord):
		return []
	var contents: Array = _chests[tile_coord]
	_chests.erase(tile_coord)
	return contents


# 矿洞宝箱首次填战利品. 同位置只填一次 (用 _treasure_marked 标记),
# 玩家拿光后或砸了空箱子, 即便 chunk 重载也不会再填.
# 战利品根据深度 (tile.y 越大越深) 调整: 浅层 = 火把+食物+铜锡, 深层 = 加铁+金.
func try_populate_treasure(tile: Vector2i, world_seed: int) -> void:
	if _treasure_marked.has(tile):
		return
	_treasure_marked[tile] = true
	var rng := RandomNumberGenerator.new()
	# 跟世界 seed 和位置确定性绑死 → 同 seed 同位置永远同战利品.
	rng.seed = (world_seed * 0x9E3779B1) ^ (tile.x * 73856093) ^ (tile.y * 19349663)
	var loot: Array = []
	loot.resize(SLOTS_PER_CHEST)
	for i in SLOTS_PER_CHEST:
		loot[i] = null
	# 一定有: 火把 5-12 个 + 熟肉 1-3 个 (玩家进矿要的)
	loot[0] = {"item_id": "torch", "count": rng.randi_range(5, 12)}
	loot[1] = {"item_id": "cooked_meat", "count": rng.randi_range(1, 3)}
	# 浅层 (y<70) 给铜/锡 + 木板; 深层 (>=70) 加铁; 超深 (>=100) 偶发金/钻
	var slot_idx: int = 2
	if tile.y < 70:
		loot[slot_idx] = {"item_id": "copper_ore", "count": rng.randi_range(5, 10)}
		slot_idx += 1
		if rng.randf() < 0.6:
			loot[slot_idx] = {"item_id": "tin_ore", "count": rng.randi_range(5, 10)}
			slot_idx += 1
		loot[slot_idx] = {"item_id": "planks", "count": rng.randi_range(8, 15)}
		slot_idx += 1
	else:
		loot[slot_idx] = {"item_id": "iron_ore", "count": rng.randi_range(4, 9)}
		slot_idx += 1
		loot[slot_idx] = {"item_id": "coal_ore", "count": rng.randi_range(6, 12)}
		slot_idx += 1
		if tile.y >= 100 and rng.randf() < 0.5:
			loot[slot_idx] = {"item_id": "gold_ore", "count": rng.randi_range(2, 5)}
			slot_idx += 1
		if tile.y >= 100 and rng.randf() < 0.15:
			loot[slot_idx] = {"item_id": "diamond_ore", "count": rng.randi_range(1, 2)}
			slot_idx += 1
	_chests[tile] = loot


# === 存档 ===

# 序列化所有箱子内容 → Dictionary<"x,y", Array[24] dict slots>
# JSON / Resource 不支持 Vector2i key, 转 String "x,y".
# 顺带 dump _treasure_marked 防 chunk 重载后还原矿洞宝箱.
func dump() -> Dictionary:
	var out: Dictionary = {}
	for k in _chests.keys():
		var pos: Vector2i = k
		var key_str: String = "%d,%d" % [pos.x, pos.y]
		out[key_str] = _chests[k].duplicate()
	var marked: Array = []
	for k in _treasure_marked.keys():
		var pos: Vector2i = k
		marked.append("%d,%d" % [pos.x, pos.y])
	return {"chests": out, "treasure_marked": marked}


# 从存档还原. 清空当前, 重建字典.
# 兼容老存档 (只有 chests 字段或直接是 chests dict).
func restore(data: Dictionary) -> void:
	_chests.clear()
	_treasure_marked.clear()
	# 新格式: {"chests": {...}, "treasure_marked": [...]}
	# 老格式: {"x,y": [...], ...} 直接是 chest dict
	var chests_dict: Dictionary = data
	if data.has("chests") and data.chests is Dictionary:
		chests_dict = data.chests
		if data.has("treasure_marked"):
			for s in data.treasure_marked:
				var parts: PackedStringArray = String(s).split(",")
				if parts.size() == 2:
					_treasure_marked[Vector2i(int(parts[0]), int(parts[1]))] = true
	for k in chests_dict.keys():
		var parts: PackedStringArray = String(k).split(",")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_chests[tile] = chests_dict[k]
