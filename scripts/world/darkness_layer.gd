# 平滑黑暗覆盖 (Terraria 风).
# 实现: 1 像素/tile 的 ImageTexture, Sprite2D 上以 LINEAR 滤镜放大 16x.
# 像素插值天然产生 sub-tile 平滑过渡, 不再有"阶梯感".
#
# 性能: 每 UPDATE_INTERVAL 秒 BFS 重算视野光值. 像素用 PackedByteArray 批写,
# 不用 set_pixel (GDScript 单像素写慢).
extends Sprite2D

const TileLightGrid = preload("res://scripts/world/tile_light_grid.gd")

const TILE_SIZE := ChunkConstants.TILE_SIZE
# 纹理大小动态算: viewport_size / (camera_zoom * TILE_SIZE) + buffer.
# 上限必须盖住"拉到最远"(camera_zoom 最小 0.5) 的整屏, 否则屏幕边缘那圈没黑暗层覆盖 =
# 中间有阴影、边上却太亮没阴影 (用户报). 注意 TILE_SIZE=12 不是 16:
#   宽: 1280/(0.5*12) = 214 tile, + BUFFER*2(16) = 230  → 取 240 留余量
#   高:  720/(0.5*12) = 120 tile, + BUFFER*2(16) = 136  → 取 144 留余量
# (旧值 180×116 是按 TILE=16 误算的, 比实际视野小 → 边缘漏盖.)
# 重算是 4Hz 节流 (UPDATE_INTERVAL), 且默认 zoom 0.8 只需 ~149×91 远小于上限,
# 故调大上限不影响正常游玩开销, 只在真拉到最远时才用满。
const MAX_W := 240
const MAX_H := 144
const BUFFER_TILES := 8
const UPDATE_INTERVAL := 0.25   # 原值 (用户要求调回 4Hz)

var _img: Image
var _last_update: float = 0.0
var _cur_w: int = MAX_W        # 当前实际用的纹理宽 (按 zoom 算)
var _cur_h: int = MAX_H
var _cached_player: Node2D = null   # 缓存 player ref, 避免每帧 get_tree() 查
var _cached_cm: Node = null         # 缓存 chunk_manager ref
# 预分配 bytes buffer + 全黑模板, 每帧 duplicate (C-level memcpy 比 21k GDScript loop 快)
var _bytes_buffer: PackedByteArray
var _full_dark_template: PackedByteArray


func _ready() -> void:
	# 用 MAX 大小创建一次, 后续按 zoom 算 _cur_w/_cur_h 只填那部分
	_img = Image.create(MAX_W, MAX_H, false, Image.FORMAT_RGBA8)
	_img.fill(Color(0, 0, 0, 1))
	texture = ImageTexture.create_from_image(_img)
	scale = Vector2(TILE_SIZE, TILE_SIZE)
	z_index = 10
	add_to_group("darkness_layer")
	# 模板: 全黑 alpha=255. 每帧 _update_viewport duplicate 它再覆盖 viewport.
	_full_dark_template = PackedByteArray()
	_full_dark_template.resize(MAX_W * MAX_H * 4)
	for k in range(MAX_W * MAX_H):
		_full_dark_template[k * 4 + 3] = 255


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
	# compute_region 返 PackedByteArray (索引 (y-y0)*_cur_w + (x-x0)), 不再是 Vector2i dict.
	var grid: PackedByteArray = TileLightGrid.compute_region(cm, x0, y0, x0 + _cur_w, y0 + _cur_h,
			Vector2i(px, py), torches)
	global_position = Vector2(x0 * TILE_SIZE, y0 * TILE_SIZE)
	# 批量构造像素字节 — 用 MAX_W × MAX_H buffer, 只填 _cur_w × _cur_h 区域.
	# 优化: 不再 GDScript 循环填 alpha=255 (21k iter), 直接 duplicate 预算好的模板 (C-level memcpy).
	var bytes: PackedByteArray = _full_dark_template.duplicate()
	var max_l: float = float(TileLightGrid.MAX_LIGHT)
	for y in range(_cur_h):
		var row_grid: int = y * _cur_w
		var row_bytes: int = y * MAX_W
		for x in range(_cur_w):
			var light: int = grid[row_grid + x]
			var a: int = clampi(int((1.0 - float(light) / max_l) * 255.0), 0, 255)
			var bi: int = (row_bytes + x) * 4
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
