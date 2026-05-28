# 多语言查表 autoload. 用法:
#   Locale.t("menu_new_game")        # 当前语言对应的字符串
#   Locale.set_language("en")        # 切到英文, 发 language_changed 信号
#   Locale.language_changed.connect(_refresh)   # UI 监听后刷新文字
#
# 找不到 key 时: 当前语言找不到 → 退回中文 → 中文也没 → 返回 key 本身 (好定位漏翻).
# 当前语言持久化在 GameSettings.current_language (zh / en / ja / ko).
extends Node

const SUPPORTED := ["zh", "en", "ja", "ko"]
const DEFAULT_LANG := "zh"

signal language_changed(new_lang: String)

const _StringsZH := preload("res://scripts/locale/strings_zh.gd")
const _StringsEN := preload("res://scripts/locale/strings_en.gd")
const _StringsJA := preload("res://scripts/locale/strings_ja.gd")
const _StringsKO := preload("res://scripts/locale/strings_ko.gd")

# 4 个语言字典: lang_code → {key: 译文}
var _tables: Dictionary = {
	"zh": _StringsZH.S,
	"en": _StringsEN.S,
	"ja": _StringsJA.S,
	"ko": _StringsKO.S,
}

var _current: String = DEFAULT_LANG


func _ready() -> void:
	# GameSettings autoload 顺序在 Locale 之前 (project.godot 顺序), 这里读它的值. 没存过取默认中文.
	if Engine.has_singleton("GameSettings") or get_node_or_null("/root/GameSettings") != null:
		var saved: String = String(GameSettings.current_language)
		if SUPPORTED.has(saved):
			_current = saved


# 查 key. 当前语言找不到退回中文, 中文也没就返回 key (方便定位漏翻).
func t(key: String, default: String = "") -> String:
	var table: Dictionary = _tables.get(_current, _tables["zh"])
	if table.has(key):
		return String(table[key])
	# Fallback 1: 中文基准
	if _current != "zh" and _tables["zh"].has(key):
		return String(_tables["zh"][key])
	# Fallback 2: 调用方提供的默认值
	if default != "":
		return default
	# Fallback 3: key 本身 (开发时一眼看出哪里漏翻)
	return key


func current_language() -> String:
	return _current


# 切语言: 更新内部 + 存盘 + 发信号. 已经是当前语言就 noop.
func set_language(code: String) -> void:
	if not SUPPORTED.has(code):
		push_warning("Locale.set_language: 不支持的语言代码 '%s', 忽略" % code)
		return
	if code == _current:
		return
	_current = code
	# 存到 GameSettings (它的 setter 会落盘)
	if get_node_or_null("/root/GameSettings") != null:
		GameSettings.current_language = code
	language_changed.emit(code)


# 当前语言在 SUPPORTED 里的 index (UI OptionButton 选中项用)
func current_language_index() -> int:
	return SUPPORTED.find(_current)


# 第 i 项语言的显示名 (用各语言里 lang_name 的值, 比如中文 "中文", 英文 "English")
func language_display_name(code: String) -> String:
	var table: Dictionary = _tables.get(code, _tables["zh"])
	return String(table.get("lang_name", code))
