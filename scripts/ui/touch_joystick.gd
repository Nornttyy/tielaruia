# 触屏虚拟摇杆 (Control). 拖动 knob, 按方向注入 move_left/right/jump Input actions.
# 配合 TouchScreenButton 用 (它们管 primary/secondary).
# 死区 (DEADZONE) 内不触发, 避免误碰. 上推 ≥ JUMP_THRESH 触发 jump.
extends Control

const RADIUS := 70.0            # 摇杆底盘半径
const KNOB_R := 32.0            # 摇杆 knob 半径
const DEADZONE := 18.0          # 水平死区 (knob.x 绝对值 ≤ 这个不触发左右)
const JUMP_THRESH := 35.0       # 垂直上推阈值 (knob.y ≤ -此值触发 jump)

var _knob_offset: Vector2 = Vector2.ZERO   # knob 相对 center 的偏移
var _touch_active: bool = false
var _pressed_actions: Dictionary = {}      # action → true (跟踪状态防重复 press)


func _ready() -> void:
	custom_minimum_size = Vector2(RADIUS * 2.0, RADIUS * 2.0)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touch_active = true
			_update_knob(t.position)
		else:
			_touch_active = false
			_knob_offset = Vector2.ZERO
			_release_all()
			queue_redraw()
		queue_redraw()
		accept_event()
	elif event is InputEventScreenDrag and _touch_active:
		var d := event as InputEventScreenDrag
		_update_knob(d.position)
		queue_redraw()
		accept_event()
	# 兼容鼠标 (PC 测试触屏 UI 用)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_touch_active = true
				_update_knob(mb.position)
			else:
				_touch_active = false
				_knob_offset = Vector2.ZERO
				_release_all()
			queue_redraw()
			accept_event()
	elif event is InputEventMouseMotion and _touch_active:
		_update_knob((event as InputEventMouseMotion).position)
		queue_redraw()


func _update_knob(local_pos: Vector2) -> void:
	var offset: Vector2 = local_pos - Vector2(RADIUS, RADIUS)
	if offset.length() > RADIUS:
		offset = offset.normalized() * RADIUS
	_knob_offset = offset
	_apply_input()


func _apply_input() -> void:
	# 左右
	if _knob_offset.x < -DEADZONE:
		_press("move_left")
		_release("move_right")
	elif _knob_offset.x > DEADZONE:
		_press("move_right")
		_release("move_left")
	else:
		_release("move_left")
		_release("move_right")
	# 跳: 上推到 JUMP_THRESH 触发
	if _knob_offset.y < -JUMP_THRESH:
		_press("jump")
	else:
		_release("jump")


func _press(action: String) -> void:
	if _pressed_actions.get(action, false):
		return
	_pressed_actions[action] = true
	Input.action_press(action)


func _release(action: String) -> void:
	if not _pressed_actions.get(action, false):
		return
	_pressed_actions[action] = false
	Input.action_release(action)


func _release_all() -> void:
	for action in _pressed_actions.keys():
		if _pressed_actions[action]:
			Input.action_release(action)
			_pressed_actions[action] = false


func _draw() -> void:
	var center: Vector2 = Vector2(RADIUS, RADIUS)
	# 底盘 (半透明白圈)
	draw_circle(center, RADIUS, Color(1, 1, 1, 0.18))
	draw_arc(center, RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.45), 2.0)
	# knob
	var knob_color: Color = Color(1, 1, 1, 0.7) if _touch_active else Color(1, 1, 1, 0.45)
	draw_circle(center + _knob_offset, KNOB_R, knob_color)
