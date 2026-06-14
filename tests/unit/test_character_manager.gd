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

# 回归 (用户报: 每次进游戏多出一个"我的角色"): 开机 _ready 不该自动造角色。
# 旧版 _ready 调 _migrate_from_world_saves, 网页 FS 没就绪时 has_any 误判 → 每次启动造一个。
func test_ready_does_not_autocreate_character():
	add_child(cm)                      # 触发 _ready (new() 不跑 _ready)
	await get_tree().process_frame
	assert_false(cm.has_any(), "_ready 不该自动造角色")
	assert_eq(cm.list_characters().size(), 0, "_ready 后列表该为空")
	remove_child(cm)

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

# --- 回归: 网页角色文件加载失败时, 不能把它从列表里抹掉 (否则建第二个会撞名覆盖第一个) ---
# 写一个"坏"角色文件 (内容不是合法 CharacterData), 模拟网页 ResourceLoader.load 失败。
func _write_corrupt_char(name: String):
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	var f = FileAccess.open(cm.chars_dir() + name + ".tres", FileAccess.WRITE)
	f.store_string("这不是合法的 tres 内容")
	f.close()

func test_list_names_includes_unloadable():
	_write_corrupt_char("坏档甲")
	assert_true(cm.list_character_names().has("坏档甲"), "加载失败的角色名也要列出来 (去重靠它)")

func test_list_characters_keeps_unloadable_with_placeholder():
	_write_corrupt_char("坏档乙")
	var names := []
	for e in cm.list_characters():
		names.append(String(e["name"]))
	assert_true(names.has("坏档乙"), "加载失败的角色不该从列表消失 (用占位顶上)")

func test_second_char_not_overwriting_when_first_unloadable():
	# 第一个角色文件加载失败 (模拟网页), 再建同名第二个 → 必须改名共存, 不能覆盖
	_write_corrupt_char("我的角色")
	var taken := {}
	for nm in cm.list_character_names():
		taken[nm] = true
	assert_true(taken.has("我的角色"), "去重表里要有坏掉的第一个角色")
	# 第二个同名角色保存后, 盘上该有两个不同文件
	var c2 = _make("我的角色 2")
	cm.save_character(c2)
	assert_eq(cm.list_character_names().size(), 2, "两个角色共存 (没互相覆盖)")
