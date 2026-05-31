extends GutTest
## 存档目录测试 test_save_clean_profile
##
## 挡住这个 bug: 全新机器 (或浏览器清过缓存) 上, user://save_slot_0/ 还不存在,
## 以前 new_game 先写 meta.json 再建目录 → 写失败 → has_save() 永远 false → 存档丢/读不出来.
## 修好后: new_game 必须先把目录建好, 存档要存得上.

const SLOT := "user://save_slot_0"

func before_each() -> void:
	_nuke_save_dir()

func after_each() -> void:
	_nuke_save_dir()

# 把整个存档槽彻底删掉, 模拟"全新机器"
func _nuke_save_dir() -> void:
	var cd := DirAccess.open(SLOT + "/chunks")
	if cd != null:
		cd.list_dir_begin()
		var fn := cd.get_next()
		while fn != "":
			if not cd.current_is_dir():
				cd.remove(fn)
			fn = cd.get_next()
		cd.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT + "/chunks"))
	var d := DirAccess.open(SLOT)
	if d != null:
		d.list_dir_begin()
		var f := d.get_next()
		while f != "":
			if not d.current_is_dir():
				d.remove(f)
			f = d.get_next()
		d.list_dir_end()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SLOT))

func test_new_game_persists_on_clean_profile() -> void:
	# 确认起点真的是"啥都没有"
	assert_false(SaveManager.has_save(), "测试前置: 存档应已被清空")

	SaveManager.new_game(12345, Vector2(100, 50))

	# 全新机器上也必须存得上
	assert_true(SaveManager.has_save(), "新游戏后 has_save() 应为 true (meta.json 要写进去)")
	assert_true(FileAccess.file_exists(SLOT + "/meta.json"), "meta.json 文件应存在")

	# 再读回来, seed 要对得上
	var ok := SaveManager.load_all()
	assert_true(ok, "应能成功读档")
	assert_eq(SaveManager.current_seed, 12345, "读回来的种子应一致")
