# 10 颗红心: 每颗 2 HP; cur >= (i+1)*2 满, cur == 2i+1 半, 否则空。
extends Control

const HEART_SIZE := 10
const HEART_SCALE := 2          # 渲染放大倍数 (20px 每颗)
const HEART_SPACING := 2
const NUM_HEARTS := 10
const PAD := 8

var _cur: int = 20
var _max: int = 20


func _ready() -> void:
	custom_minimum_size = Vector2(
		PAD * 2 + (HEART_SIZE * HEART_SCALE + HEART_SPACING) * NUM_HEARTS - HEART_SPACING,
		PAD * 2 + HEART_SIZE * HEART_SCALE
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
	var heart_px := HEART_SIZE * HEART_SCALE
	for i in NUM_HEARTS:
		var x: float = PAD + i * (heart_px + HEART_SPACING)
		var y: float = PAD
		var tex: ImageTexture
		var threshold: int = (i + 1) * 2  # 这颗心代表 HP 范围 (2i+1, 2i+2)
		if _cur >= threshold:
			tex = ArtCache.heart_full
		elif _cur == threshold - 1:
			tex = ArtCache.heart_half
		else:
			tex = ArtCache.heart_empty
		if tex != null:
			draw_texture_rect(tex, Rect2(x, y, heart_px, heart_px), false)
