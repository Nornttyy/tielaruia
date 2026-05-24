# 雨点视觉层 (Terraria 风): 雨点在世界坐标里下落, 碰到实心方块就出现涟漪 + 消失.
# CanvasLayer 跟相机 (screen 空间) 渲染雨/涟漪, 但内部位置用世界坐标算, 每帧 canvas_transform
# 投回屏幕.
# 由 Weather 状态控制 enabled. enabled=false 时停止生成新雨点 (现有继续落).
# 同时附带闪雷全屏白闪 + 雨天压暗 modulate.
extends CanvasLayer

# Tiles 是 autoload 实例 (脚本 tile_data.gd 挂在 autoload 上), 不用 preload

const RAIN_COUNT := 220         # 屏幕上同时存在的雨点数
const RAIN_SPEED_MIN := 600.0   # 像素/秒
const RAIN_SPEED_MAX := 900.0
const RAIN_LENGTH_MIN := 14.0
const RAIN_LENGTH_MAX := 24.0
const RAIN_WIDTH := 2.5
const RAIN_COLOR := Color(0.85, 0.92, 1.0, 0.95)
const RAIN_TILT_X := 120.0      # 雨倾斜速度 (像素/秒, 风向)
const TILE_SIZE := 16
const SPAWN_MARGIN_PX := 200.0  # 雨在玩家上方多少像素的范围内随机生成
const SPAWN_HEIGHT_PX := 60.0   # 雨初始在视野上方多少像素 (出屏外, 看着像从天上来)

const RIPPLE_RADIUS_START := 1.5
const RIPPLE_RADIUS_END := 5.0
const RIPPLE_DURATION := 0.35
const RIPPLE_COLOR := Color(0.85, 0.92, 1.0, 0.85)
const RIPPLE_WIDTH := 1.2

const LIGHTNING_FLASH_COLOR := Color(1, 1, 1, 0.7)
const LIGHTNING_FLASH_DURATION := 0.12

const DARK_OVERLAY_COLOR := Color(0.05, 0.08, 0.15, 0.45)
const DARK_FADE_SEC := 1.5

var _enabled: bool = false
# 每滴 [Line2D, world_pos:Vector2, speed:float, length:float]
var _drops: Array = []
# 每个涟漪 [Line2D, world_pos:Vector2, time:float]
var _ripples: Array = []
var _vp_size: Vector2

@onready var _darken_rect: ColorRect = ColorRect.new()
@onready var _lightning_rect: ColorRect = ColorRect.new()


func _ready() -> void:
	# 渲染层: 5 在 HUD (1) 上面但在菜单 (50+) 下面.
	layer = 5
	_darken_rect.color = Color(DARK_OVERLAY_COLOR.r, DARK_OVERLAY_COLOR.g,
		DARK_OVERLAY_COLOR.b, 0.0)
	_darken_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_darken_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_darken_rect)
	_lightning_rect.color = Color(1, 1, 1, 0.0)
	_lightning_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lightning_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_lightning_rect)
	_vp_size = get_viewport().get_visible_rect().size
	get_viewport().size_changed.connect(_on_vp_size_changed)


func set_enabled(v: bool) -> void:
	_enabled = v
	var target_a: float = DARK_OVERLAY_COLOR.a if v else 0.0
	var t := create_tween()
	t.tween_property(_darken_rect, "color:a", target_a, DARK_FADE_SEC)


func flash_lightning() -> void:
	_lightning_rect.color = LIGHTNING_FLASH_COLOR
	var t := create_tween()
	t.tween_property(_lightning_rect, "color:a", 0.0, LIGHTNING_FLASH_DURATION)


