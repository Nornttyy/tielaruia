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
static func char_to_tile(ch: String) -> int:
	match ch:
		"P":
			return Tiles.PLANKS
		"D":
			return Tiles.DOOR
		_:
			return -1   # skip
