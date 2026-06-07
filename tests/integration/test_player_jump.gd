# 玩家跳跃测试: 验证按一下 jump 能跳上 1 格高方块.
# 用户反馈"跳不上 1 格方块", 这个测试用来定位问题.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 6


func test_jump_height_clears_one_tile():
	# 验证: 站平地按 jump, 最高离地高度至少 16 px (1 格方块)
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)  # 让世界稳定
	var player: CharacterBody2D = main.get_node("World").get_player()
	assert_not_null(player)
	# 等玩家落地 (出生在空中)
	var landed_frames := 0
	while landed_frames < 120 and not player.is_on_floor():
		await wait_frames(1)
		landed_frames += 1
	assert_true(player.is_on_floor(), "玩家应在 2s 内落地")
	var floor_y: float = player.global_position.y
	# 模拟按一下 jump
	Input.action_press("jump")
	await wait_frames(1)
	Input.action_release("jump")
	var min_y: float = floor_y
	for _i in 60:  # 1 秒内峰值
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	var jump_height: float = floor_y - min_y
	print("[jump test] floor_y=", floor_y, " peak_y=", min_y, " height=", jump_height)
	assert_gt(jump_height, float(TILE_SIZE), "跳跃高度应 > 1 格 (16px), 实际 %.1f" % jump_height)


func test_jump_clears_one_tile_block_in_front():
	# 验证: 在玩家正前方放 1 格方块, 玩家边按方向边按跳, 能站到方块上
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)
	var player: CharacterBody2D = main.get_node("World").get_player()
	var world: Node2D = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	# 落地
	for _i in 120:
		if player.is_on_floor():
			break
		await wait_frames(1)
	assert_true(player.is_on_floor())
	var pt := Vector2i(int(floor(player.global_position.x / TILE_SIZE)),
			int(floor(player.global_position.y / TILE_SIZE)))
	# 在玩家正右 +2 格放 1 格 STONE (pt.y = 1 格台阶, 不是头顶)
	var block_tile := Vector2i(pt.x + 2, pt.y)
	world._set_tile(block_tile.x, block_tile.y, Tiles.STONE)
	terrain.set_cell(block_tile, Tiles.STONE, Vector2i.ZERO)
	await wait_frames(2)
	var start_y: float = player.global_position.y
	# 按右 + 跳
	Input.action_press("move_right")
	Input.action_press("jump")
	await wait_frames(1)
	Input.action_release("jump")
	# 维持右移 1 秒, 看玩家是否爬上方块
	for _i in 60:
		await wait_frames(1)
	Input.action_release("move_right")
	var ended_higher: bool = player.global_position.y < start_y - TILE_SIZE * 0.5
	print("[jump-block test] start_y=", start_y, " end_y=", player.global_position.y,
			" delta=", start_y - player.global_position.y)
	assert_true(ended_higher, "玩家应站到方块上 (y 上升 ~1 格). 实际 dy=%.1f" % (start_y - player.global_position.y))


# 玩家不会自动爬台阶 (用户偏好需要按跳, 不要 Terraria 风 auto-step).
# 测试: 撞 1 格台阶 + 不按跳 → 应该卡住不上去.
func test_no_auto_step_one_tile_player_stuck():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)
	var player: CharacterBody2D = main.get_node("World").get_player()
	var world: Node2D = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	for _i in 120:
		if player.is_on_floor():
			break
		await wait_frames(1)
	var pt := Vector2i(int(floor(player.global_position.x / TILE_SIZE)),
			int(floor(player.global_position.y / TILE_SIZE)))
	var btile := Vector2i(pt.x + 1, pt.y)
	world._set_tile(btile.x, btile.y, Tiles.STONE)
	terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	await wait_frames(2)
	var start_y: float = player.global_position.y
	var min_y: float = start_y
	Input.action_press("move_right")
	for _f in 30:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	Input.action_release("move_right")
	var dy: float = start_y - min_y
	assert_lt(dy, float(TILE_SIZE) * 0.5, "玩家不该自动爬台阶 (峰值 dy < 8). 实际 %.1f" % dy)


# 2 格墙跳跃测试已删: 之前要求 dy>=24 是依赖 auto-step + jump 合作.
# 用户关闭了 auto-step, 跳+水平在 2 格距离能否上 2 格墙取决于精准 timing, 不稳定.
# 单纯跳跃 1 格墙的能力由 test_jump_clears_one_tile_block_in_front 覆盖了.
