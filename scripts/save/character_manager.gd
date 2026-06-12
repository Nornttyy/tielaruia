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
	# 不再开机自动迁移/造默认角色 (用户报: 每次进游戏多出一个"我的角色")。
	# 根因: 这行每次启动都跑, 而网页(IndexedDB)在 autoload _ready 时常还没同步好 →
	# has_any() 误判"没角色" → 又造一个 (名字 = player_name, 多半就是"我的角色")。
	# 现在角色创建/选择全靠显式 UI; 真没角色时由 ensure_current 在"开始游戏"那刻兜底 (那会儿 FS 已就绪)。
	# migrate_with_saves 函数保留 (可显式调 / 老测试用), 只是不再开机自动跑。


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
		# 网页 (HTML5) 文件系统 rename 偶尔失败 → 角色会卡成 .tmp.tres (列表跳过这种文件) =
		# "保存了却没出现在列表里" (用户报). 兜底: 直接写最终路径, 别让 rename 失败把角色弄丢。
		push_warning("save_character: rename 失败 err=%d, 改直接写最终路径" % rename_err)
		var direct_err: int = ResourceSaver.save(c, path)
		DirAccess.remove_absolute(tmp_path)   # 清掉残留的 .tmp.tres
		if direct_err != OK:
			push_error("save_character: 直接写也失败 err=%d" % direct_err)
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


# 从 player 节点收集玩家状态写进 current。沿用 main.gd 的就绪护栏: current 为空 /
# inventory 未就绪 → 返 false 不写 (防加载窗口期 autosave 写出空背包覆盖好档 = 丢三件套)。
func save_current_from_player(player: Node) -> bool:
	if current == null or player == null:
		return false
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	if inv_node == null or inv_node.inventory == null:
		return false
	# 背包 (深拷贝, 不跟 player 共享引用)
	var slots_copy: Array = []
	for s in inv_node.inventory.slots:
		slots_copy.append(null if s == null else {"item_id": s.item_id, "count": s.count})
	current.inventory_slots = slots_copy
	if "hotbar_selected" in inv_node:
		current.hotbar_selection = inv_node.hotbar_selected
	current.armor_helmet_id = "" if inv_node.armor_helmet == null else String(inv_node.armor_helmet.item_id)
	current.armor_chest_id = "" if inv_node.armor_chest == null else String(inv_node.armor_chest.item_id)
	current.armor_pants_id = "" if inv_node.armor_pants == null else String(inv_node.armor_pants.item_id)
	# 血量
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and "current_health" in hp:
		current.player_hp = float(hp.current_health)
		current.player_max_hp = int(hp.MAX_HEALTH) if "MAX_HEALTH" in hp else 100
	# 魔力
	var mn: Node = player.get_node_or_null("PlayerMana")
	if mn != null and "current_mana" in mn:
		current.player_mana = int(mn.current_mana)
		current.player_max_mana = int(mn.MAX_MANA) if "MAX_MANA" in mn else 100
	return true


