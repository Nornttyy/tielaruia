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
var _surface_clips: Array[Vector3] = [] # 屏幕横段 [left, right, 地表以下的起始 y]

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
	_update_surface_clips()
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

func _update_surface_clips() -> void:
	_surface_clips.clear()
	var world := get_parent()
	var cm = world.get("chunk_manager") if world != null and "chunk_manager" in world else null
	var left_world := _camera_center.x - _view.x * 0.5 / _zoom.x
	var first := floori(left_world / 12.0)
	var count := ceili(_view.x / (_zoom.x * 12.0)) + 1
	for x in range(first, first + count):
		var surface := Generator.SURFACE_BASE * 256.0 + 10.0
		if cm != null:
			var chunk = cm.get_chunk(Chunk.chunk_x_of(x))
			if chunk != null: surface = float(chunk.surfaces[Chunk.local_x_of(x)]) + 1.0
		var x0 := (x * 12.0 - left_world) * _zoom.x
		_surface_clips.append(Vector3(maxf(0.0,x0), minf(_view.x,x0+12.0*_zoom.x), _screen_y(surface*12.0)))

func _bands_for(biome: int) -> Array:
	# 山坡里的洞穴可能高于全世界平均地表。当地下远景淡入时，泥土带必须
	# 覆盖视口上缘，不能在洞顶留出天空；岩层和地狱边界仍固定在世界深度。
	var ids: Array = STYLES[biome]
	var rock := _screen_y((Generator.SURFACE_BASE * 256.0 + 36.0) * 12.0)
	var lava := _screen_y(220.0 * 12.0)
	var edge := 16.0 * PIXEL_SCALE * _zoom.y
	var hell_edge := 48.0 * PIXEL_SCALE * _zoom.y
	return [[ids[1], 0.0, rock, true], [ids[2], rock, rock + edge, false],
		[ids[3], rock + edge, lava, true], [6, lava, lava + hell_edge, false],
		[5, lava + hell_edge, _view.y, true]]

func _draw_background() -> void:
	if _shallow_alpha <= 0.001: return
	var first := true
	for id in _weights:
		var alpha := _shallow_alpha if first else _shallow_alpha * float(_weights[id])
		first = false
		for band in _bands_for(id):
			_band(band[0], band[1], band[2], alpha, band[3])

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
		# 平铺相位只由世界摄像机坐标决定，与视口裁切边界无关。
		y = -fposmod(_camera_center.y * PARALLAX * _zoom.y - _view.y * 0.5, size_px.y)
		y += floor((maxf(0.0, top) - y) / size_px.y) * size_px.y
	while y < minf(_view.y, bottom):
		var y0 := maxf(maxf(y, top), 0.0)
		var y1 := minf(minf(y + size_px.y, bottom), _view.y)
		var x := left
		while x < _view.x and y1 > y0:
			var x0 := maxf(x, 0.0)
			var x1 := minf(x + size_px.x, _view.x)
			# 根据每列真实地表裁掉外面的远景：洞内不能漏天，地表也不能糊成土色。
			for clip in _surface_clips:
				var clip_left := maxf(x0,clip.x)
				var right := minf(x1,clip.y)
				var top_y := maxf(y0,clip.z)
				if right <= clip_left or y1 <= top_y: continue
				var dest := Rect2(Vector2(roundf(clip_left),roundf(top_y)), Vector2(roundf(right)-roundf(clip_left),roundf(y1)-roundf(top_y)))
				var src := Rect2(Vector2(clip_left-x,top_y-y)/scale_px,Vector2(right-clip_left,y1-top_y)/scale_px)
				_canvas.draw_texture_rect_region(tex,dest,src,Color(1,1,1,alpha))
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
