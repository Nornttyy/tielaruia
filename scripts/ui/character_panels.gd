# 选角色 + 捏人 两个面板 (代码动态建)。main_menu 实例化为子节点。
# 选角色: 列表 + 捏新角色 + 返回。捏人: Task 2 实现。
extends Control

signal character_chosen   # 选了角色 (current 已设), main_menu 去开世界选择
signal closed             # 返回主菜单

const CharacterData = preload("res://scripts/save/character_data.gd")

var _select_panel: Panel
var _list: VBoxContainer


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


# Task 2 实现
func _on_new_character() -> void:
	pass
