# 捏人界面 + 选角色界面 Implementation Plan (Plan 3)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家在「开始游戏」里**先选角色 (列表+捏新角色)→ 再选世界**, 捏人界面能改名字/性别/发型/胸围(女)/皮肤·头发·衬衫·裤子·披风·眼珠 6 色, 带活的小人预览, 保存进 `CharacterManager`。

**Architecture:** 新建 `scripts/ui/character_panels.gd` (一个 `Control`, main_menu 实例化为子节点), 用**代码动态构建** 选角色面板 + 捏人面板 (照 main_menu 现有 `_make_save_row` 动态生成思路, 不手写脆弱 .tscn)。main_menu 的「开始游戏」改成先开选角色面板; 选中角色 → `CharacterManager.current` = 它 → 转世界选择面板 (复用现有流程)。本计划只放**当前能渲染**的定制项 (性别/发型/胸围/6 色 + 名字); 衣裤款式选择器留 Plan 4 (服装美术做好再加)。

**Tech Stack:** Godot 4.3 + GDScript; `CharacterManager` / `CharacterData` / `ArtCache.player_frames_for` (已有); GUT。

**⚠️ 并发**: `main_menu.gd` 近期别的 session 动过。每步 `git add <精确路径>`, 禁 `-am`/`-A`/`.`。

**⚠️ 测试**: 加新 class_name/autoload 才需 `--editor --quit`; 本计划不加 autoload (character_panels 是普通脚本, 不注册 autoload)。单文件测试:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=<file>.gd -gexit
```

---

## File Structure

**新增**:
- `scripts/ui/character_panels.gd` — `extends Control`。一个挂在 MainMenu 下的容器, 代码建两个子面板:
  - `_select_panel` (选角色): 标题 + 角色列表 (每行 `[名字] [选择] [删除]`) + `[捏个新角色]` + `[返回]`。
  - `_creator_panel` (捏人): 左 `AnimatedSprite2D` 活预览 + 右选项 (名字/性别/发型/胸围/6 色) + `[保存] [取消]`。
  - 信号: `character_chosen` (选了角色, main_menu 去开世界选择), `closed` (返回主菜单)。
  - 方法: `open_select()` (打开选角色面板)。
- `tests/unit/test_character_panels.gd` — 面板存在/选角色设 current/捏人保存/性别切换显隐胸围。

**修改**:
- `scripts/ui/main_menu.gd` — `_on_new_game_pressed` 改成开 `character_panels.open_select()`; 接 `character_chosen` → 开 WorldSelectPanel; 接 `closed` → 回主按钮; `_ready` 实例化 character_panels。

**关键复用**: 小人预览用 `ArtCache.player_frames_for(appearance)` (Plan 2 已加)。颜色色块/款式切换照 `_apply_button_style` 风格 (main_menu 有)。

---

## Task 1: 选角色面板 + 流程接线

**Files:**
- Create: `scripts/ui/character_panels.gd` (先只做 select 面板; creator 占位)
- Modify: `scripts/ui/main_menu.gd`
- Test: `tests/unit/test_character_panels.gd`

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_character_panels.gd`:

```gdscript
extends GutTest

const CharacterPanels = preload("res://scripts/ui/character_panels.gd")
const CharacterData = preload("res://scripts/save/character_data.gd")

var panels

func before_each():
	panels = CharacterPanels.new()
	add_child_autofree(panels)
	# 用独立角色目录, 不污染真存档
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
	panels._choose_character("勇者A")   # 直调选中逻辑 (不点按钮)
	assert_eq(CharacterManager.current.character_name, "勇者A", "current 设成选中角色")
	assert_signal_emitted(panels, "character_chosen")

func _all_labels(node: Node) -> Array:
	var out: Array = []
	if node is Label: out.append(node)
	for c in node.get_children(): out += _all_labels(c)
	return out
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_character_panels.gd -gexit`
Expected: FAIL — character_panels.gd 不存在。

- [ ] **Step 3: 写 character_panels.gd (select 面板)**

Create `scripts/ui/character_panels.gd`:

```gdscript
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
	_select_panel.set_anchors_preset(Control.PRESET_CENTER)
	_select_panel.custom_minimum_size = Vector2(420, 460)
	_select_panel.position = Vector2(430, 130)
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
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_character_panels.gd -gexit`
Expected: PASS (3 passing)。

- [ ] **Step 5: main_menu 接线**

In `scripts/ui/main_menu.gd`:

(a) 顶部加 const + 变量:
```gdscript
const CharacterPanelsScene = preload("res://scripts/ui/character_panels.gd")
var _character_panels: Control = null
```

(b) `_ready()` 末尾 (在 `Locale.language_changed.connect` 之后) 加:
```gdscript
	_character_panels = CharacterPanelsScene.new()
	add_child(_character_panels)
	_character_panels.character_chosen.connect(_on_character_chosen)
	_character_panels.closed.connect(_on_character_panels_closed)
```

(c) 改 `_on_new_game_pressed()` —— 现在它直接开 WorldSelectPanel, 改成先开选角色:
```gdscript
func _on_new_game_pressed() -> void:
	# 先选角色 (Plan 3): 选完角色再开世界选择。
	$ButtonLayer/VBox.visible = false
	_character_panels.open_select()
```

(d) 加两个接线回调:
```gdscript
# 选完角色 → 开世界选择 (原 _on_new_game_pressed 的内容)。
func _on_character_chosen() -> void:
	$WorldSelectPanel.visible = true
	_refresh_saves_list()

# 选角色面板点返回 → 回主菜单按钮。
func _on_character_panels_closed() -> void:
	$ButtonLayer/VBox.visible = true
```

- [ ] **Step 6: 跑全套确认不回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
Expected: 全 PASS (尤其 `test_main_menu.gd` 不回归 —— 它测 `_on_new_game_pressed` 显示 WorldSelectPanel, 现在改成显示选角色面板, **该测试需同步更新**)。
若 `test_main_menu.gd::test_new_game_button_shows_world_select_panel` 挂, 改它: 断言点 NewGame 后 `_character_panels.visible == true` (而非 WorldSelectPanel)。改完再跑。

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/character_panels.gd scripts/ui/main_menu.gd tests/unit/test_character_panels.gd tests/unit/test_main_menu.gd
git commit -m "feat(character-ui): 选角色面板 + 开始游戏先选角色再选世界"
```

---

## Task 2: 捏人面板 (预览 + 定制 + 保存)

**Files:**
- Modify: `scripts/ui/character_panels.gd` (加 creator 面板)
- Test: `tests/unit/test_character_panels.gd` (加断言)

**说明**: 捏人面板用代码建: 左侧 `AnimatedSprite2D` (从 `ArtCache.player_frames_for(_appearance)` 出图, 改任意项就重建) + 右侧选项。选项只放**能渲染**的: 名字 / 性别(男女) / 发型(◀▶ 0..3) / 胸围(滑条 0..5, 仅女显示) / 6 个颜色行 (每行几个色块按钮)。保存 → 组 `CharacterData` → `CharacterManager.save_character` + 设 current → 回选角色面板。

- [ ] **Step 1: 加失败测试** (追加到 test_character_panels.gd)

```gdscript
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
```

- [ ] **Step 2: 跑确认失败** (creator 方法/节点不存在)。

- [ ] **Step 3: 实现 creator 面板**

In `scripts/ui/character_panels.gd`, 加成员 + 替换 `_on_new_character` stub + 加方法:

```gdscript
const PlayerArt = preload("res://scripts/art/player_art.gd")

var _creator_panel: Panel
var _preview: AnimatedSprite2D
var _name_edit: LineEdit
var _chest_row: HBoxContainer
var _appearance: Dictionary = {}

# 色块候选 (暖色优先)
const _SKIN := [Color8(255,218,185), Color8(240,190,150), Color8(200,150,110), Color8(150,100,70), Color8(95,60,40)]
const _HAIR := [Color8(121,85,72), Color8(60,40,30), Color8(20,20,20), Color8(210,180,90), Color8(180,70,50), Color8(120,90,160)]
const _SHIRT := [Color8(229,57,53), Color8(50,110,200), Color8(70,160,90), Color8(240,200,70), Color8(230,140,60), Color8(240,240,240)]
const _PANTS := [Color8(38,70,130), Color8(60,50,45), Color8(80,80,90), Color8(120,80,60), Color8(40,90,70), Color8(20,20,30)]
const _EYE := [Color8(60,110,70), Color8(70,120,200), Color8(110,70,50), Color8(40,40,40), Color8(150,90,170), Color8(200,140,60)]


func _on_new_character() -> void:
	_appearance = PlayerArt.DEFAULT_APPEARANCE.duplicate(true)
	if _creator_panel == null:
		_build_creator_panel()
	_name_edit.text = ""
	_select_panel.visible = false
	_creator_panel.visible = true
	visible = true
	_rebuild_preview()
	_set_gender(int(_appearance["gender"]))


