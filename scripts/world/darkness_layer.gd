# 平滑黑暗覆盖 (Terraria 风).
# 实现: 1 像素/tile 的 ImageTexture, Sprite2D 上以 LINEAR 滤镜放大 16x.
# 像素插值天然产生 sub-tile 平滑过渡, 不再有"阶梯感".
#
# 性能: 每 UPDATE_INTERVAL 秒 BFS 重算视野光值. 像素用 PackedByteArray 批写,
# 不用 set_pixel (GDScript 单像素写慢).
extends Sprite2D

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")

const TILE_SIZE := 16
# 纹理覆盖区域要够大: 1280×720 viewport @ zoom=1.0 = 80×45 tile 可见.
# 留 buffer 防边缘闪烁 → 96×60. 玩家中心 ±48 ×30 tile.
# 计算开销 O(W×H) = 5760 像素/更新, 10 Hz = 57600/s, 可接受.
const W := 96                  # 纹理宽度 (tiles)
const H := 60                  # 纹理高度
const HALF_W := 48
const HALF_H := 30
const UPDATE_INTERVAL := 0.1   # 10 Hz, 玩家走 0.9 tile/帧, 够顺

var _img: Image
var _last_update: float = 0.0


func _ready() -> void:
	# 用 LA8 (luminance + alpha) 反而麻烦, 直接用 RGBA8 但 RGB 始终 0, 只填 alpha
	_img = Image.create(W, H, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(_img)
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
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	var x0: int = px - HALF_W
	var y0: int = py - HALF_H
	var torches: Array = _collect_torches()
	var grid: Dictionary = TileLightGrid.compute_region(cm, x0, y0, x0 + W, y0 + H,
			Vector2i(px, py), torches)
	global_position = Vector2(x0 * TILE_SIZE, y0 * TILE_SIZE)
	# 批量构造像素字节 (RGBA): R=G=B=0, alpha 反映暗度
	var bytes := PackedByteArray()
	bytes.resize(W * H * 4)
	var max_l: float = float(TileLightGrid.MAX_LIGHT)
	var i: int = 0
	for y in range(H):
		for x in range(W):
			var light: int = int(grid.get(Vector2i(x0 + x, y0 + y), 0))
			# alpha 0..255: 暗 = 1.0, 全亮 = 0.0
			var a: int = clampi(int((1.0 - float(light) / max_l) * 255.0), 0, 255)
			bytes[i] = 0       # R
			bytes[i + 1] = 0   # G
			bytes[i + 2] = 0   # B
			bytes[i + 3] = a   # A
			i += 4
	# 一次性上传整个图像 (比 set_pixel 循环快 1-2 个数量级)
	_img.set_data(W, H, false, Image.FORMAT_RGBA8, bytes)
	texture.update(_img)


# 收集 WorldLighting 管理的火把坐标
func _collect_torches() -> Array:
	var wl: Node = get_tree().get_first_node_in_group("world_lighting")
	if wl == null or not "_torches" in wl:
		return []
	return wl._torches.keys()


# 兼容 stub: 现在 _process 视野更新接管, 不需要专门触发
func recompute_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func clear_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func recompute_around(_tile_x: int, _tile_y: int, _radius: int) -> void:
	pass
