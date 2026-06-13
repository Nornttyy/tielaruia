# 重生清零速度: 防摔死(高速下坠)/被炸飞(上抛)的残留速度带进复活 → 乱飞/穿地/落不到地。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_respawn_zeroes_velocity() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var w = main.get_node("World")
	var player = w.get_player()
	# 假装摔死那一刻的高速下坠 (坠落伤害致死场景)
	player.velocity = Vector2(40.0, 950.0)
	w.respawn_player()
	assert_eq(player.velocity, Vector2.ZERO, "重生该把速度清零 (否则带速度乱飞/穿地/落不到地)")


func test_respawn_upward_velocity_also_cleared() -> void:
	# 被炸飞/击退致死 → 上抛速度也别带进复活 (否则重生飘起来落不下)
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var w = main.get_node("World")
	var player = w.get_player()
	player.velocity = Vector2(0.0, -600.0)
	w.respawn_player()
	assert_eq(player.velocity.y, 0.0, "上抛速度也该清零")
