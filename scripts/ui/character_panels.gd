# 选角色 + 捏人 两个面板 (代码动态建)。main_menu 实例化为子节点。
# 选角色: 列表 + 捏新角色 + 返回。捏人: Task 2 实现。
extends Control

signal character_chosen   # 选了角色 (current 已设), main_menu 去开世界选择
signal closed             # 返回主菜单

const CharacterData = preload("res://scripts/save/character_data.gd")
const PlayerArt = preload("res://scripts/art/player_art.gd")
const UIStyle = preload("res://scripts/ui/ui_style.gd")

var _select_panel: Panel
var _select_title: Label
var _list: VBoxContainer
var _creator_panel: Panel
var _preview: AnimatedSprite2D
var _name_edit: LineEdit
var _chest_row: HBoxContainer
var _chest_slider: HSlider
var _step_vals: Dictionary = {}
var _named_refresh: Dictionary = {}   # key → Callable, 给"显中文名"的款式选择器刷新用
var _appearance: Dictionary = {}
# 捏人当前是"改造现有角色"(非空 = 正在改的角色名, 保存时覆盖它) 还是"新建"(空 = 重名才加2/3)。
# 没这个标志的话, 想给自己角色改样子保存 → 每次都自动改名加2/3 → 角色越堆越多 (用户报)。
var _editing_name: String = ""

# 自由调色: 选部位 (◀ ▶) + 3 滑杆 (色相/饱和度/亮度), 任意颜色随便调。
const _COLOR_PARTS := [["皮肤", "skin_color"], ["头发", "hair_color"], ["衬衫", "shirt_color"], ["裤子", "pants_color"], ["鞋", "shoe_color"], ["眼珠", "eye_color"]]
var _active_part_index: int = 0
var _active_color_key: String = "skin_color"
var _part_name_label: Label
var _active_swatch: ColorRect
var _hue_slider: HSlider
var _sat_slider: HSlider
var _val_slider: HSlider
var _sat_gradient: Gradient   # 饱和度条背景: 灰→当前色 (随色相/亮度实时更新)
var _val_gradient: Gradient   # 亮度条背景: 黑→当前色

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_select_panel()
	visible = false


func open_select() -> void:
	visible = true
	_select_panel.visible = true
	_refresh_list()


func _build_select_panel() -> void:
	_select_panel = Panel.new()
	_select_panel.name = "SelectPanel"
	_select_panel.custom_minimum_size = Vector2(420, 460)
	_select_panel.position = Vector2(430, 130)
	_select_panel.size = Vector2(420, 460)
	add_child(_select_panel)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 8)
	vbox.position = Vector2(20, 18)
	vbox.custom_minimum_size = Vector2(380, 0)
	_select_panel.add_child(vbox)
	_select_title = Label.new()
	_select_title.text = "选择角色"
	_select_title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(_select_title)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 300)
	vbox.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	var new_btn := Button.new()
	new_btn.text = "＋ 捏个新角色"
	new_btn.pressed.connect(_on_new_character)
	vbox.add_child(new_btn)
	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.pressed.connect(func(): visible = false; closed.emit())
	vbox.add_child(back_btn)
	# 蓝色统一: 面板 + 按钮 (色块 ColorRect 保留原色, _style_controls 不动它)
	_select_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_style_controls(_select_panel)


# 递归把按钮/输入框/滑条刷蓝 (色块/标签不动)
func _style_controls(node: Node) -> void:
	for c in node.get_children():
		if c is Button:
			if (c as Button).toggle_mode:
				UIStyle.style_toggle(c)
			else:
				UIStyle.style_button(c)
		elif c is LineEdit:
			UIStyle.style_line_edit(c)
		elif c is HSlider:
			if not c.has_meta("color_slider"):   # 调色滑杆是透明轨道+彩色渐变, 别套默认皮
				UIStyle.style_slider(c)
		_style_controls(c)


func _refresh_list() -> void:
	for c in _list.get_children():
		c.queue_free()
	for entry in CharacterManager.list_characters():
		_make_row(String(entry["name"]))


