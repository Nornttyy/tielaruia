# 滚轮设置: 默认切快捷栏物品; 开了"缩放"后滚轮改摄像头 zoom.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _wheel(up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	return ev


func test_scroll_switches_items_or_zooms() -> void:
	var saved_mode: bool = GameSettings.scroll_wheel_zoom
	var saved_zoom: float = GameSettings.camera_zoom
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var inv: Node = player.get_node("PlayerInventory")
	# --- 模式 = 切物品 (默认) ---
	GameSettings.scroll_wheel_zoom = false
	inv.set_hotbar_selection(0)
	var z_before: float = GameSettings.camera_zoom
	inv._unhandled_input(_wheel(false))   # 下滚
	assert_eq(inv.hotbar_selected, 1, "切物品模式: 下滚应切到下一格")
	assert_eq(GameSettings.camera_zoom, z_before, "切物品模式: 不应改 zoom")
	# --- 模式 = 缩放镜头 ---
	GameSettings.scroll_wheel_zoom = true
	var sel_before: int = inv.hotbar_selected
	var z0: float = GameSettings.camera_zoom
	inv._unhandled_input(_wheel(true))    # 上滚 = 拉近 (zoom 变大)
	assert_gt(GameSettings.camera_zoom, z0, "缩放模式: 上滚应放大 zoom")
	assert_eq(inv.hotbar_selected, sel_before, "缩放模式: 不应切物品")
	var z1: float = GameSettings.camera_zoom
	inv._unhandled_input(_wheel(false))   # 下滚 = 拉远 (zoom 变小)
	assert_lt(GameSettings.camera_zoom, z1, "缩放模式: 下滚应缩小 zoom")
	# 还原设置 (setter 会落盘)
	GameSettings.scroll_wheel_zoom = saved_mode
	GameSettings.camera_zoom = saved_zoom


# 用户报: 对战房选武器面板滑动时摄像机会跟着缩放. 面板开着 → 滚轮该被挡 (不缩放)。
func test_weapon_panel_open_blocks_scroll_zoom() -> void:
	var prev_mode = NetworkManager.room_mode
	var panel = preload("res://scripts/ui/pvp_mode_panel.gd").new()
	add_child_autofree(panel)
	var inv = preload("res://scripts/player/player_inventory.gd").new()
	add_child_autofree(inv)
	await wait_frames(1)
	assert_false(inv._is_inventory_ui_open(), "面板没开时: 滚轮正常 (可缩放)")
	NetworkManager.room_mode = "pvp"
	panel._show_weapon_switch()
	panel._set_open(true, false)   # 开切武器面板 (不暂停)
	assert_true(panel.is_open(), "切武器面板开着")
	assert_true(inv._is_inventory_ui_open(), "切武器面板开着 → 滚轮被挡, 不缩放摄像机")
	panel._close()
	assert_false(inv._is_inventory_ui_open(), "关掉后滚轮恢复")
	NetworkManager.room_mode = prev_mode
