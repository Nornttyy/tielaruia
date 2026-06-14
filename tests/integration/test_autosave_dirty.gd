# 自动存档脏标记: 有变化(背包/血)才标 dirty; 光走路不标 → 不触发每秒全量存档 → 不卡 (用户报卡顿)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(4)   # 等 _wire_player (call_deferred) 接好信号
	return main


func test_inventory_change_marks_dirty():
	var main = await _boot()
	var inv: Node = main.get_node("World").get_player().get_node("PlayerInventory")
	main._save_dirty = false
	inv.inventory.add("dirt", 1)
	inv.inventory_changed.emit()   # 挖/放/捡物都会发这个
	await wait_frames(1)
	assert_true(main._save_dirty, "背包变化 → 标记该存档")


func test_walking_does_not_mark_dirty():
	var main = await _boot()
	var player = main.get_node("World").get_player()
	# 血/蓝拉满, 免得自然回血/回蓝发信号干扰
	var hp = player.get_node_or_null("PlayerHealth")
	if hp != null and "current_health" in hp and "MAX_HEALTH" in hp:
		hp.current_health = hp.MAX_HEALTH
	var mana = player.get_node_or_null("PlayerMana")
	if mana != null and "current_mana" in mana and "MAX_MANA" in mana:
		mana.current_mana = mana.MAX_MANA
	await wait_frames(3)
	main._save_dirty = false   # 清零后开始"走路"
	Input.action_press("move_right")
	await wait_frames(25)
	Input.action_release("move_right")
	assert_false(main._save_dirty, "光走路啥都没改 → 不标记存档 (不卡)")


func test_mark_save_dirty_sets_flag():
	var main = await _boot()
	main._save_dirty = false
	main.mark_save_dirty()
	assert_true(main._save_dirty, "mark_save_dirty 置 true")
