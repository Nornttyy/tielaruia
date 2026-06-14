# 合成配方列表只显示"当前能合成"的 (用户要求): 材料不够的隐藏, 集齐后重新出现。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _find_entry(cp, output_id: String):
	for e in cp._recipe_buttons:
		if String(e.recipe.output_id) == output_id:
			return e
	return null


func test_unaffordable_recipe_hidden_then_shown():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var inv: Node = player.get_node("PlayerInventory")
	var cp: CanvasLayer = get_tree().get_first_node_in_group("crafting_panel")
	cp.open(2)
	await wait_frames(1)
	var entry = _find_entry(cp, "planks")   # planks: 1 log → 4 planks, 徒手可合, 在列表里
	assert_not_null(entry, "配方列表里有 planks")

	# 清空背包 → 没 log → planks 该隐藏
	for i in inv.inventory.slots.size():
		inv.inventory.slots[i] = null
	cp._refresh_recipes()
	await wait_frames(1)
	assert_false(entry.button.visible, "没材料的配方隐藏")

	# 加 1 log → planks 能合成 → 重新显示且可点 (不灰)
	inv.inventory.add("log", 1)
	cp._refresh_recipes()
	await wait_frames(1)
	assert_true(entry.button.visible, "集齐材料后重新显示")
	assert_false(entry.button.disabled, "显示出来的就是能合成的 (不再灰显)")
	cp.close()
