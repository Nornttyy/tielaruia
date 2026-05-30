# 持有所有 loaded chunks + 玩家修改 delta。
# 调度 load/unload 由 World._physics_process 触发 (调 ensure_loaded / unload_far_from)。
class_name ChunkManager extends Node

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

signal chunk_loaded(chunk: Chunk)
signal chunk_unloaded(chunk_x: int)

const LIFE_CRYSTAL_PER_PLAYER := 15   # 每个玩家世界上限 15 颗水晶 (单人 15, 联机 ×N)
const LIFE_CRYSTAL_MIN_DIST := 40     # 任意两颗水晶世界坐标最小曼哈顿距离 (约 2/3 chunk 宽)
const MANA_CRYSTAL_PER_PLAYER := 5    # 每玩家 5 颗 (100 base + 5×20 = 200 cap)
const MANA_CRYSTAL_MIN_DIST := 60     # 比 life_crystal 离得更远 (更稀有)

var world_seed: int = 0
var _loaded: Dictionary = {}    # chunk_x: int → Chunk
var _deltas: Dictionary = {}    # chunk_x: int → Dict[Vector2i → tid]
# 生命水晶世界限制: 跨 chunk 总量上限 + 最小间距.
# spawned = 已放出数 (含被吃的). processed_chunks = 已查过 cap 的 chunk_x.
# positions = 所有已放水晶世界坐标 (用 Vector2i 存 — 即使被吃也保留, 防 "原位置再生").
var life_crystals_spawned: int = 0
var processed_chunks: Dictionary = {}   # chunk_x → true (O(1) 查重)
var life_crystal_positions: Array = []   # Array of Vector2i (world coords)
# 魔力水晶: 同款 cap + 位置追踪
var mana_crystals_spawned: int = 0
var mana_crystal_positions: Array = []


func setup(p_seed: int) -> void:
	world_seed = p_seed
	add_to_group("chunk_manager")


# 联机里把水晶按 deterministic 哈希分配 owner (0 或 1).
# 单人 → 全部 owner 0. 联机两个玩家都用同一公式 → 算出一致结果, 不需同步.
# 用 (x*73 + y*31) % 2 做位置 → owner 索引. 73/31 是素数减少 pattern.
static func crystal_owner_for_pos(pos: Vector2i) -> int:
	return (int(pos.x) * 73 + int(pos.y) * 31) & 1


# 本地玩家在网络里的 peer 索引: host = 0, client = 1. 单人也 0.
# 这跟 crystal_owner_for_pos 对得上 — host 看到 owner=0 的水晶, client 看到 owner=1 的.
func local_peer_idx() -> int:
	if NetworkManager == null or not NetworkManager.has_method("connected") or not NetworkManager.connected():
		return 0
	return 0 if NetworkManager.is_host else 1


# 这颗水晶是不是属于本地玩家? 单人永远 true. 联机时按 owner 哈希分.
func is_my_crystal(pos: Vector2i) -> bool:
	if NetworkManager == null or not NetworkManager.has_method("connected") or not NetworkManager.connected():
		return true   # 单人, 都是自己的
	return crystal_owner_for_pos(pos) == local_peer_idx()


# 当前世界水晶上限 = 15 × 玩家数. NetworkManager 不存在或没连 = 单人 = 1 个玩家.
# 联机 PeerJS 是 2 人, connected() true 时返 2.
func current_crystal_cap() -> int:
	var players: int = 1
	if NetworkManager != null and NetworkManager.has_method("connected") and NetworkManager.connected():
		players = 2  # PeerJS host + 1 client
	return LIFE_CRYSTAL_PER_PLAYER * players


func current_mana_crystal_cap() -> int:
	var players: int = 1
	if NetworkManager != null and NetworkManager.has_method("connected") and NetworkManager.connected():
		players = 2
	return MANA_CRYSTAL_PER_PLAYER * players


# 加载 center_cx ± VIEW_RADIUS 范围内的 chunks
func ensure_loaded(center_cx: int) -> void:
	var radius: int = ChunkConstants.VIEW_RADIUS
	for cx in range(center_cx - radius, center_cx + radius + 1):
		if not _loaded.has(cx):
			_load_chunk(cx)


# 卸载超出 keep_radius 的 chunks
func unload_far_from(center_cx: int, keep_radius: int) -> void:
	var to_unload: Array = []
	for cx in _loaded.keys():
		if abs(cx - center_cx) > keep_radius:
			to_unload.append(cx)
	for cx in to_unload:
		_unload_chunk(cx)


