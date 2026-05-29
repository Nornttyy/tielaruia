# 怪物头顶血条 (通用 Node2D, 挂在 enemy 子节点).
# 自动从 parent.current_health / parent.max_health 读取, 满血时隐藏.
# 受伤后显示 FADE_DELAY 秒, 然后淡掉 (减少满血时的视觉杂乱).
extends Node2D

const WIDTH := 18.0           # 血条总宽 (px)
const HEIGHT := 2.5           # 血条高
const Y_OFFSET := -22.0       # 在 sprite 头顶 (相对 parent 原点)
const FADE_DELAY := 4.0       # 受伤 4s 后开始淡; 再过 1s 完全消
const FADE_DURATION := 1.0

const BG_COLOR := Color8(8, 6, 12, 220)        # 几乎黑的底
const BORDER_COLOR := Color8(8, 6, 12, 255)
const FILL_FULL := Color8(120, 220, 80)        # 满血绿
const FILL_MID := Color8(245, 200, 70)         # 中血黄
const FILL_LOW := Color8(220, 60, 50)          # 残血红

var _cur: int = 1
var _max: int = 1
var _show_t: float = 0.0      # 受伤后保持显示倒计时 (0 = 已隐藏)


func _ready() -> void:
	z_index = 5
	position = Vector2(0, Y_OFFSET)
	# 先取一次 parent 血量 (后续 _process 监听变化)
	_sync_from_parent()


func _process(delta: float) -> void:
	var changed: bool = _sync_from_parent()
	if changed:
		# 血量变了 → 重置显示倒计时 + 重画
		_show_t = FADE_DELAY + FADE_DURATION
		queue_redraw()
	elif _show_t > 0.0:
		_show_t = max(0.0, _show_t - delta)
		# 进入淡出阶段 (剩 FADE_DURATION 秒) 才需要每帧重画 alpha
		if _show_t <= FADE_DURATION:
			queue_redraw()


# 从 parent 节点拉血量. 返 true 表示有变化.
func _sync_from_parent() -> bool:
	var parent: Node = get_parent()
	if parent == null:
		return false
	var c: int = _cur
	var m: int = _max
	if "current_health" in parent:
		c = int(parent.current_health)
	if "max_health" in parent:
		m = int(parent.max_health)
	if c == _cur and m == _max:
		return false
	_cur = c
	_max = m
	return true


func _draw() -> void:
	if _max <= 0 or _show_t <= 0.0:
		return
	# 满血时不显示 (受伤倒计时还在内可显, 让玩家瞄一眼"我刚把它打满了"也合理)
	if _cur >= _max:
		return
	# 淡出: _show_t < FADE_DURATION 时 alpha 线性减
	var alpha: float = 1.0
	if _show_t < FADE_DURATION:
		alpha = _show_t / FADE_DURATION
	var w: float = WIDTH
	var h: float = HEIGHT
	var x: float = -w * 0.5
	var y: float = 0.0
	# 黑底 + 边框 (1 px)
	var bg: Color = BG_COLOR
	bg.a *= alpha
	draw_rect(Rect2(x - 1, y - 1, w + 2, h + 2), bg, true)
	# 填充: 按比例选颜色 (绿 → 黄 → 红)
	var frac: float = clamp(float(_cur) / float(_max), 0.0, 1.0)
	var fill_w: float = w * frac
	var fill_color: Color
	if frac > 0.5:
		fill_color = FILL_FULL.lerp(FILL_MID, (1.0 - frac) * 2.0)
	else:
		fill_color = FILL_MID.lerp(FILL_LOW, (0.5 - frac) * 2.0)
	fill_color.a *= alpha
	draw_rect(Rect2(x, y, fill_w, h), fill_color, true)
