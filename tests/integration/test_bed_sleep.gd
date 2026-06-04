# 床睡觉: 上床 → 躺下 + 挪到床上; 晚上睡快进、白天睡只歇(不秒醒); 下床全复位。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE := 12.0


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
		TimeOfDay.time_multiplier = 1.0
		TimeOfDay.time = 0.35


func test_day_sleep_lies_down_and_no_instant_wake() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	TimeOfDay.time = 0.4   # 白天
	world.sleep_in_bed(Vector2i(5, 5))
	assert_true(world._sleeping, "白天也能躺下")
	assert_almost_eq(TimeOfDay.time_multiplier, 1.0, 0.01, "白天睡不快进 (1x)")
	assert_almost_eq(ctx["sprite"].rotation, -PI / 2.0, 0.01, "睡觉动作: 躺下")
	assert_not_null(world._sleep_zzz, "头顶有 Zzz")
	assert_almost_eq(ctx["player"].global_position.x, (5.0 + 0.5) * TILE, 1.5, "玩家挪到床 x")
	# 关键: 白天睡不该秒醒 (这样才看得到躺下)
	await wait_frames(3)
	assert_true(world._sleeping, "白天睡不该被 is_day 秒醒")
	world._wake_up()


func test_night_sleep_fast_forwards() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	TimeOfDay.time = 0.85   # 夜里
	world.sleep_in_bed(Vector2i(5, 5))
	assert_true(world._sleeping)
	assert_true(world._sleep_fast, "晚上睡 = 快进模式")
	assert_almost_eq(TimeOfDay.time_multiplier, 10.0, 0.01, "晚上睡 10x 快进")
	world._wake_up()


func test_wake_restores_everything() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	TimeOfDay.time = 0.85
	world.sleep_in_bed(Vector2i(5, 5))
	world._wake_up()
	assert_false(world._sleeping, "下床 → 不睡了")
	assert_almost_eq(TimeOfDay.time_multiplier, 1.0, 0.01, "时间恢复 1x")
	assert_almost_eq(ctx["sprite"].rotation, 0.0, 0.01, "起身: 人物复位")
	assert_null(world._sleep_zzz, "Zzz 消失")
	assert_eq(world.bed_spawn_point, Vector2i(5, 5), "复活点设到床")
