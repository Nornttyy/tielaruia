# Buff HUD: 屏幕上一排 buff 图标 + 倒计时条. 绑 PlayerBuffs, 有 buff 时每帧重画.
# 图标 ≥ 20px (用户要求特效够明显). 4 种: speed/jump/mining/regen.
extends Control

const ICON_PX := 22
const ICON_GAP := 6
const PAD := 6
const BAR_H := 4

# 每种 buff 的底色 (暖色, 一眼区分)
const KIND_COLOR := {
	"speed":  Color8(90, 200, 120),    # 绿: 跑快
	"jump":   Color8(120, 170, 255),   # 蓝: 跳高
	"mining": Color8(230, 180, 70),    # 橙黄: 挖快
	"regen":  Color8(230, 90, 110),    # 红: 回血
}
# 8x8 像素字形 (X=画, .=透明)
const KIND_GLYPH := {
	"speed":  ["........", "..XX.X..", ".XXXXX..", "XXXX.X..", ".XXXXX..", "..XX.X..", "........", "........"],
	"jump":   ["...XX...", "..XXXX..", ".XX..XX.", "X.X..X.X", "...XX...", "...XX...", "..XXXX..", "........"],
	"mining": [".....XX.", "....XXX.", "...XXX..", "..XXX.X.", ".XXX..X.", "XXX.....", "X.......", "........"],
	"regen":  [".XX..XX.", "XXXXXXXX", "XXXXXXXX", ".XXXXXX.", "..XXXX..", "...XX...", "........", "........"],
}

var _buffs: Node = null


func bind(buffs_node: Node) -> void:
	_buffs = buffs_node
	if _buffs != null and _buffs.has_signal("buffs_changed"):
		_buffs.buffs_changed.connect(func(): queue_redraw())
	queue_redraw()


func _active_kinds() -> Array:
	if _buffs == null:
		return []
	return _buffs.active_kinds()


func _process(_delta: float) -> void:
	# 有 buff 时每帧重画 (倒计时条平滑). 没 buff 不画, 省开销.
	if _buffs != null and not _buffs.active_kinds().is_empty():
		queue_redraw()


func _draw() -> void:
	if _buffs == null:
		return
	var kinds: Array = _buffs.active_kinds()
	var x: float = PAD
	for kind in kinds:
		var col: Color = KIND_COLOR.get(kind, Color.WHITE)
		# 圆角底块 + 黑描边
		draw_rect(Rect2(x, PAD, ICON_PX, ICON_PX), col)
		draw_rect(Rect2(x, PAD, ICON_PX, ICON_PX), Color(0, 0, 0, 0.6), false, 2.0)
		# 像素字形
		var glyph: Array = KIND_GLYPH.get(kind, [])
		if glyph.size() == 8:
			var cell: float = ICON_PX / 8.0
			for row in 8:
				var s: String = glyph[row]
				for c in 8:
					if s[c] == "X":
						draw_rect(Rect2(x + c * cell, PAD + row * cell, cell + 0.5, cell + 0.5), Color(0.1, 0.1, 0.1))
		# 倒计时条 (底部, 随剩余缩短)
		var frac: float = _buffs.remaining_frac(kind)
		draw_rect(Rect2(x, PAD + ICON_PX + 1, ICON_PX, BAR_H), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(x, PAD + ICON_PX + 1, ICON_PX * frac, BAR_H), col)
		x += ICON_PX + ICON_GAP
