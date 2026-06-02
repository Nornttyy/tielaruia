# 存档管理 autoload. 多存档系统: user://saves/{world_name}.tres
# 老 user://save.tres 兼容: 启动时自动迁移成 "默认存档".
extends Node

const SaveData = preload("res://scripts/save/save_data.gd")
const SAVES_DIR := "user://saves/"
const LEGACY_SAVE_PATH := "user://save.tres"

signal save_completed
signal load_completed(data: SaveData)


func _ready() -> void:
	# 确保目录存在
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		DirAccess.make_dir_absolute(SAVES_DIR)
	# 迁移老存档 (user://save.tres → user://saves/默认存档.tres)
	_migrate_legacy_save()


func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	var legacy = ResourceLoader.load(LEGACY_SAVE_PATH)
	if not legacy is SaveData:
		return
	# 老存档可能没 world_name, 给个默认
	var name: String = legacy.world_name if (legacy.world_name != null and legacy.world_name != "") else "默认存档"
	var new_path: String = SAVES_DIR + name + ".tres"
	if not FileAccess.file_exists(new_path):
		ResourceSaver.save(legacy, new_path)
	# 不删除老文件 (保险, 用户重启游戏看不到老存档丢了)


# 从 main + world + player 收集状态, 写到 user://saves/{world_name}.tres.
# 返回 true 表示成功写盘.
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
	data.world_size = GameSettings.current_world_size if GameSettings != null else 1
	data.spawn_point = world.spawn_point
	# 床复活点 (玩家睡过床后才有意义)
	if "bed_spawn_point" in world:
		data.bed_spawn_point = world.bed_spawn_point
	# 世界时间 (昼夜) - 让玩家加载后接着原来的时间过, 而不是回到早晨
	if TimeOfDay != null and "time" in TimeOfDay:
		data.world_time = TimeOfDay.time
	data.chunk_deltas = _serialize_chunk_deltas(world.chunk_manager)
	data.entities = _serialize_entities()
	data.chest_contents = ChestStorage.dump()
	# 生命水晶世界限: 累计已放数 + 已处理 chunk 列表 + 已放位置 (防间距重新算)
	if world.chunk_manager != null:
		data.life_crystals_spawned = world.chunk_manager.life_crystals_spawned
		var arr: PackedInt32Array = PackedInt32Array()
		for cx in world.chunk_manager.processed_chunks.keys():
			arr.append(int(cx))
		data.processed_chunks = arr
		# positions 扁平存 [x0,y0, x1,y1, ...] 让 PackedInt32Array 装下
		var pos_arr: PackedInt32Array = PackedInt32Array()
		for p in world.chunk_manager.life_crystal_positions:
			pos_arr.append(int(p.x))
			pos_arr.append(int(p.y))
		data.life_crystal_positions = pos_arr
		# 同款: 魔力水晶 spawned + positions
		data.mana_crystals_spawned = world.chunk_manager.mana_crystals_spawned
		var mc_pos_arr: PackedInt32Array = PackedInt32Array()
		for p in world.chunk_manager.mana_crystal_positions:
			mc_pos_arr.append(int(p.x))
			mc_pos_arr.append(int(p.y))
		data.mana_crystal_positions = mc_pos_arr
	# 已 spawn 过守卫木乃伊的金字塔 chunk_x 列表 (防 chunk 重载/存档重读后木乃伊复活)
	var pyramid_arr: PackedInt32Array = PackedInt32Array()
	if "_pyramid_chunks_spawned" in world:
		for cx in world._pyramid_chunks_spawned.keys():
			pyramid_arr.append(int(cx))
	data.pyramid_chunks_spawned = pyramid_arr
	# 世纪树已删 (用户要求), data.world_tree_chunks_spawned 字段留空保留向后兼容
	data.world_tree_chunks_spawned = PackedInt32Array()
	# 废弃矿井蜘蛛同款持久化
	var ms_arr: PackedInt32Array = PackedInt32Array()
	if "_mineshaft_chunks_spawned" in world:
		for cx in world._mineshaft_chunks_spawned.keys():
			ms_arr.append(int(cx))
	data.mineshaft_chunks_spawned = ms_arr
	var player: Node2D = world.get_player()
	if player != null:
		data.player_position = player.global_position
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and "current_health" in hp:
			data.player_hp = float(hp.current_health)
			# 永久上限 (吃水晶+20 那个值). 没 MAX_HEALTH 字段 → 兜底 100.
			data.player_max_hp = int(hp.MAX_HEALTH) if "MAX_HEALTH" in hp else 100
		# 魔力: current + max (跟 hp 同套). 没节点也存 0
		var mn: Node = player.get_node_or_null("PlayerMana")
		if mn != null and "current_mana" in mn:
			data.player_mana = int(mn.current_mana)
			data.player_max_mana = int(mn.MAX_MANA) if "MAX_MANA" in mn else 100
		var inv_node: Node = player.get_node_or_null("PlayerInventory")
		if inv_node != null and inv_node.inventory != null:
			data.inventory_slots = _serialize_inventory(inv_node.inventory.slots)
			data.hotbar_selection = inv_node.hotbar_selected
			# 盔甲槽 (3 槽, item_id 字符串. null → "")
			data.armor_helmet_id = "" if inv_node.armor_helmet == null else String(inv_node.armor_helmet.item_id)
			data.armor_chest_id = "" if inv_node.armor_chest == null else String(inv_node.armor_chest.item_id)
			data.armor_pants_id = "" if inv_node.armor_pants == null else String(inv_node.armor_pants.item_id)
	# 存档名: 用 world_name; 没有就 fallback. 防路径注入: 把危险字符替换掉.
	var save_name: String = data.world_name if (data.world_name != null and data.world_name != "") else "默认存档"
	# 把 / \ .. : * ? " < > | 这些路径相关 / 文件系统非法字符全替换为 _
	for bad_char in ["/", "\\", "..", ":", "*", "?", "\"", "<", ">", "|"]:
		save_name = save_name.replace(bad_char, "_")
	if save_name.is_empty():
		save_name = "默认存档"
	var path: String = SAVES_DIR + save_name + ".tres"
	# 原子写: 先写 tmp 再 rename. 防 1Hz autosave 时浏览器关掉 / 断电留半残 .tres
	# (老 bug: 直接 ResourceSaver.save(path) 中途崩 → 下次启动加载失败).
	# 注意: tmp 也必须 .tres 结尾! ResourceSaver 按扩展名选格式, ".tmp" 不被识别会报
	# ERR_FILE_UNRECOGNIZED(15) → 存档全失败 (之前就是这个 bug). 故用 ".tmp.tres".
	var tmp_path: String = SAVES_DIR + save_name + ".tmp.tres"
	var err: int = ResourceSaver.save(data, tmp_path)
	if err != OK:
		push_error("save: ResourceSaver 失败 err=%d" % err)
		return false
	# rename 在大多数 FS 是原子的; web (HTML5 idbfs) 也支持
	var rename_err: int = DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		push_error("save: rename .tmp → .tres 失败 err=%d" % rename_err)
		DirAccess.remove_absolute(tmp_path)  # 别留垃圾
		return false
	# 网页版: 把刚写的存档"刷进"浏览器的 IndexedDB.
	# 浏览器里 user:// 其实存在内存文件系统 (IDBFS), 不主动刷一下, 关页面/刷新就丢了.
	# 这是"网页版丢存档"最可能的原因. 桌面/测试上这步自动跳过, 不受影响.
	_flush_web_filesystem()
	save_completed.emit()
	return true


