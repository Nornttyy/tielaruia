# 拖尾光弧/突刺 FX 验收: 划完会自己消失 (寿命 = sweep + fade)。
extends GutTest

const SlashScene = preload("res://scenes/fx/slash_trail.tscn")


func test_arc_self_frees() -> void:
	var fx = SlashScene.instantiate()
	add_child_autofree(fx)
	fx.setup_arc(0.0, PI, 26.0, Color(1, 1, 1, 1), 0.2)
	# 跑够长 (0.2 sweep + 0.14 fade = 0.34s) 应触发 queue_free (手动跑帧不立即销毁, 查标记)
	for i in 20:
		fx._process(0.03)
	assert_true(fx.is_queued_for_deletion(), "光弧划完应自己消失")


func test_line_self_frees() -> void:
	var fx = SlashScene.instantiate()
	add_child_autofree(fx)
	fx.setup_line(0.0, 30.0, Color(1, 0.8, 0.4, 1))
	for i in 20:
		fx._process(0.03)
	assert_true(fx.is_queued_for_deletion(), "突刺 streak 应自己消失")


func test_effects_spawn_no_crash() -> void:
	# Effects 三个新方法能跑不崩 (FX 丢到 current_scene 兜底)
	Effects.spawn_slash(Vector2(50, 50), 0.0, PI, 26.0, Color(0.8, 0.9, 1.0), 0.2)
	Effects.spawn_thrust_streak(Vector2(50, 50), 0.0, 30.0, Color(1, 0.8, 0.4))
	Effects.spawn_melee_hit(Vector2(50, 50), Color(1, 1, 1))
	assert_true(true, "三个新特效方法不崩")
