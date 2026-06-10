# 成就系统验收: 事件解锁 / 物品轮询解锁 / 不重复 / 存读.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func before_each() -> void:
	Achievements.SAVE_PATH_OVERRIDE = "user://test_achievements.cfg"
	Achievements._reset_for_test()


func after_each() -> void:
	DirAccess.remove_absolute("user://test_achievements.cfg")
	Achievements.SAVE_PATH_OVERRIDE = ""
	Achievements._reset_for_test()


func test_fire_event_unlocks_and_emits() -> void:
	watch_signals(Achievements)
	Achievements.fire("boss_king_slime")
	assert_true(Achievements.is_unlocked("boss_slime"), "打赢史莱姆王该解锁'屠王者'")
	assert_signal_emitted(Achievements, "achievement_unlocked")


func test_unknown_event_does_nothing() -> void:
	Achievements.fire("not_a_real_event")
	assert_eq(Achievements.unlocked_count(), 0, "未知事件不解锁任何成就")


func test_unlock_idempotent() -> void:
	watch_signals(Achievements)
	Achievements.unlock("gun")
	Achievements.unlock("gun")
	assert_signal_emit_count(Achievements, "achievement_unlocked", 1, "重复解锁只发一次信号")


func test_item_poll_unlocks() -> void:
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var player = main.get_node("World").get_player()
	player.get_node("PlayerInventory").pickup("log", 1)
	Achievements._reset_for_test()
	Achievements._poll_items()
	assert_true(Achievements.is_unlocked("first_wood"), "拿到木头该解锁'伐木工'")


func test_item_any_unlocks_on_any_match() -> void:
	# 钓到任意一种鱼就解锁"渔获"
	var main = MainScene.instantiate(); add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var player = main.get_node("World").get_player()
	player.get_node("PlayerInventory").pickup("tuna", 1)   # 鱼列表里的一种
	Achievements._reset_for_test()
	Achievements._poll_items()
	assert_true(Achievements.is_unlocked("fish"), "拿到任一种鱼该解锁'渔获'")


func test_player_death_event() -> void:
	Achievements.fire("player_death")
	assert_true(Achievements.is_unlocked("first_death"), "倒下该解锁'哎呀'")


func test_save_load_roundtrip() -> void:
	Achievements.unlock("diamond")
	Achievements._save()
	Achievements._reset_for_test()
	assert_false(Achievements.is_unlocked("diamond"), "reset 后内存清空")
	Achievements._load()
	assert_true(Achievements.is_unlocked("diamond"), "重读盘该恢复解锁")
