extends GutTest

const CharacterPanels = preload("res://scripts/ui/character_panels.gd")
const CharacterData = preload("res://scripts/save/character_data.gd")

var panels

func before_each():
	panels = CharacterPanels.new()
	add_child_autofree(panels)
	CharacterManager.CHARS_DIR_OVERRIDE = "user://test_ui_chars/"
	_clear_dir(CharacterManager.chars_dir())

func after_each():
	_clear_dir(CharacterManager.chars_dir())
	CharacterManager.CHARS_DIR_OVERRIDE = ""

func _clear_dir(p: String):
	if not DirAccess.dir_exists_absolute(p): return
	var d = DirAccess.open(p)
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		if not d.current_is_dir(): DirAccess.remove_absolute(p + f)
		f = d.get_next()
	d.list_dir_end()

func test_has_select_panel():
	assert_not_null(panels.get_node_or_null("SelectPanel"), "有选角色面板")

func test_open_select_lists_characters():
	var c = CharacterData.new(); c.character_name = "阿狗"
	CharacterManager.save_character(c)
	panels.open_select()
	await wait_frames(1)
	var found := false
	for lbl in _all_labels(panels):
		if lbl.text.contains("阿狗"): found = true
	assert_true(found, "列表里有阿狗")

func test_choose_character_sets_current_and_emits():
	var c = CharacterData.new(); c.character_name = "勇者A"
	CharacterManager.save_character(c)
	CharacterManager.current = null
	watch_signals(panels)
	panels.open_select()
	await wait_frames(1)
	panels._choose_character("勇者A")
	assert_eq(CharacterManager.current.character_name, "勇者A", "current 设成选中角色")
	assert_signal_emitted(panels, "character_chosen")

func test_new_character_opens_creator():
	panels.open_select()
	await wait_frames(1)
	panels._on_new_character()
	await wait_frames(1)
	assert_not_null(panels.get_node_or_null("CreatorPanel"), "捏人面板出现")
	assert_true(panels.get_node("CreatorPanel").visible, "捏人面板可见")

func test_creator_save_writes_character():
	panels._on_new_character()
	await wait_frames(1)
	panels._set_creator_name("新角色X")
	panels._appearance["gender"] = 1
	panels._appearance["hair_style"] = 2
	panels._save_creator()
	var loaded = CharacterManager.load_character_by_name("新角色X")
	assert_not_null(loaded, "捏人保存写盘了")
	assert_eq(loaded.gender, 1)
	assert_eq(loaded.hair_style, 2)

func test_chest_row_only_visible_for_female():
	panels._on_new_character()
	await wait_frames(1)
	panels._set_gender(0)
	assert_false(panels._chest_row.visible, "男: 胸围行隐藏")
	panels._set_gender(1)
	assert_true(panels._chest_row.visible, "女: 胸围行显示")

func test_color_sliders_change_active_part_color():
	panels._on_new_character()
	await wait_frames(1)
	panels._set_active_color_index(0)   # 皮肤
	# 拖动滑杆 (设 value 会触发 value_changed → 合成颜色写回 _appearance)
	panels._hue_slider.value = 200
	panels._sat_slider.value = 50
	panels._val_slider.value = 80
	var c: Color = panels._appearance["skin_color"]
	assert_almost_eq(c.s, 0.5, 0.02, "饱和度滑杆该改皮肤饱和度")
	assert_almost_eq(c.v, 0.8, 0.02, "亮度滑杆该改皮肤亮度")


func test_color_editor_switches_part():
	panels._on_new_character()
	await wait_frames(1)
	panels._set_active_color_index(1)   # 头发
	assert_eq(panels._active_color_key, "hair_color", "切到头发")
	panels._cycle_part(1)               # 下一个 = 衬衫
	assert_eq(panels._active_color_key, "shirt_color", "◀▶ 切到衬衫")


func _all_labels(node: Node) -> Array:
	var out: Array = []
	if node is Label: out.append(node)
	for c in node.get_children(): out += _all_labels(c)
	return out
