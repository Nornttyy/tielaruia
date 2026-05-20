# 一柱地形数据。tiles[local_x][y] = tile_id。
class_name Chunk extends RefCounted

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

var chunk_x: int = 0
var tiles: Array = []   # tiles[local_x: 0..63][y: 0..255] = int


func _init(p_chunk_x: int = 0) -> void:
	chunk_x = p_chunk_x


func init_empty() -> void:
	tiles.resize(ChunkConstants.CHUNK_WIDTH)
	for lx in ChunkConstants.CHUNK_WIDTH:
		var col: Array = []
		col.resize(ChunkConstants.WORLD_HEIGHT)
		col.fill(Tiles.AIR)
		tiles[lx] = col


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


func apply_delta(delta: Dictionary) -> void:
	for k in delta:
		var v: Vector2i = k
		set_tile(v.x, v.y, delta[k])


static func chunk_x_of(world_x: int) -> int:
	return int(floor(float(world_x) / float(ChunkConstants.CHUNK_WIDTH)))


static func local_x_of(world_x: int) -> int:
	var cx: int = chunk_x_of(world_x)
	return world_x - cx * ChunkConstants.CHUNK_WIDTH
