# 触屏控制 UI (手机/iPad 浏览器版).
# 左下: TouchJoystick (拖动方向 → move + jump).
# 右下: 3 个圆形按钮 (击 / 用 / 跳), 触屏直接注入 primary/secondary/jump action.
#
# 只在 mobile/小屏 出现 (main.gd 判断后才实例化).
# 屏中其他区域 (摇杆/按钮外) 触摸 → 经 emulate_mouse_from_touch 当成鼠标用于瞄准.
extends CanvasLayer

const TouchJoystick = preload("res://scripts/ui/touch_joystick.gd")

const BTN_RADIUS := 52.0           # 按钮可点半径
const BTN_SPACING := 18.0          # 按钮之间间距
const EDGE_MARGIN := 36.0          # 距屏幕边
const VIEWPORT_SIZE := Vector2(1280, 720)


func _ready() -> void:
	layer = 60   # 在 HUD (50) 之上
	_build_ui()


func _build_ui() -> void:
	# 触屏 UI 用 viewport size 锚定底部, resize 时 Control 跟着调.
	# 左下: joystick
	var joy: Control = TouchJoystick.new()
	joy.name = "Joystick"
	# 锚定左下角. 用 anchors 让 resize 时跟着跑.
	joy.anchor_left = 0.0
	joy.anchor_top = 1.0
	joy.anchor_right = 0.0
	joy.anchor_bottom = 1.0
	var joy_radius: float = TouchJoystick.RADIUS
	joy.offset_left = EDGE_MARGIN
	joy.offset_top = -(joy_radius * 2.0 + EDGE_MARGIN)
	joy.offset_right = EDGE_MARGIN + joy_radius * 2.0
	joy.offset_bottom = -EDGE_MARGIN
	add_child(joy)

	# 右下 3 按钮 (从右到左: 跳 / 用 / 击, 主按钮 "击" 最靠右好按)
	_add_action_button("BtnAttack", "primary", "击", 0, Color(1.0, 0.45, 0.35))
	_add_action_button("BtnUse", "secondary", "用", 1, Color(0.45, 0.85, 0.45))
	_add_action_button("BtnJump", "jump", "跳", 2, Color(0.45, 0.65, 1.0))


# index 0 = 最右 (主), 1 = 中, 2 = 最左
func _add_action_button(node_name: String, action: String, label: String, index: int, color: Color) -> void:
	var btn := Button.new()
	btn.name = node_name
	btn.text = label
	btn.flat = true
	# 圆形可点区: 用 custom_minimum_size + 自画 (圆 + 文字).
	# 用普通 Button 接 button_down/up 信号 (TouchScreenButton 在 mouse-emulated 模式下也 ok, 但 Button 跟键盘事件兼容更好)
	btn.custom_minimum_size = Vector2(BTN_RADIUS * 2.0, BTN_RADIUS * 2.0)
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	# 右起 offset: index 0 最右, index 1 往左一档...
	var x_offset: float = -(EDGE_MARGIN + (BTN_RADIUS * 2.0 + BTN_SPACING) * (index + 1) - BTN_SPACING)
	btn.offset_left = x_offset
	btn.offset_right = x_offset + BTN_RADIUS * 2.0
	# 跳/用 排第二行 (按钮多了挤), 击 单独最低. 简化: 都同一行, 用 horizontal 排.
	btn.offset_top = -(BTN_RADIUS * 2.0 + EDGE_MARGIN)
	btn.offset_bottom = -EDGE_MARGIN
	# 圆形外观 (StyleBoxFlat 圆角 = 半径)
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(color.r, color.g, color.b, 0.55)
	sb_normal.corner_radius_top_left = int(BTN_RADIUS)
	sb_normal.corner_radius_top_right = int(BTN_RADIUS)
	sb_normal.corner_radius_bottom_left = int(BTN_RADIUS)
	sb_normal.corner_radius_bottom_right = int(BTN_RADIUS)
	sb_normal.border_width_left = 2
	sb_normal.border_width_top = 2
	sb_normal.border_width_right = 2
	sb_normal.border_width_bottom = 2
	sb_normal.border_color = Color(1, 1, 1, 0.7)
	btn.add_theme_stylebox_override("normal", sb_normal)
	var sb_pressed := sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(color.r, color.g, color.b, 0.85)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	btn.add_theme_stylebox_override("hover", sb_normal)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	btn.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1.0))
	btn.add_theme_font_size_override("font_size", 24)
	# 按下/松开 → action_press/release. 按住一直按时长效.
	btn.button_down.connect(func(): Input.action_press(action))
	btn.button_up.connect(func(): Input.action_release(action))
	add_child(btn)


# 检测是否手机/平板, 给 main.gd 调用决定是否实例化.
static func should_show() -> bool:
	# 1. OS feature "mobile" = iOS/Android 原生 (HTML5 export 不算)
	if OS.has_feature("mobile"):
		return true
	# 2. HTML5 + 小屏: 视口宽 ≤ 900 或 触屏类型 (iPad/手机浏览器)
	if OS.get_name() == "Web":
		# Web 没法直接查触屏, 用窗口宽近似: 手机/iPad 竖屏宽都 ≤ 900
		# 注: window_get_size 返 Vector2i, 用 Vector2i 接 (老 Vector2 严格类型可能炸)
		var vp_size: Vector2i = DisplayServer.window_get_size()
		if vp_size.x <= 900 or vp_size.y <= 700:
			return true
		# 主流台式机宽 > 900, 这里 false
		return false
	# 3. 其它平台 (Linux/Mac/Windows 桌面) 默认不显
	return false
