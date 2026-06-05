extends GutTest

const HeldItemScript = preload("res://scripts/player/held_item.gd")


func _make_held() -> Sprite2D:
	var held := Sprite2D.new()
	held.set_script(HeldItemScript)
	add_child_autofree(held)
	# 跳过 _ready 里的 inventory 绑定, 直接强制 visible 让 swing 函数生效
	held.visible = true
	# 提供一个最小 texture 避免 visible 被 _refresh 拒绝 (但我们不会调 _refresh)
	return held


func test_play_swing_directional_target_right():
	var held: Sprite2D = _make_held()
	# 用户改 sweep arc 180°→220° (half = 110°).
	# 目标朝正右 (target_angle=0), facing_right. base = 1 * (0+PI/2) = PI/2
	# start = PI/2 - 110° = -20°
	held.play_swing_directional(0.0)
	assert_almost_eq(held.rotation, deg_to_rad(-20.0), 0.05,
		"facing_right + mouse_right: 起手 base-110° = -20°")


func test_play_swing_directional_target_up():
	var held: Sprite2D = _make_held()
	# 目标朝正上 (-PI/2). mouse_on_right=true. base = 0, start = 0 - 110° = -110°
	held.play_swing_directional(-PI / 2.0)
	assert_almost_eq(held.rotation, deg_to_rad(-110.0), 0.05,
		"target=正上时, 起手 base-110° = -110°")


func test_play_swing_directional_target_left_flips_facing():
	var held: Sprite2D = _make_held()
	# 目标朝正左 (PI). facing_left, s=-1.
	# base = -1 * (PI + PI/2) = -3PI/2 ≈ wrapf → PI/2
	# start = PI/2 - 110° = -20°
	held.play_swing_directional(PI)
	assert_eq(held._facing_right, false, "mouse 在左时应翻到 facing_left")
	assert_almost_eq(held.rotation, deg_to_rad(-20.0), 0.05,
		"facing_left + target_left: 起手 base-110° = -20°")


func test_play_swing_directional_skips_when_invisible():
	var held: Sprite2D = _make_held()
	held.visible = false
	held.rotation = 0.0
	held.play_swing_directional(PI / 4.0)
	# 不可见时直接 return, rotation 不动
	assert_eq(held.rotation, 0.0, "invisible 时不应动 rotation")


# 剑尖朝鼠标 (戳剑/木剑石剑用): rotation = target_angle + PI/2 → tip dir = (sin rot, -cos rot).
# 验证四个方向的剑尖朝向都对.
func _tip_dir(rot: float) -> Vector2:
	return Vector2(sin(rot), -cos(rot))


func test_play_thrust_tip_right():
	var held: Sprite2D = _make_held()
	held.play_thrust(0.0)   # 鼠标在右
	var d: Vector2 = _tip_dir(held.rotation)
	assert_almost_eq(d.x, 1.0, 0.05, "剑尖朝右 x≈1")
	assert_almost_eq(d.y, 0.0, 0.05, "剑尖朝右 y≈0")


func test_play_thrust_tip_up():
	var held: Sprite2D = _make_held()
	held.play_thrust(-PI / 2.0)   # 鼠标在上
	var d: Vector2 = _tip_dir(held.rotation)
	assert_almost_eq(d.x, 0.0, 0.05, "剑尖朝上 x≈0")
	assert_almost_eq(d.y, -1.0, 0.05, "剑尖朝上 y≈-1")


func test_play_thrust_tip_left():
	# 关键 case: 鼠标在左时, 旧公式 s*(target+PI/2) 把旋转反向, 剑尖指右 (bug). 修后应指左.
	var held: Sprite2D = _make_held()
	held.play_thrust(PI)
	assert_eq(held._facing_right, false, "鼠标在左应翻到 facing_left")
	var d: Vector2 = _tip_dir(held.rotation)
	assert_almost_eq(d.x, -1.0, 0.05, "剑尖朝左 x≈-1")
	assert_almost_eq(d.y, 0.0, 0.05, "剑尖朝左 y≈0")


func test_play_thrust_tip_lower_left():
	# 鼠标左下 (target=3PI/4): 旧公式得 rotation=3PI/4 → tip(√2/2,√2/2) 右下 (bug). 修后应左下.
	var held: Sprite2D = _make_held()
	held.play_thrust(3.0 * PI / 4.0)
	var d: Vector2 = _tip_dir(held.rotation)
	assert_almost_eq(d.x, -sqrt(2.0) / 2.0, 0.05, "剑尖左下 x≈-0.707")
	assert_almost_eq(d.y, sqrt(2.0) / 2.0, 0.05, "剑尖左下 y≈+0.707")
