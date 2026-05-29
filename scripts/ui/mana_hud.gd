# 魔力 HUD: Terraria 风 5 角星, 竖排. 每颗 = 20 mana. 100 满 = 5 星, max 上限增长就多星.
# 用户改: 横排 → 竖排 (一列 10 颗, 超出加新列).
# 蓝紫色调 (跟魔晶/法杖呼应).
extends Control

const STAR_SLOT_PX := 24       # 一颗星占的边框正方形大小
const STAR_SPACING := 4
const STARS_PER_COL := 10      # 一列最多 10 颗, 超出右侧加新列
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
	# 竖排: label 跨整个 container 宽度顶部, 居中对齐数字 "100 / 100"
	_mana_label = Label.new()
	_mana_label.add_theme_font_size_override("font_size", TEXT_FONT_SIZE)
	_mana_label.add_theme_color_override("font_color", Color(0.93, 0.93, 1.0))
	_mana_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	_mana_label.add_theme_constant_override("shadow_offset_x", 1)
	_mana_label.add_theme_constant_override("shadow_offset_y", 1)
	_mana_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mana_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_mana_label.offset_left = 0.0
	_mana_label.offset_right = 0.0
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
		_mana_label.text = "魔 %d / %d" % [_cur, _max]


func _update_min_size() -> void:
	var num_stars: int = _star_count()
	var cols: int = ceili(float(num_stars) / float(STARS_PER_COL))
	var rows_first_col: int = min(num_stars, STARS_PER_COL)
	# 竖排: 宽 = 列数 × slot, 高 = 一列里星数 × slot. 上面留 TEXT_HEIGHT 给 label.
	custom_minimum_size = Vector2(
		PAD * 2 + (STAR_SLOT_PX + STAR_SPACING) * cols - STAR_SPACING,
		PAD * 2 + TEXT_HEIGHT + (STAR_SLOT_PX + STAR_SPACING) * rows_first_col - STAR_SPACING
	)


func _star_count() -> int:
	return ceili(float(_max) / float(MANA_PER_STAR))


func _draw() -> void:
	var num_stars: int = _star_count()
	# 竖排: i / STARS_PER_COL = 列号 (从左数), i % STARS_PER_COL = 列内行号 (从上数).
	# 第 1 列 = i 0-9, 第 2 列 = i 10-19 ...
	# 顶部留 TEXT_HEIGHT 让数字 label 不撞星.
	for i in num_stars:
		var col: int = i / STARS_PER_COL
		var row: int = i % STARS_PER_COL
		var cx: float = PAD + col * (STAR_SLOT_PX + STAR_SPACING) + STAR_SLOT_PX * 0.5
		var cy: float = PAD + TEXT_HEIGHT + row * (STAR_SLOT_PX + STAR_SPACING) + STAR_SLOT_PX * 0.5
		var center := Vector2(cx, cy)
		# 边框
		_draw_star(center, STAR_SLOT_PX * BORDER_SIZE_RATIO, COLOR_BORDER)
		# 空星底
		_draw_star(center, STAR_SLOT_PX * EMPTY_SIZE_RATIO, COLOR_EMPTY)
		# 蓝紫填充, 按 fraction 缩 (像素 grid)
		var fill_mana: int = clamp(_cur - i * MANA_PER_STAR, 0, MANA_PER_STAR)
		if fill_mana > 0:
			var frac: float = float(fill_mana) / float(MANA_PER_STAR)
			var fill_size: float = STAR_SLOT_PX * FILL_MAX_RATIO * frac
			fill_size = max(4.0, fill_size)
			_draw_star(center, fill_size, COLOR_FILL)
			# 像素风去掉抗锯齿圆形高光


# 8x8 像素星 pattern. X = 填色, . = 透明.
# 4 点罗盘星形状 — 上下左右各 1 点突出 + 菱形中央. 8x8 网格里 5 点星会
# 卡得很丑 (底部分腿成奇怪嘴), 罗盘星干净对称, 像素艺术辨识度好.
const STAR_PIXELS := [
	"....X...",
	"....X...",
	"...XXX..",
	"XXXXXXXX",
	"XXXXXXXX",
	"...XXX..",
	"....X...",
	"....X...",
]


# 像素星: 每个 cell 画 draw_rect. size = 星总宽, cell = size/8.
# 跟其他方块美术一致 chunky 像素风, 不抗锯齿.
func _draw_star(center: Vector2, size: float, color: Color) -> void:
	if size <= 0.0:
		return
	var cell: float = size / 8.0
	var origin_x: float = center.x - size * 0.5
	var origin_y: float = center.y - size * 0.5
	var cell_draw: float = cell + 0.5
	for row in 8:
		var s: String = STAR_PIXELS[row]
		for col in 8:
			if s[col] == "X":
				draw_rect(Rect2(origin_x + col * cell, origin_y + row * cell, cell_draw, cell_draw), color)