func _build_creator_panel() -> void:
	_creator_panel = Panel.new()
	_creator_panel.name = "CreatorPanel"
	_creator_panel.custom_minimum_size = Vector2(520, 470)
	_creator_panel.position = Vector2(380, 125)
	add_child(_creator_panel)
	# 左: 预览
	_preview = AnimatedSprite2D.new()
	_preview.position = Vector2(90, 240)
	_preview.scale = Vector2(3, 3)
	_creator_panel.add_child(_preview)
	# 右: 选项 VBox
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(190, 20)
	vbox.custom_minimum_size = Vector2(310, 0)
	vbox.add_theme_constant_override("separation", 6)
	_creator_panel.add_child(vbox)
	# 名字
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "角色名字"
	_name_edit.custom_minimum_size = Vector2(300, 0)
	vbox.add_child(_name_edit)
	# 性别
	var gender_row := HBoxContainer.new()
	var male_b := Button.new(); male_b.text = "男"; male_b.pressed.connect(func(): _set_gender(0))
	var female_b := Button.new(); female_b.text = "女"; female_b.pressed.connect(func(): _set_gender(1))
	gender_row.add_child(male_b); gender_row.add_child(female_b)
	vbox.add_child(gender_row)
	# 发型 ◀▶
	vbox.add_child(_stepper("发型", "hair_style", 0, 3))
	# 胸围 (女) 滑条
	_chest_row = _slider_row("胸围", "chest_size", 0, 5)
	vbox.add_child(_chest_row)
	# 6 色行
	vbox.add_child(_color_row("皮肤", "skin_color", _SKIN))
	vbox.add_child(_color_row("头发", "hair_color", _HAIR))
	vbox.add_child(_color_row("衬衫", "shirt_color", _SHIRT))
	vbox.add_child(_color_row("裤子", "pants_color", _PANTS))
	vbox.add_child(_color_row("眼珠", "eye_color", _EYE))
	# 保存 / 取消
	var btn_row := HBoxContainer.new()
	var save_b := Button.new(); save_b.text = "保存"; save_b.pressed.connect(_save_creator)
	var cancel_b := Button.new(); cancel_b.text = "取消"; cancel_b.pressed.connect(func():
		_creator_panel.visible = false; _select_panel.visible = true; _refresh_list())
	btn_row.add_child(save_b); btn_row.add_child(cancel_b)
	vbox.add_child(btn_row)


# 一行 ◀ 名称 ▶ stepper, 改 _appearance[key] 在 [lo,hi] 循环。
func _stepper(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var left := Button.new(); left.text = "◀"; row.add_child(left)
	var val := Label.new(); val.custom_minimum_size = Vector2(40, 0)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var refresh := func(): val.text = str(int(_appearance[key]))
	refresh.call()
	row.add_child(val)
	var right := Button.new(); right.text = "▶"; row.add_child(right)
	left.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) - 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	right.pressed.connect(func():
		_appearance[key] = wrapi(int(_appearance[key]) + 1, lo, hi + 1); refresh.call(); _rebuild_preview())
	return row


