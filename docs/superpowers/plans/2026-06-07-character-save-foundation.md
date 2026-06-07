# 角色存档地基 (Character Save Foundation) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把玩家状态 (背包/血量/魔力/盔甲/外观) 从世界存档里抽出来变成独立的「角色卡」`CharacterData`, 由 `CharacterManager` autoload 管理, 让同一角色带着背包/装备/血量跨世界 (泰拉瑞亚式)。

**Architecture:** 新增 `CharacterData` (Resource) 存角色全部状态 + `CharacterManager` (autoload) 管 `user://characters/{name}.tres` (照抄 `SaveManager` 的多档/原子写/网页 flush/防注入)。世界存档 `SaveData` 的玩家字段保留定义但作废 (升 v5)。`main.gd` 改成: 进世界时玩家状态从 `CharacterManager.current` 还原 (没选角色则 fallback 读 `SaveData` 兼容老流程), 存档时把玩家状态写回 `current`。本计划**不含**外观渲染 (留计划 2) 和捏人/选角色 UI (留计划 3) —— 角色外观字段先存着不画, 玩家这阶段仍是现状小人。

**Tech Stack:** Godot 4.3 + GDScript; GUT 9.x 测试; ResourceSaver/ResourceLoader (.tres); autoload。

**⚠️ 并发**: 仓库长期有别的 session 在改 `main.gd` / `scripts/save/` / `project.godot`。每个 Task commit 用 `git add <精确路径>`, **禁止** `-am` / `-A` / `.`。每步前先 `git status` 看清无关 WIP。

**⚠️ 测试前置**: 改了 autoload (Task 2) 必须先 `godot --headless --editor --quit` 重建 class_name 索引, 否则 GUT 报 `Identifier "..." not declared`。跑测试命令:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
(`libfontconfig.so.1` 那行警告过滤掉, 不是 error。)

---

## File Structure

**新增**:
- `scripts/save/character_data.gd` — `class_name CharacterData extends Resource`。角色卡: 外观 (性别/发型/衣裤款/披风/胸围/各色) + 玩家状态 (hp/mana/盔甲/背包/hotbar)。纯数据 + `appearance_dict()` helper。
- `scripts/save/character_manager.gd` — autoload `CharacterManager`。管 `user://characters/*.tres`: list/save/load/delete/has_any + `current` 选中态 + `ensure_current()` + `save_current_from_player(player)` + `apply_to_player(player)` + 老存档迁移。
- `tests/unit/test_character_data.gd` — CharacterData 存读往返 + 默认值 + appearance_dict。
- `tests/unit/test_character_manager.gd` — save/list/load/delete/防注入/has_any。
- `tests/unit/test_character_player_sync.gd` — save_current_from_player / apply_to_player 往返 (用 stub player)。
- `tests/unit/test_character_migration.gd` — 老 SaveData → 迁移出默认角色。
- `tests/integration/test_character_world_split.gd` — 角色背包跨世界 (端到端)。

**修改**:
- `project.godot` — autoload 注册 `CharacterManager`。
- `scripts/save/save_data.gd` — `CURRENT_VERSION` 4→5 + 玩家字段标 deprecated (保留定义)。
- `scripts/main.gd` — 进世界 `apply_to_player`(fallback 读 data) + 存档时 `save_current_from_player` + 启动 `ensure_current` + `player_name` 取 current.character_name。

**关键约定** (后续 Task 都依赖):
- 角色文件名清洗规则、原子写 `.tmp.tres`、网页 `_flush_web_filesystem` 全部**照抄** `scripts/save/save_manager.gd` 现成实现 (已读过, 见各 Task 代码)。
- `current` 是进程内全局选中态; 没 UI 时由 `ensure_current()` 兜底选第一个/造默认。

---

## Task 1: CharacterData 资源

**Files:**
- Create: `scripts/save/character_data.gd`
- Test: `tests/unit/test_character_data.gd`

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_character_data.gd`:

```gdscript
extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const TMP_PATH := "user://test_char_data.tres"

func after_each():
	if FileAccess.file_exists(TMP_PATH):
		DirAccess.remove_absolute(TMP_PATH)

func test_defaults():
	var c = CharacterData.new()
	assert_eq(c.version, CharacterData.CURRENT_VERSION, "version 默认 = CURRENT_VERSION")
	assert_eq(c.gender, 0, "默认男")
	assert_eq(c.chest_size, 1, "胸围默认 1")
	assert_eq(c.player_max_hp, 100, "默认上限 100")
	assert_eq(c.inventory_slots.size(), 0, "默认空背包数组")