func _make_row(char_name: String) -> void:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 40)
	var lbl := Label.new()
	lbl.text = char_name
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)
	var pick := Button.new()
	pick.text = "选择"
	UIStyle.style_button(pick)
	pick.pressed.connect(func(): _choose_character(char_name))
	row.add_child(pick)
	# 改造型: 把这个角色 load 进捏人改样子, 保存覆盖原角色 (不新建 → 不会越改越多)。
	var edit := Button.new()
	edit.text = "改造型"
	UIStyle.style_button(edit)
	edit.pressed.connect(func(): _on_edit_character(char_name))
	row.add_child(edit)
	var del := Button.new()
	del.text = "删除"
	UIStyle.style_button(del)
	del.pressed.connect(func():
		CharacterManager.delete_character_by_name(char_name)
		_refresh_list()
	)
	row.add_child(del)
	_list.add_child(row)


# 选中角色: 设 current → 发信号 (main_menu 去开世界选择)。
func _choose_character(char_name: String) -> void:
	var c = CharacterManager.load_character_by_name(char_name)
	if c == null:
		return
	CharacterManager.current = c
	visible = false
	character_chosen.emit()


# ---- 捏人面板 ----

func _on_new_character() -> void:
	_editing_name = ""   # 新建模式: 保存时重名才加2/3 (能建多个角色)
	_appearance = PlayerArt.DEFAULT_APPEARANCE.duplicate(true)
	if _creator_panel == null:
		_build_creator_panel()
	_name_edit.text = ""
	_select_panel.visible = false
	_creator_panel.visible = true
	visible = true
	_set_gender(int(_appearance["gender"]))
	if _hue_slider != null:
		_set_active_color_index(_active_part_index)   # 重开捏人: 滑杆同步到新角色颜色
	_rebuild_preview()


# 改造型: 把现有角色 load 进捏人 (样子 + 名字), 保存时覆盖它 (不新建 → 不会越改越多)。
func _on_edit_character(char_name: String) -> void:
	var c = CharacterManager.load_character_by_name(char_name)
	if c == null:
		return
	_editing_name = char_name   # 编辑模式: 保存覆盖这个角色
	_appearance = c.appearance_dict().duplicate(true)
	if _creator_panel == null:
		_build_creator_panel()
	_name_edit.text = char_name
	_select_panel.visible = false
	_creator_panel.visible = true
	visible = true
	_set_gender(int(_appearance["gender"]))
	if _hue_slider != null:
		_set_active_color_index(_active_part_index)   # 滑杆同步到该角色颜色
	_rebuild_preview()


func _build_creator_panel() -> void:
	_creator_panel = Panel.new()
	_creator_panel.name = "CreatorPanel"
	_creator_panel.custom_minimum_size = Vector2(520, 470)
	_creator_panel.size = Vector2(520, 470)
	_creator_panel.position = Vector2(380, 125)
	add_child(_creator_panel)
	# 左: 预览
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(90, 250)
	_preview.scale = Vector2(3, 3)
	# 强制最近邻过滤: 放大 3 倍的像素画必须清晰, 否则 1px 眼白会被线性插值糊成灰色
	# (捏人预览在 UI 层下, 可能继承到 linear; 世界里玩家走项目默认 nearest 所以不糊).
	_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_creator_panel.add_child(_preview)
	# 右: 选项 VBox
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(190, 20)
	vbox.custom_minimum_size = Vector2(310, 0)
	vbox.add_theme_constant_override("separation", 6)
	_creator_panel.add_child(vbox)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "角色名字"
	_name_edit.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(_name_edit)
	var gender_row := HBoxContainer.new()
	var male_b := Button.new(); male_b.text = "男"; male_b.pressed.connect(func(): _set_gender(0))
	var female_b := Button.new(); female_b.text = "女"; female_b.pressed.connect(func(): _set_gender(1))
	gender_row.add_child(male_b); gender_row.add_child(female_b)
	vbox.add_child(gender_row)
	vbox.add_child(_stepper("发型", "hair_style", 0, 3))
	# 服装款式 (中文名; 只列已实现的款 —— 后续按 spec 补充目录)
	vbox.add_child(_stepper_choices("上装", "shirt_style", [[0, "T恤"], [1, "背心"], [6, "泳衣"]]))
	vbox.add_child(_stepper_choices("下装", "pants_style", [[0, "长裤"], [2, "裙子"], [7, "泳裤"]]))
	_chest_row = _slider_row("胸围", "chest_size", 0, 5)
	vbox.add_child(_chest_row)
	_build_color_editor(vbox)
	# 保存/取消固定钉在面板底部 (不放进 vbox): 否则选"女"多出"胸围"行会把整列往下推,
	# 保存键跟着挪位 → 用户点原来的位置点空 = "存不进去/建不了女角色" (用户报)。
	var btn_row := HBoxContainer.new()
	btn_row.position = Vector2(190, 428)
	var save_b := Button.new(); save_b.text = "保存"; save_b.pressed.connect(_save_creator)
	var cancel_b := Button.new(); cancel_b.text = "取消"; cancel_b.pressed.connect(func():
		_creator_panel.visible = false; _select_panel.visible = true; _refresh_list())
	btn_row.add_child(save_b); btn_row.add_child(cancel_b)
	_creator_panel.add_child(btn_row)
	# 蓝色统一: 捏人面板 + 全部按钮/名字框/胸围滑条 (色块保留)
	_creator_panel.add_theme_stylebox_override("panel", UIStyle.panel())
	_style_controls(_creator_panel)


