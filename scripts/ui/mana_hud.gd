# 魔力 HUD: Terraria 风 5 角星. 每颗 = 20 mana. 100 满 = 5 星, max 上限增长就多星.
# 跟 health_hud (心) 同布局: 一行 10 颗, 超出换行.
# 蓝紫色调 (跟魔晶/法杖呼应).
extends Control

const STAR_SLOT_PX := 24       # 一颗星占的边框正方形大小
const STAR_SPACING := 4
const STARS_PER_ROW := 10
const MANA_PER_STAR := 20      # 每颗星 = 20 mana (跟法杖一发同价)
const PAD := 8

# 颜色: 蓝紫 (跟魔晶呼应)
const COLOR_BORDER := Color8(20, 15, 55)       # 深蓝紫边框
const COLOR_EMPTY := Color8(45, 35, 90)        # 空星暗紫
const COLOR_FILL := Color8(110, 90, 230)       # 满星蓝紫亮
const COLOR_HIGHLIGHT := Color8(200, 195, 255) # 闪点近白

const TEXT_FONT_SIZE := 14
const TEXT_HEIGHT := 18

# 星形比例 (相对 slot_px)
const BORDER_SIZE_RATIO := 1.0
const EMPTY_SIZE_RATIO := 0.78
const FILL_MAX_RATIO := 0.78
const HIGHLIGHT_SIZE_RATIO := 0.20
const HIGHLIGHT_OFFSET := Vector2(-0.18, -0.18)

var _cur: int = 100
var _max: int = 100
var _mana_label: Label


func _ready() -> void:
	_mana_label = Label.new()
	_mana_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_mana_label.add_theme_color_override("font_color", Color(0.93, 0.93, 1.0))
	_mana_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_mana_label.add_theme_constant_override("shadow_offset_x", 1)
	_mana_label.add_theme_constant_override("shadow_offset_y", 1)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_mana_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_mana_label.offset_left = -120.0
	_mana_label.offset_right = -PAD
	_mana_label.offset_top = 0.0
	_mana_label.offset_bottom = TEXT_HEIGHT
	add_child(_mana_label)
	_update_label()
	_update_min_size()


func bind(mana_node: Node) -> void:
	if mana_node == null:
		return
	if mana_node.has_signal("mana_changed"):
		mana_node.mana_changed.connect(_on_changed)
	_on_changed(mana_node.current_mana, mana_node.MAX_MANA)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	if maximum != _max:
		_max = maximum
		_update_min_size()
	_update_label()
	queue_redraw()


func _update_label() -> void:
	if _mana_label != null:
		_mana_label.text = "%d / %d" % [_cur, _max]


func _update_min_size() -> void:
	var num_stars: int = _star_count()
	var rows: int = ceili(float(num_stars) / float(STARS_PER_ROW))
	var cols_first_row: int = min(num_stars, STARS_PER_ROW)
	custom_minimum_size = Vector2(
		PAD * 2 + (STAR_SLOT_PX + STAR_SPACING) * cols_first_row - STAR_SPACING,
		PAD * 2 + (STAR_SLOT_PX + STAR_SPACING) * rows - STAR_SPACING
	)


func _star_count() -> int:
	return ceili(float(_max) / float(MANA_PER_STAR))


func _draw() -> void:
	var num_stars: int = _star_count()
	for i in num_stars:
		var row: int = i / STARS_PER_ROW
		var col: int = i % STARS_PER_ROW
		var cx: float = PAD + col * (STAR_SLOT_PX + STAR_SPACING) + STAR_SLOT_PX * 0.5
		var cy: float = PAD + row * (STAR_SLOT_PX + STAR_SPACING) + STAR_SLOT_PX * 0.5
		var center := Vector2(cx, cy)
		# 边框
		_draw_star(center, STAR_SLOT_PX * BORDER_SIZE_RATIO, COLOR_BORDER)
		# 空星底
		_draw_star(center, STAR_SLOT_PX * EMPTY_SIZE_RATIO, COLOR_EMPTY)
		# 蓝紫填充, 按 fraction 平滑缩
		var fill_mana: int = clamp(_cur - i * MANA_PER_STAR, 0, MANA_PER_STAR)
		if fill_mana > 0:
			var frac: float = float(fill_mana) / float(MANA_PER_STAR)
			var fill_size: float = STAR_SLOT_PX * FILL_MAX_RATIO * frac
			fill_size = max(4.0, fill_size)
			_draw_star(center, fill_size, COLOR_FILL)
			if frac > 0.3:
				var hl_size: float = fill_size * HIGHLIGHT_SIZE_RATIO * 2.0
				var hl_offset := HIGHLIGHT_OFFSET * fill_size
				draw_circle(center + hl_offset, hl_size * 0.5, COLOR_HIGHLIGHT)


# 程序绘制 5 角星. size = 外接圆 "直径". 缩任意大小都平滑.
# 5 角星 = 10 个点轮流外/内 半径. 起始朝上 (-90°).
func _draw_star(center: Vector2, size: float, color: Color) -> void:
	if size <= 0.0:
		return
	var outer_r: float = size * 0.5
	var inner_r: float = outer_r * 0.42   # 黄金分割大致
	var points := PackedVector2Array()
	for i in 10:
		var angle: float = -PI / 2.0 + float(i) * PI / 5.0
		var r: float = outer_r if i % 2 == 0 else inner_r
		points.append(center + Vector2(cos(angle), sin(angle)) * r)
	draw_colored_polygon(points, color)
