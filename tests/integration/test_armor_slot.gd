# 盔甲槽: 卸下盔甲后槽里图标要清空 (不残留)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	var panel: Node = get_tree().get_first_node_in_group("crafting_panel")
	return {"main": main, "player": player, "inv": player.get_node("PlayerInventory"), "panel": panel}


func test_unequip_armor_clears_slot_icon() -> void:
	var ctx: Dictionary = await _setup()
	var inv: Node = ctx["inv"]
	var panel = ctx["panel"]
	# 装一件头盔
	inv.set_armor("helmet", {"item_id": "skeleton_helmet", "count": 1})
	panel.open(2)
	await wait_frames(1)
	var helmet_slot = panel._armor_slot_nodes[0]   # [头, 胸, 腿]
	var icon: TextureRect = helmet_slot.get_node("Layout/Icon")
	assert_not_null(icon.texture, "装上头盔后槽里该有图标")
	# 右键卸下
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_RIGHT
	ev.pressed = true
	panel._on_armor_slot_input(ev, "helmet")
	await wait_frames(1)
	assert_null(icon.texture, "卸下后盔甲槽图标该清空 (不残留)")


func test_pick_armor_to_cursor_clears_slot_icon() -> void:
	# 左键(cursor 空)把盔甲拿到鼠标 → 槽也该清空图标
	var ctx: Dictionary = await _setup()
	var inv: Node = ctx["inv"]
	var panel = ctx["panel"]
	inv.cursor_slot = null
	inv.set_armor("chest", {"item_id": "skeleton_chest", "count": 1})
	panel.open(2)
	await wait_frames(1)
	var chest_slot = panel._armor_slot_nodes[1]
	var icon: TextureRect = chest_slot.get_node("Layout/Icon")
	assert_not_null(icon.texture, "装上胸甲后该有图标")
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	panel._on_armor_slot_input(ev, "chest")
	await wait_frames(1)
	assert_null(icon.texture, "盔甲拿到鼠标后槽图标该清空 (不残留)")
