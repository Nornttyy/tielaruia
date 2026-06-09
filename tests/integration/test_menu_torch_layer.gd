# 回归: 主菜单火把层该排在前景树(TreesFront)之前绘制 → 树从前面遮住火把 (用户要求).
extends GutTest

const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")


func test_torch_layer_behind_front_trees() -> void:
	var menu = MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(3)   # 等 _ready 跑完 (建树+火把)
	var bg: Node = menu.get_node("BackgroundLayer")
	var torches: Node = bg.get_node_or_null("Torches")
	var front: Node = bg.get_node_or_null("TreesFront")
	assert_not_null(torches, "该有火把层 Torches")
	assert_not_null(front, "该有前景树层 TreesFront")
	if torches != null and front != null:
		assert_lt(torches.get_index(), front.get_index(), "火把层该在前景树之前绘制 (索引更小=更靠后=被树遮)")
