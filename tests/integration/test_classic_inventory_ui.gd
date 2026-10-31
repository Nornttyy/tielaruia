extends GutTest

const Hud = preload("res://scenes/ui/hud.tscn")
const Craft = preload("res://scenes/ui/crafting_panel.tscn")
const InvNode = preload("res://scripts/player/player_inventory.gd")
const Cursor = preload("res://scripts/items/inventory_cursor.gd")
const Chest = preload("res://scripts/ui/chest_panel.gd")

func test_fifty_cells_ten_hotbar_and_hud_stay_inside_window():
	var inv := InvNode.new()
	add_child_autofree(inv)
	var hud := Hud.instantiate()
	add_child_autofree(hud)
	hud.hotbar.bind(inv)
	var panel := Craft.instantiate()
	add_child_autofree(panel)
	await wait_frames(2)
	assert_eq(hud.hotbar._slot_nodes.size(), 10)
	assert_eq(panel._inv_slot_nodes.size(), 50)
	assert_eq(panel._inv_grid.columns, 10)
	assert_eq(hud.hotbar._slot_nodes[9].get_node("Layout/IndexLabel").text, "0")
	assert_gte(hud.hotbar._slot_nodes[0].get_global_rect().position.x, 16.0)
	assert_gte(panel._inv_slot_nodes[0].get_global_rect().position.x, 16.0)
	assert_lt(panel._inv_slot_nodes[49].get_global_rect().end.y, 320.0)
	hud.health_hud._on_changed(400, 400)
	hud.mana_hud._on_changed(200, 200)
	await wait_frames(2)
	assert_false(hud.health_hud.get_rect().intersects(hud.mana_hud.get_rect()))
	assert_false(hud.health_hud.get_rect().intersects(hud.minimap.get_rect()))

func test_chest_first_and_last_cells_include_hotbar_and_main_inventory():
	var inv := InvNode.new()
	add_child_autofree(inv)
	var chest := Chest.new()
	add_child_autofree(chest)
	chest._player_inv = inv
	inv.inventory.slots[9] = {"item_id": "stone", "count": 2}
	inv.inventory.slots[10] = {"item_id": "wood", "count": 3}
	inv.inventory.slots[49] = {"item_id": "dirt", "count": 4}
	assert_eq(chest._player_slots_ui.size(), 50)
	assert_eq(chest._chest_slots_ui.size(), 40)
	chest._apply_click(10, false)
	assert_eq(inv.cursor_slot.item_id, "wood")
	assert_eq(inv.inventory.slots[9].count, 2)
	chest._apply_click(49, false)
	assert_eq(inv.inventory.slots[49].item_id, "wood")
	assert_eq(inv.cursor_slot.item_id, "dirt")
	chest._apply_click(0, false)
	assert_eq(inv.inventory.slots[0].item_id, "dirt")
	assert_null(inv.cursor_slot)

func test_right_click_takes_one_without_destroying_remaining_stack():
	var inv := InvNode.new()
	add_child_autofree(inv)
	inv.inventory.slots[49] = {"item_id": "dirt", "count": 2}
	Cursor.take_one(inv, inv.inventory.slots, 49)
	assert_eq(inv.cursor_slot.count, 1)
	assert_eq(inv.inventory.slots[49].count, 1)
	Cursor.take_one(inv, inv.inventory.slots, 49)
	assert_eq(inv.cursor_slot.count, 2)
	assert_null(inv.inventory.slots[49])
	inv.inventory.slots[0] = {"item_id": "wood", "count": 3}
	Cursor.take_one(inv, inv.inventory.slots, 0)
	assert_eq(inv.inventory.slots[0].count, 3, "不同物品不能被右键吞掉")

func test_hotbar_mouse_and_touch_select_correct_cell_after_resize():
	var inv := InvNode.new()
	add_child_autofree(inv)
	var hud := Hud.instantiate()
	add_child_autofree(hud)
	hud.hotbar.bind(inv)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	hud.hotbar._slot_nodes[9].gui_input.emit(touch)
	assert_eq(inv.hotbar_selected, 9)
	assert_eq(hud.hotbar._slot_nodes[9].size, Vector2(52, 52))
	assert_eq(hud.hotbar._slot_nodes[0].size, Vector2(39, 39))
	var click := InputEventMouseButton.new()
	click.pressed = true
	click.button_index = MOUSE_BUTTON_LEFT
	hud.hotbar._slot_nodes[2].gui_input.emit(click)
	assert_eq(inv.hotbar_selected, 2)
	for i in 9:
		assert_lt(hud.hotbar._slot_nodes[i].get_rect().end.x, hud.hotbar._slot_nodes[i + 1].position.x)
