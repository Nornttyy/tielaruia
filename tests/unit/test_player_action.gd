extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_in_reach_with_aim_override():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var pt: Vector2i = action.player_tile()
	# 玩家自身所在 tile 必在范围
	action.aim_override = pt
	assert_true(action.in_reach(pt))
	# 4 格远 - 仍在
	action.aim_override = pt + Vector2i(4, 0)
	assert_true(action.in_reach(pt + Vector2i(4, 0)))
	# 5 格远 - 超出
	action.aim_override = pt + Vector2i(5, 0)
	assert_false(action.in_reach(pt + Vector2i(5, 0)))


func test_aim_override_returns_set_value():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	action.aim_override = Vector2i(42, 100)
	assert_eq(action.aim_tile_coord(), Vector2i(42, 100))


func test_invalid_tile_not_in_reach():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	assert_false(action.in_reach(Vector2i(-1, -1)))


func test_mine_dirt_with_bare_hands():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.DIRT, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.DIRT)
	action.aim_override = target
	action.primary_override = true
	await wait_frames(60)
	assert_eq(terrain.get_cell_source_id(target), -1, "dirt 应被挖空")


func test_cannot_mine_stone_bare_hand():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	action.primary_override = true
	await wait_frames(60)
	assert_eq(terrain.get_cell_source_id(target), Tiles.STONE, "stone 不应被徒手挖空")


func test_can_mine_stone_with_pickaxe():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, 0)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	world._set_tile(target.x, target.y, Tiles.STONE)
	action.aim_override = target
	action.primary_override = true
	await wait_frames(90)
	assert_eq(terrain.get_cell_source_id(target), -1, "有镚应能挖空 stone")


func test_place_dirt_consumes_slot_and_creates_tile():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	# pt 是玩家所在 AIR tile (脚朝上 1 px). 想在 pt+(2,-1) 放 dirt,
	# try_place 要求 4 邻居至少 1 个有方块 → 在 pt+(2, 0) 加石头当 anchor.
	var anchor: Vector2i = pt + Vector2i(2, 0)
	world._set_tile(anchor.x, anchor.y, Tiles.STONE)
	terrain.set_cell(anchor, Tiles.STONE, Vector2i.ZERO)
	var target: Vector2i = pt + Vector2i(2, -1)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.DIRT, "tile 应出现 dirt")
	assert_eq(inv.inventory.slots[0].count, 4, "槽内 dirt 应减 1")


func test_place_on_wall_succeeds():
	# 在背景墙上贴方块: 即使周围全是空气, 只要背后有墙, 也应允许放置.
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var wall_layer: TileMapLayer = world.get_node("WallLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	# 选一个空中位置, 清掉周围所有 tile, 但手动放一个墙在 target
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, -2)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			terrain.set_cell(target + Vector2i(dx, dy), -1)
	wall_layer.set_cell(target, Tiles.STONE_WALL, Vector2i.ZERO)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.DIRT, "墙上应能放下 dirt")
	assert_eq(inv.inventory.slots[0].count, 4, "槽内 dirt 应减 1")


func test_place_fails_when_no_neighbor():
	# 空中无邻接方块时不能放
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	# 玩家头顶上方 3 格 - 四周都是空气
	var target: Vector2i = pt + Vector2i(0, -4)
	# 确保 target 周围都清空 (避免世界生成器恰好放了树之类)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0: continue
			terrain.set_cell(target + Vector2i(dx, dy), -1)
	terrain.set_cell(target, -1)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), -1, "无邻接时不应放下")
	assert_eq(inv.inventory.slots[0].count, 5, "未消耗")


func test_place_fails_on_occupied_tile():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	var target: Vector2i = pt + Vector2i(2, -2)
	terrain.set_cell(target, Tiles.STONE, Vector2i.ZERO)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.STONE, "不应覆盖")
	assert_eq(inv.inventory.slots[0].count, 5, "未消耗")


func test_place_fails_when_not_placeable():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	inv.inventory.add("wood_pickaxe", 1)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	action.aim_override = pt + Vector2i(2, -2)
	action.place_override = true
	await wait_frames(3)
	assert_eq(inv.inventory.slots[0].count, 1, "工具不应被消耗")


func test_sword_swing_aims_at_mouse_direction():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	# 给玩家一把木剑
	var inv: Node = player.get_node("PlayerInventory")
	inv.inventory.add("wood_sword", 1)
	inv.set_hotbar_selection(0)
	# 鼠标在玩家右上方 (世界坐标), 期望挥击中心朝向那里
	var player_pos: Vector2 = player.global_position
	action.mouse_world_override = player_pos + Vector2(100.0, -100.0)
	action.primary_override = true
	await wait_frames(2)
	# 命中中心应在 player_pos + normalize(100,-100) * SWORD_RANGE_PX * 0.5
	var expected_dir: Vector2 = Vector2(100.0, -100.0).normalized()
	var expected_center: Vector2 = player_pos + expected_dir * 18.0  # SWORD_RANGE_PX=36 * 0.5
	assert_almost_eq(action.last_swing_center.x, expected_center.x, 1.0)
	assert_almost_eq(action.last_swing_center.y, expected_center.y, 1.0)
