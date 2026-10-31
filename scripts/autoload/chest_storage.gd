# 全局箱子存储 (autoload). tile 坐标 (Vector2i) → 40 格物品槽数组.
# 槽格式: null (空) 或 {"item_id": String, "count": int}, 跟 player_inventory 一致.
# 存档时 SaveManager 调 dump() / restore() 持久化.
extends Node

const SLOTS_PER_CHEST := 40

# 旧战利品表，仅保留作迁移参考；不再用于新宝箱。
const SPECIAL_WEAPONS := ["blue_moon", "fire_god", "leaf_blade", "frost_blade", "skyfall_blade", "starfall_blade", "soul_eater", "void_blade", "magnet_blade", "echo_blade", "crimson_blade", "thunder_flail", "inferno_flail", "abyss_flail", "titan_flail", "frost_flail", "flame_flail", "leaf_flail"]

# tile_coord (Vector2i) → Array[40] of slot dicts
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
	if _chests[tile_coord].size() < SLOTS_PER_CHEST:
		_chests[tile_coord].resize(SLOTS_PER_CHEST)
	return _chests[tile_coord]


# 联机: 用对端发来的整箱内容覆盖本地 (JSON 过来 count 是 float, 这里归一化成 int).
func set_slots(tile_coord: Vector2i, slots: Array) -> void:
	var arr: Array = []
	arr.resize(SLOTS_PER_CHEST)
	for i in SLOTS_PER_CHEST:
		var s = slots[i] if i < slots.size() else null
		if s is Dictionary and s.has("item_id"):
			arr[i] = {"item_id": String(s["item_id"]), "count": int(s.get("count", 1))}
		else:
			arr[i] = null
	_chests[tile_coord] = arr


# 箱子方块被破坏时调: 把里面的内容当 ItemDrop 撒出来, 删字典 entry.
func clear(tile_coord: Vector2i) -> Array:
	if not _chests.has(tile_coord):
		return []
	var contents: Array = _chests[tile_coord]
	_chests.erase(tile_coord)
	return contents


# 矿洞宝箱首次填战利品. 同位置只填一次 (用 _treasure_marked 标记),
# 玩家拿光后或砸了空箱子, 即便 chunk 重载也不会再填.
# 第一批使用原版中存在的探索补给，尚未补全各箱子的原版独占奖励。
# 钻石箱 ID 仅用于旧档兼容，新生成的底图已改为金箱。
# tile_id 没传时, 兼容回退到按 tile.y 判 (老 caller).
func try_populate_treasure(tile: Vector2i, world_seed: int, tile_id: int = -1) -> void:
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
	# 决定 tier: 优先用 tile_id (caller 传), 否则按 tile.y (兼容老 caller).
	# Tiles.CHEST=37 / GOLD_CHEST=54 / DIAMOND_CHEST=55 / SHADOW_CHEST=60 (硬编码避免 require Tiles autoload)
	var tier: int = 0   # 0=wood, 1=gold, 2=diamond, 3=shadow
	if tile_id == 54:
		tier = 1
	elif tile_id == 55:
		tier = 2
	elif tile_id == 60:
		tier = 3
	elif tile_id < 0:
		# 老 caller 兼容: 按 y 判
		if tile.y >= 100: tier = 2
		elif tile.y >= 75: tier = 1
	# 基础探索战利品：去掉煤燃料、农作物种子、钻石盔甲和自创神兵。
	# 深层仍给更多补给；完整原版宝箱独占物品尚未全部实现。
	loot[0] = {"item_id": "torch", "count": rng.randi_range(5, 15)}
	loot[1] = {"item_id": "health_potion", "count": rng.randi_range(2, 4)}
	loot[2] = {"item_id": "rope", "count": rng.randi_range(20, 50)}
	loot[3] = {"item_id": "wood_arrow", "count": rng.randi_range(25, 50)}
	var bars: Array = ["copper_ingot", "tin_ingot"] if tier == 0 else ["iron_ingot", "silver_ingot", "gold_ingot"]
	loot[4] = {"item_id": bars[rng.randi() % bars.size()], "count": rng.randi_range(3, 8)}
	if tier == 0:
		loot[5] = {"item_id": "boomerang", "count": 1}
	_chests[tile] = loot

# 随机挑 3 件盔甲之一 (helmet / chest / pants) 返回 item_id. tier 是 "copper" / "iron" 等.
func _pick_armor_piece(rng: RandomNumberGenerator, tier: String) -> String:
	var pieces: Array = ["helmet", "chest", "pants"]
	var piece: String = pieces[rng.randi() % pieces.size()]
	return "%s_%s" % [tier, piece]


# === 存档 ===

# 序列化所有箱子内容 → Dictionary<"x,y", Array[40] dict slots>
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
		var arr = chests_dict[k]
		if arr is Array:
			ItemDB.canon_slots(arr)   # 改名物品兼容 (弹跳枪→史莱姆冲锋枪)
			if arr.size() < SLOTS_PER_CHEST: arr.resize(SLOTS_PER_CHEST)
		_chests[tile] = arr