func test_appearance_dict_has_all_keys():
	var c = CharacterData.new()
	var d = c.appearance_dict()
	for k in ["gender", "hair_style", "shirt_style", "pants_style", "cape_style",
			"chest_size", "skin_color", "hair_color", "shirt_color", "pants_color",
			"cape_color", "eye_color"]:
		assert_true(d.has(k), "appearance_dict 含 key %s" % k)

func test_save_load_round_trip():
	var c = CharacterData.new()
	c.character_name = "小明"
	c.gender = 1
	c.hair_style = 2
	c.shirt_style = 9
	c.pants_style = 10
	c.cape_style = 3
	c.chest_size = 4
	c.hair_color = Color8(10, 20, 30)
	c.eye_color = Color8(40, 50, 60)
	c.player_hp = 77.0
	c.player_max_hp = 220
	c.player_mana = 50
	c.player_max_mana = 180
	c.armor_chest_id = "iron_chestplate"
	c.hotbar_selection = 5
	c.inventory_slots = [{"item_id": "wood", "count": 99}, null, {"item_id": "stone", "count": 3}]
	assert_eq(ResourceSaver.save(c, TMP_PATH), OK, "写盘成功")
	var loaded = ResourceLoader.load(TMP_PATH)
	assert_true(loaded is CharacterData, "读回是 CharacterData")
	assert_eq(loaded.character_name, "小明")
	assert_eq(loaded.gender, 1)
	assert_eq(loaded.hair_style, 2)
	assert_eq(loaded.shirt_style, 9)
	assert_eq(loaded.pants_style, 10)
	assert_eq(loaded.cape_style, 3)
	assert_eq(loaded.chest_size, 4)
	assert_eq(loaded.hair_color, Color8(10, 20, 30))
	assert_eq(loaded.eye_color, Color8(40, 50, 60))
	assert_eq(loaded.player_hp, 77.0)
	assert_eq(loaded.player_max_hp, 220)
	assert_eq(loaded.player_mana, 50)
	assert_eq(loaded.player_max_mana, 180)
	assert_eq(loaded.armor_chest_id, "iron_chestplate")
	assert_eq(loaded.hotbar_selection, 5)
	assert_eq(loaded.inventory_slots.size(), 3)
	assert_eq(loaded.inventory_slots[0]["item_id"], "wood")
	assert_eq(loaded.inventory_slots[1], null)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_data.gd -gexit`
Expected: FAIL — `Could not load... character_data.gd` (文件还没建)。

- [ ] **Step 3: 写 CharacterData**

Create `scripts/save/character_data.gd`:

```gdscript
# 角色卡: 一个角色的全部状态 (外观 + 跟人走的背包/血量/魔力/盔甲)。
# 存 user://characters/{name}.tres, 由 CharacterManager 管。跨世界: 同一角色进任何世界。
# 外观字段款式数量见 spec docs/superpowers/specs/2026-06-07-character-creator-design.md。
class_name CharacterData extends Resource

const CURRENT_VERSION := 1
@export var version: int = CURRENT_VERSION
@export var character_name: String = ""

# ---- 外观 (捏人结果; 渲染在计划 2, 这里只存) ----
@export var gender: int = 0            # 0=男 1=女
@export var hair_style: int = 0        # 0..3
@export var shirt_style: int = 0       # 0..18 (见 spec 完整目录)
@export var pants_style: int = 0       # 0..19
@export var cape_style: int = 0        # 0=无 1=短披风 2=长披风 3=蝴蝶翅膀 4=恐龙尾 5=狗尾 6=兔尾
@export var chest_size: int = 1        # 仅 gender=1(女): 0..5
@export var skin_color: Color = Color8(255, 218, 185)
@export var hair_color: Color = Color8(121, 85, 72)
@export var shirt_color: Color = Color8(229, 57, 53)
@export var pants_color: Color = Color8(38, 70, 130)
@export var cape_color: Color = Color8(150, 40, 50)
@export var eye_color: Color = Color8(60, 110, 70)

# ---- 跟着角色走的玩家状态 (从 SaveData 搬过来) ----
@export var player_hp: float = 100.0
@export var player_max_hp: int = 100
@export var player_mana: int = 100
@export var player_max_mana: int = 100
@export var armor_helmet_id: String = ""
@export var armor_chest_id: String = ""
@export var armor_pants_id: String = ""
@export var inventory_slots: Array = []     # 36 槽: null 或 {"item_id": String, "count": int}
@export var hotbar_selection: int = 0


