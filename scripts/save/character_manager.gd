# 角色管理 autoload。管 user://characters/{name}.tres。
# 跟 SaveManager 平行: 文件名清洗/原子写/网页 flush 全照 save_manager.gd。
# current = 进程内当前选中角色 (进世界时 main 用它还原玩家)。
extends Node

const CharacterData = preload("res://scripts/save/character_data.gd")
const CHARS_DIR := "user://characters/"
const DEFAULT_CHARACTER_NAME := "默认角色"

# 测试可覆盖 (指向独立目录, 不污染真存档)。生产恒为 ""。
var CHARS_DIR_OVERRIDE: String = ""

var current: CharacterData = null

signal character_saved


func chars_dir() -> String:
	return CHARS_DIR_OVERRIDE if CHARS_DIR_OVERRIDE != "" else CHARS_DIR


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(chars_dir()):
		DirAccess.make_dir_absolute(chars_dir())
	_migrate_from_world_saves()


# 文件名清洗: 把路径相关 / 文件系统非法字符替换为 _ (照 save_manager.gd)。
func _sanitize(name: String) -> String:
	var out: String = name
	for bad_char in ["/", "\\", "..", ":", "*", "?", "\"", "<", ">", "|"]:
		out = out.replace(bad_char, "_")
	if out.is_empty():
		out = "角色"
	return out


func has_any() -> bool:
	return not list_characters().is_empty()


# 列出所有角色: [{name, data, path}] (照 SaveManager.list_saves 结构)。
func list_characters() -> Array:
	var out: Array = []
	var dir_path: String = chars_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		return out
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres") and not file_name.ends_with(".tmp.tres"):
			var full_path: String = dir_path + file_name
			var res = ResourceLoader.load(full_path)
			if res is CharacterData:
				out.append({
					"name": file_name.replace(".tres", ""),
					"data": res,
					"path": full_path,
				})
		file_name = dir.get_next()
	dir.list_dir_end()
	return out


# 原子写 user://characters/{清洗名}.tres (照 save_manager.gd: .tmp.tres → rename + web flush)。
func save_character(c: CharacterData) -> bool:
	if c == null:
		push_error("save_character: c 为 null")
		return false
	var dir_path: String = chars_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_absolute(dir_path)
	var save_name: String = _sanitize(c.character_name)
	var path: String = dir_path + save_name + ".tres"
	var tmp_path: String = dir_path + save_name + ".tmp.tres"
	var err: int = ResourceSaver.save(c, tmp_path)
	if err != OK:
		push_error("save_character: ResourceSaver 失败 err=%d" % err)
		return false
	var rename_err: int = DirAccess.rename_absolute(tmp_path, path)
	if rename_err != OK:
		push_error("save_character: rename 失败 err=%d" % rename_err)
		DirAccess.remove_absolute(tmp_path)
		return false
	_flush_web_filesystem()
	character_saved.emit()
	return true


# 防注入: 非法名拒读 (照 save_manager.load_save_by_name)。
func load_character_by_name(name: String) -> CharacterData:
	if name.is_empty() or name.contains("/") or name.contains("\\") or name.contains(".."):
		push_warning("load_character_by_name: 非法名 '%s'" % name)
		return null
	var path: String = chars_dir() + name + ".tres"
	if not FileAccess.file_exists(path):
		return null
	var res = ResourceLoader.load(path)
	if not res is CharacterData:
		return null
	return res


func delete_character_by_name(name: String) -> void:
	if name.is_empty() or name.contains("/") or name.contains("\\") or name.contains(".."):
		push_warning("delete_character_by_name: 非法名 '%s'" % name)
		return
	var path: String = chars_dir() + name + ".tres"
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


# 网页版: 刷 IndexedDB (照 save_manager.gd, 桌面/测试 no-op)。
func _flush_web_filesystem() -> void:
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval("""
		try {
			if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function(e){}); }
		} catch (e) {}
	""", true)


# --- Task 3 实现 (玩家 <-> 角色状态) ---
func save_current_from_player(_player: Node) -> bool:
	return false


func apply_to_player(_player: Node) -> void:
	pass


# --- Task 4 实现 ---
func ensure_current() -> void:
	pass


func _migrate_from_world_saves() -> void:
	pass