# 网页版专用: 请求浏览器把内存里的存档同步到 IndexedDB (持久化).
# 非网页平台 (桌面 / gut 测试) 直接 no-op.
# 说明: 这是 best-effort. Godot web 导出本身有个定时自动同步, 但玩家可能在它跑之前
# 就关了页面 → 丢档. 这里存完立刻主动喊一次, 把丢档窗口压到最小.
func _flush_web_filesystem() -> void:
	if not OS.has_feature("web"):
		return
	# 调浏览器的 Emscripten 文件系统 FS.syncfs(false, cb): false = 内存 → IndexedDB 方向.
	# 用 typeof 兜底: 万一这版导出没把 FS 暴露到全局, 也不会报错, 只是这次不刷.
	JavaScriptBridge.eval("""
		try {
			if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(e){}); }
		} catch (e) {}
	""", true)


# 列出所有存档. 按文件修改时间排序 (最新的在前).
func list_saves() -> Array:
	var out: Array = []
	if not DirAccess.dir_exists_absolute(SAVES_DIR):
		return out
	var dir := DirAccess.open(SAVES_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres") and not file_name.ends_with(".tmp.tres"):
			var full_path: String = SAVES_DIR + file_name
			var res = ResourceLoader.load(full_path)
			if res is SaveData:
				out.append({
					"name": file_name.replace(".tres", ""),
					"data": res,
					"path": full_path,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	# TODO 按时间排序 (FileAccess.get_modified_time 在 web 可能不可用, 暂保持文件名顺序)
	return out


# 用存档名读特定存档. None → null. 防路径注入同 delete_save_by_name.
func load_save_by_name(save_name: String) -> SaveData:
	if save_name.is_empty() or save_name.contains("/") or save_name.contains("\\") or save_name.contains(".."):
		push_warning("load_save_by_name: 非法存档名 '%s', 拒绝读" % save_name)
		return null
	var path: String = SAVES_DIR + save_name + ".tres"
	if not FileAccess.file_exists(path):
		return null
	var res = ResourceLoader.load(path)
	if not res is SaveData:
		push_error("load: 文件不是 SaveData")
		return null
	load_completed.emit(res)
	return res


# 兼容老 API (单存档): 返回第一个存档 (用于"继续上次")
func load_save() -> SaveData:
	var saves := list_saves()
	if saves.is_empty():
		return null
	return saves[0]["data"]


func has_save() -> bool:
	return not list_saves().is_empty()


# 删一个存档 (不可恢复). 防路径注入: save_name 不能含 "/" / ".." / 空 (否则可删任意文件).
func delete_save_by_name(save_name: String) -> void:
	if save_name.is_empty() or save_name.contains("/") or save_name.contains("\\") or save_name.contains(".."):
		push_warning("delete_save_by_name: 非法存档名 '%s', 拒绝删" % save_name)
		return
	var path: String = SAVES_DIR + save_name + ".tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# 兼容老 API: 删 LEGACY_SAVE_PATH
func delete_save() -> void:
	if FileAccess.file_exists(LEGACY_SAVE_PATH):
		DirAccess.remove_absolute(LEGACY_SAVE_PATH)


# 把 inventory.slots (Array of Dictionary or null) 转可序列化形式.
func _serialize_inventory(slots: Array) -> Array:
	var out: Array = []
	for s in slots:
		if s == null:
			out.append(null)
		else:
			out.append({"item_id": s.item_id, "count": s.count})
	return out


# Vector2i 在 .tres 里不能当 Dict key, 转成 flat PackedInt32Array (lx, y, tid)*N.
# 返回 Dict<int (cx), PackedInt32Array>.
func _serialize_chunk_deltas(cm) -> Dictionary:
	var out: Dictionary = {}
	for cx in cm._deltas.keys():
		var inner: Dictionary = cm._deltas[cx]
		var arr := PackedInt32Array()
		for pos_v2i in inner.keys():
			arr.append(pos_v2i.x)
			arr.append(pos_v2i.y)
			arr.append(inner[pos_v2i])
		# 用字符串 key: Godot .tres ResourceSaver 会丢掉整数 key 0
		# (出生点 = 0 号区块 → 出生点附近的建筑/挖掘存档后全没了!). str(cx) 绕开.
		out[str(cx)] = arr
	return out


# 把序列化的 deltas 还原到 chunk_manager._deltas (供 load 后调用).
static func apply_chunk_deltas(cm, serialized: Dictionary) -> void:
	for cx_key in serialized.keys():
		var cx: int = int(cx_key)   # key 现在是 String (老存档可能是 int, int() 都兼容)
		var arr: PackedInt32Array = serialized[cx_key]
		var inner: Dictionary = {}
		var i: int = 0
		while i + 2 < arr.size():
			inner[Vector2i(arr[i], arr[i + 1])] = arr[i + 2]
			i += 3
		cm._deltas[cx] = inner


# 收集 slime/villager/item_drop 位置 + 状态.
func _serialize_entities() -> Array:
	var out: Array = []
	for s in get_tree().get_nodes_in_group("slimes"):
		# Boss 也在 "slimes" 组, 但不能当普通史莱姆存 (reload 会刷成小史莱姆), 跳过
		if s.is_in_group("boss"):
			continue
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


# 反序列化背包槽 — 给外部调用方用 (load 后把 SaveData.inventory_slots 还原).
static func deserialize_inventory(stored: Array) -> Array:
	var out: Array = []
	for s in stored:
		if s == null:
			out.append(null)
		else:
			out.append({"item_id": s.item_id, "count": s.count})
	return out