# 给渲染层 (计划 2 的 PlayerArt.build_sprite_frames) 用的外观快照。
# 单独抽出避免渲染层依赖整个 CharacterData。
func appearance_dict() -> Dictionary:
	return {
		"gender": gender,
		"hair_style": hair_style,
		"shirt_style": shirt_style,
		"pants_style": pants_style,
		"cape_style": cape_style,
		"chest_size": chest_size,
		"skin_color": skin_color,
		"hair_color": hair_color,
		"shirt_color": shirt_color,
		"pants_color": pants_color,
		"cape_color": cape_color,
		"eye_color": eye_color,
	}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_data.gd -gexit`
Expected: PASS (3 passing)。

- [ ] **Step 5: Commit**

```bash
git add scripts/save/character_data.gd tests/unit/test_character_data.gd
git commit -m "feat(character): CharacterData 角色卡资源 + 存读往返测试"
```

---

## Task 2: CharacterManager autoload (增删查 + 选中态)

**Files:**
- Create: `scripts/save/character_manager.gd`
- Modify: `project.godot` (autoload 段, 在 SaveManager 行后加一行)
- Test: `tests/unit/test_character_manager.gd`

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_character_manager.gd`:

```gdscript
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
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_manager.gd -gexit`
Expected: FAIL — 加载 character_manager.gd 失败 (没建)。

- [ ] **Step 3: 写 CharacterManager (增删查部分)**

Create `scripts/save/character_manager.gd`:

```gdscript
# 角色管理 autoload。管 user://characters/{name}.tres。
# 跟 SaveManager 平行: 文件名清洗/原子写/网页 flush 全照 save_manager.gd。
# current = 进程内当前选中角色 (进世界时 main 用它还原玩家)。
extends Node

const CharacterData = preload("res://scripts/save/character_data.gd")
const CHARS_DIR := "user://characters/"

# 测试可覆盖 (指向独立目录, 不污染真存档)。生产恒为 ""。
var CHARS_DIR_OVERRIDE: String = ""

var current: CharacterData = null

signal character_saved


func chars_dir() -> String:
	return CHARS_DIR_OVERRIDE if CHARS_DIR_OVERRIDE != "" else CHARS_DIR


func _ready() -> void:
	if not DirAccess.dir_exists_absolute(chars_dir()):
		DirAccess.make_dir_absolute(chars_dir())
	_migrate_from_world_saves()   # Task 4 实现


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
```

- [ ] **Step 4: 注册 autoload**

Modify `project.godot` — 在 `[autoload]` 段 `SaveManager="*res://scripts/save/save_manager.gd"` 那行**后面**加一行:

```
CharacterManager="*res://scripts/save/character_manager.gd"
```

- [ ] **Step 5: 重建索引 + 跑测试确认通过**

```bash
godot --headless --editor --quit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_manager.gd -gexit
```
Expected: PASS (5 passing)。若报 `Identifier "CharacterManager" not declared` → 没跑 `--editor --quit` 重建索引。

- [ ] **Step 6: Commit**

```bash
git add scripts/save/character_manager.gd tests/unit/test_character_manager.gd project.godot
git commit -m "feat(character): CharacterManager autoload 增删查 + 防注入测试"
```

---

## Task 3: 玩家 ↔ 角色状态同步 (save_current_from_player / apply_to_player)

**Files:**
- Modify: `scripts/save/character_manager.gd` (实现两个 stub)
- Test: `tests/unit/test_character_player_sync.gd`

**说明**: 这两个函数照 `main.gd` 现有「从 player 收集 / 还原到 player」的同款 guard (get_node_or_null + `in` 检查), 把玩家状态在 player 节点和 `current` 之间搬。stub player 用最小节点树模拟 `PlayerInventory`/`PlayerHealth`/`PlayerMana`。

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_character_player_sync.gd`:

```gdscript
extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const CharacterManager = preload("res://scripts/save/character_manager.gd")

var cm

func before_each():
	cm = CharacterManager.new()

func after_each():
	cm.free()

# --- 最小 stub player: 一个 Node 带 PlayerInventory/PlayerHealth/PlayerMana 子节点 ---
class StubInventoryHolder extends Node:
	var inventory = StubInv.new()
	var hotbar_selected: int = 0
	var armor_helmet = null
	var armor_chest = null
	var armor_pants = null
	signal inventory_changed
	signal hotbar_selection_changed(idx)
	func set_armor(kind: String, item: Dictionary) -> void:
		if kind == "helmet": armor_helmet = item
		elif kind == "chest": armor_chest = item
		elif kind == "pants": armor_pants = item
	func pickup(_id: String, _n: int) -> void:
		pass

