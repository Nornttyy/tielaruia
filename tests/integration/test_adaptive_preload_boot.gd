# 护栏: 同步路径 (boot_to_game / 测试) 不测速、保持默认半径 2 → 测试不被拖慢/多载.
# 测速+大预载只该在异步加载界面路径(真实新游戏)发生.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_sync_boot_keeps_default_radius():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(10)
	var world = main.get_node("World")
	assert_eq(world.chunk_manager.view_radius, 2, "同步路径不动半径, 保持默认 2 (否则测试会变慢+多载)")


func test_async_new_game_preloads_big():
	# 异步新游戏路径 (走 _run_async_load, 不是 boot_to_game): 真测速 → 调大半径 → 预载一大片
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main._start_game(777)
	# 轮询等预载块跑过 (基准总会多载 8 个 chunk ±3..6 → loaded_count 必 >5, 不管机器快慢).
	# 注: 半径本身按机器速度变 (慢机=MIN 2), 所以别断言半径>2, 那是环境相关; 断言"预载发生过"才稳.
	var tries := 0
	while tries < 300:
		var w = main.get_node_or_null("World")
		if w != null and w.chunk_manager != null and w.chunk_manager.loaded_count() > 5:
			break
		await wait_frames(1)
		tries += 1
	var world = main.get_node_or_null("World")
	assert_not_null(world, "异步加载该建出 World")
	assert_gt(world.chunk_manager.loaded_count(), 5, "测速+预载块跑过了 (载了远多于默认 5 个 chunk)")
