# 史莱姆王 Boss 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 加入游戏第一个真正的 Boss——史莱姆王：召唤道具开战、三阶段攻击、掉专属弹跳武器「史莱姆球」。

**Architecture:** 以现有 `slime.gd` / `arrow.gd` 为模板新建 `king_slime.gd` 和 `slime_ball.gd`（独立 `CharacterBody2D` / `Area2D` 实体，复用难度缩放、掉落、血条、group 机制）。召唤道具走 `player_action.gd` 的右键使用路径（仿 grappling_hook 分支），由 `world.gd` 实例化并跟踪唯一 Boss。

**Tech Stack:** Godot 4.3 + GDScript，GUT 测试。所有 `.tscn`/美术由文本/程序生成（用户不开编辑器）。

参考设计：`docs/superpowers/specs/2026-05-31-king-slime-boss-design.md`

---

## 运行测试的方式（每个 task 用）

```bash
# 新 clone / 改了 class_name 后先建索引 (本仓库已建过, 通常可跳)
godot --headless --editor --quit          # 过滤 libfontconfig 警告

# 跑单个测试文件
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gsuffix=.gd -gtest=res://tests/integration/test_king_slime.gd -gexit 2>&1 | grep -v libfontconfig
```

> 注：本环境 GUT 偶尔加载很慢。若 GUT 超时，可用 `godot --headless --editor --quit` 整体导入来确认无编译/解析错误（exit 0 且无 SCRIPT ERROR 即脚本健康），再依赖逻辑正确性。

---

## Task 1: 新增物品 slime_crown / slime_ball + 中文名

**Files:**
- Modify: `scripts/items/item_db.gd`（`_DEFS` 加两条；加 `is_summon` 辅助）
- Modify: `scripts/ui/crafting_panel.gd`（`_ZH_NAMES` 加两条）
- Test: `tests/integration/test_king_slime.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/integration/test_king_slime.gd`：

```gdscript
# 史莱姆王 Boss 验收
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_slime_crown_and_ball_defs_exist() -> void:
	var crown = ItemDB.get_def("slime_crown")
	assert_not_null(crown, "slime_crown 应在 ItemDB")
	assert_eq(crown.tool_kind, "summon", "slime_crown 是召唤道具")
	assert_eq(crown.max_stack, 1, "王冠不可堆叠")

	var ball = ItemDB.get_def("slime_ball")
	assert_not_null(ball, "slime_ball 应在 ItemDB")
	assert_eq(ball.tool_kind, "slimeball", "slime_ball 是投射武器")

	assert_true(ItemDB.is_summon("slime_crown"), "is_summon 该认 slime_crown")
	assert_false(ItemDB.is_summon("slime_ball"), "slime_ball 不是召唤道具")
```

- [ ] **Step 2: 跑测试看它失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gsuffix=.gd -gtest=res://tests/integration/test_king_slime.gd -gexit 2>&1 | grep -v libfontconfig`
Expected: FAIL（`slime_crown` 为 null / `is_summon` 方法不存在）

- [ ] **Step 3: 加物品定义**

在 `scripts/items/item_db.gd` 的 `_DEFS` 字典里（紧挨 `"slime_jelly"` 那行附近）加：

```gdscript
	"slime_crown":  {"placeable_tile_id": -1, "tool_kind": "summon",    "tool_tier": 0, "max_stack": 1},
	"slime_ball":   {"placeable_tile_id": -1, "tool_kind": "slimeball", "tool_tier": 5, "max_stack": 1, "damage_mult": 1.0},
```

在 `item_db.gd` 里（仿现有 `is_food` / `is_mana_potion` 写法）加辅助函数：

```gdscript
func is_summon(item_id: String) -> bool:
	var def = get_def(item_id)
	return def != null and def.get("tool_kind", "") == "summon"
```

- [ ] **Step 4: 加中文名**

在 `scripts/ui/crafting_panel.gd` 的 `_ZH_NAMES` 字典加：

```gdscript
	"slime_crown": "史莱姆王冠",
	"slime_ball": "史莱姆球",
```

- [ ] **Step 5: 跑测试看它通过**

Run: 同 Step 2
Expected: `test_slime_crown_and_ball_defs_exist` PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/items/item_db.gd scripts/ui/crafting_panel.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): slime_crown/slime_ball 物品 + 中文名"
```

---

## Task 2: 史莱姆王冠配方（9 史莱姆胶 + 工作台）

**Files:**
- Modify: `scripts/crafting/recipe_db.gd`（`_RECIPES` 加一条）
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`：