class StubInv:
	var slots: Array = []

class StubHealth extends Node:
	var current_health: int = 100
	var MAX_HEALTH: int = 100
	var BASE_MAX_HEALTH: int = 100
	var MAX_HEALTH_CAP: int = 400
	signal health_changed(cur, mx)

class StubMana extends Node:
	var current_mana: int = 100
	var MAX_MANA: int = 100
	signal mana_changed(cur, mx)

func _make_player() -> Node:
	var p = Node.new()
	p.name = "Player"
	var inv = StubInventoryHolder.new()
	inv.name = "PlayerInventory"
	p.add_child(inv)
	var hp = StubHealth.new()
	hp.name = "PlayerHealth"
	p.add_child(hp)
	var mn = StubMana.new()
	mn.name = "PlayerMana"
	p.add_child(mn)
	return p

func test_save_current_collects_player_state():
	cm.current = CharacterData.new()
	var p = _make_player()
	p.get_node("PlayerInventory").inventory.slots = [{"item_id": "gold", "count": 5}, null]
	p.get_node("PlayerInventory").hotbar_selected = 3
	p.get_node("PlayerInventory").armor_chest = {"item_id": "iron_chestplate", "count": 1}
	p.get_node("PlayerHealth").current_health = 42
	p.get_node("PlayerHealth").MAX_HEALTH = 180
	p.get_node("PlayerMana").current_mana = 33
	p.get_node("PlayerMana").MAX_MANA = 150
	assert_true(cm.save_current_from_player(p), "收集成功")
	assert_eq(cm.current.inventory_slots.size(), 2)
	assert_eq(cm.current.inventory_slots[0]["item_id"], "gold")
	assert_eq(cm.current.hotbar_selection, 3)
	assert_eq(cm.current.armor_chest_id, "iron_chestplate")
	assert_eq(cm.current.player_hp, 42.0)
	assert_eq(cm.current.player_max_hp, 180)
	assert_eq(cm.current.player_mana, 33)
	assert_eq(cm.current.player_max_mana, 150)
	p.free()

func test_save_current_returns_false_when_no_current():
	cm.current = null
	var p = _make_player()
	assert_false(cm.save_current_from_player(p), "没 current 不收集")
	p.free()

func test_save_current_returns_false_when_inventory_not_ready():
	# 加载窗口期护栏: inventory 为 null 不写 (防丢三件套)。
	cm.current = CharacterData.new()
	var p = _make_player()
	p.get_node("PlayerInventory").inventory = null
	assert_false(cm.save_current_from_player(p), "inventory 未就绪不收集")
	p.free()

func test_apply_to_player_restores_state():
	cm.current = CharacterData.new()
	cm.current.inventory_slots = [{"item_id": "wood", "count": 10}]
	cm.current.hotbar_selection = 2
	cm.current.armor_helmet_id = "iron_helmet"
	cm.current.player_hp = 55.0
	cm.current.player_max_hp = 200
	cm.current.player_mana = 60
	cm.current.player_max_mana = 140
	var p = _make_player()
	cm.apply_to_player(p)
	var inv = p.get_node("PlayerInventory")
	assert_eq(inv.inventory.slots.size(), 1)
	assert_eq(inv.inventory.slots[0]["item_id"], "wood")
	assert_eq(inv.hotbar_selected, 2)
	assert_eq(inv.armor_helmet["item_id"], "iron_helmet")
	assert_eq(p.get_node("PlayerHealth").current_health, 55)
	assert_eq(p.get_node("PlayerHealth").MAX_HEALTH, 200)
	assert_eq(p.get_node("PlayerMana").current_mana, 60)
	assert_eq(p.get_node("PlayerMana").MAX_MANA, 140)
	p.free()

