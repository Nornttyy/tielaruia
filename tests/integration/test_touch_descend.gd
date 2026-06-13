# 手机创造模式下降: 左摇杆下推 → move_down → 玩家 _down_held() 为真 (创造模式据此下降)。
extends GutTest

const TouchJoystick = preload("res://scripts/ui/touch_joystick.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")


func after_each() -> void:
	# 清掉可能残留的 move_down 按下状态, 别影响别的测试
	if Input.is_action_pressed("move_down"):
		Input.action_release("move_down")


func test_move_down_action_exists() -> void:
	assert_true(InputMap.has_action("move_down"), "该有 move_down 输入动作 (键盘 S/↓ + 手机摇杆下推)")


func test_joystick_down_push_presses_move_down() -> void:
	var joy = TouchJoystick.new()
	add_child_autofree(joy)
	await wait_frames(1)
	# 下推摇杆 (knob.y 正 = 往下) 超过阈值
	joy._knob_offset = Vector2(0, TouchJoystick.DOWN_THRESH + 10.0)
	joy._apply_input()
	assert_true(Input.is_action_pressed("move_down"), "摇杆下推该按下 move_down")
	# 回中 → 松开
	joy._knob_offset = Vector2.ZERO
	joy._apply_input()
	assert_false(Input.is_action_pressed("move_down"), "摇杆回中该松开 move_down")


func test_joystick_aim_mode_ignores_down() -> void:
	# 右下瞄准摇杆 (aim_mode) 不该注入移动 → 下推不按 move_down
	var joy = TouchJoystick.new()
	joy.aim_mode = true
	add_child_autofree(joy)
	await wait_frames(1)
	joy._knob_offset = Vector2(0, TouchJoystick.DOWN_THRESH + 10.0)
	joy._apply_input()
	assert_false(Input.is_action_pressed("move_down"), "瞄准摇杆下推不该触发 move_down")


func test_player_down_held_reads_move_down() -> void:
	var p = PlayerScene.instantiate()
	add_child_autofree(p)
	await wait_frames(1)
	assert_false(p._down_held(), "没按下时 _down_held 为假")
	Input.action_press("move_down")
	assert_true(p._down_held(), "按下 move_down → _down_held 为真 (创造模式据此下降)")
	Input.action_release("move_down")
	assert_false(p._down_held(), "松开后 _down_held 回假")
