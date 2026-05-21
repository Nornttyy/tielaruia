# 天光遮蔽: 查询某 tile 是否暴露在天空下 (无方块挡住).
# 列存改 Dictionary 懒填: 第一次查 column x 时算 _light_top[x], 之后缓存.
# 修改 tile 时由 World 调 invalidate_column(x) 清缓存.
extends Node

const ChunkConstants = preload("res://scripts/world/chunk_constants.gd")

var _light_top: Dictionary = {}  # int x → int top_solid_y (该列最顶的 solid tile 的 y; 找不到返回 WORLD_HEIGHT-1)


# 公开 API: 该 tile 是否在天空下
func is_sky_exposed(x: int, y: int) -> bool:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return false
	if not _light_top.has(x):
		_light_top[x] = _compute_light_top(x)
	return y <= _light_top[x]


# 公开 API: 该 (x, y) 离天光顶有多深 (单位: tile)
# 返回 0 = 自己在/上方就是天光顶 (该列地表层及以上)
# 返回 >0 = 地表下方 N 格
func depth_from_sky(x: int, y: int) -> int:
	if not _light_top.has(x):
		_light_top[x] = _compute_light_top(x)
	# _light_top 存的是"最后一个空气格" → 地表块在 _light_top + 1
	# 即: depth = y - (_light_top[x] + 1) = y - _light_top[x] - 1
	# y 在地表块以下时 depth 为正; y 在地表或以上时 depth <= 0
	return y - _light_top[x] - 1


# 由 World 在 set_tile 后调用
func invalidate_column(x: int, _tiles_unused: Variant = null) -> void:
	_light_top.erase(x)


# 兼容旧 API: 不再预算, 仅清缓存
func recompute_from(_tiles: Array) -> void:
	_light_top.clear()


# 从顶往下找第一个 solid tile, 返回它上方一格的 y. 找不到返回 WORLD_HEIGHT-1.
func _compute_light_top(x: int) -> int:
	var cm: Node = get_tree().get_first_node_in_group("chunk_manager")
	if cm == null:
		return ChunkConstants.WORLD_HEIGHT - 1
	for y in ChunkConstants.WORLD_HEIGHT:
		var tid: int = cm.get_tile(x, y)
		if tid != Tiles.AIR and Tiles.is_solid(tid):
			return y - 1
	return ChunkConstants.WORLD_HEIGHT - 1
