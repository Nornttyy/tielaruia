# 睡觉视觉: 睡觉时藏手持物 + 躺姿绕身体中心(居中不歪); 醒来复位精灵站立配置 + 恢复手持物.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _boot() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"world": world, "player": player,
		"sprite": player.get_node("AnimatedSprite2D"),
		"held": player.get_node("HeldItem")}


func after_each() -> void:
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 1.0


func test_sleep_hides_held_item_then_wake_restores() -> void:
	var ctx = await _boot()
	var player = ctx["player"]
	var held = ctx["held"]
	# 拿个木剑. 工具只在"使用时"显示 (用户要求): 挥一下才冒出来.
	var inv = player.get_node("PlayerInventory")
	inv.pickup("wood_sword", 1)
	inv.hotbar_selected = 0
	held._refresh()
	held.play_swing()   # 使用 → 显示
	assert_true(held.visible, "前置: 挥剑(使用)时手持物可见")
	ctx["world"].sleep_in_bed(Vector2i(5, 5))
	assert_false(held.visible, "睡觉时手持物应藏起来")
	ctx["world"]._wake_up()
	# 醒来: 不强制显示 (工具只在使用时显示), 但还拿着剑 → 再挥一下能正常显示
	assert_true(held._has_item, "醒来后还拿着剑 (_has_item)")
	held.play_swing()
	assert_true(held.visible, "醒来后再挥一下 → 正常显示 (没被睡觉弄坏)")


func test_sleep_pose_centered_then_wake_restores_stand_config() -> void:
	var ctx = await _boot()
	var spr = ctx["sprite"]
	# 站立默认配置 (跟 player.tscn 一致)
	assert_false(spr.centered, "前置: 站立 centered=false")
	ctx["world"].sleep_in_bed(Vector2i(5, 5))
	# 躺下: centered=true 让旋转绕中心 (不甩到角点 = 不歪)
	assert_true(spr.centered, "睡觉躺下 centered=true (绕身体中心转, 不歪)")
	assert_almost_eq(spr.rotation, -PI / 2.0, 0.01, "躺下")
	ctx["world"]._wake_up()
	# 起身复位成站立配置
	assert_false(spr.centered, "醒来 centered 复位 false")
	assert_almost_eq(spr.rotation, 0.0, 0.01, "醒来站直")
	assert_eq(spr.position, Vector2(0, -30), "醒来 sprite position 复位 (0,-30)")
	assert_eq(spr.offset, Vector2(-6, 0), "醒来 offset 复位 (-6,0)")
