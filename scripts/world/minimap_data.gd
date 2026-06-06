# 小地图探索记录: 玩家走过的 tile 缓存其 tile_id, minimap 即使 chunk 已卸载也能正确显示.
# 按 chunk 存 PackedByteArray (每 tile 1 byte, 共 CHUNK_WIDTH*WORLD_HEIGHT byte).
# 0xff = 未探索 (sentinel); 其他值 = 已见的 tile_id (Tiles 常量, 都 < 255).
# 全局通过 group "minimap_data" 查找 (同 chunk_manager 模式).
class_name MinimapData extends Node

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")
const Chunk = preload("res://scripts/world/chunk.gd")

const BYTES_PER_CHUNK := ChunkConstants.CHUNK_WIDTH * ChunkConstants.WORLD_HEIGHT
const UNEXPLORED := 0xff

# chunk_x: int → PackedByteArray (idx = local_x * WORLD_HEIGHT + world_y)
var _tiles: Dictionary = {}


func _ready() -> void:
	add_to_group("minimap_data")


# 标记单个 tile 为已探索 + 缓存 tile_id
func mark(world_x: int, world_y: int, tile_id: int) -> void:
	if world_y < 0 or world_y >= ChunkConstants.WORLD_HEIGHT:
		return
	if tile_id < 0 or tile_id >= UNEXPLORED:
		return
	var cx: int = Chunk.chunk_x_of(world_x)
	var lx: int = Chunk.local_x_of(world_x)
	var bm: PackedByteArray = _ensure_buffer(cx)
	bm[lx * ChunkConstants.WORLD_HEIGHT + world_y] = tile_id
	_tiles[cx] = bm


# 单格揭图 (按光照/玩家旁边逐格揭用). 含 chunk未载跳过 / 已探索跳过 / 联机别人水晶藏 (跟 mark_rect 一致).
func mark_one(chunk_mgr: Node, world_x: int, world_y: int) -> void:
	if world_y < 0 or world_y >= ChunkConstants.WORLD_HEIGHT:
		return
	var cx: int = Chunk.chunk_x_of(world_x)
	if chunk_mgr.has_method("is_chunk_loaded") and not chunk_mgr.is_chunk_loaded(cx):
		return   # chunk 没载, 别拿 AIR 误标成洞穴
	if is_explored(world_x, world_y):
		return   # 已探索, 省一次 get_tile
	var tid: int = chunk_mgr.get_tile(world_x, world_y)
	if (tid == Tiles.LIFE_CRYSTAL or tid == Tiles.MANA_CRYSTAL) \
			and chunk_mgr.has_method("is_my_crystal") and not chunk_mgr.is_my_crystal(Vector2i(world_x, world_y)):
		tid = Tiles.AIR
	mark(world_x, world_y, tid)


# 标记矩形范围 (玩家移动时一次刷一片). 用 chunk_mgr 查每格 tile_id 写入缓存.
# 联机: 别人家的水晶在小地图也别露馅, 替换成 AIR.
# perf:
# 1) has_method 检查提到循环外 (chunk_mgr 不变)
# 2) 已探索 tile 跳过 chunk_mgr.get_tile() — 老逻辑每次都查, 60×40 = 2400 tile × 4Hz
#    = 9600/s 严重卡顿. 内联 is_explored 直接走 _tiles dict, 避免函数调.
func mark_rect(chunk_mgr: Node, world_x0: int, world_y0: int, world_x1: int, world_y1: int) -> void:
	var has_crystal_check: bool = chunk_mgr.has_method("is_my_crystal")
	# 缓存 chunk 范围: 一个 chunk 内的 tile 共用同一 _tiles[cx] buffer, 不必每 tile 重查 dict
	var prev_cx: int = -999999
	var prev_bm: PackedByteArray
	var prev_loaded: bool = false
	var has_loaded_check: bool = chunk_mgr.has_method("is_chunk_loaded")
	for wx in range(world_x0, world_x1 + 1):
		var cx: int = Chunk.chunk_x_of(wx)
		var lx: int = Chunk.local_x_of(wx)
		if cx != prev_cx:
			prev_cx = cx
			prev_bm = _tiles.get(cx, PackedByteArray())
			# chunk 没加载时 get_tile 对它一律返 AIR → 把实心地面误存成洞穴色, 且"已探索就跳过"
			# 会让这个错误永久粘住. 整列跳过 (保持未探索), 等 chunk 真加载了再标. 修"小地图显示地底".
			prev_loaded = (not has_loaded_check) or chunk_mgr.is_chunk_loaded(cx)
		if not prev_loaded:
			continue
		var lx_offset: int = lx * ChunkConstants.WORLD_HEIGHT
		for wy in range(world_y0, world_y1 + 1):
			if wy < 0 or wy >= ChunkConstants.WORLD_HEIGHT:
				continue
			# 已探索 → 跳过 (省 chunk_mgr.get_tile call). bm 空 = chunk 没缓存过, 当未探索.
			if prev_bm.size() > 0 and prev_bm[lx_offset + wy] != UNEXPLORED:
				continue
			var tid: int = chunk_mgr.get_tile(wx, wy)
			if has_crystal_check and (tid == Tiles.LIFE_CRYSTAL or tid == Tiles.MANA_CRYSTAL):
				if not chunk_mgr.is_my_crystal(Vector2i(wx, wy)):
					tid = Tiles.AIR
			mark(wx, wy, tid)


# tile 变了 (挖/放/水流): 若该格已探索, 立即刷新缓存色 → 小地图实时更新.
# 未探索的不揭开 (保持迷雾, 水流到没去过的地方不会偷偷暴露地形).
func update_if_explored(world_x: int, world_y: int, tile_id: int) -> void:
	if is_explored(world_x, world_y):
		mark(world_x, world_y, tile_id)


# 查询: 此 tile 是否已探索 (不管当前 chunk 是否 loaded)
func is_explored(world_x: int, world_y: int) -> bool:
	if world_y < 0 or world_y >= ChunkConstants.WORLD_HEIGHT:
		return false
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _tiles.has(cx):
		return false
	var lx: int = Chunk.local_x_of(world_x)
	var bm: PackedByteArray = _tiles[cx]
	return bm[lx * ChunkConstants.WORLD_HEIGHT + world_y] != UNEXPLORED


# 查询: 此 tile 最后一次被看见时的 tile_id. 未探索 → Tiles.AIR (fallback).
func get_tile_at(world_x: int, world_y: int) -> int:
	if world_y < 0 or world_y >= ChunkConstants.WORLD_HEIGHT:
		return Tiles.AIR
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _tiles.has(cx):
		return Tiles.AIR
	var lx: int = Chunk.local_x_of(world_x)
	var bm: PackedByteArray = _tiles[cx]
	var v: int = bm[lx * ChunkConstants.WORLD_HEIGHT + world_y]
	return Tiles.AIR if v == UNEXPLORED else v


func _ensure_buffer(cx: int) -> PackedByteArray:
	if _tiles.has(cx):
		return _tiles[cx]
	var bm := PackedByteArray()
	bm.resize(BYTES_PER_CHUNK)
	bm.fill(UNEXPLORED)
	_tiles[cx] = bm
	return bm


# 给 SaveData 序列化用: {chunk_x: int → PackedByteArray}
func to_save_dict() -> Dictionary:
	return _tiles.duplicate()


# 从 SaveData 反序列化
func from_save_dict(d: Dictionary) -> void:
	_tiles.clear()
	for cx in d:
		_tiles[cx] = d[cx]
