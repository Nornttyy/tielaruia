# 选角色 + 捏人 两个面板 (代码动态建)。main_menu 实例化为子节点。
# 选角色: 列表 + 捏新角色 + 返回。捏人: Task 2 实现。
extends Control

signal character_chosen   # 选了角色 (current 已设), main_menu 去开世界选择
signal closed             # 返回主菜单

const CharacterData = preload("res://scripts/save/character_data.gd")
const PlayerArt = preload("res://scripts/art/player_art.gd")

var _select_panel: Panel
var _list: VBoxContainer
var _creator_panel: Panel
var _preview: AnimatedSprite2D
var _name_edit: LineEdit
var _chest_row: HBoxContainer
var _appearance: Dictionary = {}

# 色块候选 (暖色优先)
const _SKIN := [Color8(255,218,185), Color8(240,190,150), Color8(200,150,110), Color8(150,100,70), Color8(95,60,40)]
const _HAIR := [Color8(121,85,72), Color8(60,40,30), Color8(20,20,20), Color8(210,180,90), Color8(180,70,50), Color8(120,90,160)]
const _SHIRT := [Color8(229,57,53), Color8(50,110,200), Color8(70,160,90), Color8(240,200,70), Color8(230,140,60), Color8(240,240,240)]
const _PANTS := [Color8(38,70,130), Color8(60,50,45), Color8(80,80,90), Color8(120,80,60), Color8(40,90,70), Color8(20,20,30)]
const _EYE := [Color8(60,110,70), Color8(70,120,200), Color8(110,70,50), Color8(40,40,40), Color8(150,90,170), Color8(200,140,60)]


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
	var title := Label.new()
	title.text = "选择角色"
	title.add_theme_font_size_override("font_size", 22)
	vbox.add_child(title)
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
	pick.pressed.connect(func(): _choose_character(char_name))
	row.add_child(pick)
	var del := Button.new()
	del.text = "删除"
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
	_appearance = PlayerArt.DEFAULT_APPEARANCE.duplicate(true)
	if _creator_panel == null:
		_build_creator_panel()
	_name_edit.text = ""
	_select_panel.visible = false
	_creator_panel.visible = true
	visible = true
	_set_gender(int(_appearance["gender"]))
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
	_chest_row = _slider_row("胸围", "chest_size", 0, 5)
	vbox.add_child(_chest_row)
	vbox.add_child(_color_row("皮肤", "skin_color", _SKIN))
	vbox.add_child(_color_row("头发", "hair_color", _HAIR))
	vbox.add_child(_color_row("衬衫", "shirt_color", _SHIRT))
	vbox.add_child(_color_row("裤子", "pants_color", _PANTS))
	vbox.add_child(_color_row("眼珠", "eye_color", _EYE))
	var btn_row := HBoxContainer.new()
	var save_b := Button.new(); save_b.text = "保存"; save_b.pressed.connect(_save_creator)
	var cancel_b := Button.new(); cancel_b.text = "取消"; cancel_b.pressed.connect(func():
		_creator_panel.visible = false; _select_panel.visible = true; _refresh_list())
	btn_row.add_child(save_b); btn_row.add_child(cancel_b)
	vbox.add_child(btn_row)


# 一行 ◀ 名称 ▶ stepper, 改 _appearance[key] 在 [lo,hi] 循环。
func _stepper(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var left := Button.new(); left.text = "◀"; row.add_child(left)
	var val := Label.new(); val.custom_minimum_size = Vector2(40, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func(): val.text = str(int(_appearance[key]))
	refresh.call()
	row.add_child(val)
	var right := Button.new(); right.text = "▶"; row.add_child(right)
	left.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) - 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	right.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) + 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	return row


func _slider_row(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 1
	s.value = int(_appearance[key]); s.custom_minimum_size = Vector2(180, 0)
	s.value_changed.connect(func(v): _appearance[key] = int(v); _rebuild_preview())
	row.add_child(s)
	return row


# 一行色块: 点哪块就把 _appearance[key] 设成那色 + 重建预览。
func _color_row(label: String, key: String, colors: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	for col in colors:
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(28, 28)
		sw.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				_appearance[key] = col; _rebuild_preview())
		row.add_child(sw)
	return row


func _set_gender(g: int) -> void:
	_appearance["gender"] = g
	if _chest_row != null:
		_chest_row.visible = (g == 1)   # 胸围只女显示
	_rebuild_preview()


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
	c.character_name = nm if nm != "" else "我的角色"
	c.gender = int(_appearance["gender"])
	c.hair_style = int(_appearance["hair_style"])
	c.chest_size = int(_appearance["chest_size"])
	c.skin_color = _appearance["skin_color"]
	c.hair_color = _appearance["hair_color"]
	c.shirt_color = _appearance["shirt_color"]
	c.pants_color = _appearance["pants_color"]
	c.eye_color = _appearance["eye_color"]
	CharacterManager.save_character(c)
	CharacterManager.current = c
	_creator_panel.visible = false
	_select_panel.visible = true
	_refresh_list()
