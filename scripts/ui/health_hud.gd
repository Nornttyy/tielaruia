# 血条 HUD: 左上角红条 + 数字 "HP/MAX"。
# 通过 hud.gd 的 bind_player 绑定 PlayerHealth.health_changed 信号。
extends Control

const BAR_WIDTH := 160
const BAR_HEIGHT := 16
const BG_COLOR := Color(0.15, 0.05, 0.05, 0.85)
const FILL_COLOR := Color(0.85, 0.15, 0.18)
const FILL_LOW_COLOR := Color(0.65, 0.55, 0.15)  # < 30% 时偏黄警告
const BORDER_COLOR := Color(0.0, 0.0, 0.0, 0.9)

var _cur: int = 20
var _max: int = 20

@onready var _label: Label = $Label


func _ready() -> void:
	custom_minimum_size = Vector2(BAR_WIDTH + 8, BAR_HEIGHT + 8)


func bind(health_node: Node) -> void:
	if health_node == null:
		return
	if health_node.has_signal("health_changed"):
		health_node.health_changed.connect(_on_changed)
	_on_changed(health_node.current_health, health_node.MAX_HEALTH)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	_label.text = "%d / %d" % [cur, maximum]
	queue_redraw()


func _draw() -> void:
	var bar_rect := Rect2(4, 4, BAR_WIDTH, BAR_HEIGHT)
	# 背景
	draw_rect(bar_rect, BG_COLOR)
	# 填充
	if _max > 0 and _cur > 0:
		var ratio: float = float(_cur) / float(_max)
		var fill := Rect2(bar_rect.position, Vector2(BAR_WIDTH * ratio, BAR_HEIGHT))
		var col: Color = FILL_LOW_COLOR if ratio < 0.3 else FILL_COLOR
		draw_rect(fill, col)
	# 边框
	draw_rect(bar_rect, BORDER_COLOR, false, 1.0)
