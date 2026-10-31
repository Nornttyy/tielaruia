extends GutTest

const InvNode = preload("res://scripts/player/player_inventory.gd")

func test_fifty_slots_and_tenth_hotbar():
	var inv := Inventory.new()
	assert_eq(inv.slots.size(), 50)
	for i in 50:
		inv.slots[i] = {"item_id": "dirt", "count": ItemDB.max_stack("dirt")}
	inv.slots[49] = null
	assert_eq(inv.add("stone", 7), 0)
	assert_eq(inv.slots[49].count, 7)

func test_legacy_inventory_preserves_both_regions_and_copies_items():
	var legacy: Array = []
	legacy.resize(36)
	for i in 36:
		legacy[i] = {"item_id": "dirt", "count": i + 1}
	var inv := Inventory.new()
	inv.restore(legacy)
	assert_eq(inv.slots.size(), 50)
	for i in 9:
		assert_eq(inv.slots[i].count, i + 1)
	assert_null(inv.slots[9], "新增快捷格不能抢走旧背包的物品")
	for i in range(9, 36):
		assert_eq(inv.slots[i + 1].count, i + 1)
	inv.remove(10, 1)
	assert_eq(legacy[9].count, 10, "读入的资源不会被运行时修改")

func test_current_inventory_round_trip_keeps_slot_zero_and_last_slot():
	var inv := Inventory.new()
	inv.slots[9] = {"item_id": "stone", "count": 7}
	inv.slots[49] = {"item_id": "dirt", "count": 11}
	var saved := inv.slots.duplicate(true)
	inv.restore(saved)
	assert_eq(inv.slots[9].count, 7)
	assert_eq(inv.slots[49].count, 11)
	assert_eq(SaveManager.deserialize_inventory(saved).size(), 50)

func test_empty_and_short_save_are_padded_safely():
	var inv := Inventory.new()
	inv.restore([])
	assert_eq(inv.slots.size(), 50)
	assert_eq(inv.add("dirt", 1), 0)
	inv.restore([{"item_id": "stone", "count": 3}])
	assert_eq(inv.slots[0].count, 3)
	assert_null(inv.slots[49])

func test_zero_key_and_wheel_wrap_tenth_slot():
	var node := InvNode.new()
	add_child_autofree(node)
	var previous := GameSettings.scroll_wheel_zoom
	GameSettings.scroll_wheel_zoom = false
	var key := InputEventKey.new()
	key.keycode = KEY_0
	key.pressed = true
	node._unhandled_input(key)
	assert_eq(node.hotbar_selected, 9)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	node._unhandled_input(wheel)
	assert_eq(node.hotbar_selected, 0)
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	node._unhandled_input(wheel)
	assert_eq(node.hotbar_selected, 9)
	GameSettings.scroll_wheel_zoom = previous
