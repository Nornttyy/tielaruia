# 10 颗鸡腿: 每颗 10 点饱食; cur >= (i+1)*10 满, cur in [10i+5, 10i+9] 半, 否则空。
# 饿坏 (cur < HUNGRY_THRESHOLD) 时整条左右轻微抖动。
extends Control

const DRUM_SIZE := 10
const DRUM_SCALE := 2          # 渲染放大倍数 (20px 每颗)
const DRUM_SPACING := 2
const NUM_DRUMS := 10
const PAD := 8
const HUNGRY_THRESHOLD := 30
const SHAKE_INTERVAL := 0.5
const SHAKE_OFFSET_PX := 1

var _cur: int = 100
var _max: int = 100
var _shake_t: float = 0.0
var _shake_x: int = 0


func _ready() -> void:
	custom_minimum_size = Vector2(
		PAD * 2 + (DRUM_SIZE * DRUM_SCALE + DRUM_SPACING) * NUM_DRUMS - DRUM_SPACING,
		PAD * 2 + DRUM_SIZE * DRUM_SCALE
	)
	set_process(true)


func _process(delta: float) -> void:
	if _cur < HUNGRY_THRESHOLD:
		_shake_t += delta
		if _shake_t >= SHAKE_INTERVAL:
			_shake_t -= SHAKE_INTERVAL
			_shake_x = -_shake_x if _shake_x != 0 else SHAKE_OFFSET_PX
			queue_redraw()
	elif _shake_x != 0 or _shake_t != 0.0:
		_shake_x = 0
		_shake_t = 0.0
		queue_redraw()


func bind(hunger_node: Node) -> void:
	if hunger_node == null:
		return
	if hunger_node.has_signal("hunger_changed"):
		hunger_node.hunger_changed.connect(_on_changed)
	if hunger_node.has_method("emit_state"):
		hunger_node.emit_state()
	else:
		_on_changed(int(hunger_node.current), hunger_node.MAX)


func _on_changed(cur: int, maximum: int) -> void:
	_cur = cur
	_max = maximum
	queue_redraw()


func _draw() -> void:
	var drum_px := DRUM_SIZE * DRUM_SCALE
	for i in NUM_DRUMS:
		var x: float = PAD + i * (drum_px + DRUM_SPACING) + _shake_x
		var y: float = PAD
		var tex: ImageTexture
		var threshold: int = (i + 1) * 10
		if _cur >= threshold:
			tex = ArtCache.drumstick_full
		elif _cur >= threshold - 5:
			tex = ArtCache.drumstick_half
		else:
			tex = ArtCache.drumstick_empty
		if tex != null:
			draw_texture_rect(tex, Rect2(x, y, drum_px, drum_px), false)
