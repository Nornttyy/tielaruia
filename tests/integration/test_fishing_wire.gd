extends GutTest

const MainScene = preload("res://scenes/main.tscn")

func _terrain() -> TileMapLayer:
	return get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer

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

# 持鱼竿对着水右键 → PlayerFishing 进入 waiting
func test_rod_click_on_water_starts_fishing():
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
	# 玩家旁边铺一格水
	var water_t: Vector2i = pt + Vector2i(1, 0)
	world._set_tile(water_t.x, water_t.y, Tiles.WATER)
	terrain.set_cell(water_t, Tiles.WATER, Vector2i.ZERO)
	inv.inventory.add("fishing_rod", 1)
	_select_item(inv, "fishing_rod")
	# 瞄准水格 → 调公开的鱼竿右键逻辑 (避免在 headless 模拟真实按键)
	pa.aim_override = water_t
	pa.try_fishing_click()
	assert_eq(pf.state(), "waiting", "持竿对水右键应开始钓鱼")
	# 浮标视觉生成了 (effects_root 下多了节点, 不崩)
	assert_true(pf.is_fishing())