# 一行 ◀ 名称 ▶ stepper, 改 _appearance[key] 在 [lo,hi] 循环。
func _stepper(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var left := Button.new(); left.text = "◀"; row.add_child(left)
	var val := Label.new(); val.custom_minimum_size = Vector2(40, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func(): val.text = str(int(_appearance[key]))
	refresh.call()
	_step_vals[key] = val   # 存引用, _sync_controls 能刷新
	row.add_child(val)
	var right := Button.new(); right.text = "▶"; row.add_child(right)
	left.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) - 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	right.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) + 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	return row


# 一行 ◀ 中文名 ▶, 在 choices=[[value,中文名],...] 里循环 (跳过没实现的款), 设 _appearance[key]=value。
func _stepper_choices(label: String, key: String, choices: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var left := Button.new(); left.text = "◀"; row.add_child(left)
	var val := Label.new(); val.custom_minimum_size = Vector2(80, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var idx_of := func() -> int:
		for i in choices.size():
			if int(choices[i][0]) == int(_appearance.get(key, 0)):
				return i
		return 0
	var refresh := func(): val.text = String(choices[idx_of.call()][1])
	refresh.call()
	_named_refresh[key] = refresh
	row.add_child(val)
	var right := Button.new(); right.text = "▶"; row.add_child(right)
	left.pressed.connect(func():
		_appearance[key] = int(choices[wrapi(idx_of.call() - 1, 0, choices.size())][0]); refresh.call(); _rebuild_preview())
	right.pressed.connect(func():
		_appearance[key] = int(choices[wrapi(idx_of.call() + 1, 0, choices.size())][0]); refresh.call(); _rebuild_preview())
	return row


func _slider_row(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 1
	s.value = int(_appearance[key]); s.custom_minimum_size = Vector2(180, 0)
	s.value_changed.connect(func(v): _appearance[key] = int(v); _rebuild_preview())
	if key == "chest_size":
		_chest_slider = s
	row.add_child(s)
	return row


# 自由调色 UI: 一行"调色 ◀ 部位 ▶ [当前色]" + 色相/饱和度/亮度 三滑杆。
func _build_color_editor(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = "调色"; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var left := Button.new(); left.text = "◀"; row.add_child(left)
	_part_name_label = Label.new()
	_part_name_label.custom_minimum_size = Vector2(50, 0)
	_part_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_part_name_label)
	var right := Button.new(); right.text = "▶"; row.add_child(right)
	_active_swatch = ColorRect.new(); _active_swatch.custom_minimum_size = Vector2(28, 28)
	row.add_child(_active_swatch)
	parent.add_child(row)
	left.pressed.connect(func(): _cycle_part(-1))
	right.pressed.connect(func(): _cycle_part(1))
	# 三滑杆, 每条都有彩色渐变背景 = 一眼看到拖到哪是什么色
	_hue_slider = _make_color_slider("色相", 0, 359, parent, _make_hue_gradient_tex())
	_sat_gradient = _two_stop_gradient(Color(0.5, 0.5, 0.5), Color.RED)
	_sat_slider = _make_color_slider("饱和度", 0, 100, parent, _grad_tex(_sat_gradient))
	_val_gradient = _two_stop_gradient(Color.BLACK, Color.RED)
	_val_slider = _make_color_slider("亮度", 0, 100, parent, _grad_tex(_val_gradient))
	_set_active_color_index(0)


# 一条带彩色渐变背景的滑杆: 渐变 TextureRect 垫底 + 透明轨道滑杆叠上面 (只露手柄)。
func _make_color_slider(label: String, lo: int, hi: int, parent: VBoxContainer, tex: Texture2D) -> HSlider:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var stack := Control.new()
	stack.custom_minimum_size = Vector2(180, 22)
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var bg := TextureRect.new()
	bg.texture = tex
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(bg)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 1
	s.set_anchors_preset(Control.PRESET_FULL_RECT)
	s.set_meta("color_slider", true)   # _style_controls 跳过它, 别拿默认皮盖住渐变
	var empty := StyleBoxEmpty.new()
	s.add_theme_stylebox_override("slider", empty)
	s.add_theme_stylebox_override("grabber_area", empty)
	s.add_theme_stylebox_override("grabber_area_highlight", empty)
	s.value_changed.connect(func(_v): _on_color_slider_changed())
	stack.add_child(s)
	row.add_child(stack)
	parent.add_child(row)
	return s


func _two_stop_gradient(a: Color, b: Color) -> Gradient:
	var g := Gradient.new()
	g.set_offset(0, 0.0); g.set_color(0, a)
	g.set_offset(1, 1.0); g.set_color(1, b)
	return g


func _grad_tex(g: Gradient) -> GradientTexture1D:
	var t := GradientTexture1D.new()
	t.gradient = g
	t.width = 128
	return t


# 彩虹色相条 (红→黄→绿→青→蓝→品红→红)
func _make_hue_gradient_tex() -> GradientTexture1D:
	var g := Gradient.new()
	var offs: PackedFloat32Array = [0.0, 1.0/6, 2.0/6, 3.0/6, 4.0/6, 5.0/6, 1.0]
	var cols := PackedColorArray()
	for o in offs:
		cols.append(Color.from_hsv(o, 1.0, 1.0))
	g.offsets = offs    # 直接替换默认的 2 个点
	g.colors = cols
	return _grad_tex(g)


# 饱和度/亮度条颜色随当前色相+另两轴实时更新 (色相条是固定彩虹不用更新)。
func _update_color_gradients() -> void:
	if _hue_slider == null:
		return
	var h: float = _hue_slider.value / 359.0
	var s: float = _sat_slider.value / 100.0
	var v: float = maxf(_val_slider.value / 100.0, 0.05)   # 太暗看不出饱和度变化, 给个下限
	if _sat_gradient != null:
		_sat_gradient.set_color(0, Color.from_hsv(h, 0.0, v))
		_sat_gradient.set_color(1, Color.from_hsv(h, 1.0, v))
	if _val_gradient != null:
		_val_gradient.set_color(0, Color.from_hsv(h, s, 0.0))
		_val_gradient.set_color(1, Color.from_hsv(h, s, 1.0))


func _cycle_part(d: int) -> void:
	_set_active_color_index(wrapi(_active_part_index + d, 0, _COLOR_PARTS.size()))


# 切到第 i 个部位: 标题 + 把该部位当前颜色拆成 HSV 填进三滑杆 (no_signal 防回环)。
func _set_active_color_index(i: int) -> void:
	_active_part_index = i
	_active_color_key = String(_COLOR_PARTS[i][1])
	if _part_name_label != null:
		_part_name_label.text = String(_COLOR_PARTS[i][0])
	var c: Color = _appearance.get(_active_color_key, Color.WHITE)
	_hue_slider.set_value_no_signal(roundi(c.h * 359.0))
	_sat_slider.set_value_no_signal(roundi(c.s * 100.0))
	_val_slider.set_value_no_signal(roundi(c.v * 100.0))
	_update_color_gradients()
	if _active_swatch != null:
		_active_swatch.color = c


# 拖任意滑杆 → 用三滑杆当前值合成颜色, 写回当前部位 + 即时重画预览。
func _on_color_slider_changed() -> void:
	var c := Color.from_hsv(_hue_slider.value / 359.0, _sat_slider.value / 100.0, _val_slider.value / 100.0)
	_appearance[_active_color_key] = c
	_update_color_gradients()   # 拖一条 → 另两条的渐变实时跟着变色
	if _active_swatch != null:
		_active_swatch.color = c
	_rebuild_preview()


func _set_gender(g: int) -> void:
	_appearance["gender"] = g
	# 切性别给个对应的默认发型 (男短发0 / 女长发1), 让性别一眼看出区别; 之后还能自己改。
	_appearance["hair_style"] = 1 if g == 1 else 0
	if _chest_row != null:
		_chest_row.visible = (g == 1)   # 胸围只女显示
	_sync_controls()
	_rebuild_preview()


# 把控件的显示值同步到 _appearance (重开捏人 / 切性别后控件不再显旧值)。
func _sync_controls() -> void:
	for key in _step_vals.keys():
		_step_vals[key].text = str(int(_appearance.get(key, 0)))
	for cb in _named_refresh.values():
		cb.call()
	if _chest_slider != null:
		_chest_slider.set_value_no_signal(int(_appearance.get("chest_size", 1)))


func _set_creator_name(n: String) -> void:
	_name_edit.text = n


func _rebuild_preview() -> void:
	if _preview == null:
		return
	_preview.sprite_frames = ArtCache.player_frames_for(_appearance)
	_preview.animation = "idle"
	_preview.play()


func _save_creator() -> void:
	var c := CharacterData.new()
	var nm: String = _name_edit.text.strip_edges()
	if nm == "":
		nm = "我的角色"
	if _editing_name != "":
		# 改造现有角色: 用这个名字直接覆盖原角色 (不自动改名, 否则又多一个)。
		if nm == _editing_name:
			c.character_name = nm                       # 原地覆盖
		else:
			c.character_name = _unique_character_name(nm)  # 改了名 = 当新名 (防撞别的角色)
			CharacterManager.delete_character_by_name(_editing_name)  # 删旧名档, 别留副本
	else:
		# 新建: 重名才加 2/3/… (防覆盖别的角色), 保证能建多个角色
		c.character_name = _unique_character_name(nm)
	c.gender = int(_appearance["gender"])
	c.hair_style = int(_appearance["hair_style"])
	c.shirt_style = int(_appearance.get("shirt_style", 0))
	c.pants_style = int(_appearance.get("pants_style", 0))
	c.cape_style = int(_appearance.get("cape_style", 0))
	c.chest_size = int(_appearance["chest_size"])
	c.skin_color = _appearance["skin_color"]
	c.hair_color = _appearance["hair_color"]
	c.shirt_color = _appearance["shirt_color"]
	c.pants_color = _appearance["pants_color"]
	c.eye_color = _appearance["eye_color"]
	c.shoe_color = _appearance.get("shoe_color", Color8(74, 47, 26))
	c.cape_color = _appearance.get("cape_color", Color8(150, 40, 50))   # 改造型 load 回来的披风色别丢
	CharacterManager.save_character(c)
	CharacterManager.current = c
	_editing_name = ""   # 退出编辑模式 (下次默认新建)
	_creator_panel.visible = false
	_select_panel.visible = true
	_refresh_list()


# 重名就在后面加 2/3/… (按存档文件名比对), 防第二个角色覆盖第一个。
func _unique_character_name(base: String) -> String:
	var taken := {}
	# 只看文件名 (不加载资源): 网页加载失败也不会漏掉已有角色 → 第二个角色不会撞名覆盖第一个
	for nm in CharacterManager.list_character_names():
		taken[String(nm)] = true
	if not taken.has(CharacterManager._sanitize(base)):
		return base
	var i: int = 2
	while taken.has(CharacterManager._sanitize(base + " " + str(i))):
		i += 1
	return base + " " + str(i)
