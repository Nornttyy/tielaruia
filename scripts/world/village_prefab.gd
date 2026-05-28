# 村庄预制解析器。读 JSON, 验证字段, 暴露 houses 列表。
# 每间屋子: { anchor_x, anchor_y, grid (Array[String]), villager_offset (Array[int, int] | null) }
class_name VillagePrefab extends RefCounted

const PATH := "res://resources/prefabs/village.json"


static func load_default() -> Dictionary:
	return load_from(PATH)


static func load_from(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("village prefab 打不开: " + path)
		return {}
	var text: String = file.get_as_text()
	var parsed = JSON.parse_string(text)
	if not parsed is Dictionary:
		push_error("village prefab 不是 JSON 对象")
		return {}
	if not parsed.has("houses"):
		push_error("village prefab 缺 houses 字段")
		return {}
	return parsed


# 把 grid 字符转 tile_id。'.' 表示不写 (跳过, 保留原 tile)。
# 扩展 char 让 prefab 能放家具/装饰让村子像样:
#   P/W = wall (PLANKS/STONE), D = DOOR, L = LOG (柱/梁)
#   C = CHEST, B = WORKBENCH, F = FURNACE, T = TORCH (室内灯)
#   _ = WOOD_PLATFORM (穿过式平台, 阁楼地板)
static func char_to_tile(ch: String) -> int:
	match ch:
		"P":
			return Tiles.PLANKS
		"D":
			return Tiles.DOOR
		"L":
			return Tiles.LOG
		"W":
			return Tiles.STONE
		"C":
			return Tiles.CHEST
		"B":
			return Tiles.WORKBENCH
		"F":
			return Tiles.FURNACE
		"T":
			return Tiles.TORCH
		"_":
			return Tiles.WOOD_PLATFORM
		_:
			return -1   # skip