```gdscript
func test_slime_crown_recipe_exists() -> void:
	var found := false
	for r in RecipeDB._RECIPES:
		if r.get("output_id", "") == "slime_crown":
			found = true
			assert_eq(r.get("requires", ""), "workbench", "王冠配方要工作台")
			# 统计 pattern 里 slime_jelly 格子数
			var jelly := 0
			for row in r["pattern"]:
				for cell in row:
					if cell == "slime_jelly":
						jelly += 1
			assert_eq(jelly, 9, "王冠 = 9 个史莱姆胶")
	assert_true(found, "应有 slime_crown 配方")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同 Task 1 Step 2
Expected: FAIL（找不到 slime_crown 配方）

- [ ] **Step 3: 加配方**

在 `scripts/crafting/recipe_db.gd` 的 `_RECIPES` 数组里（任意位置，建议挨着其它 3×3 配方）加：

```gdscript
	{
		"id": "slime_crown",
		"grid_size": Vector2i(3, 3),
		"pattern": [
			["slime_jelly", "slime_jelly", "slime_jelly"],
			["slime_jelly", "slime_jelly", "slime_jelly"],
			["slime_jelly", "slime_jelly", "slime_jelly"],
		],
		"output_id": "slime_crown",
		"output_count": 1,
		"requires": "workbench",
		"mirror_ok": true,
	},
```

- [ ] **Step 4: 跑测试看它通过**

Run: 同上
Expected: `test_slime_crown_recipe_exists` PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/crafting/recipe_db.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): 史莱姆王冠配方 (9 jelly + workbench)"
```

---

## Task 3: 物品图标（王冠 + 球）

**Files:**
- Modify: `scripts/art/items_art.gd`（`get_icon` / `has_icon` 加两个 case + pattern）
- Modify: `scripts/autoload/art_cache.gd`（icon 构建循环加两个 id）
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`：

```gdscript
func test_item_icons_exist() -> void:
	assert_not_null(ArtCache.get_inventory_icon("slime_crown"), "王冠该有 icon")
	assert_not_null(ArtCache.get_inventory_icon("slime_ball"), "球该有 icon")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（`get_inventory_icon` 返回 null + push_warning "未知 item icon"）

- [ ] **Step 3: 加图标 pattern + get_icon case**

在 `scripts/art/items_art.gd` 顶部（其它 pattern 常量附近）加两个 16×16 像素画（`.`=透明）。皇冠（黄金 `g`/高光 `G`/红宝石 `r`），球（史莱姆绿 `s`/高光 `S`/深边 `d`）：

```gdscript
const _SLIME_CROWN := [
	"................",
	"................",
	"................",
	"....g......g....",
	"...gG..g...Gg...",
	"...gG.gGg..Gg...",
	"..gGg.gGg.gGg...",
	"..gGggggggggGg..",
	"..gGgGgGgGgGgGg.",
	"..ggrggggrgggg..",
	"..gggggggggggg..",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SLIME_BALL := [
	"................",
	"................",
	".....dddd.......",
	"...ddSSSSdd.....",
	"..dSSSSSSSSd....",
	"..dSSsssSSSd....",
	".dSSssssssSSd...",
	".dSssssssssSd...",
	".dSssssssssSd...",
	".dSssssssssSd...",
	"..dSsssssssSd...",
	"..dSSsssssSdd...",
	"...ddSSSSdd.....",
	".....dddd.......",
	"................",
	"................",
]
```

在 `items_art.gd` 找一个该文件内已有的调色板字典（或新建）。新建一个本地调色板并在 `get_icon` 里用：

```gdscript
const _P_SLIME_CROWN := {
	".": Color(0, 0, 0, 0),
	"g": Color8(212, 175, 55),    # 金
	"G": Color8(255, 224, 130),   # 金高光
	"r": Color8(220, 60, 60),     # 红宝石
}
const _P_SLIME_BALL := {
	".": Color(0, 0, 0, 0),
	"s": Color8(120, 200, 110),   # 史莱姆绿
	"S": Color8(180, 240, 160),   # 高光
	"d": Color8(70, 130, 70),     # 深绿边
}
```

在 `static func get_icon(item_id: String) -> ImageTexture:` 函数体最前面加分支（用本文件已有的 `PixelArt.grid_to_image` 写法，参考同文件其它 icon）：

```gdscript
	if item_id == "slime_crown":
		return ImageTexture.create_from_image(PixelArt.grid_to_image(_SLIME_CROWN, _P_SLIME_CROWN))
	if item_id == "slime_ball":
		return ImageTexture.create_from_image(PixelArt.grid_to_image(_SLIME_BALL, _P_SLIME_BALL))
```

> 确认 `items_art.gd` 顶部已 `const PixelArt = preload("res://scripts/art/pixel_art.gd")`；若无则加（参考 `player_art.gd` 的写法）。

在 `has_icon` 里让这两个 id 也返回 true（若 `has_icon` 是查表，则把它们加进表；若是 `return get_icon(...) != null` 之类则自动覆盖——按现有实现调整）。

- [ ] **Step 4: 注册到 ArtCache icon 构建**

在 `scripts/autoload/art_cache.gd` 里，找到构建 `item_icons` 的循环/列表（约 line 235-246，`item_icons[item_id] = ItemsArt.get_icon(item_id)` 那段）。把 `"slime_crown"` 和 `"slime_ball"` 加进被遍历的 item id 列表里（与现有非工具物品同样方式）。

- [ ] **Step 5: 跑测试看它通过**

Run: 同上
Expected: `test_item_icons_exist` PASS