func test_round_trip_player_to_character_to_player():
	cm.current = CharacterData.new()
	var p1 = _make_player()
	p1.get_node("PlayerInventory").inventory.slots = [{"item_id": "diamond", "count": 7}]
	p1.get_node("PlayerHealth").current_health = 88
	cm.save_current_from_player(p1)
	p1.free()
	var p2 = _make_player()
	cm.apply_to_player(p2)
	assert_eq(p2.get_node("PlayerInventory").inventory.slots[0]["item_id"], "diamond")
	assert_eq(p2.get_node("PlayerHealth").current_health, 88)
	p2.free()
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_player_sync.gd -gexit`
Expected: FAIL — `save_current_from_player` 返回 false (stub), apply 不改 player。

- [ ] **Step 3: 实现两个函数**

In `scripts/save/character_manager.gd`, 替换 Task 2 留的两个 stub:

```gdscript
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
	if inv_node != null and inv_node.inventory != null:
		inv_node.inventory.slots = current.inventory_slots.duplicate(true)
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_player_sync.gd -gexit`
Expected: PASS (5 passing)。

- [ ] **Step 5: Commit**

```bash
git add scripts/save/character_manager.gd tests/unit/test_character_player_sync.gd
git commit -m "feat(character): 玩家<->角色状态同步 (背包/血量/魔力/盔甲) + 测试"
```

---

## Task 4: 迁移老存档 + ensure_current

**Files:**
- Modify: `scripts/save/character_manager.gd` (实现 `_migrate_from_world_saves` + `ensure_current`)
- Test: `tests/unit/test_character_migration.gd`

**说明**: 迁移仅在 `chars_dir()` 为空且存在世界存档时跑: 取最新世界存档的玩家字段 + 默认外观造一张「默认角色」。`ensure_current` 兜底选中态 (没 UI 时): current 为空 → 选第一个角色; 一个都没有 → 造一张默认。

为可测, `_migrate_from_world_saves` 接受可选的「存档来源」回调; 默认用 `SaveManager.list_saves()`。测试注入一个假来源。

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_character_migration.gd`:

```gdscript
extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")
const CharacterManager = preload("res://scripts/save/character_manager.gd")
const SaveData = preload("res://scripts/save/save_data.gd")

var cm

func before_each():
	cm = CharacterManager.new()
	cm.CHARS_DIR_OVERRIDE = "user://test_chars_mig/"
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

func _fake_save(inv: Array, hp: int, max_hp: int) -> SaveData:
	var s = SaveData.new()
	s.world_name = "老世界"
	s.inventory_slots = inv
	s.player_hp = float(hp)
	s.player_max_hp = max_hp
	s.hotbar_selection = 4
	s.armor_chest_id = "gold_chestplate"
	return s

func test_migration_creates_default_character_from_newest_save():
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	var save = _fake_save([{"item_id": "emerald", "count": 12}], 73, 240)
	# 注入假存档来源 (最新在前)
	cm.migrate_with_saves([{"name": "老世界", "data": save}], "勇者")
	var chars = cm.list_characters()
	assert_eq(chars.size(), 1, "迁移出 1 个角色")
	var c = chars[0]["data"]
	assert_eq(c.inventory_slots[0]["item_id"], "emerald", "背包搬过来")
	assert_eq(c.player_hp, 73.0, "血量搬过来")
	assert_eq(c.player_max_hp, 240, "上限搬过来")
	assert_eq(c.hotbar_selection, 4)
	assert_eq(c.armor_chest_id, "gold_chestplate")
	assert_eq(c.gender, 0, "外观=默认 (男)")

func test_migration_skips_when_characters_exist():
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	var pre = CharacterData.new()
	pre.character_name = "已有"
	cm.save_character(pre)
	cm.migrate_with_saves([{"name": "老世界", "data": _fake_save([], 100, 100)}], "勇者")
	assert_eq(cm.list_characters().size(), 1, "已有角色则不迁移")

func test_migration_noop_when_no_saves():
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	cm.migrate_with_saves([], "勇者")
	assert_false(cm.has_any(), "没世界存档 → 不造角色")

func test_ensure_current_picks_existing():
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	var c = CharacterData.new()
	c.character_name = "现成"
	cm.save_character(c)
	cm.current = null
	cm.ensure_current()
	assert_not_null(cm.current, "ensure_current 选了一个")
	assert_eq(cm.current.character_name, "现成")

func test_ensure_current_creates_default_when_none():
	if not DirAccess.dir_exists_absolute(cm.chars_dir()):
		DirAccess.make_dir_absolute(cm.chars_dir())
	cm.current = null
	cm.ensure_current()
	assert_not_null(cm.current, "没角色则造默认")
	assert_true(cm.has_any(), "默认角色写盘了")
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_migration.gd -gexit`
Expected: FAIL — `migrate_with_saves` 方法不存在。

- [ ] **Step 3: 实现迁移 + ensure_current**