# 把 current 的玩家状态还原到 player 节点 (照 main._apply_save_data 的玩家段)。
# 外观不在此处理 (计划 2 渲染)。current 为空则 no-op。
func apply_to_player(player: Node) -> void:
	if current == null or player == null:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and "current_health" in hp:
		if "MAX_HEALTH" in hp and "BASE_MAX_HEALTH" in hp and "MAX_HEALTH_CAP" in hp:
			hp.MAX_HEALTH = clamp(current.player_max_hp, hp.BASE_MAX_HEALTH, hp.MAX_HEALTH_CAP)
		hp.current_health = clamp(int(current.player_hp), 0, hp.MAX_HEALTH)
		if hp.has_signal("health_changed"):
			hp.health_changed.emit(hp.current_health, hp.MAX_HEALTH)
	var mn: Node = player.get_node_or_null("PlayerMana")
	if mn != null and "current_mana" in mn:
		if "MAX_MANA" in mn:
			mn.MAX_MANA = int(current.player_max_mana)
		mn.current_mana = clamp(int(current.player_mana), 0, mn.MAX_MANA)
		if mn.has_signal("mana_changed"):
			mn.mana_changed.emit(mn.current_mana, mn.MAX_MANA)
	var inv_node: Node = player.get_node_or_null("PlayerInventory")
	# 只在角色卡【有东西】时才覆盖背包. 空卡 (全新角色/没存过) 不抹掉玩家已有/世界存档还原的背包,
	# 防"读档丢三件套 / 拿不了方块". (旧 bug: 继续读档时空卡无条件覆盖, 把背包清空。)
	var card_has_items := false
	for s in current.inventory_slots:
		if s != null:
			card_has_items = true
			break
	if inv_node != null and inv_node.inventory != null and card_has_items:
		inv_node.inventory.slots = current.inventory_slots.duplicate(true)
		ItemDB.canon_slots(inv_node.inventory.slots)   # 改名物品兼容 (弹跳枪→史莱姆冲锋枪)
		if "hotbar_selected" in inv_node:
			inv_node.hotbar_selected = current.hotbar_selection
		if inv_node.has_signal("inventory_changed"):
			inv_node.inventory_changed.emit()
		if inv_node.has_signal("hotbar_selection_changed"):
			inv_node.hotbar_selection_changed.emit(current.hotbar_selection)
		if inv_node.has_method("set_armor"):
			for pair in [["helmet", current.armor_helmet_id], ["chest", current.armor_chest_id], ["pants", current.armor_pants_id]]:
				if pair[1] != "":
					inv_node.set_armor(pair[0], {"item_id": pair[1], "count": 1})


# 没选中角色时兜底 (计划 3 的选角色 UI 上线前, main 启动时调)。
# current 已有 → 不动; 否则选第一个已存角色; 一个都没有 → 造默认并写盘。
func ensure_current() -> void:
	if current != null:
		return
	var chars: Array = list_characters()
	if not chars.is_empty():
		current = chars[0]["data"]
		return
	var c := CharacterData.new()
	c.character_name = DEFAULT_CHARACTER_NAME
	save_character(c)
	current = c


# 生产入口 (_ready 调): 用 SaveManager 的真存档列表迁移。autoload 才有 SaveManager/GameSettings。
func _migrate_from_world_saves() -> void:
	var saves: Array = []
	if typeof(SaveManager) != TYPE_NIL and SaveManager.has_method("list_saves"):
		saves = SaveManager.list_saves()
	var p_name: String = "玩家"
	if typeof(GameSettings) != TYPE_NIL and "player_name" in GameSettings:
		p_name = GameSettings.player_name
	migrate_with_saves(saves, p_name)


# 可测核心: 给定存档列表 (最新在前) + 玩家名, 仅当无角色且有存档时造默认角色。
# 只读不删世界存档 (世界地形/箱子原样保留, 其玩家字段从此被忽略)。
func migrate_with_saves(saves: Array, player_name: String) -> void:
	if has_any():
		return            # 已有角色 → 不迁移
	if saves.is_empty():
		return            # 没世界存档 → 不造
	var newest = saves[0]["data"]
	var c := CharacterData.new()
	c.character_name = player_name if (player_name != null and player_name != "") else DEFAULT_CHARACTER_NAME
	# 玩家状态从最新世界存档搬过来 (字段名同 SaveData)
	if "inventory_slots" in newest:
		c.inventory_slots = newest.inventory_slots.duplicate(true)
	if "player_hp" in newest:
		c.player_hp = float(newest.player_hp)
	if "player_max_hp" in newest:
		c.player_max_hp = int(newest.player_max_hp)
	if "player_mana" in newest:
		c.player_mana = int(newest.player_mana)
	if "player_max_mana" in newest:
		c.player_max_mana = int(newest.player_max_mana)
	if "hotbar_selection" in newest:
		c.hotbar_selection = int(newest.hotbar_selection)
	if "armor_helmet_id" in newest:
		c.armor_helmet_id = String(newest.armor_helmet_id)
	if "armor_chest_id" in newest:
		c.armor_chest_id = String(newest.armor_chest_id)
	if "armor_pants_id" in newest:
		c.armor_pants_id = String(newest.armor_pants_id)
	# 外观 = 默认 (现状小人); 计划 2 渲染。
	save_character(c)