- [ ] **Step 6: 整体导入确认无报错**

Run: `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|items_art|art_cache"`
Expected: 无输出（exit 0）

- [ ] **Step 7: 提交**

```bash
git add scripts/art/items_art.gd scripts/autoload/art_cache.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): 王冠/史莱姆球 物品图标"
```

---

## Task 4: 史莱姆球弹跳投射物

**Files:**
- Create: `scripts/entities/slime_ball.gd`
- Create: `scenes/entities/slime_ball.tscn`
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`（顶部 const 区加 `const SlimeBallScene = preload("res://scenes/entities/slime_ball.tscn")`，`const SlimeScene = preload("res://scenes/entities/slime.tscn")`）：

```gdscript
func test_slime_ball_damages_enemy() -> void:
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	var slime = SlimeScene.instantiate()
	add_child_autofree(slime)
	slime.global_position = Vector2(100, 100)
	await wait_frames(1)
	# 朝 slime 正下方一点点的位置投 (水平命中)
	ball.setup(Vector2(70, 100), Vector2(100, 100), 16, null)
	var hp_before: int = slime.current_health
	await wait_frames(30)
	assert_lt(slime.current_health, hp_before, "史莱姆球该打到 slime 扣血")

func test_slime_ball_bounces_off_ground() -> void:
	# 纯逻辑: 给一个向下的速度 + 模拟撞地, bounce 计数应增加. 这里用 has_method 占位验证接口存在.
	var ball = SlimeBallScene.instantiate()
	add_child_autofree(ball)
	assert_true("_bounces" in ball, "slime_ball 应有 _bounces 计数")
	assert_true(ball.has_method("setup"), "应有 setup")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（preload 找不到 slime_ball.tscn）

- [ ] **Step 3: 写脚本**

Create `scripts/entities/slime_ball.gd`（以 `arrow.gd` 为模板，加重力 + 弹跳）：

```gdscript
# 史莱姆球: 玩家专属投射物 (Boss 掉落武器发射). Area2D, 受重力抛物线飞,
# 撞实心方块/地面反弹 (最多 MAX_BOUNCES 次, 速度衰减), 命中怪 → 伤害 + 销毁.
extends Area2D

const TILE_SIZE := 12
const SPEED := 240.0
const GRAVITY := 480.0
const LIFETIME_SEC := 4.0
const BASE_DAMAGE := 16
const HIT_RADIUS_PX := 9.0
const MAX_BOUNCES := 3
const BOUNCE_DAMP := 0.6     # 反弹速度保留比例

var velocity: Vector2 = Vector2.ZERO
var damage: int = BASE_DAMAGE
var _life_t: float = 0.0
var _bounces: int = 0
var _cached_chunk_manager = null
var _is_dead: bool = false
var _shooter: Node = null

@onready var sprite: Sprite2D = $Sprite2D


func setup(start_pos: Vector2, target_pos: Vector2, dmg: int, shooter: Node) -> void:
	global_position = start_pos
	damage = dmg
	_shooter = shooter
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED


func _ready() -> void:
	# icon 当贴图 (球图)
	sprite.texture = ArtCache.get_inventory_icon("slime_ball")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	velocity.y += GRAVITY * delta
	var next: Vector2 = global_position + velocity * delta
	var cm = _get_cm()
	if cm != null:
		var tx: int = int(floor(next.x / TILE_SIZE))
		var ty: int = int(floor(next.y / TILE_SIZE))
		var t: int = cm.get_tile(tx, ty)
		if t != Tiles.AIR and Tiles.is_solid(t):
			# 撞实心 → 反弹 (按主要运动轴翻转). 简化: 竖直为主翻 y, 横向为主翻 x.
			_bounces += 1
			if _bounces > MAX_BOUNCES:
				_destroy()
				return
			if abs(velocity.y) >= abs(velocity.x):
				velocity.y = -velocity.y * BOUNCE_DAMP
			else:
				velocity.x = -velocity.x * BOUNCE_DAMP
			velocity *= BOUNCE_DAMP
			return  # 本帧不前进, 下帧用新速度
	global_position = next
	_check_enemy_hit()


func _check_enemy_hit() -> void:
	for group in ["king_slime", "slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy == _shooter or not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			if global_position.distance_to((enemy as Node2D).global_position) > HIT_RADIUS_PX:
				continue
			if enemy.has_method("take_damage"):
				var src: Vector2 = global_position - velocity.normalized() * 32.0
				enemy.take_damage(damage, src, 120.0)
				_destroy()
				return


func _destroy() -> void:
	if _is_dead:
		return
	_is_dead = true
	queue_free()


func _get_cm():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	_cached_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	return _cached_chunk_manager
```

- [ ] **Step 4: 写场景**

Create `scenes/entities/slime_ball.tscn`（仿 arrow.tscn，但用 Sprite2D）：

