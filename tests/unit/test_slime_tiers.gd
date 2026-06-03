extends GutTest

const Slime = preload("res://scripts/entities/slime.gd")


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
