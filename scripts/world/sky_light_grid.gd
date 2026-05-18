# 天光暗格：每列从上往下扫描，遇到首个实心 tile 之后下方均标记为"无天光"。
# 用于 P4 史莱姆刷新条件查询。本类不渲染、不影响视觉。
extends Node

var _width: int = 0
var _height: int = 0
# _exposed[x][y] = true 表示 (x,y) 可被天光直射 (本格不实心 + 上方无实心遮挡)
var _exposed: Array = []
var _tiles_ref: Array = []


func recompute_from(tiles: Array) -> void:
	_tiles_ref = tiles
	_width = tiles.size()
	if _width == 0:
		_height = 0
		_exposed = []
		return
	_height = (tiles[0] as Array).size()
	_exposed.resize(_width)
	for x in _width:
		_exposed[x] = _compute_column(tiles[x])


func invalidate_column(x: int, tiles: Variant = null) -> void:
	if x < 0 or x >= _width:
		return
	var col: Array = (tiles[x] if tiles != null else _tiles_ref[x])
	_exposed[x] = _compute_column(col)


func is_sky_exposed(x: int, y: int) -> bool:
	if x < 0 or x >= _width or y < 0 or y >= _height:
		return false
	return _exposed[x][y]


func _compute_column(col: Array) -> Array:
	var result := []
	result.resize(_height)
	var blocked := false
	for y in _height:
		var tile_id: int = col[y]
		if blocked:
			result[y] = false
			continue
		if Tiles.is_solid(tile_id):
			result[y] = false  # 实心本身不算"被天光照"
			blocked = true
		else:
			result[y] = true
	return result