```
[gd_scene load_steps=3 format=3 uid="uid://b_slimeball_2026"]

[ext_resource type="Script" path="res://scripts/entities/slime_ball.gd" id="1_sb"]

[sub_resource type="CircleShape2D" id="CircleShape2D_sb"]
radius = 4.0

[node name="SlimeBall" type="Area2D"]
script = ExtResource("1_sb")
collision_layer = 0
collision_mask = 4

[node name="Sprite2D" type="Sprite2D" parent="."]

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
shape = SubResource("CircleShape2D_sb")
```

- [ ] **Step 5: 跑测试看它通过**

Run: 同上
Expected: `test_slime_ball_damages_enemy` + `test_slime_ball_bounces_off_ground` PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/slime_ball.gd scenes/entities/slime_ball.tscn tests/integration/test_king_slime.gd
git commit -m "feat(boss): 史莱姆球弹跳投射物"
```

---

## Task 5: 史莱姆球武器发射（player_action）

**Files:**
- Modify: `scripts/player/player_action.gd`（`_process` 工具分支加 `slimeball`；加 `ThrowSlimeBall` 逻辑 + preload）
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`（复用 `_setup_game` / `_equip_tool` 辅助——从 test_combat_phase1.gd 复制这两个辅助到本文件，或确认本文件已有）：

```gdscript
func _setup_game() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {"main": main, "world": world, "player": player,
		"action": player.get_node("PlayerAction"), "inv": player.get_node("PlayerInventory")}

func _equip(ctx: Dictionary, item_id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return

func test_slimeball_weapon_throws_projectile() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "slime_ball")
	var before := ctx["world"].get_tree().get_nodes_in_group("slime_balls").size()
	ctx["action"].mouse_world_override = ctx["player"].global_position + Vector2(40, 0)
	ctx["action"].primary_override = true
	await wait_frames(3)
	ctx["action"].primary_override = false
	var after := ctx["world"].get_tree().get_nodes_in_group("slime_balls").size()
	assert_gt(after, before, "持史莱姆球点 LMB 应投出一个投射物")
```

> 注：为可测，slime_ball 投射物 `_ready` 里 `add_to_group("slime_balls")`（在 Task 4 脚本 `_ready` 末尾加 `add_to_group("slime_balls")`，并补一次提交或并入本 task）。

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（slimeball 武器无发射逻辑，组里数量不增）

- [ ] **Step 3: 加发射逻辑**

在 `scripts/player/player_action.gd` 的 `_process` 工具 `kind` 分支链里（`elif kind == "staff":` 之后）加：

```gdscript
	elif kind == "slimeball":
		# 史莱姆球: LMB 按下 → 朝鼠标投弹跳球. cd 0.45s. 无弹药 (Boss 武器).
		_reset_mining()
		var primary_pressed_sb: bool = (primary_override == true) if primary_override != null else Input.is_action_pressed("primary")
		if primary_pressed_sb and _attack_cooldown <= 0.0:
			_try_throw_slimeball()
```

在 `player_action.gd`（`_try_cast_staff` 附近）加常量 + 函数：

```gdscript
const SlimeBallScene = preload("res://scenes/entities/slime_ball.tscn")
const SLIMEBALL_COOLDOWN := 0.45
const SLIMEBALL_DAMAGE := 16   # 高于 iron 剑 (tier4 ≈ 10)

func _try_throw_slimeball() -> void:
	_attack_cooldown = SLIMEBALL_COOLDOWN
	var parent: Node2D = get_parent() as Node2D
	if parent == null:
		return
	var start: Vector2 = parent.global_position + Vector2(0, -8)
	var target: Vector2 = mouse_world_override if mouse_world_override != null else parent.get_global_mouse_position()
	var ball = SlimeBallScene.instantiate()
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = parent.get_parent()
	entities.add_child(ball)
	var dmg: int = int(round(float(SLIMEBALL_DAMAGE) * _tool_damage_mult()))
	ball.setup(start, target, dmg, parent)
	SfxBank.play("break", 0.10)
```

- [ ] **Step 4: 跑测试看它通过**

Run: 同上
Expected: `test_slimeball_weapon_throws_projectile` PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/player/player_action.gd scripts/entities/slime_ball.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): 史莱姆球武器发射"
```

---

## Task 6: 史莱姆王本体（HP 1000 + 大跳 + 巨大 + 皇冠）

**Files:**
- Create: `scripts/entities/king_slime.gd`
- Create: `scenes/entities/king_slime.tscn`
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`（顶部加 `const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")`）：

```gdscript
func test_king_slime_base_stats() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var expected := int(round(1000 * GameSettings.enemy_hp_multiplier()))
	assert_eq(boss.max_health, expected, "Boss HP = 1000 × 难度倍率")
	assert_eq(boss.CONTACT_DAMAGE, 20, "接触伤害 20")
	assert_true(boss.is_in_group("king_slime"), "应在 king_slime 组")
	assert_true(boss.is_in_group("boss"), "应在 boss 组")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（preload 找不到 king_slime.tscn）

- [ ] **Step 3: 写脚本**

Create `scripts/entities/king_slime.gd`（以 `slime.gd` 为骨架，HP/接触伤/大跳放大；阶段逻辑在 Task 7 加）：

```gdscript
# 史莱姆王 Boss: 巨大史莱姆, 大跳砸玩家. HP 1000.
# 阶段 (Task 7): 血<50% 召唤小史莱姆; 血越少体型越小、跳越快.
# 收尾 (Task 8): 玩家死/远离 → 消失; 掉 slime_ball + 大量 slime_jelly.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")

