extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")
var world: Node2D
var player: Node2D
var action: Node2D
var inv: Node
var terrain: TileMapLayer
var anchor: Vector2i
var previous_creative: bool

func before_each():
	previous_creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	world = WorldScene.instantiate()
	world.world_seed = 42
	add_child_autofree(world)
	world.process_mode = Node.PROCESS_MODE_DISABLED
	player = world.get_player()
	action = player.get_node("PlayerAction")
	inv = player.get_node("PlayerInventory")
	terrain = world.get_node("TerrainLayer")
	anchor = action.player_tile() + Vector2i(1, 0)
	for dx in [0, 1]:
		world._set_tile(anchor.x + dx, anchor.y, Tiles.AIR)
		world._set_tile(anchor.x + dx, anchor.y + 1, Tiles.STONE)
	inv.inventory.slots.fill(null)
	inv.pickup("iron_anvil", 1)
	inv.set_hotbar_selection(0)
	action.aim_override = anchor

func after_each():
	GameSettings.creative_mode = previous_creative

func _assert_gone_with_one_drop():
	assert_eq(world.chunk_manager.get_tile(anchor.x, anchor.y), Tiles.AIR)
	assert_eq(world.chunk_manager.get_tile(anchor.x + 1, anchor.y), Tiles.AIR)
	var count := 0
	for node in world.entities_root.get_children():
		if node.get("item_id") == "iron_anvil":
			count += node.count
	assert_eq(count, 1, "两半只掉一件铁砧")

func test_place_anvil_has_two_visible_tiles_and_consumes_one():
	assert_true(action.try_place())
	assert_eq(world.chunk_manager.get_tile(anchor.x, anchor.y), Tiles.IRON_ANVIL)
	assert_eq(world.chunk_manager.get_tile(anchor.x + 1, anchor.y), Tiles.IRON_ANVIL_RIGHT)
	assert_eq(terrain.get_cell_source_id(anchor + Vector2i.RIGHT), Tiles.IRON_ANVIL_RIGHT)
	assert_null(inv.current_hotbar_slot())

func test_occupied_right_tile_rejects_atomically():
	world._set_tile(anchor.x + 1, anchor.y, Tiles.STONE)
	assert_false(action.try_place())
	assert_eq(world.chunk_manager.get_tile(anchor.x, anchor.y), Tiles.AIR)
	assert_eq(inv.current_hotbar_slot().count, 1)

func test_both_feet_need_support():
	world._set_tile(anchor.x + 1, anchor.y + 1, Tiles.AIR)
	assert_false(action.try_place())
	assert_eq(inv.current_hotbar_slot().count, 1)

func test_mining_left_removes_both_halves():
	assert_true(action.try_place())
	action._finish_mine(anchor, Tiles.IRON_ANVIL, "pickaxe", terrain)
	_assert_gone_with_one_drop()

func test_mining_right_removes_both_halves():
	assert_true(action.try_place())
	action._finish_mine(anchor + Vector2i.RIGHT, Tiles.IRON_ANVIL_RIGHT, "pickaxe", terrain)
	_assert_gone_with_one_drop()

func test_breaking_support_drops_whole_anvil():
	assert_true(action.try_place())
	action._finish_mine(anchor + Vector2i.DOWN, Tiles.STONE, "pickaxe", terrain)
	_assert_gone_with_one_drop()
