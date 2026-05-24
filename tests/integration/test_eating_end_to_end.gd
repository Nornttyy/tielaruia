# 端到端: 玩家拿苹果 + 饱食度低 + 按住右键 → 真的吃掉 + 饱食度回升.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_eating_apple_restores_hunger() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = world.get_player()
	var hunger: Node = player.get_node("PlayerHunger")
	var pinv: Node = player.get_node("PlayerInventory")
	var action: Node = player.get_node("PlayerAction")

	# 1. 给玩家放 1 个 apple 到 hotbar 槽 0
	pinv.pickup("apple", 1)
	pinv.set_hotbar_selection(0)
	# 2. 把饱食度强行降到 50
	hunger.current = 50.0
	hunger.emit_state()
	var before: float = hunger.current
	# 3. 模拟按住右键
	action.set_secondary_held_for_test(true)
	# 4. 等 2.2 秒 (EAT_DURATION_SEC = 2.0)
	await wait_frames(135)
	# 5. 释放
	action.set_secondary_held_for_test(false)
	await wait_frames(2)

	var after: float = hunger.current
	# apple food_fill = 25, 应该从 50 → 75
	assert_gt(after, before, "饱食度应回升 (before=%.1f after=%.1f)" % [before, after])
	assert_gte(int(after), 70, "回升至少 ~25 单位 (apple food_fill)")
	# 苹果应被消耗
	var slot = pinv.current_hotbar_slot()
	if slot != null:
		assert_lt(slot.count, 1, "apple count 应减少 (was 1)")
