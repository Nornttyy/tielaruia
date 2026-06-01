extends GutTest

const MainScene = preload("res://scenes/main.tscn")

func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer

# 把某 item 挪到 0 号 hotbar 槽并选中 (开局自带物品占了 0 槽)
func _select_item(inv: Node, item_id: String) -> void:
	var idx := -1
	for i in 36:
		var sl = inv.inventory.slots[i]
		if sl != null and sl.item_id == item_id:
			idx = i
			break
	assert_gte(idx, 0, "%s 应在背包里" % item_id)
	inv.inventory.swap(0, idx)
	inv.set_hotbar_selection(0)

# 锅放在炉子正上方 → 成功
func test_pot_places_on_furnace():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var pa: Node = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain := _terrain()
	var pt: Vector2i = pa.player_tile()
	var target: Vector2i = pt + Vector2i(1, -1)
	var below: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(target.x, target.y, Tiles.AIR)
	terrain.set_cell(target, -1)
	world._set_tile(below.x, below.y, Tiles.FURNACE)
	terrain.set_cell(below, Tiles.FURNACE, Vector2i.ZERO)
	inv.inventory.add("cooking_pot", 1)
	_select_item(inv, "cooking_pot")
	pa.aim_override = target
	var ok: bool = pa.try_place()
	assert_true(ok, "锅应能叠在炉子上")
	await wait_frames(1)
	assert_eq(terrain.get_cell_source_id(target), Tiles.COOKING_POT)

# 锅放在非炉子上方 → 失败
func test_pot_rejects_non_furnace():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var pa: Node = player.get_node("PlayerAction")
	var inv: Node = player.get_node("PlayerInventory")
	var terrain := _terrain()
	var pt: Vector2i = pa.player_tile()
	var target: Vector2i = pt + Vector2i(1, -1)
	var below: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(target.x, target.y, Tiles.AIR)
	terrain.set_cell(target, -1)
	world._set_tile(below.x, below.y, Tiles.STONE)     # 石头 (不是炉子)
	terrain.set_cell(below, Tiles.STONE, Vector2i.ZERO)
	inv.inventory.add("cooking_pot", 1)
	_select_item(inv, "cooking_pot")
	pa.aim_override = target
	var ok: bool = pa.try_place()
	assert_false(ok, "锅不该放在非炉子上")

# 锅自己的配方: 熔炉炼
func test_cooking_pot_recipe():
	var r = RecipeDB.get_recipe("cooking_pot")
	assert_not_null(r, "应有铁锅配方")
	assert_eq(r.output_id, "cooking_pot")
	assert_eq(r.get("requires", ""), "furnace", "铁锅在熔炉炼")
