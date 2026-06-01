extends GutTest

const MainScene = preload("res://scenes/main.tscn")

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

# 吃带 buff 的料理 → 回血 + buff 生效 + 消耗
func test_eat_dish_applies_buff():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var hp: Node = player.get_node("PlayerHealth")
	var buffs: Node = player.get_node("PlayerBuffs")
	var pa: Node = player.get_node("PlayerAction")
	# 掉点血, 拿 2 份面包 (speed buff)
	hp.current_health = 50
	inv.inventory.add("bread", 2)
	_select_item(inv, "bread")
	# 模拟"按住吃" ~2.5 秒
	pa.secondary_held_override = true
	for i in 150:
		pa._update_eat_or_place(1.0 / 60.0)
	pa.secondary_held_override = null
	assert_gt(hp.current_health, 50, "面包应回血")
	assert_true(buffs.is_active("speed"), "面包应给 speed buff")
	# 至少消耗了 1 个面包
	var total: int = 0
	for slot in inv.inventory.slots:
		if slot != null and slot.item_id == "bread":
			total += slot.count
	assert_lt(total, 2, "应消耗至少 1 个面包")
