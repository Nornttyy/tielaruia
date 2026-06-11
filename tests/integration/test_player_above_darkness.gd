# 回归: 角色永远明亮 (用户要求) — 玩家 z 高于光照层(DarknessLayer), 黑暗盖不到 → 眼白不变灰.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_player_drawn_above_darkness() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_gt(player.z_index, 10, "玩家 z 该高于光照层(z=10) → 永远明亮")
	var darkness = world.get_node_or_null("DarknessLayer")
	if darkness != null:
		assert_gt(player.z_index, darkness.z_index, "玩家画在光照层之上")
