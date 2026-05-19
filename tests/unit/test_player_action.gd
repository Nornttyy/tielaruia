extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_in_reach_with_aim_override():
	var main = MainScene.instantiate()
	add_child_autofree(main)
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
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	action.aim_override = Vector2i(42, 100)
	assert_eq(action.aim_tile_coord(), Vector2i(42, 100))


func test_invalid_tile_not_in_reach():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var action: Node2D = player.get_node("PlayerAction")
	assert_false(action.in_reach(Vector2i(-1, -1)))


func test_mine_dirt_with_bare_hands():
	var main = MainScene.instantiate()
	add_child_autofree(main)
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
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	inv.inventory.add("dirt", 5)
	inv.set_hotbar_selection(0)
	var pt: Vector2i = action.player_tile()
	# 紧贴地面上方一格 (下方草地是邻接 anchor)
	var target: Vector2i = pt + Vector2i(2, -1)
	action.aim_override = target
	action.place_override = true
	await wait_frames(3)
	assert_eq(terrain.get_cell_source_id(target), Tiles.DIRT, "tile 应出现 dirt")
	assert_eq(inv.inventory.slots[0].count, 4, "槽内 dirt 应减 1")


func test_place_fails_when_no_neighbor():
	# 空中无邻接方块时不能放
	var main = MainScene.instantiate()
	add_child_autofree(main)
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
