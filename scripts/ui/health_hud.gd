# 5 颗红心 HUD. 每颗 = 20 HP 槽位.
# Terraria 风: 外圈深色边框 + 内部红色, 红心按本槽剩余 HP 平滑缩小.
# 用程序绘制 (圆 + 三角) 而不是缩像素纹理 — 像素艺术缩小会糊, 这样任意大小都顺滑.
extends Control

const HEART_SLOT_PX := 24       # 一颗心占的边框正方形大小 (像素)
const HEART_SPACING := 4
const NUM_HEARTS := 5
const HP_PER_HEART := 20
const PAD := 8

# 颜色分层: 外深红边框 → 暗红空心底 → 鲜红填充 → 浅红高光.
const COLOR_BORDER := Color8(60, 8, 12)       # 几乎黑的深红 (Terraria 重边框感)
const COLOR_EMPTY := Color8(95, 25, 28)       # 空心时露的暗红 (跟边框拉开一档让边框看得清)
const COLOR_FILL := Color8(220, 45, 55)       # 鲜红主体
const COLOR_HIGHLIGHT := Color8(255, 145, 150) # 左上角小高光让心立体

# 心形 "外圈"/"内圈" 的相对尺寸 (相对 slot_px)
const BORDER_SIZE_RATIO := 1.0    # 占满槽位
const EMPTY_SIZE_RATIO := 0.78    # 边框给 (1-0.78)/2 = 11% slot 厚度的深红边
const FILL_MAX_RATIO := 0.78      # 满血时填充 = 空心底大小, 完全盖住
const HIGHLIGHT_SIZE_RATIO := 0.18 # 高光小圆
const HIGHLIGHT_OFFSET := Vector2(-0.18, -0.18)   # 左上偏移 (相对 slot 中心)

var _cur: int = 100
var _max: int = 100


func _ready() -> void:
	custom_minimum_size = Vector2(
		PAD * 2 + (HEART_SLOT_PX + HEART_SPACING) * NUM_HEARTS - HEART_SPACING,
		PAD * 2 + HEART_SLOT_PX
	)


func bind(health_node: Node) -> void:
	if health_node == null:
		return
	if health_node.has_signal("health_changed"):
		health_node.health_changed.connect(_on_changed)
	_on_changed(health_node.current_health, health_node.MAX_HEALTH)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	queue_redraw()


func _draw() -> void:
	for i in NUM_HEARTS:
		var cx: float = PAD + i * (HEART_SLOT_PX + HEART_SPACING) + HEART_SLOT_PX * 0.5
		var cy: float = PAD + HEART_SLOT_PX * 0.5
		var center := Vector2(cx, cy)
		# 边框 (最外, 始终画)
		_draw_heart(center, HEART_SLOT_PX * BORDER_SIZE_RATIO, COLOR_BORDER)
		# 空心底 (略缩, 露出一圈边框)
		_draw_heart(center, HEART_SLOT_PX * EMPTY_SIZE_RATIO, COLOR_EMPTY)
		# 红色填充: 平滑按 fraction 缩
		var fill_hp: int = clamp(_cur - i * HP_PER_HEART, 0, HP_PER_HEART)
		if fill_hp > 0:
			var frac: float = float(fill_hp) / float(HP_PER_HEART)
			var fill_size: float = HEART_SLOT_PX * FILL_MAX_RATIO * frac
			# 心太小时跳过避免锯齿, 但 1 HP 还是要看见点, 给最小 4px
			fill_size = max(4.0, fill_size)
			_draw_heart(center, fill_size, COLOR_FILL)
			# 高光: 跟着 fill 一起缩, 只在 fraction > 0.3 时画 (太小没意义)
			if frac > 0.3:
				var hl_size: float = fill_size * HIGHLIGHT_SIZE_RATIO * 2.0
				var hl_offset := HIGHLIGHT_OFFSET * fill_size
				draw_circle(center + hl_offset, hl_size * 0.5, COLOR_HIGHLIGHT)


# 程序绘制心形: 两个圆叠 + 一个倒三角. size 是心的"全宽". 用此函数缩放才平滑.
func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	if size <= 0.0:
		return
	var lobe_radius: float = size * 0.28        # 两个圆瓣半径
	var lobe_offset_x: float = size * 0.22      # 圆心相对 center.x 的左右偏移
	var lobe_offset_y: float = -size * 0.16     # 圆心相对 center.y 的上偏 (心顶在上)
	# 两个圆瓣 (左右)
	draw_circle(center + Vector2(-lobe_offset_x, lobe_offset_y), lobe_radius, color)
	draw_circle(center + Vector2(lobe_offset_x, lobe_offset_y), lobe_radius, color)
	# 底部倒三角: 顶边连接两瓣外缘, 底点在心尖
	var tri_top_y: float = center.y + lobe_offset_y    # 两瓣中心连线 y
	var tri_left := Vector2(center.x - lobe_offset_x - lobe_radius * 0.85, tri_top_y)
	var tri_right := Vector2(center.x + lobe_offset_x + lobe_radius * 0.85, tri_top_y)
	var tri_bottom := Vector2(center.x, center.y + size * 0.42)
	draw_colored_polygon(PackedVector2Array([tri_left, tri_right, tri_bottom]), color)
