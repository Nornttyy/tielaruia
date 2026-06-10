# 回归: 背包外面的大方框/背景板已删 (用户要求) — InvPanel 套空 stylebox, 只剩小格子.
extends GutTest

const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")


func test_inv_panel_has_no_background_box() -> void:
	var cp = CraftingPanelScene.instantiate()
	add_child_autofree(cp)
	await wait_frames(1)   # 等 _ready/_build_ui 跑完
	var inv_panel: PanelContainer = cp.get_node("InvAnchor/InvPanel")
	assert_not_null(inv_panel, "InvPanel 存在")
	var sb = inv_panel.get_theme_stylebox("panel")
	assert_true(sb is StyleBoxEmpty, "背包面板该是空 stylebox (大方框已删)")


func test_armor_slots_anchored_bottom_right() -> void:
	var cp = CraftingPanelScene.instantiate()
	add_child_autofree(cp)
	await wait_frames(1)
	# 盔甲槽 → 行 → 盒子; 盒子该锚到右下 (anchor 都=1)
	assert_eq(cp._armor_slot_nodes.size(), 3, "还是 3 个盔甲槽")
	var box: Control = cp._armor_slot_nodes[0].get_parent().get_parent()
	assert_eq(box.anchor_right, 1.0, "盔甲盒锚右边 (右下角)")
	assert_eq(box.anchor_bottom, 1.0, "盔甲盒锚底边 (右下角)")