func _slider_row(label: String, key: String, lo: int, hi: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	var s := HSlider.new(); s.min_value = lo; s.max_value = hi; s.step = 1
	s.value = int(_appearance[key]); s.custom_minimum_size = Vector2(180, 0)
	s.value_changed.connect(func(v): _appearance[key] = int(v); _rebuild_preview())
	row.add_child(s)
	return row


# 一行色块: 点哪块就把 _appearance[key] 设成那色 + 重建预览。
func _color_row(label: String, key: String, colors: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	var l := Label.new(); l.text = label; l.custom_minimum_size = Vector2(60, 0); row.add_child(l)
	for col in colors:
		var sw := ColorRect.new()
		sw.color = col
		sw.custom_minimum_size = Vector2(28, 28)
		sw.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed:
				_appearance[key] = col; _rebuild_preview())
		row.add_child(sw)
	return row


func _set_gender(g: int) -> void:
	_appearance["gender"] = g
	_chest_row.visible = (g == 1)   # 胸围只女显示
	_rebuild_preview()


func _set_creator_name(n: String) -> void:
	_name_edit.text = n


func _rebuild_preview() -> void:
	if _preview == null:
		return
	_preview.sprite_frames = ArtCache.player_frames_for(_appearance)
	_preview.animation = "idle"
	_preview.play()


func _save_creator() -> void:
	var c := CharacterData.new()
	var nm: String = _name_edit.text.strip_edges()
	c.character_name = nm if nm != "" else "我的角色"
	c.gender = int(_appearance["gender"])
	c.hair_style = int(_appearance["hair_style"])
	c.chest_size = int(_appearance["chest_size"])
	c.skin_color = _appearance["skin_color"]
	c.hair_color = _appearance["hair_color"]
	c.shirt_color = _appearance["shirt_color"]
	c.pants_color = _appearance["pants_color"]
	c.eye_color = _appearance["eye_color"]
	CharacterManager.save_character(c)
	CharacterManager.current = c
	_creator_panel.visible = false
	_select_panel.visible = true
	_refresh_list()
```

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_character_panels.gd -gexit`
Expected: PASS (6 passing)。

- [ ] **Step 5: 跑全套 + 手验**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
然后 `./run.sh --rebuild` 让用户手验: 开始游戏 → 选角色 → 捏个新角色 → 改性别/发型/颜色看预览变 → 保存 → 选它 → 选世界 → 进游戏看玩家是捏的样子。

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/character_panels.gd tests/unit/test_character_panels.gd
git commit -m "feat(character-ui): 捏人面板 — 活预览 + 名字/性别/发型/胸围/6色 + 保存"
```

---

## Task 3: i18n + 收尾

**Files:**
- Modify: `scripts/ui/character_panels.gd` (文字走 Locale.t)
- Modify: i18n 语言表 (`scripts/autoload/locale.gd` 或对应资源)
- Test: 跑全套回归

- [ ] **Step 1: 查 i18n 接口**

Read `scripts/autoload/locale.gd` 看 `t(key)` + 加 key 的地方 (4 语言)。照已有 `menu_*` key 习惯加: `char_select_title`(选择角色)、`char_new`(捏个新角色)、`char_back`(返回)、`char_pick`(选择)、`char_delete`(删除)、`char_name_placeholder`(角色名字)、`char_gender_male`(男)、`char_gender_female`(女)、`char_hair`(发型)、`char_chest`(胸围)、`char_skin`/`char_hair_color`/`char_shirt`/`char_pants`/`char_eye`、`char_save`(保存)、`char_cancel`(取消)。

- [ ] **Step 2: 加 4 语言 key**

照 locale 现有结构, 给 zh/en/ja/ko 各加上面的 key (中文为主, 其它语言可先英译/与中文同义)。确保 4 语言 key 集合一致 (test_locale.gd `test_all_languages_have_same_keys` 会查)。

- [ ] **Step 3: character_panels.gd 文字换 Locale.t**

把 Step 写死的中文 (`"选择角色"`/`"＋ 捏个新角色"`/`"返回"`/`"选择"`/`"删除"`/`"男"`/`"女"`/`"发型"`/`"胸围"`/`"皮肤"`...等) 全换成 `Locale.t("char_...")`。

- [ ] **Step 4: 跑全套回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 全 PASS (含 `test_locale.gd` 4 语言 key 一致; 既有牛爬台阶 1 失败无关)。

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/character_panels.gd scripts/autoload/locale.gd
git commit -m "feat(character-ui): 捏人/选角色界面 i18n (4 语言)"
```

---

## Self-Review

**Spec 覆盖 (spec D 捏人+选角色 UI)**:
- 开始游戏 → 选角色 → 选世界 流程 → Task 1 ✅
- 选角色面板 (列表+捏新+返回+选择/删除) → Task 1 ✅
- 捏人面板活预览 + 名字/性别/发型/胸围(女)/6色 → Task 2 ✅
- 选中设 current → 进世界玩家是该角色 (Plan 1/2 已接) → Task 1 `_choose_character` ✅
- i18n → Task 3 ✅

**本计划不含 (留 Plan 4, 非遗漏)**: 衣裤款式/披风款式选择器 (服装美术 Plan 4 才做); 联机外观同步 (spec 非目标)。

**占位/一致性**: `open_select`/`_choose_character`/`_on_new_character`/`_save_creator`/`_set_gender`/`_set_creator_name`/`_rebuild_preview`/`_appearance`/`_chest_row` 全计划一致。`ArtCache.player_frames_for` / `PlayerArt.DEFAULT_APPEARANCE` / `CharacterManager.list_characters/load_character_by_name/save_character/current/CHARS_DIR_OVERRIDE` 均 Plan 1/2 已存在。

**风险**: `test_main_menu.gd` 的「点新游戏显 WorldSelectPanel」断言需改成显选角色面板 (Task 1 Step 6 已交代)。捏人 UI 是代码动态建, 手验靠用户眼看 (无 GUI 自动验收)。
