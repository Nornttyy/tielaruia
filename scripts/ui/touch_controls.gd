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
const AIM_REACH_PX := 110.0        # 准星离玩家(屏幕)的距离 (瞄准摇杆控方向)

var _aim_joy: Control = null        # 右下瞄准摇杆 (控制准星)
var _attack_btn: Button = null      # "击"钮: 显示手里物品图标, 点一下使用
var _aim_dir: Vector2 = Vector2(1.0, 0.0)   # 当前瞄准方向 (默认朝右), 摇杆更新


func _ready() -> void:
	layer = 60   # 在 HUD (50) 之上
	_build_ui()


func _process(_delta: float) -> void:
	_update_attack_icon()   # "击"钮跟着选中物品换图标
	_update_aim()           # 瞄准摇杆 → 把虚拟鼠标钉到准星处


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

	# 右下角: 瞄准摇杆 (拖动 → 准星朝那方向; 跳由左摇杆上推包办, 省掉跳钮)
	_aim_joy = TouchJoystick.new()
	_aim_joy.name = "AimJoystick"
	_aim_joy.aim_mode = true
	var aim_r: float = TouchJoystick.RADIUS
	_aim_joy.anchor_left = 1.0
	_aim_joy.anchor_top = 1.0
	_aim_joy.anchor_right = 1.0
	_aim_joy.anchor_bottom = 1.0
	_aim_joy.offset_left = -(aim_r * 2.0 + EDGE_MARGIN)
	_aim_joy.offset_top = -(aim_r * 2.0 + EDGE_MARGIN)
	_aim_joy.offset_right = -EDGE_MARGIN
	_aim_joy.offset_bottom = -EDGE_MARGIN
	add_child(_aim_joy)
	# 击 (主): 显示手里物品图标, 点一下使用 (text="" → 只有图标). 放瞄准摇杆左边。
	_add_action_button("BtnAttack", "primary", "", 0, Color(1.0, 0.45, 0.35))
	_attack_btn = get_node_or_null("BtnAttack")
	if _attack_btn != null:
		_attack_btn.expand_icon = true   # 物品图标填满按钮 (像素图 NEAREST 不糊)
	# 用 (放方块/副操作) + 背包 + 丢 — 都用图标, 不要字 (用户要求)
	_add_action_button("BtnUse", "secondary", "", 1, Color(0.45, 0.85, 0.45))
	_add_action_button("BtnBag", "interact", "", 0, Color(0.95, 0.78, 0.4), 1)
	_add_action_button("BtnDrop", "drop_item", "", 1, Color(0.7, 0.7, 0.75), 1)
	_set_btn_icon("BtnUse", _glyph_icon("use"))
	_set_btn_icon("BtnBag", _glyph_icon("bag"))
	_set_btn_icon("BtnDrop", _glyph_icon("drop"))
	# 右上角: 暂停
	_add_pause_button()


# index 0 = 最右 (主), 1 = 中, 2 = 最左. row 0 = 最下排, 1 = 上一排.
func _add_action_button(node_name: String, action: String, label: String, index: int, color: Color, row: int = 0) -> void:
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
	# 右起 offset: index 0 最右, index 1 往左一档... 整体往左让出右下瞄准摇杆的位
	var aim_clear: float = TouchJoystick.RADIUS * 2.0 + BTN_SPACING
	var x_offset: float = -(EDGE_MARGIN + aim_clear + (BTN_RADIUS * 2.0 + BTN_SPACING) * (index + 1) - BTN_SPACING)
	btn.offset_left = x_offset
	btn.offset_right = x_offset + BTN_RADIUS * 2.0
	# row 抬高一排: 每排高 = 按钮直径 + 间距
	var row_h: float = BTN_RADIUS * 2.0 + BTN_SPACING
	btn.offset_top = -(BTN_RADIUS * 2.0 + EDGE_MARGIN) - row * row_h
	btn.offset_bottom = -EDGE_MARGIN - row * row_h
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


# 右上角暂停钮. main 用事件方式收 ui_pause (Input.action_press 不触发) → 注入动作事件。
func _add_pause_button() -> void:
	var r := 32.0
	var btn := Button.new()
	btn.name = "BtnPause"
	btn.text = ""
	btn.icon = _glyph_icon("pause")
	btn.expand_icon = true
	btn.flat = true
	btn.anchor_left = 1.0
	btn.anchor_top = 0.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 0.0
	btn.offset_left = -(EDGE_MARGIN + r * 2.0)
	btn.offset_right = -EDGE_MARGIN
	btn.offset_top = EDGE_MARGIN
	btn.offset_bottom = EDGE_MARGIN + r * 2.0
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.2, 0.6)
	sb.set_corner_radius_all(int(r))
	sb.set_border_width_all(2)
	sb.border_color = Color(1, 1, 1, 0.6)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var sbp := sb.duplicate() as StyleBoxFlat
	sbp.bg_color = Color(0.15, 0.18, 0.3, 0.9)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.95))
	btn.add_theme_font_size_override("font_size", 18)
	btn.pressed.connect(_on_pause_pressed)
	add_child(btn)


func _on_pause_pressed() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_pause"
	ev.pressed = true
	Input.parse_input_event(ev)


# "击"钮跟着当前选中的物品换图标 (用户: 不要"击"字, 只要图标; 没物品就空着)。
func _update_attack_icon() -> void:
	if _attack_btn == null:
		return
	_attack_btn.icon = _held_item_icon()
	_attack_btn.text = ""


