# 玩家动作姿势: 挥击/放置时身体短暂做动作 (不锁移动); 受击优先, 不被打断。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot_player():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	return main.get_node("World").get_player()


func test_play_action_sets_anim():
	var player = await _boot_player()
	player._hurt_timer = 0.0
	player.play_action_anim("swing", 0.3)
	assert_gt(player._action_timer, 0.0, "动作计时启动")
	assert_eq(player._action_anim, "swing", "记录动作 = swing")
	assert_eq(player.get_node("AnimatedSprite2D").animation, "swing", "立刻播挥击姿势")


func test_hurt_blocks_action():
	var player = await _boot_player()
	player._hurt_timer = 0.4   # 正在受击
	player.play_action_anim("swing", 0.3)
	assert_eq(player._action_timer, 0.0, "受击期间挥击不打断受击 (动作不启动)")


func test_action_timer_counts_down():
	var player = await _boot_player()
	player._hurt_timer = 0.0
	player.play_action_anim("place", 0.2)
	var t0: float = player._action_timer
	await wait_frames(8)
	assert_lt(player._action_timer, t0, "动作计时会倒数 (到时回站/走)")
