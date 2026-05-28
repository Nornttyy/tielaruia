# 平滑黑暗覆盖 (Terraria 风).
# 实现: 1 像素/tile 的 ImageTexture, Sprite2D 上以 LINEAR 滤镜放大 16x.
# 像素插值天然产生 sub-tile 平滑过渡, 不再有"阶梯感".
#
# 性能: 每 UPDATE_INTERVAL 秒 BFS 重算视野光值. 像素用 PackedByteArray 批写,
# 不用 set_pixel (GDScript 单像素写慢).
extends Sprite2D

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")

const TILE_SIZE := 12
# 纹理大小动态算: viewport_size / (camera_zoom * TILE_SIZE) + buffer.
# 最小 zoom 0.5 (摄像机调小看更远) → 视野 ~160×90 tiles, 我们准备 200×120 上限.
const MAX_W := 180             # zoom 0.5 视野 160 tile + buffer
const MAX_H := 116              # 720/(0.5*16) = 90 + buffer
const BUFFER_TILES := 8
const UPDATE_INTERVAL := 0.25   # 原值 (用户要求调回 4Hz)

var _img: Image
var _last_update: float = 0.0
var _cur_w: int = MAX_W        # 当前实际用的纹理宽 (按 zoom 算)
var _cur_h: int = MAX_H
var _cached_player: Node2D = null   # 缓存 player ref, 避免每帧 get_tree() 查
var _cached_cm: Node = null         # 缓存 chunk_manager ref


func _ready() -> void:
	# 用 MAX 大小创建一次, 后续按 zoom 算 _cur_w/_cur_h 只填那部分
	_img = Image.create(MAX_W, MAX_H, false, Image.FORMAT_RGBA8)
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
	# 缓存 player + chunk_manager 引用 (web 端 get_tree 查询很慢)
	if _cached_player == null or not is_instance_valid(_cached_player):
		_cached_player = get_tree().get_first_node_in_group("player")
		if _cached_player == null:
			return
	if _cached_cm == null or not is_instance_valid(_cached_cm):
		_cached_cm = get_tree().get_first_node_in_group("chunk_manager")
		if _cached_cm == null:
			return
	var player: Node2D = _cached_player
	var cm: Node = _cached_cm
	# 注: 不加"玩家没动就跳过", 否则挖墙看不到光变化
	# 按当前 viewport_size + camera_zoom 算需要多少 tile 才能盖满屏
	var vp_size: Vector2 = get_viewport_rect().size
	var zoom: float = max(0.1, GameSettings.camera_zoom)
	var need_w: int = int(ceil(vp_size.x / (zoom * float(TILE_SIZE)))) + BUFFER_TILES * 2
	var need_h: int = int(ceil(vp_size.y / (zoom * float(TILE_SIZE)))) + BUFFER_TILES * 2
	_cur_w = clampi(need_w, 32, MAX_W)
	_cur_h = clampi(need_h, 32, MAX_H)
	var half_w: int = _cur_w / 2
	var half_h: int = _cur_h / 2
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	var x0: int = px - half_w
	var y0: int = py - half_h
	var torches: Array = _collect_torches()
	var grid: Dictionary = TileLightGrid.compute_region(cm, x0, y0, x0 + _cur_w, y0 + _cur_h,
			Vector2i(px, py), torches)
	global_position = Vector2(x0 * TILE_SIZE, y0 * TILE_SIZE)
	# 批量构造像素字节 — 用 MAX_W × MAX_H buffer, 但只填 _cur_w × _cur_h 区域
	# (没填的边缘像素仍是 alpha=255 即全黑, 没关系因为 sprite 不会渲染超出 _cur_*)
	var bytes := PackedByteArray()
	bytes.resize(MAX_W * MAX_H * 4)
	# 先全 alpha=255 (黑) 再覆盖
	for k in range(MAX_W * MAX_H):
		bytes[k * 4 + 3] = 255
	var max_l: float = float(TileLightGrid.MAX_LIGHT)
	for y in range(_cur_h):
		for x in range(_cur_w):
			var light: int = int(grid.get(Vector2i(x0 + x, y0 + y), 0))
			var a: int = clampi(int((1.0 - float(light) / max_l) * 255.0), 0, 255)
			var bi: int = (y * MAX_W + x) * 4
			bytes[bi] = 0
			bytes[bi + 1] = 0
			bytes[bi + 2] = 0
			bytes[bi + 3] = a
	_img.set_data(MAX_W, MAX_H, false, Image.FORMAT_RGBA8, bytes)
	texture.update(_img)


# 收集 WorldLighting 管理的发光 tile 坐标 (TORCH + SLIME_TORCH)
func _collect_torches() -> Array:
	var wl: Node = get_tree().get_first_node_in_group("world_lighting")
	if wl == null:
		return []
	if wl.has_method("get_light_tiles"):
		return wl.get_light_tiles()
	# 兼容旧接口
	if "_torches" in wl:
		return wl._torches.keys()
	return []


# 兼容 stub: 现在 _process 视野更新接管, 不需要专门触发
func recompute_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func clear_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	pass


func recompute_around(_tile_x: int, _tile_y: int, _radius: int) -> void:
	pass