const BASE_MAX_HEALTH := 1000
const CONTACT_DAMAGE := 20
const GRAVITY := 675.0
const TILE_SIZE := 12
const HIT_FLASH_SEC := 0.1
const ENEMY_IFRAME_SEC := 0.15
const AGGRO_RANGE_PX := 600.0   # Boss 视野大 (50 tile)
# 大跳: 比小史莱姆高得多
const HOP_HEIGHT_TILES := 4.0
const HOP_DIST_TILES := 5.0
const HOP_COOLDOWN_FULL := 1.6   # 满血跳跃间隔 (随血量降低见 Task 7)
const SCALE_FULL := 4.0          # 满血体型
const SCALE_LOW := 2.0           # 残血体型 (Task 7)

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hop_timer: float = 1.0
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _current_hop_vx: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.slime_frames
	sprite.play("idle")
	sprite.modulate = Color(0.6, 0.5, 1.0)   # 王者紫蓝染色, 区别普通绿史莱姆
	add_to_group("king_slime")
	add_to_group("slimes")   # 复用剑挥/弹射物命中扫描
	add_to_group("boss")     # 出生点死亡清除逻辑跳过 boss
	_apply_scale()
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _hp_ratio() -> float:
	return clamp(float(current_health) / float(max_health), 0.0, 1.0)


func _apply_scale() -> void:
	# 体型随血量从 SCALE_FULL 线性缩到 SCALE_LOW (Task 7 让它生效; 满血时 = SCALE_FULL)
	var s: float = lerp(SCALE_LOW, SCALE_FULL, _hp_ratio())
	sprite.scale = Vector2(s, s)


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return null
	_cached_player = players[0]
	return _cached_player


func _physics_process(delta: float) -> void:
	if has_meta("is_remote") or _is_dying:
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color(0.6, 0.5, 1.0)
	_iframe_t = max(0.0, _iframe_t - delta)

	if not is_on_floor():
		velocity.y += GRAVITY * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, 200.0 * delta)
		_hop_timer -= delta
		if _hop_timer <= 0.0:
			_attempt_hop()

	move_and_slide()
	if not is_on_floor() and _current_hop_vx != 0.0:
		velocity.x = _current_hop_vx
	_check_player_contact()


func _attempt_hop() -> void:
	_hop_timer = HOP_COOLDOWN_FULL
	var player := _find_player()
	var dir: float = 0.0
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dx: float = player.global_position.x - global_position.x
		dir = signf(dx) if abs(dx) > float(TILE_SIZE) else (1.0 if randf() < 0.5 else -1.0)
		sprite.flip_h = dir < 0
	else:
		dir = 1.0 if randf() < 0.5 else -1.0
	var h_px: float = HOP_HEIGHT_TILES * TILE_SIZE
	var d_px: float = HOP_DIST_TILES * TILE_SIZE
	var vy_mag: float = sqrt(2.0 * GRAVITY * h_px)
	var vx_mag: float = 0.0 if vy_mag == 0.0 else (d_px * GRAVITY) / (2.0 * vy_mag)
	_current_hop_vx = dir * vx_mag
	velocity.x = _current_hop_vx
	velocity.y = -vy_mag


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	# Boss 大: 命中盒按当前体型放大 (基础 12×12 sprite × scale)
	var half: float = 6.0 * sprite.scale.x
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > half or dy < -2.0 * half or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 100.0)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0 or _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -6), actual_loss)
	# Boss 太重: 只吃很小击退 (knockback × 0.1), 不被推飞
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var d: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity += d * knockback * 0.1
	_apply_scale()   # 血量变 → 体型可能变 (Task 7)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	queue_free()   # 掉落在 Task 8 补
```

- [ ] **Step 4: 写场景**

Create `scenes/entities/king_slime.tscn`（碰撞框大；非实心 layer=0 mask=3 同小史莱姆）：

```
[gd_scene load_steps=3 format=3 uid="uid://b_kingslime_2026"]

[ext_resource type="Script" path="res://scripts/entities/king_slime.gd" id="1_ks"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_ks"]
size = Vector2(40, 32)

[node name="KingSlime" type="CharacterBody2D"]
script = ExtResource("1_ks")
collision_layer = 0
collision_mask = 3

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -16)
centered = true

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -16)
shape = SubResource("RectangleShape2D_ks")
```

> 注：sprite 用 `centered = true` 让放大以中心为基（区别小史莱姆的 `centered=false`），避免放大 4 倍后偏移；脚本里 `_check_player_contact` 的命中盒按 sprite.scale 计算已配合此设定。

- [ ] **Step 5: 跑测试看它通过**

Run: 同上
Expected: `test_king_slime_base_stats` PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/king_slime.gd scenes/entities/king_slime.tscn tests/integration/test_king_slime.gd
git commit -m "feat(boss): 史莱姆王本体 (HP 1000 + 大跳 + 巨大)"
```

