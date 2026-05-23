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
	# 目标朝正右 (target_angle=0), facing_right=true 默认. base = 1 * (0+PI/2) = PI/2
	# start = PI/2 - 45° = PI/4
	held.play_swing_directional(0.0)
	assert_almost_eq(held.rotation, PI / 2.0 - deg_to_rad(45.0), 0.05,
		"facing_right + mouse_right: 起手应在 PI/4")


func test_play_swing_directional_target_up():
	var held: Sprite2D = _make_held()
	# 目标朝正上 (target_angle=-PI/2). cos(-PI/2)≈0 → mouse_on_right=true, _facing_right=true
	# base = 1 * (-PI/2 + PI/2) = 0, start = -PI/4
	held.play_swing_directional(-PI / 2.0)
	assert_almost_eq(held.rotation, -PI / 4.0, 0.05,
		"target=正上时, 起手应在 -PI/4")


func test_play_swing_directional_target_left_flips_facing():
	var held: Sprite2D = _make_held()
	# 目标朝正左 (target_angle=PI). cos(PI)=-1 → mouse_on_right=false
	# 函数会调 set_facing(false), 但 set_facing 内部 _facing_right 翻面 + position 调
	# 翻面后 s=-1, base = -1 * (PI + PI/2) = -3PI/2 (等价于 PI/2)
	# start = PI/2 - PI/4 = PI/4
	held.play_swing_directional(PI)
	assert_eq(held._facing_right, false, "mouse 在左时应翻到 facing_left")
	# 注意: rotation 值跟 mouse_on_right 那个 case 一样, 但 scale.x 不同, 视觉表现镜像
	assert_almost_eq(held.rotation, PI / 4.0, 0.05,
		"facing_left + target_left: 起手 PI/4 (镜像后是 upper-left)")


func test_play_swing_directional_skips_when_invisible():
	var held: Sprite2D = _make_held()
	held.visible = false
	held.rotation = 0.0
	held.play_swing_directional(PI / 4.0)
	# 不可见时直接 return, rotation 不动
	assert_eq(held.rotation, 0.0, "invisible 时不应动 rotation")
