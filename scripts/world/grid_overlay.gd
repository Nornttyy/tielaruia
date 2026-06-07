# 网格辅助 (按 Ctrl 开关)。整屏画 tile 网格线 + 高亮鼠标所在格, 帮搭建时对齐。
# 纯视觉叠加: 不碰任何 tile / 放置 / 存档逻辑。挂在 World 下 → Node2D 本地坐标 == 世界坐标,
# _draw 直接用世界坐标画, 跟着相机移动 (每帧 queue_redraw)。
extends Node2D

const TILE_SIZE := 12
const LINE_COLOR := Color(1.0, 0.97, 0.9, 0.22)    # 柔白暖调网格线, 淡 (不抢戏)
const HILITE_FILL := Color(1.0, 0.95, 0.7, 0.18)   # 鼠标所在格填充
const HILITE_EDGE := Color(1.0, 0.92, 0.55, 0.75)  # 鼠标所在格边框 (亮黄, 看清放哪)

var _active: bool = false      # 网格是否显示 (Ctrl 开关切换)
var _prev_ctrl: bool = false   # 上一帧 Ctrl 按住状态 (检测"刚按下"的上升沿)


# 世界坐标 → tile 坐标 (floor, 负数也对)。draw 高亮 + 测试都用。
static func snap_to_tile(world_pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))


func _ready() -> void:
	z_index = 90   # 画在地形/黑暗层之上, 当辅助叠加 (HUD 在 CanvasLayer 仍盖在最上, 不冲突)
	add_to_group("grid_overlay")
	set_process(true)


func _process(_delta: float) -> void:
	# Ctrl 上升沿 = 切换: 按一下开, 再按一下关。
	var ctrl_down: bool = Input.is_key_pressed(KEY_CTRL)
	if ctrl_down and not _prev_ctrl:
		_active = not _active
		queue_redraw()   # 立刻反映开/关 (关时清屏)
	_prev_ctrl = ctrl_down
	if _active:
		queue_redraw()   # 相机/鼠标动 → 每帧重画


func _draw() -> void:
	if not _active:
		return
	var cam: Camera2D = get_viewport().get_camera_2d()
	if cam == null:
		return
	# 相机可视世界范围: 中心 ± (视口尺寸/2 / zoom)
	var half: Vector2 = get_viewport_rect().size * 0.5 / cam.zoom
	var center: Vector2 = cam.get_screen_center_position()
	var left: float = center.x - half.x
	var right: float = center.x + half.x
	var top: float = center.y - half.y
	var bottom: float = center.y + half.y
	# 竖线 (对齐 tile 边界)
	var x: int = int(floor(left / TILE_SIZE)) * TILE_SIZE
	while x <= right:
		draw_line(Vector2(x, top), Vector2(x, bottom), LINE_COLOR, 1.0)
		x += TILE_SIZE
	# 横线
	var y: int = int(floor(top / TILE_SIZE)) * TILE_SIZE
	while y <= bottom:
		draw_line(Vector2(left, y), Vector2(right, y), LINE_COLOR, 1.0)
		y += TILE_SIZE
	# 高亮鼠标所在格 (看清方块会放在哪)
	var tile: Vector2i = snap_to_tile(get_global_mouse_position())
	var cell := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	draw_rect(cell, HILITE_FILL, true)         # 填充
	draw_rect(cell, HILITE_EDGE, false, 1.5)   # 边框
