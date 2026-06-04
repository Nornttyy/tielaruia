# 床睡觉: 上床 → 时间 10x + 人物躺下 + 头顶 Zzz; 下床 → 全复位。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _setup() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "world": world, "player": player,
		"sprite": player.get_node("AnimatedSprite2D")}


func after_each() -> void:
	if TimeOfDay != null:
		TimeOfDay.time_multiplier = 1.0   # 别污染别的测试


func test_sleep_then_wake() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	var spr = ctx["sprite"]
	# 上床 (同步检查, 不 await — 避开 _process 因白天立刻把人叫醒)
	world.sleep_in_bed(Vector2i(5, 5))
	assert_true(world._sleeping, "上床 → 睡觉中")
	assert_almost_eq(TimeOfDay.time_multiplier, 10.0, 0.01, "时间 10x 加速")
	assert_almost_eq(spr.rotation, -PI / 2.0, 0.01, "睡觉动作: 人物躺下 (转 90°)")
	assert_not_null(world._sleep_zzz, "头顶有 Zzz 提示")
	assert_false(world._sleep_armed, "刚睡下未武装 (等触发的点击松开)")
	assert_eq(world.bed_spawn_point, Vector2i(5, 5), "复活点设到床")
	# 下床
	world._wake_up()
	assert_false(world._sleeping, "下床 → 不睡了")
	assert_almost_eq(TimeOfDay.time_multiplier, 1.0, 0.01, "时间恢复 1x")
	assert_almost_eq(spr.rotation, 0.0, 0.01, "起身: 人物复位")
	assert_null(world._sleep_zzz, "Zzz 消失")
