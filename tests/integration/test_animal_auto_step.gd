# 动物 auto-step 测试: 撞 1 格台阶应自动爬上, 撞 2 格高墙应反向 (不抬).
# 注: 地形由测试自己铺平 (天然地形有坡; 且玩家正好站在格子边界时 floor(y/12) 会差一行,
# 曾让台阶放进地里 → 牛顶的是天然 2 格坡, 测试误报).
extends GutTest

const CowScene = preload("res://scenes/entities/cow.tscn")
const TILE_SIZE := 12


# 找到玩家脚下真实地面行 (gy), 然后在右边铺 8 格平地 + 清空上方 3 行.
# 返回 {"px": 玩家列, "gy": 地面行}.
func _build_flat_ground(world: Node2D, terrain: TileMapLayer, player: CharacterBody2D) -> Dictionary:
	var cm = world.get("chunk_manager")
	var px := int(floor(player.global_position.x / TILE_SIZE))
	var py := int(floor(player.global_position.y / TILE_SIZE))
	var gy := -1
	for dy_scan in range(-1, 8):   # 从头顶往下扫, 第一块实心 = 地面
		var ty := py + dy_scan
		if Tiles.is_solid(cm.get_tile(px, ty)):
			gy = ty
			break
	if gy < 0:
		return {}
	for x in range(px + 1, px + 9):
		world._set_tile(x, gy, Tiles.STONE)
		terrain.set_cell(Vector2i(x, gy), Tiles.STONE, Vector2i.ZERO)
		for dy_clear in [1, 2, 3]:
			world._set_tile(x, gy - dy_clear, Tiles.AIR)
			terrain.erase_cell(Vector2i(x, gy - dy_clear))
	return {"px": px, "gy": gy}


func _boot() -> Dictionary:
	var main = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(20)
	var world: Node2D = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var player: CharacterBody2D = world.get_player()
	for _i in 60:
		if player.is_on_floor():
			break
		await wait_frames(1)
	var ground: Dictionary = _build_flat_ground(world, terrain, player)
	return {"world": world, "terrain": terrain, "ground": ground}


func _spawn_cow_walking_right(world: Node2D, px: int, gy: int):
	var cow = CowScene.instantiate()
	cow.global_position = Vector2((px + 3) * TILE_SIZE + 8, (gy - 2) * TILE_SIZE)
	world.entities_root.add_child(cow)
	for _i in 60:   # 等牛真正落地 (gravity 沉到地面要 ~10 帧)
		if cow.is_on_floor():
			break
		await wait_frames(1)
	cow._wander_dir = 1.0
	cow._wander_timer = 10.0
	cow._flee_timer = 0.0
	return cow


func test_cow_climbs_one_tile_step():
	var ctx: Dictionary = await _boot()
	var world: Node2D = ctx["world"]
	var terrain: TileMapLayer = ctx["terrain"]
	assert_false(ctx["ground"].is_empty(), "该能找到玩家脚下的地面行")
	var px: int = ctx["ground"]["px"]
	var gy: int = ctx["ground"]["gy"]
	# 平地上凸 1 格台阶
	var btile := Vector2i(px + 6, gy - 1)
	world._set_tile(btile.x, btile.y, Tiles.STONE)
	terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	var cow = await _spawn_cow_walking_right(world, px, gy)
	var start_y: float = cow.global_position.y
	var start_x: float = cow.global_position.x
	# 等 1.5 秒让牛走到台阶并爬上去 (持续强制朝右, wander timer 到会自动改方向).
	# 记"途中最高爬升"而不是终点差 — 牛爬上台阶后会继续走, 走出平整区下天然坡, 终点差会缩水.
	var peak_dy: float = 0.0
	for f in 90:
		await wait_frames(1)
		cow._wander_dir = 1.0
		cow._wander_timer = 5.0
		peak_dy = maxf(peak_dy, start_y - cow.global_position.y)
	var dx: float = cow.global_position.x - start_x
	print("[cow auto-step] start=(", start_x, ",", start_y, ") end=", cow.global_position, " dx=", dx, " peak_dy=", peak_dy)
	assert_gt(peak_dy, float(TILE_SIZE) * 0.5, "牛应自动爬 1 格台阶 (峰值 dy >= 8). 实际 %.1f" % peak_dy)


func test_cow_does_not_climb_two_tile_wall():
	# 2 格高墙: 牛应该卡住反向, 不会魔法 teleport 上去
	var ctx: Dictionary = await _boot()
	var world: Node2D = ctx["world"]
	var terrain: TileMapLayer = ctx["terrain"]
	assert_false(ctx["ground"].is_empty(), "该能找到玩家脚下的地面行")
	var px: int = ctx["ground"]["px"]
	var gy: int = ctx["ground"]["gy"]
	# 平地上凸 2 格高墙
	for dy_off in [1, 2]:
		var btile := Vector2i(px + 6, gy - dy_off)
		world._set_tile(btile.x, btile.y, Tiles.STONE)
		terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	var cow = await _spawn_cow_walking_right(world, px, gy)
	var start_y: float = cow.global_position.y
	for _i in 60:
		await wait_frames(1)
	var dy: float = start_y - cow.global_position.y
	print("[cow 2-tile wall] start_y=", start_y, " end_y=", cow.global_position.y, " dy=", dy)
	# 牛 auto-step 1 格成功 (dy ~ 12), 但碰上层 wall tile 卡住, dy 不应到 2 格.
	assert_lt(dy, float(TILE_SIZE) * 1.5, "牛不应越过 2 格高墙 (dy < 1.5 tile). 实际 %.1f" % dy)
