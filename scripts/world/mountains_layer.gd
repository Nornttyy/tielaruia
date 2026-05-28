# 视差远山. ParallaxBackground 含 3 个 ParallaxLayer (远/中/近).
# 每层一张 1280x256 纹理, motion_mirroring 水平铺无限.
# 颜色根据 TimeOfDay 做大气透视染色: 黄昏偏橙, 夜里偏蓝紫.
extends ParallaxBackground

const MountainsArt = preload("res://scripts/art/mountains_art.gd")

# 纹理尺寸: 横向 1 个视口宽, 纵向占下半屏幕 (~360 px)
const TEX_WIDTH := 1280
const TEX_HEIGHT := 360

# 视口宽 1280, 高 720. 地平线 (horizon) 大致在 y=420 (略低于中线)
const HORIZON_Y := 420

# 每层定义: motion_scale (越小越远), color_idx, peaks, jaggedness, snow, y_extra
# y_extra: 在 horizon 之上额外偏移 (远山高一点, 近丘低一点)
const _LAYERS := [
	{
		# 最远层: 用户要求"远处背景不动" → motion_scale = 0 锁视口
		"motion_scale": 0.0, "color_idx": 0,
		"peaks": 4, "jaggedness": 0.5, "snow": true,
		"y_extra": -40, "alpha": 0.95,
	},
	{
		"motion_scale": 0.12, "color_idx": 1,
		"peaks": 7, "jaggedness": 0.7, "snow": false,
		"y_extra": 10, "alpha": 0.96,
	},
	{
		"motion_scale": 0.20, "color_idx": 2,
		"peaks": 10, "jaggedness": 1.0, "snow": false,
		"y_extra": 60, "alpha": 1.0,
	},
]

# 视口高度 (跟 project.godot 的 window/size/viewport_height 同步)
const VIEWPORT_HEIGHT := 720

var _layer_data: Array = []  # 每层 {sprite, fill, base_color}
var _layer_alpha: float = 1.0  # 由 ScenicDirector 设 (0=矿洞 1=地表)


func _ready() -> void:
	# 远山要在天空 (-10) 之上, 云 (默认 0) 之下 — 用 layer=-9
	layer = -9
	# 锁屏幕空间 (用户要求"不管 zoom 都盖满"). parallax 会失效 (没立体感)
	scroll_ignore_camera_zoom = true
	var colors: Array = MountainsArt.all_colors()
	for i in _LAYERS.size():
		var ld: Dictionary = _LAYERS[i]
		var pl := ParallaxLayer.new()
		# 山只跟 X 视差, Y 不动
		pl.motion_scale = Vector2(ld.motion_scale, 0.0)
		pl.motion_mirroring = Vector2(TEX_WIDTH, 0)
		add_child(pl)
		var sprite := Sprite2D.new()
		var base_color: Color = colors[ld.color_idx]
		sprite.texture = MountainsArt.generate_ridge(
			TEX_WIDTH, TEX_HEIGHT,
			ld.peaks, ld.jaggedness,
			base_color, ld.snow, 1001 + i * 17
		)
		sprite.centered = false
		# sprite 顶部 = horizon - tex_height + y_extra
		# 这样山顶在 horizon 之上 ~ tex_height-y_extra, 山脚延伸到 horizon+y_extra
		var sprite_top: int = HORIZON_Y - TEX_HEIGHT + ld.y_extra
		sprite.position = Vector2(0, sprite_top)
		sprite.modulate.a = ld.alpha
		pl.add_child(sprite)
		# Fill 条: 山的底部到屏幕底, 用 base_color 填上, 不然玩家在高山上往下看
		# 会有一片空 (露出 sky 颜色), 像浮空岛. 这里把山身延展下来覆盖到屏幕底.
		var sprite_bottom: int = sprite_top + TEX_HEIGHT
		var fill_h: int = max(0, VIEWPORT_HEIGHT - sprite_bottom + 200)  # 多铺 200 px 防视口变大
		var fill := ColorRect.new()
		fill.color = base_color
		fill.position = Vector2(0, sprite_bottom)
		fill.size = Vector2(TEX_WIDTH, fill_h)
		fill.modulate.a = ld.alpha
		pl.add_child(fill)
		_layer_data.append({
			"sprite": sprite,
			"fill": fill,
			"base_color": base_color,
			"alpha": ld.alpha,
		})


func _process(_delta: float) -> void:
	# 大气透视染色: 黄昏偏橙, 夜里偏蓝紫.
	# 用 TimeOfDay.sky_color 跟 base_color 混合, 白天保持原色
	var f: float = TimeOfDay.day_factor()
	var sky_tint: Color = TimeOfDay.sky_color()
	for ld in _layer_data:
		var base: Color = ld.base_color
		var blend_amount: float = (1.0 - f) * 0.55  # 夜里 0.55, 白天 0
		var tinted: Color = base.lerp(sky_tint, blend_amount)
		# 夜里整体压暗
		var brightness: float = lerp(0.35, 1.0, f)
		tinted = tinted * brightness
		tinted.a = ld.alpha * _layer_alpha  # 乘 ScenicDirector 给的 alpha
		ld.sprite.modulate = tinted
		# fill rect 同步色 + alpha (跟 sprite 一致, 不然边界突变)
		ld.fill.color = tinted
		ld.fill.modulate.a = 1.0  # color 已含 alpha, modulate 重置避免双重


# ScenicDirector 调这个统一改整层 alpha
func set_layer_alpha(a: float) -> void:
	_layer_alpha = clamp(a, 0.0, 1.0)


func current_alpha() -> float:
	return _layer_alpha


# 给测试用: 当前 ParallaxLayer 数 (应 = 3)
func layer_count() -> int:
	var n: int = 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
