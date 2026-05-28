# 一柱地形数据。
# tiles[local_x][y] = 前景方块 (玩家可破坏/放置)
# walls[local_x][y] = 背景墙 (装饰, 不可破坏, 显示在前景方块后面)
class_name Chunk extends RefCounted

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

var chunk_x: int = 0
var tiles: Array = []
var walls: Array = []
var surfaces: Array = []   # 每列原始地表 y_tile (生成时定, 不被玩家挖动)
# 矿洞宝箱位置 (世界坐标 Vector2i), 给 ChestStorage 首次填战利品用. 不存档 (chunk 一致性生成保证).
var treasure_spots: Array = []


func _init(p_chunk_x: int = 0) -> void:
	chunk_x = p_chunk_x


func init_empty(height: int = ChunkConstants.WORLD_HEIGHT) -> void:
	tiles.resize(ChunkConstants.CHUNK_WIDTH)
	walls.resize(ChunkConstants.CHUNK_WIDTH)
	surfaces.resize(ChunkConstants.CHUNK_WIDTH)
	surfaces.fill(0)
	for lx in ChunkConstants.CHUNK_WIDTH:
		var col: Array = []
		col.resize(height)
		col.fill(Tiles.AIR)
		tiles[lx] = col
		var wall_col: Array = []
		wall_col.resize(height)
		wall_col.fill(Tiles.AIR)
		walls[lx] = wall_col


func get_tile(local_x: int, y: int) -> int:
	if local_x < 0 or local_x >= ChunkConstants.CHUNK_WIDTH \
			or y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return Tiles.AIR
	return tiles[local_x][y]


func set_tile(local_x: int, y: int, tid: int) -> void:
	if local_x < 0 or local_x >= ChunkConstants.CHUNK_WIDTH \
			or y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	tiles[local_x][y] = tid


func get_wall(local_x: int, y: int) -> int:
	if local_x < 0 or local_x >= ChunkConstants.CHUNK_WIDTH \
			or y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return Tiles.AIR
	return walls[local_x][y]


func set_wall(local_x: int, y: int, wid: int) -> void:
	if local_x < 0 or local_x >= ChunkConstants.CHUNK_WIDTH \
			or y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	walls[local_x][y] = wid


func apply_delta(delta: Dictionary) -> void:
	for k in delta:
		var v: Vector2i = k
		set_tile(v.x, v.y, delta[k])


static func chunk_x_of(world_x: int) -> int:
	return int(floor(float(world_x) / float(ChunkConstants.CHUNK_WIDTH)))


static func local_x_of(world_x: int) -> int:
	var cx: int = chunk_x_of(world_x)
	return world_x - cx * ChunkConstants.CHUNK_WIDTH
