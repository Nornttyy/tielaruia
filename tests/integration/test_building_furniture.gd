extends GutTest
const WorldScene = preload("res://scenes/world/world.tscn")
const Art = preload("res://scripts/art/building_art.gd")
var world: Node2D
var action: Node2D
var inv: Node
var terrain: TileMapLayer
var anchor: Vector2i
var old_creative: bool

func before_each():
	old_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	world = WorldScene.instantiate()
	world.world_seed = 42
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	var player = world.get_player()
	action = player.get_node("PlayerAction")
	inv = player.get_node("PlayerInventory")
	terrain = world.terrain_layer
	anchor = action.player_tile() + Vector2i(1, 0)
	for dx in 3:
		for dy in [-1, 0]: world._set_tile(anchor.x + dx, anchor.y + dy, Tiles.AIR)
		world._set_tile(anchor.x + dx, anchor.y + 1, Tiles.STONE)
	inv.inventory.slots.fill(null)
	inv.pickup("wood_table", 1)
	inv.set_hotbar_selection(0)
	action.aim_override = anchor

func after_each():
	GameSettings.creative_mode = old_creative

func test_table_places_full_rectangle_and_consumes_one():
	assert_true(action.try_place())
	for i in 6:
		assert_eq(terrain.get_cell_source_id(anchor + Art.part_offset(121 + i)), 121 + i)
	assert_null(inv.current_hotbar_slot())

func test_blocked_upper_part_leaves_inventory_and_world_unchanged():
	world._set_tile(anchor.x + 2, anchor.y - 1, Tiles.STONE)
	assert_false(action.try_place())
	assert_eq(inv.current_hotbar_slot().count, 1)
	assert_eq(world.chunk_manager.get_tile(anchor.x, anchor.y), Tiles.AIR)

func test_breaking_upper_part_removes_whole_table_once():
	assert_true(action.try_place())
	action._finish_mine(anchor + Art.part_offset(126), 126, "pickaxe", terrain)
	for i in 6:
		assert_eq(terrain.get_cell_source_id(anchor + Art.part_offset(121 + i)), -1)
	var count := 0
	for node in world.entities_root.get_children():
		if node.get("item_id") == "wood_table": count += node.count
	assert_eq(count, 1)

func test_glass_is_a_background_wall():
	inv.inventory.slots.fill(null)
	inv.pickup("glass_wall", 1)
	world._set_wall(anchor.x, anchor.y, Tiles.AIR)
	assert_true(action.try_place())
	assert_eq(world.chunk_manager.get_wall(anchor.x, anchor.y), Tiles.GLASS_WALL)
	assert_eq(terrain.get_cell_source_id(anchor), -1, "玻璃窗不变成挡人的前景块")
