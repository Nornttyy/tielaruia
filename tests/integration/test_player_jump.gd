# 玩家跳跃测试: 验证按一下 jump 能跳上 1 格高方块.
# 用户反馈"跳不上 1 格方块", 这个测试用来定位问题.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 16


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


func test_auto_step_one_tile_no_jump():
	# Auto-step: 玩家走着碰 1 格高台阶, 不按跳应该自动爬上去
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
	# 1 格台阶: pt.y 是玩家"所在" tile (脚朝上 1 px), 在右一列同 y 放方块,
	# 让右边列地面高 1 格 (vs pt.y-1 是头顶, 那是 2 格高 = 跳不上去的墙).
	var btile := Vector2i(pt.x + 1, pt.y)
	world._set_tile(btile.x, btile.y, Tiles.STONE)
	terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	await wait_frames(2)
	var start_y: float = player.global_position.y
	var start_x: float = player.global_position.x
	var min_y: float = start_y   # 跟踪过程中的最高点 (y 越小 = 越高)
	# 只按 right, 不按 jump
	Input.action_press("move_right")
	for f in 30:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
		if f % 3 == 0:
			print("  F%d: pos=%s on_wall=%s on_floor=%s" % [f, player.global_position, player.is_on_wall(), player.is_on_floor()])
	Input.action_release("move_right")
	# dy 算 "过程中最高升了多少", 不是最终位置 (因为单块台阶爬上去后会继续走过去掉下来)
	var dy: float = start_y - min_y
	var dx: float = player.global_position.x - start_x
	print("[auto-step] start=(", start_x, ",", start_y, ") end=", player.global_position, " dx=", dx, " peak_dy=", dy)
	assert_gt(dy, float(TILE_SIZE) * 0.5, "auto-step 应让玩家爬过 1 格台阶 (峰值 dy >= 8). 实际 %.1f" % dy)


func test_jump_clears_two_tile_block():
	# 2 格高墙 (玩家右 +2 距离): 边按方向边跳, 应能站到墙顶 (dy >= 32)
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
	for dy_off in [0, 1]:
		var btile := Vector2i(pt.x + 2, pt.y - dy_off)
		world._set_tile(btile.x, btile.y, Tiles.STONE)
		terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	await wait_frames(2)
	var start_y: float = player.global_position.y
	Input.action_press("move_right")
	Input.action_press("jump")
	await wait_frames(1)
	Input.action_release("jump")
	for _i in 90:
		await wait_frames(1)
	Input.action_release("move_right")
	var dy: float = start_y - player.global_position.y
	print("[jump-2tile test] start_y=", start_y, " end_y=", player.global_position.y, " dy=", dy)
	assert_gte(dy, float(TILE_SIZE) * 1.5, "跳 + auto-step 应能上 2 格墙 (dy >= 24). 实际 %.1f" % dy)
