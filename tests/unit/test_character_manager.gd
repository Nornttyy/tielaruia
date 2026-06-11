extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const CharacterManager = preload("res://scripts/save/character_manager.gd")

var cm

func before_each():
	# 用独立实例 (非 autoload 单例) 测, 避免污染真 user://characters。
	# 改 CHARS_DIR 指向测试目录。
	cm = CharacterManager.new()
	cm.CHARS_DIR_OVERRIDE = "user://test_chars/"
	_clear_dir(cm.chars_dir())

func after_each():
	_clear_dir(cm.chars_dir())
	cm.free()

func _clear_dir(path: String):
	if not DirAccess.dir_exists_absolute(path):
		return
	var d = DirAccess.open(path)
	d.list_dir_begin()
	var f = d.get_next()
	while f != "":
		if not d.current_is_dir():
			DirAccess.remove_absolute(path + f)
		f = d.get_next()
	d.list_dir_end()

func _make(name: String) -> CharacterData:
	var c = CharacterData.new()
	c.character_name = name
	return c

func test_has_any_false_when_empty():
	assert_false(cm.has_any(), "空目录 has_any=false")

func test_save_then_list_and_load():
	var c = _make("阿狗")
	c.player_max_hp = 160
	assert_true(cm.save_character(c), "存盘成功")
	assert_true(cm.has_any(), "存后 has_any=true")
	var names = []
	for e in cm.list_characters():
		names.append(e["name"])
	assert_true(names.has("阿狗"), "列表含阿狗")
	var loaded = cm.load_character_by_name("阿狗")
	assert_true(loaded is CharacterData, "读回 CharacterData")
	assert_eq(loaded.player_max_hp, 160)

func test_delete():
	cm.save_character(_make("待删"))
	cm.delete_character_by_name("待删")
	assert_false(cm.has_any(), "删后空")

# 保存后不该留下 .tmp.tres (列表跳过这种文件 → 会"存了却不显示"). 网页 rename 失败兜底也要保证最终是 .tres。
func test_save_leaves_no_tmp_file():
	assert_true(cm.save_character(_make("小明")), "存盘成功")
	var d = DirAccess.open(cm.chars_dir())
	d.list_dir_begin()
	var f = d.get_next()
	var tmp_count := 0
	var tres_count := 0
	while f != "":
		if f.ends_with(".tmp.tres"): tmp_count += 1
		elif f.ends_with(".tres"): tres_count += 1
		f = d.get_next()
	d.list_dir_end()
	assert_eq(tmp_count, 0, "不该留下 .tmp.tres (否则角色不显示)")
	assert_eq(tres_count, 1, "该有 1 个正式 .tres")

func test_reject_path_injection_on_save():
	var c = _make("../../evil")
	cm.save_character(c)
	# 文件名被清洗, 不会写到 chars_dir 外。清洗后名字里不含 / 或 ..
	for e in cm.list_characters():
		assert_false(e["name"].contains("/"), "存档名不含 /")
		assert_false(e["name"].contains(".."), "存档名不含 ..")

func test_reject_path_injection_on_load_delete():
	assert_null(cm.load_character_by_name("../secret"), "非法名读 = null")
	cm.delete_character_by_name("../secret")  # 不应抛错/删别处文件
	pass_test("非法名 delete 不崩")
