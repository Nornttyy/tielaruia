# 黑暗覆盖层。盖在 TerrainLayer 上面, 按 TileLightGrid 算的光值
# 给每个 tile 画 0..6 级别的黑色半透明瓦片 (level 7 = 满亮 = 不画)。
#
# 触发器:
#   - _process: 每 UPDATE_INTERVAL 秒重算玩家视野范围
#   - recompute_chunk(chunk_x, chunk_width): chunk 加载时一次性算整柱
#   - clear_chunk(chunk_x, chunk_width): chunk 卸载时清掉
#   - recompute_around(tile_x, tile_y, radius): tile 改 / 火把 改时局部重算
#
# 光值 0..7 → tile_id 0..6 (level 7 不画)。
extends TileMapLayer

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")
const DarknessArt = preload("res://scripts/art/darkness_art.gd")

const UPDATE_INTERVAL := 0.1   # 每 0.1s 刷一次玩家视野
const VIEW_HALF_W := 30        # ±30 tiles 半宽 (覆盖典型屏幕)
const VIEW_HALF_H := 18        # ±18 tiles 半高

var _last_update: float = 0.0
var _player_tile: Vector2i = Vector2i.ZERO


func _ready() -> void:
	tile_set = _build_tileset()
	add_to_group("darkness_layer")


func _build_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)
	# Level 0..6 各一个 source (level 7 = 满亮, 不需要瓦片)
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
	var px: int = int(floor(player.global_position.x / 16.0))
	var py: int = int(floor(player.global_position.y / 16.0))
	_player_tile = Vector2i(px, py)
	var torches: Array = _collect_torches()
	# 视野范围 ±VIEW
	for dx in range(-VIEW_HALF_W, VIEW_HALF_W + 1):
		for dy in range(-VIEW_HALF_H, VIEW_HALF_H + 1):
			var tx: int = px + dx
			var ty: int = py + dy
			_set_dark_cell(tx, ty, torches)


# 收集已放置的火把 tile 坐标 (走 WorldLighting._torches dict)
func _collect_torches() -> Array:
	var wl: Node = get_tree().get_first_node_in_group("world_lighting")
	if wl == null or not "_torches" in wl:
		return []
	return wl._torches.keys()


func _set_dark_cell(x: int, y: int, torches: Array) -> void:
	var light: int = TileLightGrid.compute_light(x, y, _player_tile, torches)
	if light >= TileLightGrid.MAX_LIGHT:
		set_cell(Vector2i(x, y), -1)
	else:
		set_cell(Vector2i(x, y), light, Vector2i.ZERO)


# 公共 API: chunk 加载时全列预算
func recompute_chunk(chunk_x: int, chunk_width: int, world_height: int) -> void:
	var torches: Array = _collect_torches()
	var x0: int = chunk_x * chunk_width
	for x in range(x0, x0 + chunk_width):
		for y in world_height:
			_set_dark_cell(x, y, torches)


# 公共 API: chunk 卸载时清掉
func clear_chunk(chunk_x: int, chunk_width: int, world_height: int) -> void:
	var x0: int = chunk_x * chunk_width
	for x in range(x0, x0 + chunk_width):
		for y in world_height:
			set_cell(Vector2i(x, y), -1)


# 公共 API: 局部重算 (tile 改 / 火把 改 时调)
func recompute_around(tile_x: int, tile_y: int, radius: int) -> void:
	var torches: Array = _collect_torches()
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			_set_dark_cell(tile_x + dx, tile_y + dy, torches)
