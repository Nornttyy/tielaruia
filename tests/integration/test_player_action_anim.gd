# 挥击/放置的身体姿势已删 (用户要求): play_action_anim 现在是空操作 —
# 攻击/放方块时身体保持站/走/跳, 不切到 swing/place 姿势 (武器自己挥, 见 held_item)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot_player():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	return main.get_node("World").get_player()


func test_play_action_does_not_change_body_anim():
	var player = await _boot_player()
	player._hurt_timer = 0.0
	player.play_action_anim("swing", 0.3)   # 空操作, 不该切身体动画
	await wait_frames(1)
	var after: String = player.get_node("AnimatedSprite2D").animation
	assert_ne(after, "swing", "挥击不再切身体到 swing 姿势")
	assert_ne(after, "place", "放置不再切身体到 place 姿势")
	assert_eq(player._action_timer, 0.0, "动作计时不再启动 (姿势已删)")


func test_no_swing_place_animations_exist():
	var player = await _boot_player()
	var sf = player.get_node("AnimatedSprite2D").sprite_frames
	assert_false(sf.has_animation("swing"), "没有 swing 身体动画")
	assert_false(sf.has_animation("place"), "没有 place 身体动画")


func test_play_action_does_not_crash():
	var player = await _boot_player()
	player.play_action_anim("swing", 0.3)
	player.play_action_anim("place", 0.2)
	await wait_frames(2)
	pass_test("调用已删动作不崩")
