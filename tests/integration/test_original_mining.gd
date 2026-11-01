extends GutTest
const Player = preload("res://scenes/player/player.tscn")
const Mining = preload("res://scripts/items/original_mining.gd")
class MiningWorld extends Node2D:
	var chunk_manager: Node
	var terrain: TileMapLayer
	var walls: Dictionary = {}
	func get_tile(x: int, y: int) -> int:
		return maxi(0, terrain.get_cell_source_id(Vector2i(x,y)))
	func _set_tile(x: int, y: int, id: int):
		terrain.set_cell(Vector2i(x,y), -1 if id == Tiles.AIR else id, Vector2i.ZERO)
	func get_wall(x: int, y: int) -> int:
		return walls.get(Vector2i(x,y), Tiles.AIR)
	func _set_wall(x: int, y: int, id: int): walls[Vector2i(x,y)] = id
var world: MiningWorld
var p: CharacterBody2D
var action: Node
var inv: Node
var creative: bool
const TARGET := Vector2i(2,0)
func before_each():
	creative = GameSettings.creative_mode
	GameSettings.creative_mode = false
	world = MiningWorld.new()
	world.chunk_manager = world
	world.terrain = TileMapLayer.new()
	world.terrain.tile_set = TileSet.new()
	world.terrain.tile_set.tile_size = Vector2i(12,12)
	for id in [Tiles.STONE, Tiles.DIRT, Tiles.GRASS, Tiles.GOLD_ORE, Tiles.OBSIDIAN, Tiles.EBONSTONE]:
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(Image.create(12,12,false,Image.FORMAT_RGBA8))
		source.texture_region_size = Vector2i(12,12)
		source.create_tile(Vector2i.ZERO)
		world.terrain.tile_set.add_source(source, id)
	world.add_child(world.terrain)
	world.terrain.add_to_group("terrain_layer")
	add_child_autofree(world)
	p = Player.instantiate()
	world.add_child(p)
	p.process_mode = Node.PROCESS_MODE_DISABLED
	action = p.get_node("PlayerAction")
	inv = p.get_node("PlayerInventory")
	inv.inventory.slots.fill(null)
	_equip("copper_pickaxe")
	action.primary_override = true
	action.aim_override = TARGET
func after_each(): GameSettings.creative_mode = creative
func _equip(id: String):
	inv.inventory.slots[0] = {"item_id": id, "count": 1}
	inv.inventory_changed.emit()
	action._on_hotbar_changed(0)
func _ticks(count: int):
	for i in count: action._physics_process(1.0/60.0)
func test_copper_hits_stone_every_15_ticks_not_each_frame():
	world._set_tile(2,0,Tiles.STONE)
	action._physics_process(0.0)
	var first: float = action._mining_progress
	assert_almost_eq(first / action._hardness(Tiles.STONE), 0.35, 0.0001)
	_ticks(14)
	assert_eq(action._mining_progress, first)
	_ticks(1)
	assert_almost_eq(action._mining_progress, first * 2.0, 0.0001)
	_ticks(15)
	assert_eq(world.get_tile(2,0), Tiles.AIR)
func test_copper_can_mine_gold_ore_without_legacy_tier_gate():
	world._set_tile(2,0,Tiles.GOLD_ORE)
	action._physics_process(0.0)
	_ticks(30)
	assert_eq(world.get_tile(2,0), Tiles.AIR)
func test_hard_material_requires_pick_power():
	world._set_tile(2,0,Tiles.OBSIDIAN)
	_ticks(60)
	assert_eq(world.get_tile(2,0), Tiles.OBSIDIAN)
	_equip("gold_pickaxe")
	action._physics_process(0.0)
	_ticks(17)
	assert_eq(world.get_tile(2,0), Tiles.AIR)
	world._set_tile(2,0,Tiles.EBONSTONE)
	_ticks(90)
	assert_eq(world.get_tile(2,0), Tiles.EBONSTONE)
func test_grass_strips_first_then_dirt_takes_two_hits():
	world._set_tile(2,0,Tiles.GRASS)
	action._physics_process(0.0)
	assert_eq(world.get_tile(2,0), Tiles.DIRT)
	_ticks(15)
	assert_eq(world.get_tile(2,0), Tiles.DIRT)
	_ticks(15)
	assert_eq(world.get_tile(2,0), Tiles.AIR)
func test_target_switch_and_release_cannot_reset_hit_cooldown():
	world._set_tile(2,0,Tiles.STONE)
	world._set_tile(3,0,Tiles.STONE)
	action._physics_process(0.0)
	action.primary_override = false
	_ticks(2)
	action.aim_override = Vector2i(3,0)
	action.primary_override = true
	_ticks(1)
	assert_eq(action._mining_progress, 0.0)
	_ticks(12)
	assert_gt(action._mining_progress, 0.0)
	action.aim_override = TARGET
	_ticks(15)
	assert_almost_eq(action._mining_progress / action._hardness(Tiles.STONE), 0.7, 0.0001)
func test_wooden_hammer_uses_half_tool_time_and_four_hits():
	_equip("wood_hammer")
	world.walls[TARGET] = Tiles.STONE_WALL
	action._physics_process(0.0)
	_ticks(35)
	assert_eq(world.get_wall(2,0), Tiles.STONE_WALL)
	_ticks(1)
	assert_eq(world.get_wall(2,0), Tiles.AIR)
func test_buff_applies_only_to_pick_interval_not_power():
	assert_almost_eq(Mining.interval("copper_pickaxe",0.25), 11.0/60.0, 0.00001)
	assert_eq(Mining.interval("copper_axe",0.25), Mining.interval("copper_axe"))
	assert_eq(Mining.interval("wood_hammer",0.25), Mining.interval("wood_hammer"))
	assert_eq(Mining.power("copper_pickaxe"),35)
