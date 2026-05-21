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
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	SaveManager.save(main)
	var data = SaveManager.load_save()
	# 至少 villager 应在 entities 里
	var types: Array = []
	for e in data.entities:
		types.append(e.type)
	assert_true("villager" in types, "村民应在 entities 快照里")


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
