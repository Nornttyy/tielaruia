# 回归: 面板没绑定背包 (_player_inv=null, 如玩家加载时序/旧 parse-error 致 bind 没跑) 时,
# 点"物品大全"仍该能拿 (现找玩家背包兜底). 复现用户"看得到大全但点了没反应".
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _count_item(pinv, id: String) -> int:
	var t: int = 0
	for s in pinv.inventory.slots:
		if s != null and s.item_id == id:
			t += s.count
	return t


func test_grab_works_even_when_panel_unbound() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	GameSettings.creative_mode = true
	var panel = get_tree().get_first_node_in_group("crafting_panel")
	var pinv = main.get_node("World").get_player().get_node("PlayerInventory")
	# 模拟"没绑定"的坏状态 (旧 bug: 玩家没加载好 → bind_inventory 没跑)
	panel._player_inv = null
	var before: int = _count_item(pinv, "dirt")
	panel._on_creative_grab("dirt")
	var after: int = _count_item(pinv, "dirt")
	assert_gt(after, before, "未绑定时点物品大全也该现找背包拿到 (before=%d after=%d)" % [before, after])
	GameSettings.creative_mode = false
