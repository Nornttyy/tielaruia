# 原始地下背景：按深度分带平铺，边界跟随世界，纹理保留视差。
# 不拉伸成整屏，也不再叠加程序绘制的蘑菇、水晶和钟乳石。
extends CanvasLayer
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Generator = preload("res://scripts/world/world_generator.gd")
const PIXEL_SCALE := 0.75
const PARALLAX := 0.5
const CROSSFADE := 0.65
# 依次为地表边、泥土层、岩层边、洞穴层。160 宽原图最右 32px 为重复区。
const STYLES := {
	0: [1, 2, 4, 3], 1: [66, 67, 68, 69],
	2: [40, 33, 34, 32], 3: [146, 147, 148, 149],
	4: [146, 147, 148, 149], 5: [1, 193, 4, 194],
	6: [1, 188, 4, 191], 7: [62, 63, 64, 65], 8: [1, 2, 4, 3],
}
var _shallow_alpha := 0.0
var _deep_alpha := 0.0
var _weights: Dictionary = {0: 1.0}
var _biome := 0
var _textures: Dictionary = {}
var _canvas: Node2D
var _camera_center := Vector2.ZERO
var _zoom := Vector2.ONE
var _view := Vector2(1280, 720)

func _ready() -> void:
	layer = -8 # 天空/地表远景之上，墙和前景/光照之下。
	_canvas = Node2D.new()
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_canvas)
	_canvas.draw.connect(_draw_background)

func set_biome(id: int) -> void:
	_biome = id if STYLES.has(id) else 0
	if not _weights.has(_biome): _weights[_biome] = 0.0

func _process(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		_camera_center = camera.get_screen_center_position()
		_zoom = camera.zoom
	_view = get_viewport().get_visible_rect().size
	for id in _weights.keys():
		_weights[id] = move_toward(float(_weights[id]), 1.0 if id == _biome else 0.0, delta / CROSSFADE)
		if id != _biome and _weights[id] <= 0.0: _weights.erase(id)
	if _canvas != null: _canvas.queue_redraw()

func _texture(id: int) -> Texture2D:
	if not _textures.has(id):
		var original := Pack.source_image("Background_%d.png" % id)
		if original == null: return null
		var img := original.get_region(Rect2i(0, 0, 128, original.get_height()))
		_textures[id] = ImageTexture.create_from_image(img)
	return _textures[id]

func _screen_y(world_y: float) -> float:
	return (world_y - _camera_center.y) * _zoom.y + _view.y * 0.5

func _draw_background() -> void:
	if _shallow_alpha <= 0.001: return
	# 当前地图只有 256 格高，层界适配现有深度，不能照搬大世界的绝对格数。
	var dirt_y := (Generator.SURFACE_BASE * 256.0 + 10.0) * 12.0
	var rock_y := (Generator.SURFACE_BASE * 256.0 + 36.0) * 12.0
	var lava_y := 220.0 * 12.0
	var edge_h := 16.0 * PIXEL_SCALE * _zoom.y
	var a := _screen_y(dirt_y)
	var b := _screen_y(rock_y)
	var c := _screen_y(lava_y)
	# 每层完全覆盖自己的区间。交叉淡入前先铺旧群系，避免混合中透出天空。
	var first := true
	for id in _weights:
		var alpha := _shallow_alpha if first else _shallow_alpha * float(_weights[id])
		first = false
		var ids: Array = STYLES[id]
		_band(ids[0], a, a + edge_h, alpha, false)
		_band(ids[1], a + edge_h, b, alpha)
		_band(ids[2], b, b + edge_h, alpha, false)
		_band(ids[3], b + edge_h, c, alpha)
		_band(6, c, c + 48.0 * PIXEL_SCALE * _zoom.y, alpha, false)
		_band(5, c + 48.0 * PIXEL_SCALE * _zoom.y, _view.y, alpha)

# 裁每个贴图格，边缘用同一坐标舍入，消除缩放时的细缝。
func _band(id: int, top: float, bottom: float, alpha: float, repeat_y := true) -> void:
	if bottom <= 0.0 or top >= _view.y or bottom <= top: return
	var tex := _texture(id)
	if tex == null: return
	var scale_px := Vector2.ONE * PIXEL_SCALE * _zoom
	var size_px := tex.get_size() * scale_px
	var left := -fposmod(_camera_center.x * PARALLAX * _zoom.x - _view.x * 0.5, size_px.x)
	var y := top
	if repeat_y:
		# 锚在世界深度；上下行走时图案不会每过一格重新排布。
		y -= fposmod(_camera_center.y * (PARALLAX - 1.0) * _zoom.y, size_px.y)
		y += floor((maxf(0.0, top) - y) / size_px.y) * size_px.y
	while y < minf(_view.y, bottom):
		var y0 := maxf(maxf(y, top), 0.0)
		var y1 := minf(minf(y + size_px.y, bottom), _view.y)
		var x := left
		while x < _view.x and y1 > y0:
			var x0 := maxf(x, 0.0)
			var x1 := minf(x + size_px.x, _view.x)
			var dest := Rect2(Vector2(roundf(x0), roundf(y0)), Vector2(roundf(x1) - roundf(x0), roundf(y1) - roundf(y0)))
			var src := Rect2(Vector2(x0 - x, y0 - y) / scale_px, Vector2(x1 - x0, y1 - y0) / scale_px)
			_canvas.draw_texture_rect_region(tex, dest, src, Color(1, 1, 1, alpha))
			x += size_px.x
		if not repeat_y: break
		y += size_px.y

func set_layer_alpha(a: float) -> void:
	set_depth_alphas(a, a)
func set_depth_alphas(shallow: float, deep: float) -> void:
	_shallow_alpha = clampf(shallow, 0.0, 1.0)
	_deep_alpha = clampf(deep, 0.0, 1.0)
func current_alpha() -> float: return _shallow_alpha
func shallow_alpha() -> float: return _shallow_alpha
func deep_alpha() -> float: return _deep_alpha
