# 验证 PlayerHunger 在游戏运行时 _physics_process 真的被调用 (而不是只在单元测试里手调)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_hunger_actually_depletes_in_game() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: CharacterBody2D = world.get_player()
	var hunger: Node = player.get_node_or_null("PlayerHunger")
	assert_not_null(hunger, "PlayerHunger 节点存在")
	var before: float = hunger.current
	# 跑 120 帧 = 2 秒. 2s * 0.167/s = ~0.33 单位. 整数仍然 99.
	# 跑足够多帧让 current 从 100.0 降到至少 99.0 以下
	await wait_frames(360)  # 6 秒, 应降到 99 (drop ~1.0)
	var after: float = hunger.current
	assert_lt(after, before, "hunger.current 应下降 (before=%.3f after=%.3f)" % [before, after])
	assert_lt(after, 100.0, "至少 6 秒后 hunger.current 应 < 100 (实际 %.3f)" % after)
