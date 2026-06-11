extends GutTest

# 触屏版补的: 快捷栏可点选 + 背包/丢/暂停 按钮。
const HotbarView = preload("res://scripts/ui/hotbar_view.gd")
const TouchControls = preload("res://scripts/ui/touch_controls.gd")
const PlayerInventory = preload("res://scripts/player/player_inventory.gd")


func test_hotbar_tap_selects_slot():
	var hv = HotbarView.new()
	add_child_autofree(hv)
	await wait_frames(1)
	var pinv = PlayerInventory.new()
	add_child_autofree(pinv)
	await wait_frames(1)
	hv.bind(pinv)
	# 模拟在容器横坐标 x≈140 处点击 (槽宽 40 → idx = 140/40 = 3 = 第 4 格)
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = Vector2(140, 18)
	hv._gui_input(ev)
	assert_eq(pinv.hotbar_selected, 3, "点 hotbar x≈140 应选第 4 格")


func test_touch_has_bag_drop_pause_buttons():
	var tc = TouchControls.new()
	add_child_autofree(tc)
	await wait_frames(1)
	assert_not_null(tc.get_node_or_null("BtnBag"), "有背包钮")
	assert_not_null(tc.get_node_or_null("BtnDrop"), "有丢弃钮")
	assert_not_null(tc.get_node_or_null("BtnPause"), "有暂停钮")
	# 原有的也还在
	assert_not_null(tc.get_node_or_null("BtnAttack"), "击钮还在")
	assert_not_null(tc.get_node_or_null("BtnJump"), "跳钮还在")
