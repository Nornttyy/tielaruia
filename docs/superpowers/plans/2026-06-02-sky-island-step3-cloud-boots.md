# 空岛群系 · 第 3 步实现计划（云靴 + 二段跳）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development 或 executing-plans。步骤用 `- [ ]`。

**Goal:** 新装备「云靴」cloud_boots：羽毛 + 云块 在工作台合成；**持有即生效**——背包里有云靴就能**二段跳**（空中再跳一次）。羽毛终于有用了，整个空岛大套餐齐活。

**Architecture:** cloud_boots 是普通持有物（非方块、非工具、非盔甲槽）。设计上采「持有即生效」（spec 的最简版 fallback）：玩家 `PlayerInventory.has_item("cloud_boots")` 为真 → 解锁二段跳。玩家控制器加 `_double_jump_used` 状态 + `can_double_jump()` 门控 + 跳跃逻辑里加空中二跳分支。配方走现有 grid pattern + `"requires": "workbench"`。

**Tech Stack:** Godot 4.3 + GDScript，GUT。无 GUI，靠测试 + 集成验收。

**对应 spec:** `docs/superpowers/specs/2026-06-02-sky-island-biome-design.md`（第 3 步）。在 `sky-island` 隔间分支做，基于第 1+2 步 + 最新 main。

**关键现状（已查）:**
- 跳跃在 `player_controller.gd` `_physics_process`：`if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:` 才跳（`JUMP_VELOCITY=-240`, `GRAVITY=675` → 单跳峰高 ≈ 42.7px）。`_buff_jump_mul()` 是跳跃**高度** buff（跟二段跳无关）。
- 盔甲是 3 个**装备槽**（helmet/chest/pants，`equip_armor_from_slot`），没有 boots/饰品槽 → 不新增槽，用持有即生效。
- `Inventory` (scripts/items/inventory.gd) slot = `null` 或 `{"item_id", "count"}`（dict 支持 `.item_id` 取值）；`inventory.add(id, count)->int`。
- 配方 `RecipeDB.all_recipes()` / `get_recipe(id)`；recipe 有 `"requires": "workbench"`。

---

## 文件清单

| 文件 | 改动 |
|---|---|
| `scripts/items/item_db.gd` | `_DEFS` 加 `"cloud_boots"` |
| `scripts/ui/crafting_panel.gd` | `_ZH_NAMES` 加 `"cloud_boots": "云靴"` |
| `scripts/art/items_art.gd` | `_ICONS` 加 `"cloud_boots": _CLOUD_BOOTS` + 图案 |
| `scripts/crafting/recipe_db.gd` | `_RECIPES` 加 cloud_boots 配方 |
| `scripts/player/player_inventory.gd` | 加 `has_item(item_id)` |
| `scripts/player/player_controller.gd` | 加 `_double_jump_used` + `_has_cloud_boots()` + `can_double_jump()` + 跳跃二跳分支 + 落地重置 |
| `tests/unit/test_cloud_boots.gd` | 新建（物品/配方/has_item/门控） |
| `tests/integration/test_double_jump.gd` | 新建（真按键二段跳跳更高） |

---

## Task 1: 云靴 cloud_boots 物品 + 中文名 + 图标

**Files:** `item_db.gd`、`crafting_panel.gd`、`items_art.gd`、`tests/unit/test_cloud_boots.gd`(新建)

- [ ] **Step 1: 失败测试** — 新建 `tests/unit/test_cloud_boots.gd`：
```gdscript
extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_cloud_boots_item_def():
	var def = ItemDB.get_def("cloud_boots")
	assert_not_null(def, "云靴物品存在")
	assert_eq(def["max_stack"], 1, "云靴不堆叠")

func test_cloud_boots_has_icon():
	assert_true(ItemsArt.has_icon("cloud_boots"), "云靴有图标")
```

- [ ] **Step 2: 跑测试确认失败**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_cloud_boots.gd -gexit`
Expected: FAIL

- [ ] **Step 3: 加物品 + 中文名**
`item_db.gd` 在 `"feather": {...}` 行后加：
```gdscript
	"cloud_boots":   {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 1},
```
`crafting_panel.gd` 的 `_ZH_NAMES`，在 `"feather": "羽毛",` 行后加：
```gdscript
	"cloud_boots": "云靴",
