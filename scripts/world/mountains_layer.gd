# 视差远景. ParallaxBackground 含 3 个 ParallaxLayer (远/中/近).
# 每层一张 1280x360 剪影纹理, motion_mirroring 水平铺无限.
# 不同群系 = 真·不同的景物剪影 (森林山 / 沙漠沙丘+仙人掌 / 雪原雪山 / 丛林树冠 / 沼泽枯树),
# 由 ScenicDirector 按玩家所在 biome 调 set_biome(), 跨群系交叉淡入淡出 (不是染色).
extends ParallaxBackground

const MountainsArt = preload("res://scripts/art/mountains_art.gd")
const OriginalSprites = preload("res://scripts/art/terraria_sprite_pack.gd")

const TEX_WIDTH := 768
const TEX_HEIGHT := 720
const HORIZON_Y := 420
const VIEWPORT_HEIGHT := 720
const CROSSFADE_SEC := 0.9

# 每层: motion_scale (越小越远) + y_extra (远山高/近丘低) + alpha
const _LAYERS := [
	{"motion_scale": 0.04, "y_extra": 145, "alpha": 1.0},
	{"motion_scale": 0.10, "y_extra": 215, "alpha": 1.0},
	{"motion_scale": 0.18, "y_extra": 290, "alpha": 1.0},
]
# 每组保留原画的远山、丘陵和近树顺序。原图像素按世界方块 12/16 等比呈现。
const BACKGROUNDS := {
	0: [7, 8, 11], 1: [22, 20, 21], 2: [98, 99, 101],
	3: [15, 16, 17], 4: [15, 16, 17], 5: [12, 13, 14],
	6: [105, 106, 107], 8: [110, 110, 111],
}

var _layer_data: Array = []  # 每层 {sa, sb, fill, color_a, color_b, alpha}
var _layer_alpha: float = 1.0
var _biome_current: int = 0
var _biome_incoming: int = -1
var _blend: float = 0.0
var _tex_cache: Dictionary = {}   # "biome_layeridx" → ImageTexture (生成一次缓存)
var _surface_camera_y: float = NAN


func _ready() -> void:
	layer = -9
	scroll_ignore_camera_zoom = true
	for i in _LAYERS.size():
		var ld: Dictionary = _LAYERS[i]
		var pl := ParallaxLayer.new()
		# y 跟 x 同视差系数: 远山上下也跟摄像头动 (用户要求 — 只山跟, 云仍只左右动见 cloud_layer)。
		# 远层(motion_scale 0)仍锁屏不动, 中/近层随镜头上下飘 (近层飘得多 = 视差深度)。
		pl.motion_scale = Vector2(ld.motion_scale, ld.motion_scale)
		pl.motion_mirroring = Vector2(TEX_WIDTH * 4, 0)
		add_child(pl)
		var sprite_top: int = ld.y_extra
		var col: Color = _biome_color(_biome_current, i)
		var sa := _make_sprite(i, _biome_current, sprite_top)
		pl.add_child(sa)
		var sb := _make_sprite(i, _biome_current, sprite_top)   # 交叉淡入用的第二张
		sb.modulate.a = 0.0
		pl.add_child(sb)
		# Fill 条: 山脚到屏幕底, 防玩家在高处往下看露出天空
		var sprite_bottom: int = sprite_top + TEX_HEIGHT
		var fill_h: int = max(0, VIEWPORT_HEIGHT - sprite_bottom + 200)
		var fill := ColorRect.new()
		fill.color = col
		fill.position = Vector2(0, sprite_bottom)
		fill.size = Vector2(TEX_WIDTH, fill_h)
		fill.visible = false
		pl.add_child(fill)
		_layer_data.append({
			"sa": sa, "sb": sb, "fill": fill,
			"color_a": col, "color_b": col, "alpha": ld.alpha,
		})