In `scripts/save/character_manager.gd`, 替换 Task 2 留的 `ensure_current` / `_migrate_from_world_saves` stub:

```gdscript
const DEFAULT_CHARACTER_NAME := "默认角色"


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


# 生产入口 (_ready 调): 用 SaveManager 的真存档列表迁移。
func _migrate_from_world_saves() -> void:
	# SaveManager 是 autoload; 测试环境可能没就绪 → 容错。
	var saves: Array = []
	if Engine.has_singleton("SaveManager") == false and typeof(SaveManager) != TYPE_NIL:
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
```

注意: `_migrate_from_world_saves` 里 `Engine.has_singleton("SaveManager") == false` 那行是容错写法 —— 真正判断用 `typeof(SaveManager) != TYPE_NIL`。autoload `SaveManager` 在测试单跑某文件时也存在, 但 `_ready` 迁移用真目录 (CHARS_DIR_OVERRIDE 为空), 测试**不依赖** `_ready`, 全走 `migrate_with_saves` 直调, 不污染真存档。

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_character_migration.gd -gexit`
Expected: PASS (5 passing)。

- [ ] **Step 5: Commit**

```bash
git add scripts/save/character_manager.gd tests/unit/test_character_migration.gd
git commit -m "feat(character): 老存档迁移出默认角色 + ensure_current 兜底"
```

---

## Task 5: SaveData 升 v5, 玩家字段标 deprecated

**Files:**
- Modify: `scripts/save/save_data.gd`
- Test: (无新测试; 跑现有存档测试确认不回归)

**说明**: 升版本号 + 注释标注玩家字段作废 (保留定义防老 .tres 读不了)。**不删字段、不改 save_manager 写逻辑** —— 世界存档继续写玩家字段是无害冗余; 权威来源改成 CharacterManager 由 Task 6 在 main 接线完成。这一步纯文档化版本演进。

- [ ] **Step 1: 改 CURRENT_VERSION + 注释**

In `scripts/save/save_data.gd`, 改:

```gdscript
# v3 → v4: 加魔力 (current+max) + 魔力水晶 spawned/positions.
# v4 → v5: 角色系统上线 — 玩家状态 (hp/max_hp/mana/armor/inventory/hotbar/player_position)
#          移到 CharacterData (user://characters/), 由 CharacterManager 管, 跟着角色跨世界。
#          下面这些玩家字段保留定义 (防老 .tres 读不了) 但**作废**: 新存档权威来源是角色卡,
#          main 加载时从 CharacterManager.current 还原玩家, 不再信世界存档里的这些值。
const CURRENT_VERSION := 5
```

并在玩家相关 `@export` 字段那一段 (player_position / player_hp / player_max_hp / player_mana / player_max_mana / armor_* / inventory_slots / hotbar_selection) 上方加一行注释:

```gdscript
# ===== v5 起作废: 以下玩家字段由 CharacterData 接管 (跟角色走), 世界存档不再是权威来源 =====
```

- [ ] **Step 2: 跑现有存档测试确认不回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: 现有存档相关测试 (test_*save* 等) 全 PASS (只改了版本号常量 + 注释, 行为不变)。

- [ ] **Step 3: Commit**

```bash
git add scripts/save/save_data.gd
git commit -m "feat(save): SaveData v5 — 玩家字段移交 CharacterData (标 deprecated, 保留定义)"
```

---

## Task 6: main.gd 接线 — 玩家状态走角色卡

**Files:**
- Modify: `scripts/main.gd`
- Test: `tests/integration/test_character_world_split.gd`

**说明**: 三处接线:
1. **启动世界** (`_start_game` / `_start_game_sync` 入口): 调 `CharacterManager.ensure_current()` 保证有选中角色; `GameSettings.player_name = CharacterManager.current.character_name`。
2. **加载玩家状态** (`_apply_save_data` 玩家段): 若 `CharacterManager.current != null` → `CharacterManager.apply_to_player(player)` (角色卡权威); 否则保留现有「从 data 还原」逻辑 (兼容)。
3. **存档** (`_start_autosave` 的 timeout + 任何调 `SaveManager.save(self)` 处): 之后补 `CharacterManager.save_current_from_player(player)`。

为了让接线点集中, 加一个 helper `_save_all(self)` 同时存世界 + 角色, autosave/退出都调它。

- [ ] **Step 1: 写失败的集成测试**

Create `tests/integration/test_character_world_split.gd`:

```gdscript
# 角色背包跨世界: 给 current 角色放东西 → 进世界 → 角色卡留着这些东西;
# apply_to_player 还原到新 player → 背包是角色的 (跟人走)。
extends GutTest

