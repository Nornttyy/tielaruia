# 回归: 睡觉时 PlayerAction 子节点也要停 (否则能挖/放方块 = bug2, 且对床再点重复 sleep 永不醒 = bug1).
# 下床后恢复. 根因: player.set_physics_process(false) 不会停子节点 PlayerAction。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func after_each() -> void:
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 1.0


func test_sleep_disables_player_action_and_wake_restores() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	var pa: Node = player.get_node("PlayerAction")

	assert_true(pa.is_physics_processing(), "睡前 PlayerAction 该在跑")
	world.sleep_in_bed(Vector2i(5, 5))
	assert_true(world._sleeping, "在睡觉")
	assert_false(pa.is_physics_processing(), "睡觉时 PlayerAction 该停 (不能挖/放方块, 也不会重复触发 sleep)")

	world._wake_up()
	assert_false(world._sleeping, "醒了")
	assert_true(pa.is_physics_processing(), "下床后 PlayerAction 恢复 (又能挖/放/用)")
