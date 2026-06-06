# 按测速结果算预加载半径: 快机大、慢机小、网页封顶、坏输入不崩.
extends GutTest

const LoadPlanner = preload("res://scripts/world/load_planner.gd")


func test_fast_machine_big_radius():
	# 2ms/chunk 很快 → 半径吃满桌面上限
	var r := LoadPlanner.plan_view_radius(2.0, false, 4)
	assert_eq(r, LoadPlanner.MAX_RADIUS_DESKTOP, "快桌面机吃满桌面上限")


func test_slow_machine_min_radius():
	# 400ms/chunk 很慢 → 回到下限
	assert_eq(LoadPlanner.plan_view_radius(400.0, false, 4), LoadPlanner.MIN_RADIUS, "慢机回到最小")


func test_web_capped():
	# 网页就算快也封顶在 web 上限内
	var r := LoadPlanner.plan_view_radius(2.0, true, 8)
	assert_between(r, LoadPlanner.MIN_RADIUS, LoadPlanner.MAX_RADIUS_WEB, "网页 ≤ web 上限")


func test_bad_input_safe():
	# per=0/负 不崩, 结果仍在范围
	assert_between(LoadPlanner.plan_view_radius(0.0, false, 1), LoadPlanner.MIN_RADIUS, LoadPlanner.MAX_RADIUS_DESKTOP, "per=0 安全")
	assert_between(LoadPlanner.plan_view_radius(-5.0, false, 1), LoadPlanner.MIN_RADIUS, LoadPlanner.MAX_RADIUS_DESKTOP, "per<0 安全")