func _held_item_icon() -> Texture2D:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null:
		return null
	var pinv: Node = p.get_node_or_null("PlayerInventory")
	if pinv == null or not pinv.has_method("current_hotbar_slot"):
		return null
	var slot = pinv.current_hotbar_slot()
	if slot == null:
		return null
	if typeof(ArtCache) == TYPE_NIL or not ArtCache.has_method("get_inventory_icon"):
		return null
	return ArtCache.get_inventory_icon(String(slot.item_id))


# 瞄准摇杆 → 把虚拟鼠标钉在 (玩家屏幕位置 + 瞄准方向 × 距离): 现有所有瞄准 (挖/放/弓) + 准星
# 都按鼠标走, 所以这一招就让它们全跟着摇杆. 摇杆没推时保持上次方向 (准星不乱跳)。
func _update_aim() -> void:
	if _aim_joy == null or not _aim_joy.has_method("aim_vector"):
		return
	var pa: Node = _player_action()
	if _ui_blocking():
		# 背包/箱子开着 或 暂停: 不抢鼠标 + 清掉瞄准覆盖 (让玩家正常拖物品/点菜单)
		if pa != null:
			pa.mouse_world_override = null
		return
	var av: Vector2 = _aim_joy.aim_vector()
	if av.length() > 0.28:   # 超过死区才更新方向
		_aim_dir = av.normalized()
	# 直接把瞄准方向喂给 PlayerAction (弓/枪/法杖/剑都读 mouse_world_override)。
	# 网页(HTML5) Input.warp_mouse 不生效 → 虚拟鼠标卡在"击"钮角落 → 武器永远朝一个方向 (用户报)。
	# 用世界坐标朝瞄准方向投射 (距离只决定方向, 多远无所谓)。
	if pa != null:
		var pn := get_tree().get_first_node_in_group("player") as Node2D
		if pn != null:
			pa.mouse_world_override = pn.global_position + _aim_dir * AIM_REACH_PX
	# 仍 warp 一下 (能用的平台顺带更新真准星; 网页失效也无妨)
	var anchor: Vector2 = _player_screen_pos()
	Input.warp_mouse(anchor + _aim_dir * AIM_REACH_PX)


func _player_action() -> Node:
	var p: Node = get_tree().get_first_node_in_group("player")
	return p.get_node_or_null("PlayerAction") if p != null else null


func _player_screen_pos() -> Vector2:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p != null and p is Node2D:
		return (p as Node2D).get_global_transform_with_canvas().origin
	return get_viewport().get_visible_rect().size * 0.5


# 背包/箱子开着 或 游戏暂停 → 别抢鼠标 (玩家要用鼠标拖物品/点菜单)。
func _ui_blocking() -> bool:
	if get_tree().paused:
		return true
	var c: Node = get_tree().get_first_node_in_group("crafting_panel")
	if c != null and c.has_method("is_open") and c.is_open():
		return true
	var ch: Node = get_tree().get_first_node_in_group("chest_panel")
	if ch != null and ch.has_method("is_open") and ch.is_open():
		return true
	return false


# 给某按钮设图标 (填满 + 清文字)。
func _set_btn_icon(node_name: String, tex: Texture2D) -> void:
	var b: Button = get_node_or_null(node_name)
	if b != null:
		b.icon = tex
		b.expand_icon = true
		b.text = ""


func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and xx < img.get_width() and yy >= 0 and yy < img.get_height():
				img.set_pixel(xx, yy, col)


# 程序画的简单白色像素图标 (按钮用). kind: use(方块) / bag(箱子) / drop(下箭头) / pause(双竖杠)。
func _glyph_icon(kind: String) -> ImageTexture:
	var s := 24
	var img := Image.create(s, s, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var w := Color(1, 1, 1, 0.95)
	match kind:
		"use":     # 放方块: 一个实心小方块
			_fill_rect(img, 6, 6, 12, 12, w)
		"bag":     # 背包/箱子: 箱身 + 盖
			_fill_rect(img, 7, 5, 10, 3, w)     # 盖
			_fill_rect(img, 5, 8, 14, 12, w)    # 箱身
			_fill_rect(img, 11, 11, 2, 4, w)    # 锁扣 (深色靠透明做不出, 留白点意思)
		"drop":    # 丢: 向下箭头 (杆 + 三角)
			_fill_rect(img, 10, 3, 4, 11, w)    # 杆
			for i in range(7):                  # 三角 (越往下越窄)
				var hw := 7 - i
				_fill_rect(img, 12 - hw, 14 + i, hw * 2, 1, w)
		"pause":   # 暂停: 两条竖杠
			_fill_rect(img, 6, 5, 4, 14, w)
			_fill_rect(img, 14, 5, 4, 14, w)
	return ImageTexture.create_from_image(img)


# 检测是否手机/平板, 给 main.gd 调用决定是否实例化.
static func should_show() -> bool:
	# 1. OS feature "mobile" = iOS/Android 原生 (HTML5 export 不算)
	if OS.has_feature("mobile"):
		return true
	# 2. HTML5: 查"真有触屏"才显 (用 navigator.maxTouchPoints / ontouchstart)。
	#    旧版用窗口大小猜 → 桌面浏览器窗口稍小 (高≤700) 就被误判成手机, 触屏准星抢鼠标 →
	#    弓/武器只朝一个方向 (用户报: Mac+鼠标却中招). Mac/桌面无触屏 → maxTouchPoints=0 → 不显。
	if OS.get_name() == "Web":
		var has_touch = JavaScriptBridge.eval(
			"((navigator.maxTouchPoints||0) > 0) || ('ontouchstart' in window)", true)
		return bool(has_touch)
	# 3. 其它平台 (Linux/Mac/Windows 桌面) 默认不显
	return false
