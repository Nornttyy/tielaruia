# 存档管理 autoload。save()/load() 接口。
# M1 范围: 玩家 + 背包 + 种子 + 出生点。terrain/entities 由 S2/S3 添加。
extends Node

const SaveData = preload("res://scripts/save/save_data.gd")
const SAVE_PATH := "user://save.tres"

signal save_completed
signal load_completed(data: SaveData)


# 从 main + world + player 收集状态, 写到 user://save.tres。
# 返回 true 表示成功写盘。
func save(main: Node) -> bool:
	if main == null:
		push_error("save: main 为 null")
		return false
	var world: Node2D = main.get_node_or_null("World")
	if world == null:
		push_error("save: world 不存在")
		return false
	var data := SaveData.new()
	data.world_seed = world.world_seed
	data.world_name = GameSettings.current_world_name if GameSettings != null else ""
	data.difficulty = GameSettings.current_difficulty if GameSettings != null else 1
	data.spawn_point = world.spawn_point
	data.chunk_deltas = _serialize_chunk_deltas(world.chunk_manager)
	data.entities = _serialize_entities()
	var player: Node2D = world.get_player()
	if player != null:
		data.player_position = player.global_position
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and "current_health" in hp:
			data.player_hp = float(hp.current_health)
		var inv_node: Node = player.get_node_or_null("PlayerInventory")
		if inv_node != null and inv_node.inventory != null:
			data.inventory_slots = _serialize_inventory(inv_node.inventory.slots)
			data.hotbar_selection = inv_node.hotbar_selected
	var err: int = ResourceSaver.save(data, SAVE_PATH)
	if err != OK:
		push_error("save: ResourceSaver 失败 err=%d" % err)
		return false
	save_completed.emit()
	return true


# 从 user://save.tres 读取 SaveData。无文件返回 null。
func load_save() -> SaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var res = ResourceLoader.load(SAVE_PATH)
	if not res is SaveData:
		push_error("load: 文件不是 SaveData")
		return null
	load_completed.emit(res)
	return res


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# 把 inventory.slots (Array of Dictionary or null) 转可序列化形式。
func _serialize_inventory(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append({"item_id": s.item_id, "count": s.count})
	return out


# Vector2i 在 .tres 里不能当 Dict key, 转成 flat PackedInt32Array (lx, y, tid)*N.
# 返回 Dict<int (cx), PackedInt32Array>。
func _serialize_chunk_deltas(cm) -> Dictionary:
	var out: Dictionary = {}
	for cx in cm._deltas.keys():
		var inner: Dictionary = cm._deltas[cx]
		var arr := PackedInt32Array()
		for pos_v2i in inner.keys():
			arr.append(pos_v2i.x)
			arr.append(pos_v2i.y)
			arr.append(inner[pos_v2i])
		out[cx] = arr
	return out


# 把序列化的 deltas 还原到 chunk_manager._deltas (供 load 后调用)。
static func apply_chunk_deltas(cm, serialized: Dictionary) -> void:
	for cx in serialized.keys():
		var arr: PackedInt32Array = serialized[cx]
		var inner: Dictionary = {}
		var i: int = 0
		while i + 2 < arr.size():
			inner[Vector2i(arr[i], arr[i + 1])] = arr[i + 2]
			i += 3
		cm._deltas[cx] = inner


# 收集 slime/villager/item_drop 位置 + 状态。
func _serialize_entities() -> Array:
	var out: Array = []
	for s in get_tree().get_nodes_in_group("slimes"):
		out.append({"type": "slime", "pos": s.global_position})
	for v in get_tree().get_nodes_in_group("villagers"):
		out.append({"type": "villager", "pos": v.global_position})
	for d in get_tree().get_nodes_in_group("item_drops"):
		out.append({
			"type": "item_drop",
			"pos": d.global_position,
			"item_id": d.item_id,
			"count": d.count
		})
	return out


# 反序列化背包槽 — 给外部调用方用 (load 后把 SaveData.inventory_slots 还原)。
static func deserialize_inventory(stored: Array) -> Array:
	var out: Array = []
	for s in stored:
		if s == null:
			out.append(null)
		else:
			out.append({"item_id": s.item_id, "count": s.count})
	return out
