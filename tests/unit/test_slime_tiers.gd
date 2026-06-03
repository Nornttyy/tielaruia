extends GutTest

const Slime = preload("res://scripts/entities/slime.gd")
const SlimeScene = preload("res://scenes/entities/slime.tscn")  # 实例测试要场景(带 AnimatedSprite2D 子节点)


func test_color_for_depth_bands():
	var r := RandomNumberGenerator.new()
	r.seed = 1
	# 地表(<8): 绿(0)或蓝(1)
	assert_true(Slime.color_for_depth(0, r) in [0, 1], "地表是绿或蓝")
	# 浅地下 8-80: 蓝(1)
	assert_eq(Slime.color_for_depth(40, r), 1, "浅地下蓝")
	# 深 80-150: 红(2)
	assert_eq(Slime.color_for_depth(120, r), 2, "深地下红")
	# 极深 >=150: 紫(3)
	assert_eq(Slime.color_for_depth(200, r), 3, "极深紫")


func test_surface_green_majority():
	# 地表大量采样: 绿应占多数 (~70%) 但也有蓝
	var r := RandomNumberGenerator.new()
	r.seed = 99
	var green := 0
	for i in 400:
		if Slime.color_for_depth(0, r) == 0:
			green += 1
	assert_gt(green, 220, "地表绿占多数 (>55%%), 实际 %d/400" % green)
	assert_lt(green, 340, "地表也有蓝 (<85%%), 实际 %d/400" % green)


func test_setup_applies_tier_and_size():
	var s = SlimeScene.instantiate()
	s.setup(3, 2)   # 紫 + 大 (在 add_child/_ready 之前调)
	add_child_autofree(s)
	await wait_frames(1)
	assert_eq(s.color_tier, 3, "紫")
	assert_eq(s.size, 2, "大")
	# 紫大: HP = 25 * 2.8(紫) * 1.5(大) * 难度(普通1) ≈ 105, 远大于基础蓝中 25
	assert_gt(s.max_health, 80, "紫大史莱姆血厚, 实际 %d" % s.max_health)
	assert_gt(s.contact_damage, 6, "紫大接触伤 > 基础6, 实际 %d" % s.contact_damage)
	assert_almost_eq(s.sprite.scale.x, 1.5, 0.01, "大史莱姆 scale 1.5")


func test_setup_default_is_blue_medium():
	var s = SlimeScene.instantiate()
	add_child_autofree(s)   # 不调 setup → 默认蓝中 (向后兼容旧 spawn)
	await wait_frames(1)
	assert_eq(s.color_tier, 1, "默认蓝")
	assert_eq(s.size, 1, "默认中")
	assert_almost_eq(s.sprite.scale.x, 1.0, 0.01, "中 scale 1.0")
