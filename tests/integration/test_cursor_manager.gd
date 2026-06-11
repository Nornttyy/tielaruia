# 光标: 游戏中(无UI)用十字准星; 暂停/开面板"要选择"时用箭头 (用户要求).
extends GutTest

const CursorManager = preload("res://scripts/world/cursor_manager.gd")


func after_each() -> void:
	get_tree().paused = false


func test_crosshair_in_game_arrow_when_paused() -> void:
	var cm = CursorManager.new()
	add_child_autofree(cm)
	await wait_frames(1)
	get_tree().paused = false
	cm._process(0.0)
	assert_eq(cm._current, "crosshair", "游戏中(无 UI)该用十字准星")
	get_tree().paused = true
	cm._process(0.0)
	assert_eq(cm._current, "arrow", "暂停(要选择)时该用箭头")
	get_tree().paused = false
	cm._process(0.0)
	assert_eq(cm._current, "crosshair", "关掉暂停回到准星")