func _make_sprite(layer_idx: int, biome: int, top: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = false
	# 缩小镜头时仍覆盖整屏；只横向平铺，不能留下图层右端的直线断口。
	sp.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sp.region_enabled = true
	sp.region_rect = Rect2(0, 0, TEX_WIDTH * 4, TEX_HEIGHT)
	sp.position = Vector2(0, top)
	sp.texture = _get_tex(biome, layer_idx)
	return sp


# 取 (biome, layer) 的剪影纹理, 生成一次后缓存 (避免每次切群系都重画)
func _get_tex(biome: int, layer_idx: int) -> ImageTexture:
	var key := "%d_%d" % [biome, layer_idx]
	if _tex_cache.has(key): return _tex_cache[key]
	if biome == 8 and layer_idx > 0:
		var empty := ImageTexture.create_from_image(Image.create(TEX_WIDTH, TEX_HEIGHT, false, Image.FORMAT_RGBA8))
		_tex_cache[key] = empty
		return empty
	var source := OriginalSprites.source_image("Background_%d.png" % BACKGROUNDS.get(biome, BACKGROUNDS[0])[layer_idx])
	var scaled := source.duplicate() as Image
	scaled.resize(roundi(source.get_width() * 0.75), roundi(source.get_height() * 0.75), Image.INTERPOLATE_NEAREST)
	var canvas := Image.create(TEX_WIDTH, TEX_HEIGHT, false, Image.FORMAT_RGBA8)
	var offset := 0  # 海平线保持原画高度；不能按之前漏水后的低水位下移。
	canvas.blit_rect(scaled, Rect2i(Vector2i.ZERO, scaled.get_size()), Vector2i(0, offset))
	# 延续每一列的底色，不能用一个色块盖掉原画的山脚纹理。
	for x in TEX_WIDTH:
		canvas.fill_rect(Rect2i(x, scaled.get_height() + offset, 1, TEX_HEIGHT - scaled.get_height() - offset), scaled.get_pixel(x, scaled.get_height() - 1))
	var tex := ImageTexture.create_from_image(canvas)
	_tex_cache[key] = tex
	return tex

func _biome_color(biome: int, layer_idx: int) -> Color:
	var source := OriginalSprites.source_image("Background_%d.png" % BACKGROUNDS.get(biome, BACKGROUNDS[0])[layer_idx])
	return source.get_pixel(0, source.get_height() - 1)

# ScenicDirector 按玩家所在 biome 调: 切到该群系景物 (交叉淡入). 已是当前/在切的就跳过.
func set_biome(biome_id: int) -> void:
	if biome_id == _biome_current or biome_id == _biome_incoming:
		return
	if not BACKGROUNDS.has(biome_id):
		return
	_biome_incoming = biome_id
	_blend = 0.0
	for i in _layer_data.size():
		var ld: Dictionary = _layer_data[i]
		ld.sb.texture = _get_tex(biome_id, i)
		ld.color_b = _biome_color(biome_id, i)


func _process(delta: float) -> void:
	_align_surface_horizon()
	_align_ocean_horizon()
	# 交叉淡入推进
	if _biome_incoming >= 0:
		_blend = min(1.0, _blend + delta / CROSSFADE_SEC)
		if _blend >= 1.0:
			for ld in _layer_data:   # 收尾: incoming → current
				ld.sa.texture = ld.sb.texture
				ld.color_a = ld.color_b
			_biome_current = _biome_incoming
			_biome_incoming = -1
			_blend = 0.0
	# 大气透视染色 (黄昏偏橙/夜里压暗) + 深度 alpha
	var f: float = TimeOfDay.day_factor()
	var sky_tint: Color = TimeOfDay.sky_color()
	var fading: bool = _biome_incoming >= 0
	for ld in _layer_data:
		var ta: Color = _texture_tint(ld.color_a, f, sky_tint)
		ta.a = ld.alpha * _layer_alpha * (1.0 - (_blend if fading else 0.0))
		ld.sa.modulate = ta
		if fading:
			var tb: Color = _texture_tint(ld.color_b, f, sky_tint)
			tb.a = ld.alpha * _layer_alpha * _blend
			ld.sb.modulate = tb
		else:
			ld.sb.modulate.a = 0.0
		# 山脚也连续混色，不能切换到一半突然跳色。
		var fc: Color = _atmos(ld.color_a, f, sky_tint)
		if fading:
			fc = fc.lerp(_atmos(ld.color_b, f, sky_tint), _blend)
		fc.a = 1.0
		ld.fill.color = fc
		ld.fill.modulate.a = ld.alpha * _layer_alpha


# 海岛地平线必须留在真实水面之上；潜水时不能让海岛跟着镜头沉进水里。
func _align_ocean_horizon() -> void:
	var world := get_parent()
	if world == null or not world.has_method("get_player"): return
	var player = world.get_player()
	if player == null: return
	var surface_y := 116.0 * 12.0
	if _biome_current == 8 or _biome_incoming == 8:
		var cm = world.get("chunk_manager")
		if cm != null:
			var x := floori(player.global_position.x / 12.0)
			for y in 200:
				var level: int = Tiles.water_level(cm.get_tile(x, y))
				if level > 0:
					surface_y = (y + 1) * 12.0 - level * 1.5
					break
	var water_screen_y: float = (world.get_canvas_transform() * Vector2(0, surface_y)).y
	for i in _layer_data.size():
		var ld: Dictionary = _layer_data[i]
		for pair in [[ld.sa, _biome_current], [ld.sb, _biome_incoming]]:
			var sprite: Sprite2D = pair[0]
			if int(pair[1]) == 8:
				# 原图水线约在 y=104，世界显示比例 0.75；远水线比前水面高 24px。
				var target: float = water_screen_y - 104.0 * 0.75 - 24.0
				sprite.position.y += target - sprite.get_global_transform_with_canvas().origin.y
			else:
				sprite.position.y = _LAYERS[i].y_extra


func _align_surface_horizon() -> void:
	if not is_nan(_surface_camera_y):
		return
	var world := get_parent()
	if world == null or not world.has_method("get_player"):
		return
	var player = world.get_player()
	if player == null:
		return
	# 世界坐标中的出生地可能在上千像素处，不能直接把这个高度减到屏幕远景上。
	# 只抵消初始地表高度；此后仍保留已有的上下视差跟随。
	_surface_camera_y = player.global_position.y
	for child in get_children():
		if child is ParallaxLayer:
			child.motion_offset.y = _surface_camera_y * child.motion_scale.y


func _texture_tint(base: Color, f: float, sky_tint: Color) -> Color:
	# 纹理已经带有底色，再乘底色会变成底色的平方，导致远山过黑、与填充条断层。
	var target := _atmos(base, f, sky_tint)
	return Color(target.r / maxf(base.r, 0.001), target.g / maxf(base.g, 0.001),
		target.b / maxf(base.b, 0.001), 1.0)


func _atmos(base: Color, f: float, sky_tint: Color) -> Color:
	var blend_amount: float = (1.0 - f) * 0.55   # 夜里 0.55, 白天 0
	var tinted: Color = base.lerp(sky_tint, blend_amount)
	return tinted * lerp(0.35, 1.0, f)            # 夜里整体压暗


# ScenicDirector 调这个统一改整层 alpha (地表↔矿洞)
func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


func current_alpha() -> float:
	return _layer_alpha


func current_biome() -> int:
	return _biome_current


# 给测试用: 当前 ParallaxLayer 数 (应 = 3)
func layer_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
