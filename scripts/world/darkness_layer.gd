# 平滑彩色光照覆盖：乘色保留火把、月光与水下的颜色。
# 实现: 1 像素/tile 的 ImageTexture, Sprite2D 上以 LINEAR 滤镜放大 16x.
# 像素插值天然产生 sub-tile 平滑过渡, 不再有"阶梯感".
#
# 性能: 每 UPDATE_INTERVAL 秒 BFS 重算视野光值. 像素用 PackedByteArray 批写,
# 不用 set_pixel (GDScript 单像素写慢).
extends Sprite2D

const ColorLightGrid = preload("res://scripts/world/color_light_grid.gd")

const TILE_SIZE := 12
# 纹理大小动态算: viewport_size / (camera_zoom * TILE_SIZE) + buffer.
# 上限必须盖住"拉到最远"(camera_zoom 最小 0.5) 的整屏, 否则屏幕边缘那圈没黑暗层覆盖 =
# 中间有阴影、边上却太亮没阴影 (用户报). 注意 TILE_SIZE=12 不是 16:
#   宽: 1280/(0.5*12) = 214 tile, + BUFFER*2(16) = 230  → 取 240 留余量
#   高:  720/(0.5*12) = 120 tile, + BUFFER*2(16) = 136  → 取 144 留余量
# (旧值 180×116 是按 TILE=16 误算的, 比实际视野小 → 边缘漏盖.)
# 重算是 4Hz 节流 (UPDATE_INTERVAL), 且默认 zoom 0.8 只需 ~149×91 远小于上限,
# 故调大上限不影响正常游玩开销, 只在真拉到最远时才用满。
const MAX_W := 304
const MAX_H := 208
const BUFFER_TILES := 32
const UPDATE_INTERVAL := 0.25   # 原值 (用户要求调回 4Hz)

var _dirty := true
var _lit_rect := Rect2()
var _last_sky := Vector3(-1, -1, -1)
var _last_sources: Array = []
var update_count := 0
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
	var multiply := CanvasItemMaterial.new()
	multiply.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	multiply.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = multiply
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
	# 修改方块/液体会显式标脏；静止画面复用含缓冲区的光场。
	# 按当前 viewport_size + camera_zoom 算需要多少 tile 才能盖满屏
	var vp_size: Vector2 = get_viewport_rect().size
	var active_camera := get_viewport().get_camera_2d()
	var zoom: float = maxf(0.1, active_camera.zoom.x if active_camera != null else GameSettings.camera_zoom)
	var view_center := active_camera.get_screen_center_position() if active_camera != null else player.global_position
	var need_w: int = int(ceil(vp_size.x / (zoom * float(TILE_SIZE)))) + BUFFER_TILES * 2
	var need_h: int = int(ceil(vp_size.y / (zoom * float(TILE_SIZE)))) + BUFFER_TILES * 2
	_cur_w = clampi(need_w, 32, MAX_W)
	_cur_h = clampi(need_h, 32, MAX_H)
	var half_w: int = _cur_w / 2
	var half_h: int = _cur_h / 2
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	var x0: int = floori(view_center.x / TILE_SIZE) - half_w
	var y0: int = floori(view_center.y / TILE_SIZE) - half_h
	var sources: Array = []
	# 玩家本身不发光；实际拿着火把时才添加跟随手部的暖色光。
	var inventory := player.get_node_or_null("PlayerInventory")
	if inventory != null and inventory.has_method("current_hotbar_slot"):
		var slot: Variant = inventory.current_hotbar_slot()
		if slot != null and String(slot.item_id) in ["torch", "slime_torch"]:
			var head := Vector2i(px, py - 2)
			if not Tiles.is_water(cm.get_tile(head.x, head.y)):
				sources.append({"position": head, "color": ColorLightGrid.TORCH_COLOR})
	var view_rect := Rect2(view_center - vp_size / zoom / 2.0, vp_size / zoom)
	var current_sky := ColorLightGrid.sky_color()
	if not _dirty and _lit_rect.grow(-8 * TILE_SIZE).encloses(view_rect) and current_sky.distance_to(_last_sky) < 0.015 and sources == _last_sources:
		return
	_dirty = false
	_last_sky = current_sky
	_last_sources = sources.duplicate(true)
	_lit_rect = Rect2(Vector2(x0, y0) * TILE_SIZE, Vector2(_cur_w, _cur_h) * TILE_SIZE)
	update_count += 1
	var grid := ColorLightGrid.compute_region(cm, x0, y0, x0 + _cur_w, y0 + _cur_h, sources)
	global_position = Vector2(x0 * TILE_SIZE, y0 * TILE_SIZE)
	var bytes: PackedByteArray = _full_dark_template.duplicate()
	for y in _cur_h:
		for x in _cur_w:
			var source := (y * _cur_w + x) * 4
			var target := (y * MAX_W + x) * 4
			bytes[target] = grid[source]
			bytes[target + 1] = grid[source + 1]
			bytes[target + 2] = grid[source + 2]
	_img.set_data(MAX_W, MAX_H, false, Image.FORMAT_RGBA8, bytes)
	texture.update(_img)


# 地形变化和流动水显式失效；日夜和镜头移动由上面的条件检查。
func recompute_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	_dirty = true

func clear_chunk(_chunk_x: int, _chunk_width: int, _world_height: int) -> void:
	_dirty = true

func recompute_around(tile_x: int, tile_y: int, radius: int) -> void:
	if _lit_rect.has_point(Vector2(tile_x, tile_y) * TILE_SIZE) or _lit_rect.size == Vector2.ZERO:
		_dirty = true
