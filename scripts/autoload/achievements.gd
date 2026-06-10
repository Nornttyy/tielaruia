# 成就/目标系统 (autoload). 给玩家奔头: 做到里程碑 → 弹"🏆 成就达成" + 永久记录。
#
# 两类成就:
#   - item:  每 ~1s 轮询本地玩家背包 has_item(id), 拿到过就解锁 (零 gameplay 改动)。
#   - event: 代码调 Achievements.fire("event_id") 解锁 (Boss 死亡等)。
#
# 账号级持久化 user://achievements.cfg (跨世界跨角色, 照 Terraria)。
extends Node

signal achievement_unlocked(id: String, ach_name: String)

const SAVE_PATH := "user://achievements.cfg"
const POLL_INTERVAL := 1.0

# 每个成就: id / name(中文) / desc; 外加 "item"(拿到该物品解锁) 或 "event"(代码 fire 解锁)
const _DEFS := [
	{"id": "first_wood",   "name": "伐木工",     "desc": "第一次得到木头",   "item": "log"},
	{"id": "first_stone",  "name": "石器时代",   "desc": "挖到石头",         "item": "stone"},
	{"id": "iron",         "name": "见铁了",     "desc": "挖到铁矿",         "item": "iron_ore"},
	{"id": "diamond",      "name": "闪闪发光",   "desc": "挖到钻石",         "item": "diamond"},
	{"id": "sword",        "name": "武装自己",   "desc": "做出一把剑",       "item": "wood_sword"},
	{"id": "gun",          "name": "砰!",        "desc": "做出一把枪",       "item": "pistol"},
	{"id": "bow",          "name": "百步穿杨",   "desc": "做出一把弓",       "item": "wood_bow"},
	{"id": "bed",          "name": "安个家",     "desc": "做出一张床",       "item": "bed"},
	{"id": "fishing",      "name": "钓鱼佬",     "desc": "做出钓鱼竿",       "item": "fishing_rod"},
	{"id": "cook",         "name": "干饭人",     "desc": "做出一顿饭",       "item": "bread"},
	{"id": "slime_hunter", "name": "史莱姆猎人", "desc": "打史莱姆拿到果冻", "item": "slime_jelly"},
	{"id": "sky",          "name": "云端漫步",   "desc": "上到空岛拿到羽毛", "item": "feather"},
	{"id": "boss_slime",   "name": "屠王者",     "desc": "打赢史莱姆王",     "event": "boss_king_slime"},
	{"id": "boss_skel",    "name": "骨王克星",   "desc": "打赢骷髅王",       "event": "boss_skeleton_king"},
]

var _unlocked: Dictionary = {}   # id → true
var SAVE_PATH_OVERRIDE: String = ""   # 测试指向临时文件, 不污染真存档
var _poll_t: float = 0.0
var _toast: CanvasLayer = null
var _toast_panel: Control = null
var _toast_name: Label = null
var _toast_desc: Label = null
var _toast_tween: Tween = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # 暂停时也能弹 (Boss 死在暂停前等)
	_load()
	_build_toast()


func _process(delta: float) -> void:
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = POLL_INTERVAL
		_poll_items()


# ===== 查询 =====
func all_defs() -> Array:
	return _DEFS


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_count() -> int:
	return _unlocked.size()


# ===== 解锁 =====
# 事件类: 代码调这个解锁 (Boss 死亡等)。event_id 没对应成就就忽略。
func fire(event_id: String) -> void:
	for d in _DEFS:
		if d.get("event", "") == event_id:
			unlock(d["id"])


func unlock(id: String) -> void:
	if _unlocked.has(id):
		return
	var def: Dictionary = _def_of(id)
	if def.is_empty():
		return
	_unlocked[id] = true
	_save()
	achievement_unlocked.emit(id, String(def["name"]))
	_show_toast(String(def["name"]), String(def.get("desc", "")))


# 物品类: 轮询本地玩家背包, 拿到过对应物品就解锁
func _poll_items() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var inv: Node = player.get_node_or_null("PlayerInventory")
	if inv == null or not inv.has_method("has_item"):
		return
	for d in _DEFS:
		if d.has("item") and not _unlocked.has(d["id"]):
			if inv.has_item(String(d["item"])):
				unlock(String(d["id"]))


func _def_of(id: String) -> Dictionary:
	for d in _DEFS:
		if d["id"] == id:
			return d
	return {}


# ===== 持久化 (账号级) =====
func _path() -> String:
	return SAVE_PATH_OVERRIDE if SAVE_PATH_OVERRIDE != "" else SAVE_PATH


func _save() -> void:
	var cfg := ConfigFile.new()
	for id in _unlocked.keys():
		cfg.set_value("unlocked", id, true)
	cfg.save(_path())


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(_path()) != OK:
		return
	for id in cfg.get_section_keys("unlocked") if cfg.has_section("unlocked") else []:
		_unlocked[id] = true


# 测试用: 清空内存解锁状态 (不删盘)
func _reset_for_test() -> void:
	_unlocked.clear()


# ===== Toast 弹窗 (autoload 自建 CanvasLayer, 顶部滑入) =====
func _build_toast() -> void:
	_toast = CanvasLayer.new()
	_toast.layer = 100   # 盖在所有 UI 上
	add_child(_toast)
	var panel := PanelContainer.new()
	_toast_panel = panel
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.08, 0.14, 0.26, 0.95)
	sb.border_color = Color(0.95, 0.82, 0.35)   # 金边 (成就感)
	for s in ["left", "top", "right", "bottom"]:
		sb.set("border_width_" + s, 2)
		sb.set("corner_radius_" + ("top_left" if s == "left" else "top_right" if s == "top" else "bottom_right" if s == "right" else "bottom_left"), 8)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.position = Vector2(-110, -70)   # 顶部居中偏上 (滑入前在屏幕外)
	panel.custom_minimum_size = Vector2(220, 0)
	_toast.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var head := Label.new()
	head.text = "🏆 成就达成"
	head.add_theme_color_override("font_color", Color(0.98, 0.86, 0.4))
	head.add_theme_font_size_override("font_size", 13)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(head)
	_toast_name = Label.new()
	_toast_name.add_theme_color_override("font_color", Color.WHITE)
	_toast_name.add_theme_font_size_override("font_size", 18)
	_toast_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_toast_name)
	_toast_desc = Label.new()
	_toast_desc.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_toast_desc.add_theme_font_size_override("font_size", 11)
	_toast_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(_toast_desc)
	panel.modulate.a = 0.0


func _show_toast(ach_name: String, desc: String) -> void:
	if _toast_panel == null:
		return
	_toast_name.text = ach_name
	_toast_desc.text = desc
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	# 滑入 (从上方滑下) + 淡入 → 停 2.6s → 淡出滑回
	var start_y := -70.0
	var shown_y := 24.0
	_toast_panel.position.y = start_y
	_toast_panel.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "position:y", shown_y, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 1.0, 0.25)
	_toast_tween.set_parallel(false)
	_toast_tween.tween_interval(2.6)
	_toast_tween.set_parallel(true)
	_toast_tween.tween_property(_toast_panel, "position:y", start_y, 0.3).set_ease(Tween.EASE_IN)
	_toast_tween.tween_property(_toast_panel, "modulate:a", 0.0, 0.3)