---

## Task 7: 阶段 — 血<50% 召唤小兵 + 越打越小越快

**Files:**
- Modify: `scripts/entities/king_slime.gd`
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`：

```gdscript
func test_king_slime_shrinks_and_speeds_up() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var scale_full: float = boss.sprite.scale.x
	var hop_full: float = boss._hop_cooldown_now()
	# 砍到 10% 血
	boss.current_health = int(boss.max_health * 0.1)
	boss._apply_scale()
	assert_lt(boss.sprite.scale.x, scale_full, "残血体型应更小")
	assert_lt(boss._hop_cooldown_now(), hop_full, "残血跳跃间隔应更短")

func test_king_slime_spawns_minions_below_half() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	boss.current_health = int(boss.max_health * 0.4)   # < 50%
	var before := get_tree().get_nodes_in_group("slimes").size()
	# 直接触发召唤 (跳过计时器等待)
	boss._spawn_minions()
	var after := get_tree().get_nodes_in_group("slimes").size()
	assert_gt(after, before, "血<50% 召唤小史莱姆")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（`_hop_cooldown_now` / `_spawn_minions` 不存在；scale 不随血变）

- [ ] **Step 3: 加阶段逻辑**

在 `king_slime.gd` 加常量 + 状态：

```gdscript
const MINION_INTERVAL := 4.0     # 血<50% 每 4s 召唤一波
const MINION_PER_WAVE := 3
const MINION_CAP := 8            # 场上小史莱姆上限 (含本 Boss 召唤的)
const HOP_COOLDOWN_LOW := 0.5    # 残血跳跃间隔 (越短越疯)

var _minion_timer: float = MINION_INTERVAL
```

加方法：

```gdscript
# 当前跳跃间隔: 血越少越短 (HOP_COOLDOWN_FULL → HOP_COOLDOWN_LOW)
func _hop_cooldown_now() -> float:
	return lerp(HOP_COOLDOWN_LOW, HOP_COOLDOWN_FULL, _hp_ratio())

func _spawn_minions() -> void:
	var existing := get_tree().get_nodes_in_group("slimes").size()
	for i in MINION_PER_WAVE:
		if existing >= MINION_CAP:
			break
		var m = SlimeScene.instantiate()
		var entities: Node = get_tree().get_first_node_in_group("entities_root")
		if entities == null:
			entities = get_parent()
		entities.add_child(m)
		m.global_position = global_position + Vector2(randf_range(-20, 20), -10)
		existing += 1
```

把 `_attempt_hop` 里的 `_hop_timer = HOP_COOLDOWN_FULL` 改成 `_hop_timer = _hop_cooldown_now()`。

在 `_physics_process` 的 `if has_meta(...)` 之后、移动之前加召唤计时：

```gdscript
	# 阶段 2: 血 < 50% 周期召唤小兵
	if current_health < max_health / 2:
		_minion_timer -= delta
		if _minion_timer <= 0.0:
			_minion_timer = MINION_INTERVAL
			_spawn_minions()
```

（`_apply_scale` 已在 Task 6 按 `_hp_ratio` 缩放，且 `take_damage` 里已调用——确认无误即可，本 task 测试验证它生效。）

- [ ] **Step 4: 跑测试看它通过**

Run: 同上
Expected: 两个新测试 PASS

- [ ] **Step 5: 提交**

```bash
git add scripts/entities/king_slime.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): 史莱姆王阶段 (召唤小兵 + 越打越小越快)"
```

---

## Task 8: 掉落 + 收尾（消失规则）+ 不被存档/出生点清除误删

**Files:**
- Modify: `scripts/entities/king_slime.gd`（掉落 + 远离/玩家死消失）
- Verify: `scripts/world/world.gd`（确认出生点死亡清除 + 存档实体快照不误伤 boss 组）
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`：

```gdscript
func test_king_slime_drops_on_death() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	await wait_frames(1)
	var before := get_tree().get_nodes_in_group("item_drops").size()
	boss.take_damage(boss.max_health, boss.global_position, 0.0)
	await wait_frames(2)
	var drops := get_tree().get_nodes_in_group("item_drops")
	assert_gt(drops.size(), before, "Boss 死该掉东西")
	var has_ball := false
	for d in drops:
		if "item_id" in d and d.item_id == "slime_ball":
			has_ball = true
	assert_true(has_ball, "Boss 该掉 slime_ball")

func test_king_slime_despawns_when_player_far() -> void:
	var boss = KingSlimeScene.instantiate()
	add_child_autofree(boss)
	boss.global_position = Vector2(0, 0)
	await wait_frames(1)
	# 没有 player 在场 → 远离计时累加 → 超时消失
	boss._far_timer = boss.DESPAWN_AFTER_SEC + 1.0
	boss._check_despawn(0.1)
	await wait_frames(2)
	assert_false(is_instance_valid(boss) and not boss._is_dying, "远离超时该消失")
