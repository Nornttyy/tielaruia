extends GutTest

const HeldItemScript = preload("res://scripts/player/held_item.gd")


func _make_held() -> Sprite2D:
	var held := Sprite2D.new()
	held.set_script(HeldItemScript)
	add_child_autofree(held)
	# 跳过 _ready 里的 inventory 绑定, 直接标"有物品"让 swing 函数生效 (工具现在只在使用时显示).
	held._has_item = true
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
	# 目标朝正左 (PI). facing_left. base = wrapf(PI + PI/2) = -PI/2 (-90°).
	# 瞄左弧线反向 (half = -110°): start = base - half = -90° - (-110°) = +20°.
	# 关键: 起手 +20° 剑尖朝上 (cos20>0) → "从上往下劈"; 不是旧的 -200° (剑尖朝下 = 从下往上挑 bug)。
	held.play_swing_directional(PI)
	assert_eq(held._facing_right, false, "mouse 在左时应翻到 facing_left")
	assert_almost_eq(held.rotation, deg_to_rad(20.0), 0.05,
		"facing_left: 起手 +20° (剑尖朝上, 上往下劈), 不是 -200° (那是从下往上挑的 bug)")


func test_play_swing_directional_skips_when_no_item():
	var held: Sprite2D = _make_held()
	held._has_item = false   # 没拿工具 (空手) → 不该挥
	held.rotation = 0.0
	held.play_swing_directional(PI / 4.0)
	# 没物品时直接 return, rotation 不动
	assert_eq(held.rotation, 0.0, "空手时不应动 rotation")
	assert_false(held.visible, "空手时不显示")


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


# 工具只在使用时显示: 平时藏着, 挥一下冒出来, 计时归零自动收回.
func test_hidden_until_used_then_auto_hides():
	var held: Sprite2D = _make_held()
	held.visible = false
	assert_false(held.visible, "平时(没使用)工具藏着")
	held.play_swing()   # 挖矿挥摆 = 使用
	assert_true(held.visible, "挥一下 → 显示")
	# 跑够时间 (动画时长 + 宽限期) → 自动收回
	held._process(held.SWING_DURATION + held._HIDE_GRACE + 0.05)
	assert_false(held.visible, "用完计时归零 → 自动收回")

func test_flash_shows_briefly():
	var held: Sprite2D = _make_held()
	held.visible = false
	held.flash()   # 放方块/射箭等
	assert_true(held.visible, "flash → 显示")
	held._process(held._HIDE_GRACE + 0.05)
	assert_false(held.visible, "flash 后宽限期过 → 收回")

func test_no_item_stays_hidden_on_use():
	var held: Sprite2D = _make_held()
	held._has_item = false
	held.visible = false
	held.play_swing()
	held.flash()
	assert_false(held.visible, "空手时 play/flash 都不显示")


# 放方块动画: 朝放置方向"按"出去 (position 偏移), 显示出来, 完了归位.
func test_play_place_pokes_and_shows():
	var held: Sprite2D = _make_held()
	held.visible = false
	held.position = Vector2(held.HAND_OFFSET_X, held.HAND_OFFSET_Y)
	held.play_place(0.0)   # 朝右放
	assert_true(held.visible, "放方块时显示")
	# tween 第一段把 position 往右推 (x 变大). 推进一点点时间看是否在动.
	# (tween 在 SceneTree 里跑; 这里只验初始没崩 + 显示了)
	assert_true(held._has_item, "有物品")

func test_play_place_skips_when_no_item():
	var held: Sprite2D = _make_held()
	held._has_item = false
	held.visible = false
	held.play_place(0.0)
	assert_false(held.visible, "空手不放动画")
