# 心 HUD: 每颗 = 20 HP. 心数 = ceil(MAX_HEALTH / 20), 5 ~ 20 颗 (Terraria 上限).
# > 10 颗时换行: 第 1 行 10 颗, 第 2 行剩下的. 跟 Terraria 一致.
# Terraria 风: 程序绘制 (圆 + 三角), 4 层叠 (深红边框 + 暗红空心 + 鲜红填充 + 浅红高光).
# 心按本槽剩余 HP 平滑缩, 不分半格.
extends Control

const HEART_SLOT_PX := 24       # 一颗心占的边框正方形大小 (像素)
const HEART_SPACING := 4
const HEARTS_PER_ROW := 10      # 第 1 行最多 10 颗心, 超出换第 2 行 (Terraria 风)
const HP_PER_HEART := 20
const PAD := 8

# 颜色分层
const COLOR_BORDER := Color8(60, 8, 12)
const COLOR_EMPTY := Color8(95, 25, 28)
const COLOR_FILL := Color8(220, 45, 55)
const COLOR_HIGHLIGHT := Color8(255, 145, 150)

# 心形 "外圈"/"内圈" 相对尺寸 (相对 slot_px)
const BORDER_SIZE_RATIO := 1.0
const EMPTY_SIZE_RATIO := 0.78
const FILL_MAX_RATIO := 0.78
const HIGHLIGHT_SIZE_RATIO := 0.18
const HIGHLIGHT_OFFSET := Vector2(-0.18, -0.18)

const TEXT_FONT_SIZE := 14    # "100/100" 显示字号
const TEXT_HEIGHT := 18       # 给 label 留的垂直空间 (含 padding)

var _cur: int = 100
var _max: int = 100
var _hp_label: Label


func _ready() -> void:
	# 血量数字 label 放在 HUD 右上角 (跟 HUD 一起锚定屏幕右上角)
	_hp_label = Label.new()
	_hp_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_hp_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	_hp_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_hp_label.add_theme_constant_override("shadow_offset_x", 1)
	_hp_label.add_theme_constant_override("shadow_offset_y", 1)
	_hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hp_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_hp_label.offset_left = -120.0
	_hp_label.offset_right = -PAD
	_hp_label.offset_top = 0.0
	_hp_label.offset_bottom = TEXT_HEIGHT
	add_child(_hp_label)
	_update_label()
	_update_min_size()


func bind(health_node: Node) -> void:
	if health_node == null:
		return
	if health_node.has_signal("health_changed"):
		health_node.health_changed.connect(_on_changed)
	_on_changed(health_node.current_health, health_node.MAX_HEALTH)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	# max 变化时调整 HUD 高度 (吃了水晶后 max 变大 → 可能多行)
	if maximum != _max:
		_max = maximum
		_update_min_size()
	_update_label()
	queue_redraw()


# 把 "当前/上限" 数字同步到右上角 label. cur 改变 / max 改变都调.
func _update_label() -> void:
	if _hp_label != null:
		_hp_label.text = "%d / %d" % [_cur, _max]


# 根据当前 _max 计算总心数 + 行数, 更新 custom_minimum_size.
func _update_min_size() -> void:
	var num_hearts: int = _heart_count()
	var rows: int = ceili(float(num_hearts) / float(HEARTS_PER_ROW))
	var cols_first_row: int = min(num_hearts, HEARTS_PER_ROW)
	custom_minimum_size = Vector2(
		PAD * 2 + (HEART_SLOT_PX + HEART_SPACING) * cols_first_row - HEART_SPACING,
		PAD * 2 + (HEART_SLOT_PX + HEART_SPACING) * rows - HEART_SPACING
	)


func _heart_count() -> int:
	return ceili(float(_max) / float(HP_PER_HEART))


func _draw() -> void:
	var num_hearts: int = _heart_count()
	for i in num_hearts:
		var row: int = i / HEARTS_PER_ROW
		var col: int = i % HEARTS_PER_ROW
		var cx: float = PAD + col * (HEART_SLOT_PX + HEART_SPACING) + HEART_SLOT_PX * 0.5
		var cy: float = PAD + row * (HEART_SLOT_PX + HEART_SPACING) + HEART_SLOT_PX * 0.5
		var center := Vector2(cx, cy)
		# 边框 (始终画)
		_draw_heart(center, HEART_SLOT_PX * BORDER_SIZE_RATIO, COLOR_BORDER)
		# 空心底
		_draw_heart(center, HEART_SLOT_PX * EMPTY_SIZE_RATIO, COLOR_EMPTY)
		# 红色填充, 按 fraction 平滑缩
		var fill_hp: int = clamp(_cur - i * HP_PER_HEART, 0, HP_PER_HEART)
		if fill_hp > 0:
			var frac: float = float(fill_hp) / float(HP_PER_HEART)
			var fill_size: float = HEART_SLOT_PX * FILL_MAX_RATIO * frac
			fill_size = max(4.0, fill_size)
			_draw_heart(center, fill_size, COLOR_FILL)
			if frac > 0.3:
				var hl_size: float = fill_size * HIGHLIGHT_SIZE_RATIO * 2.0
				var hl_offset := HIGHLIGHT_OFFSET * fill_size
				draw_circle(center + hl_offset, hl_size * 0.5, COLOR_HIGHLIGHT)


# 程序绘制心: 两个圆瓣 + 底部倒三角. size 是心的"全宽". 缩任意大小都平滑.
func _draw_heart(center: Vector2, size: float, color: Color) -> void:
	if size <= 0.0:
		return
	var lobe_radius: float = size * 0.28
	var lobe_offset_x: float = size * 0.22
	var lobe_offset_y: float = -size * 0.16
	draw_circle(center + Vector2(-lobe_offset_x, lobe_offset_y), lobe_radius, color)
	draw_circle(center + Vector2(lobe_offset_x, lobe_offset_y), lobe_radius, color)
	var tri_top_y: float = center.y + lobe_offset_y
	var tri_left := Vector2(center.x - lobe_offset_x - lobe_radius * 0.85, tri_top_y)
	var tri_right := Vector2(center.x + lobe_offset_x + lobe_radius * 0.85, tri_top_y)
	var tri_bottom := Vector2(center.x, center.y + size * 0.42)
	draw_colored_polygon(PackedVector2Array([tri_left, tri_right, tri_bottom]), color)