```

> 注：`item_drop.tscn` 实例需在 `item_drops` 组——确认 `scripts/items/item_drop.gd` 的 `_ready` 有 `add_to_group("item_drops")`；若无，本 task 顺便加上（小改，独立价值）。

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（`_die` 未掉落；`_check_despawn`/`_far_timer`/`DESPAWN_AFTER_SEC` 不存在）

- [ ] **Step 3: 加掉落 + 消失逻辑**

在 `king_slime.gd` 加常量 + 状态：

```gdscript
const DESPAWN_DISTANCE_PX := 960.0   # 离玩家 80 tile
const DESPAWN_AFTER_SEC := 5.0       # 持续超距 5s → 消失
const JELLY_DROP_MIN := 20
const JELLY_DROP_MAX := 40

var _far_timer: float = 0.0
```

加方法：

```gdscript
func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-8.0, 8.0), -6.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)

func _check_despawn(delta: float) -> void:
	var player := _find_player()
	var far: bool = player == null or global_position.distance_to(player.global_position) > DESPAWN_DISTANCE_PX
	if far:
		_far_timer += delta
		if _far_timer >= DESPAWN_AFTER_SEC:
			_is_dying = true
			queue_free()   # 远离消失不掉落
	else:
		_far_timer = 0.0
```

把 `_die()` 改成掉落：

```gdscript
func _die() -> void:
	_is_dying = true
	_spawn_drop("slime_ball")
	var n := JELLY_DROP_MIN + (randi() % (JELLY_DROP_MAX - JELLY_DROP_MIN + 1))
	for i in n:
		_spawn_drop("slime_jelly")
	queue_free()
```

在 `_physics_process` 顶部（`_is_dying` 检查之后）加：

```gdscript
	_check_despawn(delta)
	if _is_dying:
		return
```

玩家死亡消失：玩家死时通常 `player` 离开 group 或场景重置。当前 `_check_despawn` 以 `player == null` 视为 far，玩家死亡/移除后 5s 内消失，已覆盖该需求。

- [ ] **Step 4: 确认出生点清除 + 存档不误伤 boss**

检查 `scripts/world/world.gd` 里"出生点死亡清除 slimes"和"存档 entities 快照"逻辑：
- 若有遍历 `slimes` 组删除/快照的代码，加 `if node.is_in_group("boss"): continue` 跳过 Boss。
- 用 grep 定位：`grep -nE "group\(\"slimes\"\)|save.*entit|snapshot|清除|出生点" scripts/world/world.gd scripts/save/save_manager.gd`
- 若确认现有逻辑不涉及（例如只清屏幕外普通怪、存档只存特定白名单），则无需改，记录在提交信息里。

- [ ] **Step 5: 跑测试看它通过**

Run: 同上
Expected: `test_king_slime_drops_on_death` + `test_king_slime_despawns_when_player_far` PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/entities/king_slime.gd tests/integration/test_king_slime.gd
# 若改了 world.gd / item_drop.gd 一并 add 具体路径
git commit -m "feat(boss): 史莱姆王掉落 + 远离消失 + 防误删"
```

---

## Task 9: 世界召唤接线 + 王冠使用召唤（唯一 Boss）

**Files:**
- Modify: `scripts/world/world.gd`（preload + `spawn_king_slime` + `_active_king_slime` 跟踪）
- Modify: `scripts/player/player_action.gd`（`_update_eat_or_place` 加 slime_crown 使用分支 + `try_use_summon_item` 可测方法）
- Test: `tests/integration/test_king_slime.gd`

- [ ] **Step 1: 写失败测试**

加到 `test_king_slime.gd`：

```gdscript
func test_crown_summons_boss_and_consumes() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "slime_crown")
	var before := get_tree().get_nodes_in_group("king_slime").size()
	var ok: bool = ctx["action"].try_use_summon_item()
	await wait_frames(2)
	assert_true(ok, "召唤应成功")
	assert_eq(get_tree().get_nodes_in_group("king_slime").size(), before + 1, "应出现 1 个史莱姆王")
	# 王冠被消耗 (手上那格没了)
	var slot = ctx["inv"].current_hotbar_slot()
	assert_true(slot == null or slot.item_id != "slime_crown", "王冠应被消耗")

func test_no_double_boss() -> void:
	var ctx: Dictionary = await _setup_game()
	_equip(ctx, "slime_crown")
	ctx["action"].try_use_summon_item()
	await wait_frames(2)
	# 再拿一个王冠再召唤 → 已有 Boss, 应拒绝
	_equip(ctx, "slime_crown")
	var ok2: bool = ctx["action"].try_use_summon_item()
	assert_false(ok2, "已有 Boss 时不该再召唤")
	assert_eq(get_tree().get_nodes_in_group("king_slime").size(), 1, "场上只 1 个 Boss")
```

- [ ] **Step 2: 跑测试看它失败**

Run: 同上
Expected: FAIL（`try_use_summon_item` / `world.spawn_king_slime` 不存在）

- [ ] **Step 3: world.gd 加召唤**

在 `scripts/world/world.gd` 顶部 preload 区加：

