extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_runs_600_frames_no_crash_and_effects_bounded():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(600)
	assert_not_null(main.get_node_or_null("World"))
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	assert_not_null(root, "effects_root 组节点应存在")
	# 期望粒子数 ≤ 200（理论瞬时上限：6 chip + 6 dust + 几 walk puff，但都很快自删）
	assert_lt(root.get_child_count(), 200, "粒子数不应失控")


func test_player_moving_60_frames():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	Input.action_press("move_right")
	await wait_frames(60)
	Input.action_release("move_right")
	# 没崩就行
	assert_not_null(main.get_node_or_null("World"))
