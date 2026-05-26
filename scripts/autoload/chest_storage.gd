# 全局箱子存储 (autoload). tile 坐标 (Vector2i) → 24 格物品槽数组.
# 槽格式: null (空) 或 {"item_id": String, "count": int}, 跟 player_inventory 一致.
# 存档时 SaveManager 调 dump() / restore() 持久化.
extends Node

const SLOTS_PER_CHEST := 24

# tile_coord (Vector2i) → Array[24] of slot dicts
var _chests: Dictionary = {}


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


# === 存档 ===

# 序列化所有箱子内容 → Dictionary<"x,y", Array[24] dict slots>
# JSON / Resource 不支持 Vector2i key, 转 String "x,y".
func dump() -> Dictionary:
	var out: Dictionary = {}
	for k in _chests.keys():
		var pos: Vector2i = k
		var key_str: String = "%d,%d" % [pos.x, pos.y]
		out[key_str] = _chests[k].duplicate()
	return out


# 从存档还原. 清空当前, 重建字典.
func restore(data: Dictionary) -> void:
	_chests.clear()
	for k in data.keys():
		var parts: PackedStringArray = String(k).split(",")
		if parts.size() != 2:
			continue
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		_chests[tile] = data[k]