```gdscript
const KingSlimeScene = preload("res://scenes/entities/king_slime.tscn")
```

加成员变量（与其它 var 一起）：

```gdscript
var _active_king_slime: Node = null
```

加方法：

```gdscript
# 召唤史莱姆王到 pos 附近. 已有存活 Boss → 返回 false 拒绝.
func spawn_king_slime(pos: Vector2) -> bool:
	if _active_king_slime != null and is_instance_valid(_active_king_slime):
		return false
	var boss = KingSlimeScene.instantiate()
	entities_root.add_child(boss)
	boss.global_position = pos
	_active_king_slime = boss
	return true
```

- [ ] **Step 4: player_action.gd 加使用召唤**

在 `scripts/player/player_action.gd` 加可测公共方法（放 `_try_throw_slimeball` 附近）：

```gdscript
# 手持召唤道具 (slime_crown) 使用 → 在玩家附近召唤 Boss, 成功则消耗 1.
# 返回 true = 召唤成功. 供右键分支 + 测试调用.
func try_use_summon_item() -> bool:
	var inv: Node = _inventory_node()
	if inv == null:
		return false
	var slot = inv.current_hotbar_slot()
	if slot == null or not ItemDB.is_summon(slot.item_id):
		return false
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return false
	var world: Node = _find_world()
	if world == null or not world.has_method("spawn_king_slime"):
		return false
	# 召唤在玩家前方 3 tile、上方一点
	var spawn_pos: Vector2 = player.global_position + Vector2(40, -24)
	if not world.spawn_king_slime(spawn_pos):
		return false   # 已有 Boss
	inv.consume_current(1)
	SfxBank.play("break", 0.2)
	return true
```

> `_find_world()`：若 player_action 已有取 world 的辅助（如 `_terrain().get_parent()` 或现成方法）就复用；否则加：
> ```gdscript
> func _find_world() -> Node:
> 	var t := _terrain()
> 	return t.get_parent() if t != null else null
> ```
> （确认 `_terrain()` 存在——本文件多处已用。）

在 `_update_eat_or_place` 里，仿 `grappling_hook` 分支（约 line 869），加召唤触发：

```gdscript
	# 持召唤道具 (史莱姆王冠) + 右键刚按下 → 召唤 Boss
	if slot != null and ItemDB.is_summon(slot.item_id) and just:
		try_use_summon_item()
		return
```

- [ ] **Step 5: 跑测试看它通过**

Run: 同上
Expected: `test_crown_summons_boss_and_consumes` + `test_no_double_boss` PASS

- [ ] **Step 6: 提交**

```bash
git add scripts/world/world.gd scripts/player/player_action.gd tests/integration/test_king_slime.gd
git commit -m "feat(boss): 王冠召唤史莱姆王 + 唯一 Boss 限制"
```

---

## Task 10: 全量验收 + 整体导入

**Files:** 无（仅运行）

- [ ] **Step 1: 跑整个 Boss 测试文件**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gsuffix=.gd -gtest=res://tests/integration/test_king_slime.gd -gexit 2>&1 | grep -v libfontconfig`
Expected: 全部 PASS（约 10 个测试），0 fail / 0 error

- [ ] **Step 2: 整体导入确认无回归**

Run: `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|Parse Error"`
Expected: 无输出（exit 0）

- [ ] **Step 3: 跑既有战斗测试确认没碰坏**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gsuffix=.gd -gtest=res://tests/integration/test_combat_phase1.gd -gexit 2>&1 | grep -v libfontconfig`
Expected: 全部 PASS（确认 player_action 改动没破坏既有武器）

- [ ] **Step 4: 给用户的验收清单（手动，部署后网页版可玩验证）**

- 工作台 3×3 摆 9 史莱姆胶 → 合成「史莱姆王冠」
- 手持王冠右键 → 召唤巨大史莱姆王（紫蓝色，1000 血大血条）
- Boss 大跳砸人；血过半冒小史莱姆；血越少越小越快
- 打死掉「史莱姆球」+ 一堆史莱姆胶
- 史莱姆球右键投出 → 抛物线 + 撞地弹跳 + 打怪
- 跑太远 / 死亡 → Boss 消失

---

## Self-Review 记录

- **Spec 覆盖**：召唤道具(T1,T2,T9)、Boss 本体(T6)、三招/阶段(T6 大跳, T7 召唤+缩放)、血量 1000(T6)、史莱姆球奖励(T3,T4,T5,T8 掉落)、收尾消失(T8)、美术(T3 + T6 染色/缩放)、防误删(T8)、验收测试(T1-T10)。全覆盖。
- **类型一致**：`tool_kind` 用 `"summon"`/`"slimeball"` 全程一致；`spawn_king_slime`/`try_use_summon_item`/`_spawn_minions`/`_hop_cooldown_now`/`_check_despawn`/`_apply_scale` 命名前后统一。
- **Placeholder**：每个代码步给了完整代码；T8 Step4 / T9 `_find_world` 留了"确认现有实现"的核查点，附带 grep 命令与兜底实现，非空泛占位。