func _process(delta: float) -> void:
	# canvas_transform: world → screen 矩阵 (camera/zoom 已纳入)
	var ctx: Transform2D = get_viewport().get_canvas_transform()
	var ctx_inv: Transform2D = ctx.affine_inverse()
	# 屏幕可视区域对应的世界 AABB (用来生成雨 + 回收出界雨)
	var top_left_world: Vector2 = ctx_inv * Vector2.ZERO
	var bottom_right_world: Vector2 = ctx_inv * _vp_size
	# 维持雨点数量
	if _enabled:
		var to_spawn: int = min(8, RAIN_COUNT - _drops.size())
		for _i in to_spawn:
			_spawn_drop(top_left_world, bottom_right_world)
	# 移动雨点 + 检查碰撞
	for i in range(_drops.size() - 1, -1, -1):
		var d = _drops[i]
		var line: Line2D = d[0]
		var wpos: Vector2 = d[1]
		var speed: float = d[2]
		wpos.x += RAIN_TILT_X * delta
		wpos.y += speed * delta
		d[1] = wpos
		# 飞出屏幕底部 (超过可视世界 +50 px) 回收
		if wpos.y > bottom_right_world.y + 50.0 \
				or wpos.x > bottom_right_world.x + 100.0:
			line.queue_free()
			_drops.remove_at(i)
			continue
		# 检查这一格 tile 实心 → 涟漪 + 消失
		if _hits_solid(wpos):
			line.queue_free()
			_drops.remove_at(i)
			_spawn_ripple(wpos)
			continue
		# 更新屏幕位置
		line.position = ctx * wpos
	# 更新涟漪 (扩大 + 渐隐 + 自销毁)
	for j in range(_ripples.size() - 1, -1, -1):
		var r = _ripples[j]
		var rline: Line2D = r[0]
		var rwpos: Vector2 = r[1]
		var rt: float = r[2] + delta
		r[2] = rt
		if rt >= RIPPLE_DURATION:
			rline.queue_free()
			_ripples.remove_at(j)
			continue
		var u: float = rt / RIPPLE_DURATION
		var radius: float = lerp(RIPPLE_RADIUS_START, RIPPLE_RADIUS_END, u)
		_update_ripple_points(rline, radius)
		rline.modulate.a = 1.0 - u
		rline.position = ctx * rwpos


func _spawn_drop(top_left_world: Vector2, bottom_right_world: Vector2) -> void:
	var line := Line2D.new()
	var length: float = randf_range(RAIN_LENGTH_MIN, RAIN_LENGTH_MAX)
	line.add_point(Vector2(0, 0))
	line.add_point(Vector2(RAIN_TILT_X * length / 700.0, length))
	line.width = RAIN_WIDTH
	line.default_color = RAIN_COLOR
	add_child(line)
	# 世界坐标: 在屏幕可视范围 X 上方一点的 Y, X 略微超出左右边
	var wx: float = randf_range(
		top_left_world.x - 100.0,
		bottom_right_world.x + 50.0
	)
	var wy: float = top_left_world.y - randf_range(0.0, SPAWN_HEIGHT_PX)
	var wpos := Vector2(wx, wy)
	# 立刻把 line 移到对应屏幕位置 (这里 ctx 还得取一次, 但成本可忽略)
	var ctx: Transform2D = get_viewport().get_canvas_transform()
	line.position = ctx * wpos
	_drops.append([line, wpos, randf_range(RAIN_SPEED_MIN, RAIN_SPEED_MAX), length])


# 查询世界坐标点是不是落在实心方块里
func _hits_solid(wpos: Vector2) -> bool:
	var tx: int = int(floor(wpos.x / float(TILE_SIZE)))
	var ty: int = int(floor(wpos.y / float(TILE_SIZE)))
	# 找 chunk_manager 查 tile (rain_layer 是 World 的子节点)
	var cm = _get_chunk_manager()
	if cm == null:
		return false
	var tid: int = cm.get_tile(tx, ty)
	# AIR 不算碰撞, BEDROCK 算 (虽然玩家挖不到, 视觉上还是该有涟漪)
	if tid == Tiles.AIR:
		return false
	return Tiles.is_solid(tid)


func _get_chunk_manager():
	var p: Node = get_parent()
	if p == null:
		return null
	return p.get("chunk_manager")


# 涟漪 = 8 段折线圆
const _RIPPLE_SEGMENTS := 8
func _spawn_ripple(wpos: Vector2) -> void:
	var line := Line2D.new()
	line.width = RIPPLE_WIDTH
	line.default_color = RIPPLE_COLOR
	# 初始很小的圆
	_update_ripple_points(line, RIPPLE_RADIUS_START)
	add_child(line)
	var ctx: Transform2D = get_viewport().get_canvas_transform()
	line.position = ctx * wpos
	_ripples.append([line, wpos, 0.0])


func _update_ripple_points(line: Line2D, radius: float) -> void:
	line.clear_points()
	for i in _RIPPLE_SEGMENTS + 1:
		var a: float = float(i) / float(_RIPPLE_SEGMENTS) * TAU
		line.add_point(Vector2(cos(a) * radius, sin(a) * radius))


func _on_vp_size_changed() -> void:
	_vp_size = get_viewport().get_visible_rect().size
