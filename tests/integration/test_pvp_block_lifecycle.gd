# 对战房方块去留 (用户最终要求):
#   - 切到"别的"模式 (换房) → 重置干净竞技场 (防带本地方块进新房成幽灵块, 用户报"模式又同步")
#   - 选同一模式 / 换武器 (不换房) → 保留搭的方块
#   - 赢了重开 / 房间没别人满 1 分钟 → 清场
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const PvpModePanel = preload("res://scripts/ui/pvp_mode_panel.gd")
const PvpScoreboard = preload("res://scripts/ui/pvp_scoreboard.gd")
const PvpArena = preload("res://scripts/world/pvp_arena.gd")


func _boot_pvp_with_block():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	NetworkManager.room_mode = "pvp"
	PvpArena.build(world)
	var tx: int = PvpArena.CENTER_X
	var ty: int = PvpArena.FLOOR_Y - 10
	world._set_tile(tx, ty, Tiles.DIRT)
	world.chunk_manager.mark_pvp_placed(Vector2i(0, 0))   # 标记"搭过方块" (让空房计时认为有东西可清)
	return {"world": world, "tx": tx, "ty": ty}


# 切到"别的"模式 = 换房 → 重置干净竞技场, 清掉本地方块 (防带去新房成"幽灵块", 用户报"模式又同步")
func test_pick_different_mode_resets_blocks():
	var prev_mode = NetworkManager.room_mode
	var prev_pub = NetworkManager.in_public_room
	var ctx = await _boot_pvp_with_block()
	var world = ctx.world
	assert_eq(world.chunk_manager.get_tile(ctx.tx, ctx.ty), Tiles.DIRT, "前置: 搭了个 dirt")
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	NetworkManager.in_public_room = true
	panel._current_tag = "PVP"          # 当前经典房
	panel._pick_mode("magic")           # 切到魔法 (不同 tag → reroute + 重置)
	await wait_frames(1)
	assert_ne(world.chunk_manager.get_tile(ctx.tx, ctx.ty), Tiles.DIRT, "切到别的模式该重置成干净竞技场 (方块清掉)")
	NetworkManager.room_mode = prev_mode
	NetworkManager.in_public_room = prev_pub


# 选"同一个"模式 (没换房) → 不重置, 方块留着
func test_pick_same_mode_keeps_blocks():
	var prev_mode = NetworkManager.room_mode
	var prev_pub = NetworkManager.in_public_room
	var ctx = await _boot_pvp_with_block()
	var world = ctx.world
	var panel = PvpModePanel.new()
	add_child_autofree(panel)
	await wait_frames(1)
	NetworkManager.in_public_room = true
	panel._current_tag = "PVP-MAGIC"    # 已在魔法房
	panel._pick_mode("magic")           # 再选魔法 = 同 tag, 不 reroute 不重置
	await wait_frames(1)
	assert_eq(world.chunk_manager.get_tile(ctx.tx, ctx.ty), Tiles.DIRT, "同模式不换房 → 方块留着")
	NetworkManager.room_mode = prev_mode
	NetworkManager.in_public_room = prev_pub


# 清场 (赢了/空房) → 方块清掉
func test_clean_arena_clears_blocks():
	var prev_mode = NetworkManager.room_mode
	var ctx = await _boot_pvp_with_block()
	var world = ctx.world
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	sb._clean_arena()
	assert_ne(world.chunk_manager.get_tile(ctx.tx, ctx.ty), Tiles.DIRT, "清场后方块该没了")
	NetworkManager.room_mode = prev_mode


# 房间没别人 + 搭过方块 → 满 1 分钟自动清场
func test_empty_room_resets_after_timeout():
	var prev_mode = NetworkManager.room_mode
	var ctx = await _boot_pvp_with_block()
	var world = ctx.world
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	# 一次性灌入超过阈值的 delta → 触发清场 (没有远程玩家 = 独自一人)
	sb._tick_empty_reset(PvpScoreboard.EMPTY_RESET_SEC + 1.0, true)
	assert_ne(world.chunk_manager.get_tile(ctx.tx, ctx.ty), Tiles.DIRT, "空房满 1 分钟该自动清场")
	NetworkManager.room_mode = prev_mode


# 没搭过方块 → 不计时 (免得把发呆/等人的玩家反复拉回出生点)
func test_empty_room_no_reset_without_blocks():
	var prev_mode = NetworkManager.room_mode
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	NetworkManager.room_mode = "pvp"
	PvpArena.build(main.get_node("World"))   # 干净竞技场, 没搭东西
	var sb = PvpScoreboard.new()
	add_child_autofree(sb)
	await wait_frames(1)
	sb._tick_empty_reset(100.0, true)
	assert_eq(sb._empty_timer, 0.0, "没搭方块不计时 (不打扰等人的玩家)")
	NetworkManager.room_mode = prev_mode
