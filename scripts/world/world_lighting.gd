# 火把光源生命周期管理。挂在 World 下，sibling 关系于 TorchLights 容器。
# - on_tile_placed(x, y, tile_id): 若 tile = TORCH, 在 ../TorchLights 下生成光源
# - on_tile_removed(x, y, old_tile_id): 若 old = TORCH, free 对应光源
# - on_chunk_loaded(chunk_x, chunk_width, tiles_2d): 扫描 chunk 内所有 TORCH 重建光
# - on_chunk_unloaded(chunk_x, chunk_width): 清掉该 chunk 范围内的火把光
#
# Phase F 把 _spawn_torch 换成 TorchFx 场景, 接口不变。
extends Node

const TILE_SIZE := 16
const TorchFxScene = preload("res://scenes/fx/torch_fx.tscn")

var _torches: Dictionary = {}  # Vector2i tile_coord → TorchFx Node2D


func _ready() -> void:
	add_to_group("world_lighting")


func on_tile_placed(x: int, y: int, tile_id: int) -> void:
	if tile_id != Tiles.TORCH:
		return
	_spawn_torch(x, y)


func on_tile_removed(x: int, y: int, old_tile_id: int) -> void:
	if old_tile_id != Tiles.TORCH:
		return
	_despawn_torch(x, y)


# 卸载 chunk 时清掉该 chunk 内所有火把光 (chunk_x = chunk index, chunk_width = 64)
func on_chunk_unloaded(chunk_x: int, chunk_width: int) -> void:
	var x0: int = chunk_x * chunk_width
	var x1: int = x0 + chunk_width
	var keys_to_remove: Array = []
	for k in _torches.keys():
		if k.x >= x0 and k.x < x1:
			keys_to_remove.append(k)
	for k in keys_to_remove:
		_despawn_torch(k.x, k.y)


# 加载 chunk 时扫描 tiles 数据, 在所有 TORCH 位置重建光
func on_chunk_loaded(chunk_x: int, chunk_width: int, tiles_2d: Array) -> void:
	var x0: int = chunk_x * chunk_width
	for lx in tiles_2d.size():
		var world_x: int = x0 + lx
		var col: Array = tiles_2d[lx]
		for y in col.size():
			if col[y] == Tiles.TORCH:
				_spawn_torch(world_x, y)


func _spawn_torch(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if _torches.has(key):
		return  # 幂等
	var fx = TorchFxScene.instantiate()
	fx.position = Vector2(x * TILE_SIZE + TILE_SIZE / 2.0, y * TILE_SIZE + TILE_SIZE / 2.0)
	var container: Node = get_node_or_null("../TorchLights")
	if container == null:
		push_warning("WorldLighting: ../TorchLights 节点不存在")
		return
	container.add_child(fx)
	_torches[key] = fx


func _despawn_torch(x: int, y: int) -> void:
	var key := Vector2i(x, y)
	if not _torches.has(key):
		return
	var n: Node = _torches[key]
	if is_instance_valid(n):
		n.queue_free()
	_torches.erase(key)
