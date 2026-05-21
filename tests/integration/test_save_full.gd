extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SAVE_PATH := "user://save.tres"


func before_each():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func after_each():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


func test_save_captures_entities():
	# 村庄 / 村民已停用. 这里仅断言 SaveManager 能正常 dump entities 数组
	# (即使为空也应可序列化), 不再要求 villager 在内.
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	assert_not_null(data, "存档可读")
	assert_true(data.entities is Array, "entities 字段是 Array")


func test_f5_triggers_save():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	assert_false(SaveManager.has_save())
	# 模拟 F5 按下事件
	var ev := InputEventKey.new()
	ev.keycode = KEY_F5
	ev.pressed = true
	main._unhandled_input(ev)
	assert_true(SaveManager.has_save(), "F5 应触发保存")
