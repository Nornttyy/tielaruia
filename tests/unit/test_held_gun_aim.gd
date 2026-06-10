# 枪面向鼠标: held_item.aim_gun 让枪绕中心转到瞄准角度, 朝左半边竖直翻转防倒置.
extends GutTest

const HeldItemScript = preload("res://scripts/player/held_item.gd")


func _make_held() -> Sprite2D:
	var h: Sprite2D = HeldItemScript.new()
	add_child_autofree(h)
	h._has_item = true                 # 绕过 inventory 绑定, 直接当"手上有枪"
	h.texture = PlaceholderTexture2D.new()
	return h


func test_aim_right_points_at_angle_not_flipped() -> void:
	var h := _make_held()
	h.aim_gun(0.0)                      # 朝右
	assert_true(h.centered, "枪瞄准用居中支点")
	assert_almost_eq(h.rotation, 0.0, 0.001, "朝右 → rotation=0")
	assert_gt(h.scale.y, 0.0, "朝右不竖直翻转")


func test_aim_left_flips_vertically() -> void:
	var h := _make_held()
	h.aim_gun(PI)                       # 朝左
	assert_almost_eq(h.rotation, PI, 0.001, "朝左 → rotation=PI")
	assert_lt(h.scale.y, 0.0, "朝左竖直翻转 (scale.y 取负) 防枪倒置")


func test_switch_back_resets_pivot() -> void:
	var h := _make_held()
	h.aim_gun(0.0)
	assert_true(h.centered, "瞄准时居中")
	h._show_for(0.0)                    # 任何普通显示 (挥/挖/放) 都该退出枪瞄准态
	assert_false(h.centered, "切回普通显示 → 恢复底端支点 (非居中)")
