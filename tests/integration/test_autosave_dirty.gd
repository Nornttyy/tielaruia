# 自动存档脏标记: 有变化(背包/血)才标 dirty; 光走路不标 → 不触发每秒全量存档 → 不卡 (用户报卡顿)。
# 只 boot 一次世界 (一个 test 里顺序验证全部), 省内存 — 多次 boot 沙盒会 OOM。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_dirty_flag_behavior():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(4)   # 等 _wire_player (call_deferred) 接好信号
	var player = main.get_node("World").get_player()
	var inv: Node = player.get_node("PlayerInventory")

	# 1) mark_save_dirty 置 true
	main._save_dirty = false
	main.mark_save_dirty()
	assert_true(main._save_dirty, "mark_save_dirty 置 true")

	# 2) 背包变化 (挖/放/捡物都发这个信号) → dirty
	main._save_dirty = false
	inv.inventory.add("dirt", 1)
	inv.inventory_changed.emit()
	await wait_frames(1)
	assert_true(main._save_dirty, "背包变化 → 标记该存档")

	# 3) 光走路 (血/蓝拉满免回血信号干扰) → 不 dirty → 不触发存档 → 不卡
	var hp = player.get_node_or_null("PlayerHealth")
	if hp != null and "current_health" in hp and "MAX_HEALTH" in hp:
		hp.current_health = hp.MAX_HEALTH
	var mana = player.get_node_or_null("PlayerMana")
	if mana != null and "current_mana" in mana and "MAX_MANA" in mana:
		mana.current_mana = mana.MAX_MANA
	await wait_frames(3)
	main._save_dirty = false
	Input.action_press("move_right")
	await wait_frames(25)
	Input.action_release("move_right")
	assert_false(main._save_dirty, "光走路啥都没改 → 不标记存档 (不卡)")
