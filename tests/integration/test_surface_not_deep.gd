# 回归: 地面不该被误判成地下 → 不该刷出红/紫史莱姆.
# 老 bug: _surf_at_x 对没加载的列返回 0, 于是 "玩家 y(≈115) - 0 = 115 >= 8" → _player_is_deep 误判真,
# 触发按深度配色的地下刷怪, depth = cand_y - 0 算成上百格 → 配出红/紫史莱姆刷在地面.
# 修法: _surf_at_x 改用区块生成时存的 surfaces, 没加载的列返回 -1, 调用方按"不深/跳过"处理.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_surface_player_not_deep_and_unloaded_col_unknown() -> void:
	var main = MainScene.instantiate()
	add_child(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	# 让玩家落到地面
	for _i in range(60):
		if player.is_on_floor():
			break
		await wait_frames(1)

	# 1) 玩家站地表 → 绝不该被判成"在地下"
	assert_false(world._player_is_deep(), "玩家站地面时 _player_is_deep 必须为假 (否则会刷地下紫史莱姆)")

	# 2) 已加载列: _surf_at_x 给出合理地表 (>=0, 在地表带内)
	var px: int = int(floor(player.global_position.x / 12.0))
	var surf: int = world._surf_at_x(px)
	assert_gte(surf, 0, "玩家所在列地表应已知 (>=0)")
	assert_lt(surf, 200, "地表 y 应在地表带内, 不该是深渊深度")

	# 3) 远处没加载的列: 返回 -1 (未知), 不再是会引发误判的 0
	var far_x: int = px + 100000
	assert_eq(world._surf_at_x(far_x), -1, "没加载的远列地表应返回 -1 (未知), 不是 0")

	main.queue_free()
	await wait_frames(2)
