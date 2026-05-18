extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _effects_count() -> int:
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	return 0 if root == null else root.get_child_count()


func test_player_walking_emits_puffs():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	# 走 0.5s
	Input.action_press("move_right")
	await wait_frames(40)
	Input.action_release("move_right")
	# 再走一段，紧跟 frame 内 count ≥ 1 大概率能见到
	Input.action_press("move_right")
	await wait_frames(20)
	var observed_any := false
	for _i in 30:
		if _effects_count() > 0:
			observed_any = true
			break
		await wait_frames(1)
	Input.action_release("move_right")
	assert_true(observed_any, "走路期间应至少观察到 1 个粒子")
