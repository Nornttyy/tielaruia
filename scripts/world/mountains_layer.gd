# 视差远景. ParallaxBackground 含 3 个 ParallaxLayer (远/中/近).
# 每层一张 1280x360 剪影纹理, motion_mirroring 水平铺无限.
# 不同群系 = 真·不同的景物剪影 (森林山 / 沙漠沙丘+仙人掌 / 雪原雪山 / 丛林树冠 / 沼泽枯树),
# 由 ScenicDirector 按玩家所在 biome 调 set_biome(), 跨群系交叉淡入淡出 (不是染色).
extends ParallaxBackground

const MountainsArt = preload("res://scripts/art/mountains_art.gd")

const TEX_WIDTH := 1280
const TEX_HEIGHT := 360
const HORIZON_Y := 420
const VIEWPORT_HEIGHT := 720
const CROSSFADE_SEC := 0.9

# 每层: motion_scale (越小越远) + y_extra (远山高/近丘低) + alpha
const _LAYERS := [
	{"motion_scale": 0.0,  "y_extra": -40, "alpha": 0.95},   # 最远 (锁视口)
	{"motion_scale": 0.12, "y_extra": 10,  "alpha": 0.96},   # 中
	{"motion_scale": 0.20, "y_extra": 60,  "alpha": 1.0},    # 近
]

# biome → 景物风格 (剪影形状). 0森林 1沙漠 2雪原 3丛林 4沼泽
const _BIOME_STYLE := {0: "mountain", 1: "dune", 2: "mountain", 3: "canopy", 4: "deadtree"}
const _BIOME_SNOW := {2: true}   # 雪原山顶盖雪
# biome → 3 层颜色 (远/中/近, 大气透视: 远浅近深)
const _BIOME_COLORS := {
	0: [Color(0.55, 0.62, 0.75), Color(0.40, 0.50, 0.55), Color(0.30, 0.40, 0.30)],  # 森林
	1: [Color(0.80, 0.72, 0.56), Color(0.84, 0.70, 0.46), Color(0.70, 0.56, 0.34)],  # 沙漠沙黄
	2: [Color(0.74, 0.80, 0.90), Color(0.66, 0.74, 0.85), Color(0.56, 0.66, 0.78)],  # 雪原冷蓝白
	3: [Color(0.42, 0.55, 0.46), Color(0.28, 0.48, 0.32), Color(0.18, 0.40, 0.24)],  # 丛林深绿
	4: [Color(0.46, 0.50, 0.46), Color(0.36, 0.42, 0.37), Color(0.26, 0.34, 0.29)],  # 沼泽灰绿
}

var _layer_data: Array = []  # 每层 {sa, sb, fill, color_a, color_b, alpha}
var _layer_alpha: float = 1.0
var _biome_current: int = 0
var _biome_incoming: int = -1
var _blend: float = 0.0
var _tex_cache: Dictionary = {}   # "biome_layeridx" → ImageTexture (生成一次缓存)


func _ready() -> void:
	layer = -9
	scroll_ignore_camera_zoom = true
	for i in _LAYERS.size():
		var ld: Dictionary = _LAYERS[i]
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(ld.motion_scale, 0.0)
		pl.motion_mirroring = Vector2(TEX_WIDTH, 0)
		add_child(pl)
		var sprite_top: int = HORIZON_Y - TEX_HEIGHT + ld.y_extra
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
		pl.add_child(fill)
		_layer_data.append({
			"sa": sa, "sb": sb, "fill": fill,
			"color_a": col, "color_b": col, "alpha": ld.alpha,
		})


func _make_sprite(layer_idx: int, biome: int, top: int) -> Sprite2D:
	var sp := Sprite2D.new()
	sp.centered = false
	sp.position = Vector2(0, top)
	sp.texture = _get_tex(biome, layer_idx)
	return sp


# 取 (biome, layer) 的剪影纹理, 生成一次后缓存 (避免每次切群系都重画)
func _get_tex(biome: int, layer_idx: int) -> ImageTexture:
	var key: String = "%d_%d" % [biome, layer_idx]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var style: String = _BIOME_STYLE.get(biome, "mountain")
	var snow: bool = _BIOME_SNOW.get(biome, false)
	var tex: ImageTexture = MountainsArt.generate_biome_ridge(
		TEX_WIDTH, TEX_HEIGHT, style, _biome_color(biome, layer_idx), snow,
		1001 + biome * 101 + layer_idx * 17)
	_tex_cache[key] = tex
	return tex


func _biome_color(biome: int, layer_idx: int) -> Color:
	var cols: Array = _BIOME_COLORS.get(biome, _BIOME_COLORS[0])
	return cols[layer_idx]


# ScenicDirector 按玩家所在 biome 调: 切到该群系景物 (交叉淡入). 已是当前/在切的就跳过.
func set_biome(biome_id: int) -> void:
	if biome_id == _biome_current or biome_id == _biome_incoming:
		return
	if not _BIOME_COLORS.has(biome_id):
		return
	_biome_incoming = biome_id
	_blend = 0.0
	for i in _layer_data.size():
		var ld: Dictionary = _layer_data[i]
		ld.sb.texture = _get_tex(biome_id, i)
		ld.color_b = _biome_color(biome_id, i)


func _process(delta: float) -> void:
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
		var ta: Color = _atmos(ld.color_a, f, sky_tint)
		ta.a = ld.alpha * _layer_alpha * (1.0 - (_blend if fading else 0.0))
		ld.sa.modulate = ta
		if fading:
			var tb: Color = _atmos(ld.color_b, f, sky_tint)
			tb.a = ld.alpha * _layer_alpha * _blend
			ld.sb.modulate = tb
		else:
			ld.sb.modulate.a = 0.0
		# fill 用主导色 (过半就换成 incoming), 跟 sprite 一致
		var fc: Color = _atmos(ld.color_b if (fading and _blend >= 0.5) else ld.color_a, f, sky_tint)
		fc.a = 1.0
		ld.fill.color = fc
		ld.fill.modulate.a = ld.alpha * _layer_alpha


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
