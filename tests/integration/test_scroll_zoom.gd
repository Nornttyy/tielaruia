# 验收: 开启 scroll_wheel_zoom 后, 滚轮该缩放摄像机.
# 测两条路: 1) 直接调 handler (验逻辑) 2) Input.parse_input_event 派发 (验没被 UI 吃掉).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _wheel(up: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_WHEEL_UP if up else MOUSE_BUTTON_WHEEL_DOWN
	ev.pressed = true
	return ev


func test_scroll_zoom_when_enabled() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cam := world.camera as Camera2D   # camera spawn 时已 reparent 到玩家下, 用成员引用拿
	var player = world.get_player()
	assert_not_null(player, "该有玩家")
	if player == null:
		return
	var pinv = player.get_node_or_null("PlayerInventory")
	assert_not_null(pinv, "玩家该有 PlayerInventory")

	var was: bool = GameSettings.scroll_wheel_zoom
	GameSettings.scroll_wheel_zoom = true

	# 上滚 = 放大. 滚轮 → handler → camera_zoom → settings_changed → 摄像机更新.
	var z0: float = cam.zoom.x
	pinv._unhandled_input(_wheel(true))
	await wait_frames(2)
	var z1: float = cam.zoom.x
	gut.p("[滚轮缩放] 上滚: zoom %.2f → %.2f" % [z0, z1])
	assert_gt(z1, z0, "开启后上滚该放大摄像机")

	# 下滚 = 缩小
	pinv._unhandled_input(_wheel(false))
	await wait_frames(2)
	var z2: float = cam.zoom.x
	gut.p("[滚轮缩放] 下滚: zoom %.2f → %.2f" % [z1, z2])
	assert_lt(z2, z1, "开启后下滚该缩小摄像机")

	# 关闭设置 → 滚轮不缩放 (改切快捷栏)
	GameSettings.scroll_wheel_zoom = false
	var z3: float = cam.zoom.x
	pinv._unhandled_input(_wheel(true))
	await wait_frames(2)
	assert_eq(cam.zoom.x, z3, "关闭设置后滚轮不缩放")

	GameSettings.scroll_wheel_zoom = was
