extends GutTest

const PanelScene = preload("res://scenes/ui/crafting_panel.tscn")
const PlayerInventory = preload("res://scripts/player/player_inventory.gd")
const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")

class ActionStub extends Node:
	var tile := Vector2i(10, 10)
	func player_tile() -> Vector2i:
		return tile

var inventory_node: Node
var panel: CanvasLayer
var terrain: TileMapLayer
var action: Node

func before_each():
	var player := Node2D.new()
	add_child_autofree(player)
	action = ActionStub.new()
	action.name = "PlayerAction"
	player.add_child(action)
	inventory_node = PlayerInventory.new()
	inventory_node.name = "PlayerInventory"
	player.add_child(inventory_node)
	terrain = TileMapLayer.new()
	terrain.tile_set = TileSetBuilder.build()
	terrain.add_to_group("terrain_layer")
	add_child_autofree(terrain)
	panel = PanelScene.instantiate()
	add_child_autofree(panel)
	panel.bind_inventory(inventory_node)
	panel.open(2)

func _give(id: String, count: int):
	inventory_node.pickup(id, count)

func _count(id: String) -> int:
	return panel._count_in_inv(inventory_node.inventory, id)

func _station(tid: int):
	terrain.set_cell(Vector2i(11, 10), tid, Vector2i.ZERO)

func test_craft_workbench_consumes_exactly_ten_wood():
	_give("planks", 20)
	panel._on_recipe_pressed("workbench")
	assert_eq(_count("planks"), 10)
	assert_eq(_count("workbench"), 1)

func test_insufficient_wood_cannot_craft():
	_give("planks", 9)
	panel._on_recipe_pressed("workbench")
	assert_eq(_count("planks"), 9)
	assert_eq(_count("workbench"), 0)

func test_torches_are_three_per_wood_and_gel():
	_give("planks", 1)
	_give("slime_jelly", 1)
	panel._on_recipe_pressed("torch")
	assert_eq(_count("torch"), 3)
	assert_eq(_count("slime_jelly"), 0)

func test_furnace_not_bypassable_by_switching_grid_mode():
	_give("stone", 20)
	_give("planks", 4)
	_give("torch", 3)
	panel._mode = 3
	panel._on_recipe_pressed("furnace")
	assert_eq(_count("furnace"), 0)
	assert_eq(_count("stone"), 20)
	_station(Tiles.WORKBENCH)
	panel._on_recipe_pressed("furnace")
	assert_eq(_count("furnace"), 1)

func test_smelting_requires_furnace_but_no_coal():
	_give("iron_ore", 6)
	panel._on_recipe_pressed("iron_ingot")
	assert_eq(_count("iron_ore"), 6)
	_station(Tiles.FURNACE)
	panel._on_recipe_pressed("iron_ingot")
	assert_eq(_count("iron_ingot"), 1)
	assert_eq(_count("iron_ore"), 3)

func test_tool_requires_anvil_and_station_is_rechecked():
	_give("iron_ingot", 30)
	_give("planks", 9)
	_station(Tiles.WORKBENCH)
	panel._on_recipe_pressed("iron_pickaxe")
	assert_eq(_count("iron_pickaxe"), 0)
	_station(Tiles.IRON_ANVIL_RIGHT)
	panel._on_recipe_pressed("iron_pickaxe")
	assert_eq(_count("iron_pickaxe"), 1)
	assert_eq(_count("iron_ingot"), 20)
	# 走远后，原先显示出来的按钮也不能继续偷偷制造。
	action.tile = Vector2i(30, 10)
	panel._on_recipe_pressed("iron_pickaxe")
	assert_eq(_count("iron_pickaxe"), 1)
	assert_eq(_count("iron_ingot"), 20)

func test_full_inventory_rolls_back_materials():
	var inv = inventory_node.inventory
	for i in inv.slots.size():
		inv.slots[i] = {"item_id": "stone", "count": 9999}
	inv.slots[0] = {"item_id": "planks", "count": 20}
	var snapshot: Array = inv.slots.duplicate(true)
	panel._on_recipe_pressed("workbench")
	assert_eq(inv.slots, snapshot)

func test_original_starter_granted_by_main():
	# 不把 Main 加入场景树：测试开局函数且不触发真实存档/主菜单。
	var main = preload("res://scripts/main.gd").new()
	main._grant_starter_inventory(inventory_node.get_parent())
	var actual: Array = []
	for slot in inventory_node.inventory.slots:
		if slot != null:
			actual.append(slot.item_id)
	assert_eq(actual, ["copper_dagger", "copper_pickaxe", "copper_axe"])
	main.free()
