# 光标: 用户要求游戏里固定十字准星 — 开背包/暂停也不换箭头.
extends GutTest

const CursorManager = preload("res://scripts/world/cursor_manager.gd")


func after_each() -> void:
	get_tree().paused = false


func test_crosshair_always_in_game() -> void:
	var cm = CursorManager.new()
	add_child_autofree(cm)
	await wait_frames(1)
	get_tree().paused = false
	cm._process(0.0)
	assert_eq(cm._current, "crosshair", "游戏中该用十字准星")
	# 暂停 (要选择) 时也固定准星, 不换箭头
	get_tree().paused = true
	cm._process(0.0)
	assert_eq(cm._current, "crosshair", "暂停时仍固定十字准星")
	get_tree().paused = false
	cm._process(0.0)
	assert_eq(cm._current, "crosshair", "始终十字准星")