const CharacterData = preload("res://scripts/save/character_data.gd")

func test_character_inventory_persists_across_apply():
	# 直接用 autoload CharacterManager (集成层)。备份/恢复 current 防污染。
	var saved_current = CharacterManager.current
	CharacterManager.current = CharacterData.new()
	CharacterManager.current.character_name = "测试勇者"
	CharacterManager.current.inventory_slots = [{"item_id": "magic_sword", "count": 1}]
	CharacterManager.current.player_hp = 65.0

	# 模拟「进世界 A」用的最小 player
	var p_a = _stub_player()
	get_tree().root.add_child(p_a)
	CharacterManager.apply_to_player(p_a)
	assert_eq(p_a.get_node("PlayerInventory").inventory.slots[0]["item_id"], "magic_sword",
		"世界 A 玩家拿到角色的剑")
	# 在世界 A 改了背包 (捡到金子) → 存回角色
	p_a.get_node("PlayerInventory").inventory.slots.append({"item_id": "gold", "count": 9})
	CharacterManager.save_current_from_player(p_a)
	p_a.queue_free()

	# 「进世界 B」: 新 player, 还原角色 → 背包带着剑 + 金子
	var p_b = _stub_player()
	get_tree().root.add_child(p_b)
	CharacterManager.apply_to_player(p_b)
	var slots = p_b.get_node("PlayerInventory").inventory.slots
	assert_eq(slots.size(), 2, "世界 B 背包 = 角色的 (剑+金子)")
	assert_eq(slots[1]["item_id"], "gold")
	assert_eq(p_b.get_node("PlayerHealth").current_health, 65, "血量也跟着角色")
	p_b.queue_free()

	CharacterManager.current = saved_current

func _stub_player() -> Node:
	var p = Node.new()
	p.name = "Player"
	var inv = _InvHolder.new()
	inv.name = "PlayerInventory"
	p.add_child(inv)
	var hp = _Health.new()
	hp.name = "PlayerHealth"
	p.add_child(hp)
	return p

class _InvHolder extends Node:
	var inventory = _Inv.new()
	var hotbar_selected: int = 0
	var armor_helmet = null
	var armor_chest = null
	var armor_pants = null
	signal inventory_changed
	signal hotbar_selection_changed(idx)
	func set_armor(_k, _i): pass

class _Inv:
	var slots: Array = []

class _Health extends Node:
	var current_health: int = 100
	var MAX_HEALTH: int = 100
	var BASE_MAX_HEALTH: int = 100
	var MAX_HEALTH_CAP: int = 400
	signal health_changed(c, m)
```

- [ ] **Step 2: 跑测试确认通过 (验证 Task 3 在 autoload 层也对)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_character_world_split.gd -gexit`
Expected: PASS (1 passing)。这步**已能过** (Task 3 实现了 apply/save), 它锁住 autoload 层行为, 防 Task 6 main 接线改坏。

- [ ] **Step 3: main.gd 加 `_save_all` helper + 改 autosave**

In `scripts/main.gd`, 找 `_start_autosave()` 里的 timeout 回调 (约 244 行):
```gdscript
	_autosave_timer.timeout.connect(func():
```
那个 lambda 里现有的 `SaveManager.save(self)` 调用, 替换成 `_save_all()`。然后在 `_stop_autosave()` 附近加 helper:

```gdscript
# 存世界 + 存当前角色卡 (玩家状态)。autosave / 退出都走这。
func _save_all() -> void:
	SaveManager.save(self)
	if typeof(CharacterManager) != TYPE_NIL and CharacterManager.current != null:
		var w = world
		if w != null:
			var player = w.get_player()
			if player != null:
				CharacterManager.save_current_from_player(player)
```

(若 autosave lambda 里原来是 `if <某条件>: SaveManager.save(self)`, 保留条件, 把 `SaveManager.save(self)` 换成 `_save_all()`。)

- [ ] **Step 4: main.gd 启动世界时 ensure_current + player_name**

In `scripts/main.gd` `_start_game(...)` 函数体**最前面** (设置 GameSettings 那几行附近, 在世界创建之前), 加:

```gdscript
	# 角色系统: 保证有选中角色 (计划 3 的选角色 UI 上线前由 ensure_current 兜底),
	# 并用角色名当玩家名 (联机/UI/死亡画面显示)。
	if typeof(CharacterManager) != TYPE_NIL:
		CharacterManager.ensure_current()
		if CharacterManager.current != null and CharacterManager.current.character_name != "":
			GameSettings.player_name = CharacterManager.current.character_name
```

