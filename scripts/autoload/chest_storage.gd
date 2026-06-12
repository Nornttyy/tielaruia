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
# 战利品 4 层 (按 tile_id 选, 与 world_generator 选 tile tier 一致):
#   木宝箱 (CHEST): 火把+食物+铜锡+木板 → 早期入门
#   金宝箱 (GOLD_CHEST): 火把+食物+铁/煤+铜锡锭 → 中期升级
#   钻石宝箱 (DIAMOND_CHEST): 火把+食物+金/钻/银+金锭 → 深矿豪华
#   阴影宝箱 (SHADOW_CHEST): 地狱专属, 黑曜石+地狱石+火果+银金锭+大量火把
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
	# 三层都有: 火把 + 熟肉. 数量按层翻倍.
	var torch_min: int = 5
	var torch_max: int = 12
	var meat_min: int = 1
	var meat_max: int = 3
	if tier == 3:
		torch_min = 15; torch_max = 30; meat_min = 3; meat_max = 6
	elif tier == 2:
		torch_min = 10; torch_max = 20; meat_min = 2; meat_max = 5
	elif tier == 1:
		torch_min = 8; torch_max = 16; meat_min = 2; meat_max = 4
	loot[0] = {"item_id": "torch", "count": rng.randi_range(torch_min, torch_max)}
	loot[1] = {"item_id": "cooked_meat", "count": rng.randi_range(meat_min, meat_max)}
	var slot_idx: int = 2
	if tier == 3:
		# 阴影层 (地狱): 黑曜石 + 地狱石 + 火果 + 钻石 + 银金锭. 最豪华.
		loot[slot_idx] = {"item_id": "obsidian", "count": rng.randi_range(5, 12)}; slot_idx += 1
		loot[slot_idx] = {"item_id": "hell_stone", "count": rng.randi_range(8, 18)}; slot_idx += 1
		loot[slot_idx] = {"item_id": "hell_fruit", "count": rng.randi_range(2, 5)}; slot_idx += 1
		if rng.randf() < 0.8:
			loot[slot_idx] = {"item_id": "diamond", "count": rng.randi_range(2, 4)}; slot_idx += 1
		if rng.randf() < 0.6:
			loot[slot_idx] = {"item_id": "gold_ingot", "count": rng.randi_range(2, 4)}; slot_idx += 1
		if rng.randf() < 0.4:
			loot[slot_idx] = {"item_id": "silver_ingot", "count": rng.randi_range(2, 4)}; slot_idx += 1
		# 钻石盔甲 (60%) 或 金 (30%): 最豪华装备
		var shadow_armor: String = _pick_armor_piece(rng, "diamond" if rng.randf() < 0.6 else "gold")
		if shadow_armor != "":
			loot[slot_idx] = {"item_id": shadow_armor, "count": 1}; slot_idx += 1
	elif tier == 2:
		# 钻石层: 金矿 + 银矿 + 钻石 + 金锭
		loot[slot_idx] = {"item_id": "gold_ore", "count": rng.randi_range(3, 7)}; slot_idx += 1
		loot[slot_idx] = {"item_id": "silver_ore", "count": rng.randi_range(3, 7)}; slot_idx += 1
		if rng.randf() < 0.6:
			loot[slot_idx] = {"item_id": "diamond", "count": rng.randi_range(1, 3)}; slot_idx += 1
		if rng.randf() < 0.5:
			loot[slot_idx] = {"item_id": "gold_ingot", "count": rng.randi_range(1, 3)}; slot_idx += 1
		if rng.randf() < 0.3:
			loot[slot_idx] = {"item_id": "iron_ingot", "count": rng.randi_range(1, 3)}; slot_idx += 1
		# 银/金盔甲 (50/30/10 → silver/gold/diamond)
		var r2: float = rng.randf()
		var t2: String = "silver" if r2 < 0.5 else ("gold" if r2 < 0.8 else "diamond")
		var dia_armor: String = _pick_armor_piece(rng, t2)
		if dia_armor != "":
			loot[slot_idx] = {"item_id": dia_armor, "count": 1}; slot_idx += 1
	elif tier == 1:
		# 金层: 铁/煤 + 偶发铜锡锭 + 偶发银锭
		loot[slot_idx] = {"item_id": "iron_ore", "count": rng.randi_range(4, 9)}; slot_idx += 1
		loot[slot_idx] = {"item_id": "coal", "count": rng.randi_range(6, 12)}; slot_idx += 1
		if rng.randf() < 0.5:
			loot[slot_idx] = {"item_id": "copper_ingot", "count": rng.randi_range(1, 3)}; slot_idx += 1
		if rng.randf() < 0.5:
			loot[slot_idx] = {"item_id": "tin_ingot", "count": rng.randi_range(1, 3)}; slot_idx += 1
		if rng.randf() < 0.3:
			loot[slot_idx] = {"item_id": "silver_ingot", "count": rng.randi_range(1, 2)}; slot_idx += 1
		# 铁/银盔甲 (50% 铁, 15% 银)
		if rng.randf() < 0.50:
			var t1: String = "silver" if rng.randf() < 0.30 else "iron"
			var gold_armor: String = _pick_armor_piece(rng, t1)
			if gold_armor != "":
				loot[slot_idx] = {"item_id": gold_armor, "count": 1}; slot_idx += 1
	else:
		# 木层 (浅): 铜锡矿 + 木板 + 偶发苹果
		loot[slot_idx] = {"item_id": "copper_ore", "count": rng.randi_range(5, 10)}; slot_idx += 1
		if rng.randf() < 0.6:
			loot[slot_idx] = {"item_id": "tin_ore", "count": rng.randi_range(5, 10)}; slot_idx += 1
		loot[slot_idx] = {"item_id": "planks", "count": rng.randi_range(8, 15)}; slot_idx += 1
		if rng.randf() < 0.4:
			loot[slot_idx] = {"item_id": "apple", "count": rng.randi_range(2, 5)}; slot_idx += 1
		# 铜盔甲 (25% 概率) — 新手鼓励
		if rng.randf() < 0.25:
			var wood_armor: String = _pick_armor_piece(rng, "copper")
			if wood_armor != "":
				loot[slot_idx] = {"item_id": wood_armor, "count": 1}; slot_idx += 1
		# 小麦种子 (50% 概率, 1-3 颗) — 菜园起步
		if rng.randf() < 0.5:
			loot[slot_idx] = {"item_id": "wheat_seed", "count": rng.randi_range(1, 3)}; slot_idx += 1
	_chests[tile] = loot


# 随机挑 3 件盔甲之一 (helmet / chest / pants) 返回 item_id. tier 是 "copper" / "iron" 等.
func _pick_armor_piece(rng: RandomNumberGenerator, tier: String) -> String:
	var pieces: Array = ["helmet", "chest", "pants"]
	var piece: String = pieces[rng.randi() % pieces.size()]
	return "%s_%s" % [tier, piece]


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
		var arr = chests_dict[k]
		if arr is Array:
			ItemDB.canon_slots(arr)   # 改名物品兼容 (弹跳枪→史莱姆冲锋枪)
		_chests[tile] = arr
