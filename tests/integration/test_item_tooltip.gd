# 物品悬浮提示: 名字 + 数值 + 用途 (用户要求碰到物品显示)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _panel():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	return get_tree().get_first_node_in_group("crafting_panel")


func test_sword_tooltip_has_name_damage_use():
	var cp = await _panel()
	var t: String = cp._item_tooltip("iron_sword")
	assert_true(t.contains("近战"), "剑显示是近战武器")
	assert_true(t.contains("伤害"), "剑显示伤害数值")
	assert_true(t.contains("打怪"), "剑显示用途")
	assert_true(t.contains("\n"), "多行 (名字+数值+用途)")


func test_block_tooltip_says_placeable():
	var cp = await _panel()
	var t: String = cp._item_tooltip("dirt")
	assert_true(t.contains("方块") or t.contains("放置"), "方块显示可放置")


func test_food_tooltip_shows_fill():
	var cp = await _panel()
	var t: String = cp._item_tooltip("apple")
	assert_true(t.contains("回饱食"), "食物显示回饱食数值")


func test_armor_tooltip_shows_defense():
	var cp = await _panel()
	var t: String = cp._item_tooltip("iron_helmet")
	assert_true(t.contains("防御"), "护甲显示防御数值")


func test_unknown_item_falls_back_to_name():
	var cp = await _panel()
	var t: String = cp._item_tooltip("___not_a_real_item___")
	assert_true(t.length() > 0, "未知物品也返回点东西 (不崩)")