(同样在 `_start_game_sync(...)` 开头加一份, 因为测试/boot 走那条路。)

- [ ] **Step 5: main.gd 加载时玩家状态优先用角色卡**

In `scripts/main.gd` `_apply_save_data(...)`, 找到「移玩家 + 还原血量/背包」段 (约 348 行 `var player: Node2D = w.get_player()` 起)。在拿到 `player` 且不为 null 之后、还原 hp/inventory 的现有代码**之前**, 插入:

```gdscript
	# 角色系统: 玩家状态 (血量/魔力/背包/盔甲) 权威来源 = 当前角色卡。
	# 有选中角色 → 用角色卡还原, 跳过下面从世界存档 (data) 还原玩家的旧逻辑。
	# 位置仍用世界存档/spawn (进世界回出生点逻辑不变)。
	var _use_character: bool = typeof(CharacterManager) != TYPE_NIL and CharacterManager.current != null
	if _use_character:
		CharacterManager.apply_to_player(player)
```

然后把该函数里**从世界存档 data 还原玩家 hp/mana/inventory/armor 的那几段** (约 371-421 行: `var hp ...` 到「重新发起步包」结束) 包进 `if not _use_character:`。位置还原段 (saved_pos / ensure_loaded, 约 352-370 行) **保持在外不变** (位置永远用世界存档)。

具体: 在 `var hp: Node = player.get_node_or_null("PlayerHealth")` 之前加 `if not _use_character:` 并把后续玩家状态段整体缩进一级, 直到 `restore_entities_from_save` 之前 (死亡掉落段不缩进, 仍照常跑)。

- [ ] **Step 6: 跑全套测试 + 手验不回归**

```bash
godot --headless --editor --quit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 全 PASS。重点看现有 `test_*save*` / 死亡掉落相关集成测试不回归。
然后 `./run.sh --rebuild` 让用户手动验: 进世界 → 背包在 → 退出重进 → 背包还在 → 换个世界 → 背包跟着 (跨世界)。

- [ ] **Step 7: Commit**

```bash
git add scripts/main.gd tests/integration/test_character_world_split.gd
git commit -m "feat(character): main 接线 — 玩家状态走角色卡 (跨世界), autosave 同存角色"
```

---

## Self-Review (写计划后自查)

**Spec 覆盖** (对 spec 组件 A/B/E):
- A CharacterData → Task 1 ✅ (全字段 + appearance_dict + 往返测试)
- B CharacterManager 增删查 → Task 2 ✅; 玩家同步 → Task 3 ✅; 迁移 + ensure_current → Task 4 ✅
- E 存档拆分: SaveData v5 → Task 5 ✅; main 接线 (apply_to_player / save_current / ensure_current / player_name / 位置仍用世界 spawn) → Task 6 ✅
- E 迁移 (只读不删世界存档, 取最新存档玩家数据) → Task 4 `migrate_with_saves` ✅
- 就绪护栏 (防丢三件套) → Task 3 `save_current_from_player` inventory null 检查 ✅
- 死亡掉落不回归 → Task 6 Step 5 把死亡掉落段留在 `_use_character` 分支外 ✅

**本计划不含** (留后续计划, 非遗漏):
- C 外观渲染 (24×48 侧面分层 / 款式美术) → 计划 2
- D 捏人 + 选角色 UI → 计划 3
- 服装内容批次 → 计划 4
- 联机外观同步 → spec 已列非目标

**占位扫描**: 无 TBD/TODO; 每个代码步给了完整代码。

**类型/命名一致性**: `current` / `chars_dir()` / `CHARS_DIR_OVERRIDE` / `save_current_from_player` / `apply_to_player` / `ensure_current` / `migrate_with_saves` / `appearance_dict` 全计划一致。stub player 节点名 `PlayerInventory`/`PlayerHealth`/`PlayerMana` 与 main.gd 真实节点名一致。

**已知风险/执行注意**:
- Task 6 Step 5 是改动面最大处 (给 main 一段代码加缩进包 `if`)。执行者务必先 `git diff` 核对缩进, 跑死亡掉落测试确认不回归。
- 改 autoload (Task 2) 后必须 `--editor --quit` 重建索引再跑测试。
- 全程 `git add <精确路径>`, 别卷入仓库的无关 WIP。
