# 床睡觉: 什么时间都能睡 → 躺下 + 挪到床上 + 时间永远 10x; 不自动醒 (按任意键下床); 下床全复位。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE := 6.0


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


func test_sleep_anytime_10x_lies_down_no_autowake() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	TimeOfDay.time = 0.4   # 白天 — 也该能睡 + 10x
	world.sleep_in_bed(Vector2i(5, 5))
	assert_true(world._sleeping, "什么时间都能睡")
	assert_almost_eq(TimeOfDay.time_multiplier, 10.0, 0.01, "在床上时间永远 10x")
	assert_almost_eq(ctx["sprite"].rotation, -PI / 2.0, 0.01, "睡觉动作: 躺下")
	assert_not_null(world._sleep_zzz, "头顶有 Zzz")
	assert_almost_eq(ctx["player"].global_position.x, (5.0 + 1.0) * TILE, 1.5, "玩家挪到床中央 (2格宽床, +1.0=接缝)")
	# 不自动醒 (没按键): 等几帧仍在睡 (10x 时间会跑, 但不该把人叫醒)
	await wait_frames(3)
	assert_true(world._sleeping, "不按键不该醒 (白天也是, 按任意键才下床)")
	world._wake_up()


func test_wake_restores_everything() -> void:
	var ctx: Dictionary = await _setup()
	var world = ctx["world"]
	world.sleep_in_bed(Vector2i(5, 5))
	world._wake_up()
	assert_false(world._sleeping, "下床 → 不睡了")
	assert_almost_eq(TimeOfDay.time_multiplier, 1.0, 0.01, "时间恢复 1x")
	assert_almost_eq(ctx["sprite"].rotation, 0.0, 0.01, "起身: 人物复位")
	assert_null(world._sleep_zzz, "Zzz 消失")
	assert_eq(world.bed_spawn_point, Vector2i(5, 5), "复活点设到床")
