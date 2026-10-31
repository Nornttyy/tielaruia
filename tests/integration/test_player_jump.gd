# 使用明确的平地和 12px 台阶，避免旧测试把 16px 坐标用于 12px 世界。
extends "res://tests/integration/test_classic_movement.gd"

func _step() -> void:
	var body := StaticBody2D.new()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240, 12)
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector2(144, 94) # 台阶从 x=24 开始，顶面 y=88，比地面高 12px。
	add_child_autofree(body)

func test_jump_clears_one_tile_block_in_front():
	_step()
	Input.action_press("jump")
	Input.action_press("move_right")
	for i in 70:
		if i == 20:
			Input.action_release("jump")
		await get_tree().physics_frame
	assert_gt(player.position.x, 24.0, "应越过台阶前沿")
	assert_almost_eq(player.position.y, 88.0, 0.1, "应落在高一格的台阶上")
	assert_true(player.is_on_floor())

func test_no_auto_step_one_tile_player_stuck():
	_step()
	Input.action_press("move_right")
	for i in 45:
		await get_tree().physics_frame
	assert_lt(player.position.x, 24.0)
	assert_almost_eq(player.position.y, 100.0, 0.1)
