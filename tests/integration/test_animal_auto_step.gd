# 动物 auto-step 测试: 撞 1 格台阶应自动爬上, 撞 2 格高墙应反向 (不抬).
extends GutTest

const CowScene = preload("res://scenes/entities/cow.tscn")
const TILE_SIZE := 12


func test_cow_climbs_one_tile_step():
	var main = preload("res://scenes/main.tscn").instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(20)
	var world: Node2D = main.get_node("World")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var player: CharacterBody2D = world.get_player()
	# 等玩家落地
	for _i in 60:
		if player.is_on_floor():
			break
		await wait_frames(1)
	var pt := Vector2i(int(floor(player.global_position.x / TILE_SIZE)),
			int(floor(player.global_position.y / TILE_SIZE)))
	# 玩家右 +5 放 1 格台阶 (pt.y 是站立面上方一格, pt.y-1 是头顶 = 2 格台阶)
	var btile := Vector2i(pt.x + 5, pt.y)
	world._set_tile(btile.x, btile.y, Tiles.STONE)
	terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	# 放一只牛在玩家右 +3, 强制让它朝右走 (碰到台阶)
	var cow = CowScene.instantiate()
	cow.global_position = Vector2((pt.x + 3) * TILE_SIZE + 8, pt.y * TILE_SIZE)
	world.entities_root.add_child(cow)
	# 等牛真正落地 (不能只靠固定帧数 — gravity 把它沉到地面要 ~10 帧).
	for _i in 60:
		if cow.is_on_floor():
			break
		await wait_frames(1)
	# 强制 wander_dir 朝右 (>0) + 重置 wander timer 让它一直朝右走 (避免随机选 idle/左)
	cow._wander_dir = 1.0
	cow._wander_timer = 10.0
	cow._flee_timer = 0.0
	var start_y: float = cow.global_position.y
	var start_x: float = cow.global_position.x
	# 等 1.5 秒让牛走到台阶并爬上去
	for f in 90:
		await wait_frames(1)
		# 持续强制朝右 (动物 wander timer 到会自动改方向, 这里手动维持)
		cow._wander_dir = 1.0
		cow._wander_timer = 5.0
		if f % 10 == 0:
			print("  F%d: pos=%s wall=%s floor=%s wdir=%.1f" % [f, cow.global_position, cow.is_on_wall(), cow.is_on_floor(), cow._wander_dir])
	var dy: float = start_y - cow.global_position.y
	var dx: float = cow.global_position.x - start_x
	print("[cow auto-step] start=(", start_x, ",", start_y, ") end=", cow.global_position, " dx=", dx, " dy=", dy)
	assert_gt(dy, float(TILE_SIZE) * 0.5, "牛应自动爬 1 格台阶 (dy >= 8). 实际 %.1f" % dy)


func test_cow_does_not_climb_two_tile_wall():
	# 2 格高墙: 牛应该卡住反向, 不会魔法 teleport 上去
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
	var pt := Vector2i(int(floor(player.global_position.x / TILE_SIZE)),
			int(floor(player.global_position.y / TILE_SIZE)))
	# 玩家右 +5 放 2 格高墙 (贴地, 不悬空 — pt.y 是 1 格台阶, pt.y-1 是 2 格台阶)
	for dy_off in [0, 1]:
		var btile := Vector2i(pt.x + 5, pt.y - dy_off)
		world._set_tile(btile.x, btile.y, Tiles.STONE)
		terrain.set_cell(btile, Tiles.STONE, Vector2i.ZERO)
	var cow = CowScene.instantiate()
	cow.global_position = Vector2((pt.x + 3) * TILE_SIZE + 8, pt.y * TILE_SIZE)
	world.entities_root.add_child(cow)
	for _i in 60:
		if cow.is_on_floor():
			break
		await wait_frames(1)
	cow._wander_dir = 1.0
	cow._wander_timer = 10.0
	var start_y: float = cow.global_position.y
	for _i in 60:
		await wait_frames(1)
	var dy: float = start_y - cow.global_position.y
	print("[cow 2-tile wall] start_y=", start_y, " end_y=", cow.global_position.y, " dy=", dy)
	assert_lt(dy, float(TILE_SIZE) * 0.5, "牛不应该爬 2 格高墙 (dy < 8). 实际 %.1f" % dy)
