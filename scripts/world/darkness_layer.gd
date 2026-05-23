# 平滑黑暗覆盖 (Terraria 风).
# 实现: 1 像素/tile 的 ImageTexture, Sprite2D 上以 LINEAR 滤镜放大 16x.
# 像素插值天然产生 sub-tile 平滑过渡, 不再有"阶梯感".
# 每 UPDATE_INTERVAL 秒 BFS 重算视野光值并写到纹理.
#
# 比 TileMapLayer 方案的关键升级: 子瓦片插值 (bilinear) → 平滑.
extends Sprite2D

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")

const TILE_SIZE := 16
const W := 80                 # 纹理宽度 (tiles) — 比可见区域大留 buffer
const H := 50                 # 纹理高度
const HALF_W := 40
const HALF_H := 25
const UPDATE_INTERVAL := 0.05  # 20 Hz, 让 BFS 跟上玩家移动

var _img: Image
var _last_update: float = 0.0


func _ready() -> void:
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 1))   # 初始全黑, 第一次 _process 后再写
	texture = ImageTexture.create_from_image(_img)
	# Sprite2D 设 centered=false (在 .tscn 里) → position = 左上角. 每像素放大 16x.
	scale = Vector2(TILE_SIZE, TILE_SIZE)
	z_index = 10
	add_to_group("darkness_layer")


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
	# 视野中心 = 玩家 tile
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	var x0: int = px - HALF_W
	var y0: int = py - HALF_H
	var torches: Array = _collect_torches()
	var grid: Dictionary = TileLightGrid.compute_region(cm, x0, y0, x0 + W, y0 + H,
			Vector2i(px, py), torches)
	# Sprite 位置 = 纹理左上角对应的世界坐标
	global_position = Vector2(x0 * TILE_SIZE, y0 * TILE_SIZE)
	# 写每像素的 alpha (黑色 RGB, alpha 反映"暗度")
	for x in range(W):
		for y in range(H):
			var tx: int = x0 + x
			var ty: int = y0 + y
			var light: int = int(grid.get(Vector2i(tx, ty), 0))
			var alpha: float = clamp(1.0 - float(light) / float(TileLightGrid.MAX_LIGHT), 0.0, 1.0)
			_img.set_pixel(x, y, Color(0, 0, 0, alpha))
	texture.update(_img)


# 收集 WorldLighting 管理的火把坐标
func _collect_torches() -> Array:
	var wl: Node = get_tree().get_first_node_in_group("world_lighting")
	if wl == null or not "_torches" in wl:
		return []
	return wl._torches.keys()


# 兼容 world.gd 的接口 stub (旧 TileMapLayer 时代). 现在 _process 视野更新接管,
# chunk 加载/卸载/tile 改变都不需要专门触发 — 下一帧 viewport 重算会涵盖.
func recompute_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func clear_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func recompute_around(_tile_x: int, _tile_y: int, _radius: int) -> void:
	pass
