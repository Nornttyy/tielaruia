extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_main_runs_60_seconds_no_crash():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	# 3600 帧 ≈ 60s @ 60fps
	await wait_frames(3600)
	assert_not_null(main.get_node_or_null("World"))
	var player = main.get_node("World").get_player()
	assert_not_null(player)
	# 玩家位置仍在合理范围
	assert_lt(player.global_position.y, 256 * 16.0, "玩家未掉出世界")
