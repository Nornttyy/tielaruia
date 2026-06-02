extends GutTest

const MainScene = preload("res://scenes/main.tscn")

const SEAFOOD := ["salmon", "tuna", "octopus", "sea_urchin", "lobster", "eel", "sweet_shrimp", "scallop", "seaweed"]

func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer

func _select_item(inv: Node, item_id: String) -> void:
	var idx := -1
	for i in 36:
		var sl = inv.inventory.slots[i]
		if sl != null and sl.item_id == item_id:
			idx = i
			break
	assert_gte(idx, 0)
	inv.inventory.swap(0, idx)
	inv.set_hotbar_selection(0)

func _count_seafood(inv: Node) -> int:
	var n := 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id in SEAFOOD:
			n += slot.count
	return n

# 完整一条龙: 甩竿 → 咬钩 → 收竿 → 背包多 1 条海鲜
func test_fishing_catches_seafood():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var pa: Node = player.get_node("PlayerAction")
	var pf: Node = player.get_node("PlayerFishing")
	var terrain := _terrain()
	var pt: Vector2i = pa.player_tile()
	var water_t: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(water_t.x, water_t.y, Tiles.WATER)
	terrain.set_cell(water_t, Tiles.WATER, Vector2i.ZERO)
	inv.inventory.add("fishing_rod", 1)
	_select_item(inv, "fishing_rod")
	var before: int = _count_seafood(inv)
	# 甩竿
	pa.aim_override = water_t
	pa.try_fishing_click()
	assert_eq(pf.state(), "waiting")
	# 快进到咬钩
	pf._force_bite()
	assert_eq(pf.state(), "biting")
	# 收竿
	pa.try_fishing_click()
	assert_eq(pf.state(), "idle", "收完回 idle")
	var after: int = _count_seafood(inv)
	assert_eq(after, before + 1, "应钓到 1 条海鲜进背包")
