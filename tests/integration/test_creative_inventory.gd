# 创造模式"物品大全": 点任何物品免费拿一组 (只创造模式显示)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup(creative: bool) -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	GameSettings.creative_mode = creative   # boot 后再设 (boot 会重置成 false)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	var panel: Node = get_tree().get_first_node_in_group("crafting_panel")
	return {"main": main, "player": player, "inv": player.get_node("PlayerInventory"), "panel": panel}


func _count(inv: Node, item_id: String) -> int:
	var total := 0
	for s in inv.inventory.slots:
		if s != null and s.item_id == item_id:
			total += int(s.count)
	return total


func after_each() -> void:
	GameSettings.creative_mode = false   # 别污染别的测试


func test_creative_grab_gives_item() -> void:
	var ctx: Dictionary = await _setup(true)
	var panel = ctx["panel"]
	assert_not_null(panel, "合成面板应存在")
	panel.open(2)
	await wait_frames(1)
	assert_true(panel._creative_section.visible, "创造模式该显示物品大全区")
	var before := _count(ctx["inv"], "diamond")
	panel._on_creative_grab("diamond")
	var after := _count(ctx["inv"], "diamond")
	assert_gt(after, before, "点物品大全里的钻石该免费拿到背包")


func test_creative_section_hidden_in_survival() -> void:
	var ctx: Dictionary = await _setup(false)
	var panel = ctx["panel"]
	panel.open(2)
	await wait_frames(1)
	assert_false(panel._creative_section.visible, "生存模式该隐藏物品大全区 (不能白拿)")
