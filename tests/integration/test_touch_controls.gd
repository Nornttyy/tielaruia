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
	assert_not_null(tc.get_node_or_null("BtnAttack"), "击钮(物品图标)还在")
	# 新增右下瞄准摇杆; 跳钮删了 (左摇杆上推包办跳)
	assert_not_null(tc.get_node_or_null("AimJoystick"), "有瞄准摇杆")
	assert_null(tc.get_node_or_null("BtnJump"), "跳钮已删 (左摇杆上推 = 跳)")
	# 用户: 加准星 + 物品钮挪到左移动摇杆上方
	assert_not_null(tc.get_node_or_null("Crosshair"), "有准星")
	assert_eq(tc.get_node("BtnAttack").anchor_left, 0.0, "物品钮锚到左边 (在左摇杆上方, 不在右下)")


# 桩: 假 PlayerAction, 只要个 mouse_world_override 字段
class StubAction:
	extends Node
	var mouse_world_override = null


# 用户报: 武器(弓)只往一个方向. 根因: 触屏瞄准靠 warp_mouse, 网页失效 → 鼠标卡在"击"钮角落。
# 修: 瞄准摇杆方向直接喂 PlayerAction.mouse_world_override. 这里验证左/右瞄 → 目标在玩家对应侧。
func test_aim_joystick_feeds_world_override_both_directions():
	var player := Node2D.new()
	player.add_to_group("player")
	player.global_position = Vector2(500, 300)
	var action := StubAction.new()
	action.name = "PlayerAction"
	player.add_child(action)
	add_child_autofree(player)
	var tc = TouchControls.new()
	add_child_autofree(tc)
	await wait_frames(1)
	# 朝左瞄
	tc._aim_dir = Vector2.LEFT
	tc._update_aim()
	assert_not_null(action.mouse_world_override, "该把瞄准目标喂给 PlayerAction")
	assert_lt(action.mouse_world_override.x, player.global_position.x, "朝左瞄 → 目标在玩家左侧")
	# 朝右瞄
	tc._aim_dir = Vector2.RIGHT
	tc._update_aim()
	assert_gt(action.mouse_world_override.x, player.global_position.x, "朝右瞄 → 目标在玩家右侧")


# 用户: 击/用合一. 一个物品图标钮, 按住自动选对操作 (方块/食物/药水=secondary, 工具/武器=primary)。
func test_merged_use_button_picks_right_action():
	var player := Node2D.new()
	player.add_to_group("player")
	var pinv = PlayerInventory.new()
	pinv.name = "PlayerInventory"
	player.add_child(pinv)
	add_child_autofree(player)
	await wait_frames(1)
	var tc = TouchControls.new()
	add_child_autofree(tc)
	await wait_frames(1)
	pinv.hotbar_selected = 0
	pinv.inventory.slots[0] = {"item_id": "dirt", "count": 1}
	assert_eq(tc._use_action_for_held(), "secondary", "拿方块按住=放(secondary)")
	pinv.inventory.slots[0] = {"item_id": "wood_pickaxe", "count": 1}
	assert_eq(tc._use_action_for_held(), "primary", "拿工具按住=挖(primary)")
	pinv.inventory.slots[0] = {"item_id": "health_potion", "count": 1}
	assert_eq(tc._use_action_for_held(), "secondary", "拿药水按住=喝(secondary)")
	# 没了"用"钮 (击/用合一)
	assert_null(tc.get_node_or_null("BtnUse"), "用钮已删 (击/用合一)")
