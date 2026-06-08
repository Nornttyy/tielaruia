# 复现: 建东西+创造 → 存档 → 走"继续"读档流程 → 建造/位置/创造模式都该还原.
# 用户报: 重进存档 地图进度消失 / 出生地底 / 创造消失 / 拿不了方块.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const WORLD := "zz_repro_continue"


func _free_main(m: Node) -> void:
	m.queue_free()


# 等异步 _run_async_load 跑完: World + player 就绪 + 给 _apply_save_data 留足帧.
func _await_world(main: Node, max_frames: int) -> Node:
	for i in range(max_frames):
		await wait_frames(1)
		var w = main.get_node_or_null("World")
		if w != null and w.has_method("get_player") and w.get_player() != null:
			return w
	return main.get_node_or_null("World")


func test_continue_restores_build_spawn_creative() -> void:
	# 删旧档
	SaveManager.delete_save_by_name(WORLD)
	# --- Phase 1: 建世界(创造) + 建一个方块 + 存 ---
	var main1 = MainScene.instantiate()
	add_child_autofree(main1)
	main1.boot_to_game(777)
	await wait_frames(8)
	var w1 = main1.get_node("World")
	var player1 = w1.get_player()
	for _i in range(60):
		if player1.is_on_floor():
			break
		await wait_frames(1)
	GameSettings.creative_mode = true
	GameSettings.current_world_name = WORLD
	# 在玩家右边 +3 格放个独特方块 (记下来验证还原)
	var ptx: int = int(floor(player1.global_position.x / 12.0))
	var pty: int = int(floor(player1.global_position.y / 12.0))
	var btx: int = ptx + 3
	var bty: int = pty
	w1._set_tile(btx, bty, Tiles.STONE)
	await wait_frames(2)
	assert_eq(w1.chunk_manager.get_tile(btx, bty), Tiles.STONE, "前置: 方块放好了")
	# 存档
	SaveManager.save(main1)
	await wait_frames(2)
	main1.queue_free()
	await wait_frames(3)

	# --- 验证存档内容 (save 自身对不对) ---
	var data = SaveManager.load_save_by_name(WORLD)
	assert_not_null(data, "存档能读出来")
	assert_true(bool(data.creative_mode), "存档里 creative_mode 应 = true")
	assert_gt(data.chunk_deltas.size(), 0, "存档里应有方块改动 (chunk_deltas)")

	# --- Phase 2: 走"继续"读档 (异步流程) ---
	var main2 = MainScene.instantiate()
	add_child_autofree(main2)
	main2._continue_game(data)
	var w2 = await _await_world(main2, 240)
	assert_not_null(w2, "继续后世界建好")
	await wait_frames(30)   # 给 _apply_save_data 留足 (LoadingScreen 淡出后才 apply)
	# 1) 创造模式还原?
	assert_true(GameSettings.creative_mode, "读档后应仍是创造模式 (否则拿不了方块)")
	# 2) 建造还原?
	w2.chunk_manager.ensure_loaded(_chunk_x(btx))
	await wait_frames(3)
	assert_eq(w2.chunk_manager.get_tile(btx, bty), Tiles.STONE, "读档后我放的方块该还在 (地图进度)")
	# 3) 没出生在地底? (玩家不在实心 tile 里)
	var p2 = w2.get_player()
	var p2tx: int = int(floor(p2.global_position.x / 12.0))
	var p2ty: int = int(floor(p2.global_position.y / 12.0))
	var here: int = w2.chunk_manager.get_tile(p2tx, p2ty)
	assert_false(Tiles.is_solid(here), "玩家不该卡在实心方块里 (出生地底)")
	SaveManager.delete_save_by_name(WORLD)


func _chunk_x(world_x: int) -> int:
	return int(floor(float(world_x) / 64.0))
