# 持有所有 loaded chunks + 玩家修改 delta。
# 调度 load/unload 由 World._physics_process 触发 (调 ensure_loaded / unload_far_from)。
class_name ChunkManager extends Node

const Chunk = preload("res://scripts/world/chunk.gd")
const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const WorldGenerator = preload("res://scripts/world/world_generator.gd")

signal chunk_loaded(chunk: Chunk)
signal chunk_unloaded(chunk_x: int)

var world_seed: int = 0
var _loaded: Dictionary = {}    # chunk_x: int → Chunk
var _deltas: Dictionary = {}    # chunk_x: int → Dict[Vector2i → tid]


func setup(p_seed: int) -> void:
	world_seed = p_seed
	add_to_group("chunk_manager")


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
	# 矿洞宝箱: 给 chunk 里每个新生成的 chest 位置填一次战利品 (idempotent, 重载不会再填)
	for spot in c.treasure_spots:
		# 如果 delta 已经把 chest 砸了 (变 AIR), 不填.
		var lx: int = spot.x - cx * ChunkConstants.CHUNK_WIDTH
		if lx >= 0 and lx < ChunkConstants.CHUNK_WIDTH:
			var ct: int = c.tiles[lx][spot.y]
			if ct == Tiles.CHEST or ct == Tiles.GOLD_CHEST or ct == Tiles.DIAMOND_CHEST or ct == Tiles.SHADOW_CHEST:
				ChestStorage.try_populate_treasure(spot, world_seed, ct)
	_loaded[cx] = c
	chunk_loaded.emit(c)


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