```

- [ ] **Step 4: 加图标**
`items_art.gd` 在 `_FEATHER := [` 前加（白靴 + 底下小云朵，用现有 PALETTE：j 骨白 / w 羊毛阴影 / W 羊毛主）：
```gdscript
const _CLOUD_BOOTS := [
	"................",
	"....jjjj........",
	"...jwwwWj.......",
	"...jwwwWj.......",
	"...jwwwWj.......",
	"...jwwwWj.......",
	"...jwwwWjjj.....",
	"...jwwwwwwWj....",
	"..jwwwwwwwWj....",
	"..jwwwwwwwWj....",
	"..jWWWWWWWWj....",
	"..jjjjjjjjjj....",
	"................",
	"...wW..wW..wW...",
	"..wWWw.wWw.wWw..",
	"................",
]
```
`_ICONS` 字典里（`"feather": _FEATHER,` 附近）加：
```gdscript
	"cloud_boots": _CLOUD_BOOTS,
```

- [ ] **Step 5: 跑测试确认通过** — Expected: 2/2 PASS

- [ ] **Step 6: 提交**
```bash
git add scripts/items/item_db.gd scripts/ui/crafting_panel.gd scripts/art/items_art.gd tests/unit/test_cloud_boots.gd
git commit -m "feat(item): 云靴 cloud_boots 物品+中文名+图标 (空岛第3步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 云靴配方（羽毛 + 云块，工作台）

**Files:** `scripts/crafting/recipe_db.gd`、`tests/unit/test_cloud_boots.gd`

- [ ] **Step 1: 失败测试** — `test_cloud_boots.gd` 末尾加：
```gdscript
func test_cloud_boots_recipe_exists():
	var r = RecipeDB.get_recipe("cloud_boots")
	assert_not_null(r, "云靴配方存在")
	assert_eq(r["output_id"], "cloud_boots", "产出云靴")
	assert_eq(r.get("requires", ""), "workbench", "要工作台")
	# 配方里用到 feather + cloud
	var ids := {}
	for row in r["pattern"]:
		for cell in row:
			if cell != "":
				ids[cell] = true
	assert_true(ids.has("feather"), "配方含羽毛")
	assert_true(ids.has("cloud"), "配方含云块")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: `get_recipe("cloud_boots")` null

- [ ] **Step 3: 加配方** — `recipe_db.gd` 的 `_RECIPES` 数组里加一条（放 slime_crown 那条 workbench 配方附近）：
```gdscript
	# 云靴: 2 云块 + 2 羽毛 → 二段跳鞋 (要工作台)
	{
		"id": "cloud_boots",
		"grid_size": Vector2i(2, 2),
		"pattern": [
			["cloud", "cloud"],
			["feather", "feather"],
		],
		"output_id": "cloud_boots",
		"output_count": 1,
		"requires": "workbench",
		"mirror_ok": true,
	},
```

- [ ] **Step 4: 跑测试确认通过** — Expected: 3/3 (含前两个) PASS

- [ ] **Step 5: 提交**
```bash
git add scripts/crafting/recipe_db.gd tests/unit/test_cloud_boots.gd
git commit -m "feat(craft): 云靴配方 (2云块+2羽毛, 工作台) (空岛第3步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 背包查询 has_item

**Files:** `scripts/player/player_inventory.gd`、`tests/unit/test_cloud_boots.gd`

- [ ] **Step 1: 失败测试** — `test_cloud_boots.gd` 末尾加：
```gdscript
const PlayerInventoryScript = preload("res://scripts/player/player_inventory.gd")

func test_has_item():
	var pinv = PlayerInventoryScript.new()
	add_child_autofree(pinv)   # 触发 _ready 建 inventory
	await wait_frames(1)
	assert_false(pinv.has_item("cloud_boots"), "一开始没有云靴")
	pinv.inventory.add("cloud_boots", 1)
	assert_true(pinv.has_item("cloud_boots"), "加了之后有云靴")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: `has_item` 方法不存在

- [ ] **Step 3: 加 has_item** — `player_inventory.gd` 里（`total_defense()` 附近）加：
```gdscript
# 背包 (含 hotbar) 里有没有某物品 (持有即生效类装备用, 如云靴二段跳)
func has_item(item_id: String) -> bool:
	for s in inventory.slots:
		if s != null and s.item_id == item_id:
			return true
	return false
```

- [ ] **Step 4: 跑测试确认通过** — Expected: 4/4 PASS

- [ ] **Step 5: 提交**
```bash
git add scripts/player/player_inventory.gd tests/unit/test_cloud_boots.gd
git commit -m "feat(player): PlayerInventory.has_item 查询 (云靴二段跳用) (空岛第3步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 二段跳逻辑（player_controller）

**Files:** `scripts/player/player_controller.gd`、`tests/integration/test_double_jump.gd`(新建)

- [ ] **Step 1: 失败测试** — 新建 `tests/integration/test_double_jump.gd`：
```gdscript
# 云靴二段跳: 持云靴时空中能再跳一次 → 跳更高. 没云靴不行.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")

func _boot_and_land():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(10)
	var player = main.get_node("World").get_player()
	for _i in 120:
		if player.is_on_floor():
			break
		await wait_frames(1)
	return player

func test_can_double_jump_reflects_boots():
	var player = await _boot_and_land()
	assert_true(player.is_on_floor(), "玩家已落地")
	# 起跳进入空中
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(4)
	assert_false(player.is_on_floor(), "已在空中")
	assert_false(player.can_double_jump(), "没云靴不能二段跳")
	player.get_node("PlayerInventory").inventory.add("cloud_boots", 1)
	assert_true(player.can_double_jump(), "有云靴能二段跳")

func test_double_jump_goes_higher_with_boots():
	var player = await _boot_and_land()
	player.get_node("PlayerInventory").inventory.add("cloud_boots", 1)
	var floor_y: float = player.global_position.y
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(8)
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")  # 二段跳
	var min_y: float = floor_y
	for _i in 50:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	var height: float = floor_y - min_y
	assert_gt(height, 55.0, "穿云靴二段跳应明显跳更高 (>55px, 单跳约42), 实际 %.1f" % height)

func test_no_double_jump_without_boots():
	var player = await _boot_and_land()
	var floor_y: float = player.global_position.y
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")
	await wait_frames(8)
	Input.action_press("jump"); await wait_frames(1); Input.action_release("jump")  # 没靴子, 空中跳无效
	var min_y: float = floor_y
	for _i in 50:
		await wait_frames(1)
		min_y = min(min_y, player.global_position.y)
	var height: float = floor_y - min_y
	assert_lt(height, 52.0, "没云靴跳不了二段, 高度≈单跳 (<52px), 实际 %.1f" % height)
```

- [ ] **Step 2: 跑测试确认失败**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_double_jump.gd -gexit`
Expected: FAIL（`can_double_jump` 方法不存在 / 没二段跳逻辑跳不高）

- [ ] **Step 3: 加二段跳** — `player_controller.gd`：
  - 字段区（`var _coyote_timer: float = 0.0` 附近）加：
    ```gdscript
	var _double_jump_used: bool = false   # 离地后是否已用过二段跳 (云靴), 落地重置
    ```
  - `_physics_process` 陆地分支里，把落地的 `else` 改成（加重置）：
    ```gdscript
		else:
			_coyote_timer = COYOTE_TIME
			_double_jump_used = false   # 落地 → 二段跳重置
    ```
  - 紧接在第一段跳 `if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:` 那个 if 块**之后**加 elif：
    ```gdscript
			elif Input.is_action_just_pressed("jump") and not _double_jump_used and _has_cloud_boots():
				# 二段跳: 空中再跳一次 (穿云靴才行)
				velocity.y = JUMP_VELOCITY * _buff_jump_mul()
				_double_jump_used = true
				did_jump = true
				SfxBank.play("jump", 0.08)
    ```
  - 文件末尾（`_buff_jump_mul()` 后）加两个方法：
    ```gdscript


# 持有云靴 → 解锁二段跳 (持有即生效, 不占装备槽)
func _has_cloud_boots() -> bool:
	var pinv: Node = get_node_or_null("PlayerInventory")
	return pinv != null and pinv.has_method("has_item") and pinv.has_item("cloud_boots")


# 二段跳是否可用 (供测试 + 逻辑): 在空中 + 没用过 + 有云靴
func can_double_jump() -> bool:
	return not is_on_floor() and not _double_jump_used and _has_cloud_boots()
    ```

- [ ] **Step 4: 跑测试确认通过**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_double_jump.gd -gexit`
Expected: 3/3 PASS（门控 + 跳更高 + 没靴不跳）

- [ ] **Step 5: 全套 unit 回归 + 提交**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -ginclude_subdirs=false -gexit`
Expected: 只有已知预存失败（iron_ingot / 列200 等），无新增。
```bash
git add scripts/player/player_controller.gd tests/integration/test_double_jump.gd
git commit -m "feat(player): 云靴二段跳 (空中再跳一次, 持有即生效) (空岛第3步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 收尾验收

- [ ] **Step 1: 全套 unit + 集成冒烟** — test_cloud_boots 全过 + test_double_jump 全过 + test_smoke 不崩。
- [ ] **Step 2: 报告** — 3-5 行（云靴 + 二段跳做了啥 + commit + 累计测试数 + 整个空岛 3 步齐活）。
- [ ] **Step 3: 合并 + push**（同前两步流程：merge-tree 干跑 → 主树合并 → 验证 → push 部署）。

---

## Self-Review（已核对）

- **Spec 覆盖**：第 3 步「cloud_boots 物品 + 中文名」「feather+cloud 工作台配方」「二段跳效果」「装备/穿戴：无装备槽 → 持有即生效最简版」全有 Task。✅
- **占位符**：无 TBD；图案/代码给全。
- **命名一致**：`cloud_boots` / `_CLOUD_BOOTS` / `has_item` / `_has_cloud_boots` / `can_double_jump` / `_double_jump_used` 全程一致。
- **风险点**：① 二段跳 elif 必须接在第一段跳 `if` 之后（同一 if/elif 链），别放错分支（在水里/绳子分支不该有二段跳）。② 集成测试高度阈值（55/52）靠 wait_frames 时序，可能有±噪声 → 若 flaky 放宽到 with>52 / without<50 仍可区分（单跳 42.7）。③ 持有即生效：云靴占背包格、不能"脱"，给用户报告里说明白。④ slot `.item_id` 是 dict 取值（现有代码已这么用，OK）。