func _load_chunk(cx: int) -> void:
	var c := WorldGenerator.generate_chunk(world_seed, cx, ChunkConstants.WORLD_HEIGHT)
	# 应用之前累积的 delta (如果有). 玩家挖过的 chest tile delta 优先, 不会再 spawn 物品.
	if _deltas.has(cx):
		c.apply_delta(_deltas[cx])
	# 生命水晶上限检查: chunk 第一次加载时扫所有 LIFE_CRYSTAL, 超量的换成 AIR + 记 delta.
	# 已 processed 的 chunk 跳过 (避免重载时重复计数).
	if not processed_chunks.has(cx):
		_cap_life_crystals_in_chunk(c, cx)
		_cap_mana_crystals_in_chunk(c, cx)
		processed_chunks[cx] = true
	# 矿洞宝箱: 给 chunk 里每个新生成的 chest 位置填一次战利品 (idempotent, 重载不会再填)
	for spot in c.treasure_spots:
		# 如果 delta 已经把 chest 砸了 (变 AIR), 不填.
		var lx: int = spot.x - cx * ChunkConstants.CHUNK_WIDTH
		if lx >= 0 and lx < ChunkConstants.CHUNK_WIDTH:
			var ct: int = c.tiles[lx][spot.y]
			if ct == Tiles.CHEST or ct == Tiles.GOLD_CHEST or ct == Tiles.DIAMOND_CHEST or ct == Tiles.SHADOW_CHEST:
				ChestStorage.try_populate_treasure(spot, world_seed, ct)
	# 金字塔守卫木乃伊: chunk 首次加载时召 (世界节点接管). 已召过的 chunk 不重生.
	if not c.mummy_spawn_spots.is_empty():
		var world_node: Node = get_tree().get_first_node_in_group("world")
		if world_node != null and world_node.has_method("spawn_mummies_for_chunk"):
			world_node.spawn_mummies_for_chunk(cx, c.mummy_spawn_spots)
	# 废弃矿井守卫蜘蛛: 同款机制
	if not c.mineshaft_spider_spots.is_empty():
		var world_node3: Node = get_tree().get_first_node_in_group("world")
		if world_node3 != null and world_node3.has_method("spawn_mineshaft_spiders_for_chunk"):
			world_node3.spawn_mineshaft_spiders_for_chunk(cx, c.mineshaft_spider_spots)
	_loaded[cx] = c
	chunk_loaded.emit(c)


# 扫 chunk 的 LIFE_CRYSTAL, 保留满足 "cap + 最小间距" 的, 多余的擦掉 + 写 delta.
# 已 processed_chunks 的不再调 (防双重计数).
func _cap_life_crystals_in_chunk(c: Chunk, cx: int) -> void:
	var cap: int = current_crystal_cap()
	var chunk_w: int = ChunkConstants.CHUNK_WIDTH
	var height: int = ChunkConstants.WORLD_HEIGHT
	for lx in chunk_w:
		for wy in height:
			if c.tiles[lx][wy] != Tiles.LIFE_CRYSTAL:
				continue
			var wx: int = cx * chunk_w + lx
			var pos := Vector2i(wx, wy)
			# 决定保留 / 擦掉: 满足 cap 内 + 离任何已存在水晶 ≥ MIN_DIST 才保留
			var keep: bool = life_crystals_spawned < cap and _far_enough_from_crystals(pos)
			if keep:
				life_crystals_spawned += 1
				life_crystal_positions.append(pos)
			else:
				c.tiles[lx][wy] = Tiles.AIR
				if not _deltas.has(cx):
					_deltas[cx] = {}
				_deltas[cx][Vector2i(lx, wy)] = Tiles.AIR


# 曼哈顿距离 < MIN_DIST → 太近, 返 false. 没历史返 true.
func _far_enough_from_crystals(pos: Vector2i) -> bool:
	for p in life_crystal_positions:
		if abs(p.x - pos.x) + abs(p.y - pos.y) < LIFE_CRYSTAL_MIN_DIST:
			return false
	return true


# 同款 cap + 距离 — 跟 _cap_life_crystals_in_chunk 平行
func _cap_mana_crystals_in_chunk(c: Chunk, cx: int) -> void:
	var cap: int = current_mana_crystal_cap()
	var chunk_w: int = ChunkConstants.CHUNK_WIDTH
	var height: int = ChunkConstants.WORLD_HEIGHT
	for lx in chunk_w:
		for wy in height:
			if c.tiles[lx][wy] != Tiles.MANA_CRYSTAL:
				continue
			var wx: int = cx * chunk_w + lx
			var pos := Vector2i(wx, wy)
			var keep: bool = mana_crystals_spawned < cap and _far_enough_from_mana_crystals(pos)
			if keep:
				mana_crystals_spawned += 1
				mana_crystal_positions.append(pos)
			else:
				c.tiles[lx][wy] = Tiles.AIR
				if not _deltas.has(cx):
					_deltas[cx] = {}
				_deltas[cx][Vector2i(lx, wy)] = Tiles.AIR


func _far_enough_from_mana_crystals(pos: Vector2i) -> bool:
	for p in mana_crystal_positions:
		if abs(p.x - pos.x) + abs(p.y - pos.y) < MANA_CRYSTAL_MIN_DIST:
			return false
	return true


func _unload_chunk(cx: int) -> void:
	if not _loaded.has(cx):
		return
	_loaded.erase(cx)
	chunk_unloaded.emit(cx)


# world 坐标 (x, y) → tile_id。chunk 未 load → AIR
func get_tile(world_x: int, world_y: int) -> int:
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _loaded.has(cx):
		return Tiles.AIR
	var lx: int = Chunk.local_x_of(world_x)
	return _loaded[cx].get_tile(lx, world_y)


# world 坐标 (x, y) → wall_id (背景墙). chunk 未 load → AIR
func get_wall(world_x: int, world_y: int) -> int:
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _loaded.has(cx):
		return Tiles.AIR
	var lx: int = Chunk.local_x_of(world_x)
	return _loaded[cx].get_wall(lx, world_y)


# 写 tile。同时记 delta 让卸载后再加载能恢复。
func set_tile(world_x: int, world_y: int, tid: int) -> void:
	var cx: int = Chunk.chunk_x_of(world_x)
	var lx: int = Chunk.local_x_of(world_x)
	if _loaded.has(cx):
		_loaded[cx].set_tile(lx, world_y, tid)
	if not _deltas.has(cx):
		_deltas[cx] = {}
	_deltas[cx][Vector2i(lx, world_y)] = tid


func is_chunk_loaded(cx: int) -> bool:
	return _loaded.has(cx)


func loaded_chunk_count() -> int:
	return _loaded.size()


func get_chunk(cx: int) -> Chunk:
	return _loaded.get(cx, null)
