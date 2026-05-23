# 黑暗覆盖层. 盖在 TerrainLayer 上面, 按 TileLightGrid (BFS 扩散) 计算每 tile 光值,
# 画对应等级的半透明黑瓦. 16 级过渡 (0=满黑, 15=透明).
#
# 每 UPDATE_INTERVAL 秒重算玩家视野范围. 触发 BFS 一次, 输出 dict, 按光值 set_cell.
# chunk_unloaded 时清掉该 chunk 的所有暗瓦 (防 stale).
extends TileMapLayer

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")
const DarknessArt = preload("res://scripts/art/darkness_art.gd")

const UPDATE_INTERVAL := 0.1   # 每 0.1s 刷一次 (10 Hz, 视觉够顺)
const VIEW_HALF_W := 30
const VIEW_HALF_H := 20

var _last_update: float = 0.0
var _player_tile: Vector2i = Vector2i.ZERO


func _ready() -> void:
	tile_set = _build_tileset()
	add_to_group("darkness_layer")


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# 0..14 = 暗瓦 (source_id = level). 15 = 满亮不画.
	for level in range(DarknessArt.LEVELS - 1):
		var src := TileSetAtlasSource.new()
		src.texture = DarknessArt.get_texture(level)
		src.texture_region_size = Vector2i(16, 16)
		ts.add_source(src, level)
		src.create_tile(Vector2i.ZERO)
	return ts


func _process(delta: float) -> void:
	_last_update += delta
	if _last_update < UPDATE_INTERVAL:
		return
	_last_update = 0.0
	_update_viewport()


func _update_viewport() -> void:
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var cm: Node = get_tree().get_first_node_in_group("chunk_manager")
	if cm == null:
		return
	var px: int = int(floor(player.global_position.x / 16.0))
	var py: int = int(floor(player.global_position.y / 16.0))
	_player_tile = Vector2i(px, py)
	var torches: Array = _collect_torches()
	var x0: int = px - VIEW_HALF_W
	var x1: int = px + VIEW_HALF_W + 1
	var y0: int = py - VIEW_HALF_H
	var y1: int = py + VIEW_HALF_H + 1
	var grid: Dictionary = TileLightGrid.compute_region(cm, x0, y0, x1, y1, _player_tile, torches)
	for x in range(x0, x1):
		for y in range(y0, y1):
			var light: int = int(grid.get(Vector2i(x, y), 0))
			if light >= TileLightGrid.MAX_LIGHT:
				set_cell(Vector2i(x, y), -1)
			else:
				set_cell(Vector2i(x, y), light, Vector2i.ZERO)


# 收集 WorldLighting 管理的火把坐标
func _collect_torches() -> Array:
	var wl: Node = get_tree().get_first_node_in_group("world_lighting")
	if wl == null or not "_torches" in wl:
		return []
	return wl._torches.keys()


# 公共 API: chunk 卸载时清掉一列 (防 stale 暗瓦留在屏幕上 / 后续 BFS 计算不到)
func clear_chunk(chunk_x: int, chunk_width: int, world_height: int) -> void:
	var x0: int = chunk_x * chunk_width
	for x in range(x0, x0 + chunk_width):
		for y in world_height:
			set_cell(Vector2i(x, y), -1)


# 兼容旧接口: 现在 BFS 接管, chunk_loaded 不需要预算, 但保留 stub 避免 world.gd 报错
func recompute_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


# 兼容旧接口: tile 改了由下次 _update_viewport 涵盖, 不需要立刻局部重算
func recompute_around(_tile_x: int, _tile_y: int, _radius: int) -> void:
	pass
