# 工具手感升级 + 工具/方块贴图重画 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 Teilaruia 的工具系统升级为泰拉瑞亚式手感（鼠标方向挥击、月牙拖尾、工具角度跟随），同时把 7 个工具和 17 个方块的像素贴图重画为更有层次的 RPG 风格。

**Architecture:** 分 3 个阶段、11 个任务。Phase A（任务 1-3）改逻辑：`player_action.gd` 的挥剑方向算法、`held_item.gd` 的旋转动画、月牙特效。Phase B（任务 4-7）重画 7 个工具像素图：扩展 `items_art.gd` 的调色板，把 3 个木质 / 3 个石质 / 1 个铁质工具改成斜柄 + 金属高光。Phase C（任务 8-11）升级 17 个方块贴图：按地表 / 木头 / 矿石 / 家具 4 类批次画 `blocks_art.gd`。每个任务独立 commit。

**Tech Stack:** Godot 4.3 / GDScript / GUT 测试框架 / 自研 PixelArt（`scripts/art/pixel_art.gd`：ASCII 网格 + 调色板 → ImageTexture）

**Spec:** `docs/superpowers/specs/2026-05-23-tools-and-textures-design.md`

---

## File Structure

**修改文件**：
- `scripts/player/player_action.gd` — 改 `_swing_sword()`、`_spawn_swing_arc()`；新增 `last_swing_center: Vector2`（测试用）
- `scripts/player/held_item.gd` — 新增 `play_swing_directional(target_angle: float)`；保留 `play_swing()`
- `scripts/art/items_art.gd` — 扩展 PALETTE；重画 7 张工具图
- `scripts/art/blocks_art.gd` — 升级 17 张方块图的 PALETTE + 像素

**新增测试**：
- `tests/unit/test_held_item.gd`（新建）— 测 `play_swing_directional`

**已有测试要加用例**：
- `tests/unit/test_player_action.gd` — 加 `test_sword_swing_aims_at_mouse_direction`

**不动**：
- `scripts/items/item_db.gd`、`scripts/world/tile_data.gd`、`scripts/player/player_inventory.gd`、`player_controller.gd`

---

## Phase A：工具手感升级（任务 1-3）

### Task 1: 挥剑方向跟随鼠标

**Goal**：`_swing_sword()` 的命中中心点改成"玩家中心指向鼠标方向"，距离 `SWORD_RANGE_PX × 0.5`。

**Files:**
- Modify: `scripts/player/player_action.gd:394-423`
- Test: `tests/unit/test_player_action.gd` (新增用例)

- [ ] **Step 1: 在 `player_action.gd` 顶部加可测试的状态**

在 `scripts/player/player_action.gd` 第 38 行 `var _attack_cooldown` 后加：

```gdscript
# 测试用: 记录最近一次挥剑的命中中心点 (玩家中心 + 鼠标方向 * 半径)
var last_swing_center: Vector2 = Vector2.ZERO
# 测试用: 注入鼠标世界坐标 (null = 真实 get_global_mouse_position)
var mouse_world_override: Variant = null
```

- [ ] **Step 2: 在 `test_player_action.gd` 末尾加新用例（写一个失败的测试）**

```gdscript
func test_sword_swing_aims_at_mouse_direction():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var action: Node2D = player.get_node("PlayerAction")
	# 给玩家一把木剑
	var inv: Node = player.get_node("PlayerInventory")
	inv.add_item("wood_sword", 1)
	inv.set_hotbar_selection(0)
	# 鼠标在玩家右上方 (世界坐标), 期望挥击中心朝向那里
	var player_pos: Vector2 = player.global_position
	action.mouse_world_override = player_pos + Vector2(100.0, -100.0)
	action.primary_override = true
	await wait_frames(2)
	# 命中中心应在 player_pos + normalize(100,-100) * SWORD_RANGE_PX * 0.5
	var expected_dir: Vector2 = Vector2(100.0, -100.0).normalized()
	var expected_center: Vector2 = player_pos + expected_dir * 18.0  # SWORD_RANGE_PX=36 * 0.5
	assert_almost_eq(action.last_swing_center.x, expected_center.x, 1.0)
	assert_almost_eq(action.last_swing_center.y, expected_center.y, 1.0)
```

- [ ] **Step 3: 跑测试看它失败**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_player_action.gd \
  -gselect=test_sword_swing_aims_at_mouse_direction -gexit
```

期望：FAIL（`last_swing_center` 还是 (0,0)，因为现有代码没设置它）。

- [ ] **Step 4: 修改 `_swing_sword()` 用鼠标方向**

把 `scripts/player/player_action.gd:394-423` 整段替换成：

```gdscript
func _swing_sword() -> void:
	_attack_cooldown = SWORD_COOLDOWN
	var player: Node2D = get_parent() as Node2D
	if player == null:
		return
	# 鼠标方向 (测试用 override > 真实输入)
	var mouse_world: Vector2 = mouse_world_override if mouse_world_override != null else player.get_global_mouse_position()
	var to_mouse: Vector2 = (mouse_world - player.global_position)
	if to_mouse.length() < 0.001:
		to_mouse = Vector2(1.0 if player.has_method("facing_dir") and player.facing_dir() > 0 else -1.0, 0)
	var swing_dir: Vector2 = to_mouse.normalized()
	# 命中中心点 = 玩家中心 + 方向 × 半个射程
	var center: Vector2 = player.global_position + swing_dir * SWORD_RANGE_PX * 0.5
	last_swing_center = center
	# 手持物品挥摆动画 (角度跟随鼠标; Task 2 实现)
	var held: Node = player.get_node_or_null("HeldItem")
	if held != null:
		if held.has_method("play_swing_directional"):
			held.play_swing_directional(swing_dir.angle())
		elif held.has_method("play_swing"):
			held.play_swing()
	SfxBank.play("swing", 0.10)
	var damage: int = _effective_sword_damage()
	if damage <= 0:
		return
	# 命中判定: 圆形范围, 半径 SWORD_RANGE_PX * 0.7
	for s in get_tree().get_nodes_in_group("slimes"):
		var sn := s as Node2D
		if sn == null:
			continue
		if center.distance_to(sn.global_position) <= SWORD_RANGE_PX * 0.7:
			if s.has_method("take_damage"):
				s.take_damage(damage, player.global_position)
	# 月牙挥击拖尾 (Task 3 重写)
	_spawn_swing_arc(player.global_position, swing_dir)
	if player.has_method("shake"):
		player.shake(3.0)
```

并把 `_spawn_swing_arc` 的签名占位改成 `(origin: Vector2, dir: Vector2)`（Task 3 会重写内部，这步只保证签名兼容）：

把原来的 `func _spawn_swing_arc(pos: Vector2, facing: int) -> void:` 改成 `func _spawn_swing_arc(origin: Vector2, dir: Vector2) -> void:`，函数体里现在的 `facing` 用法暂时改成 `var facing: int = 1 if dir.x >= 0 else -1`，弧线起点改成 `arc.global_position = origin + dir * 18.0`，其余逻辑保持不动（这步只让它编译通过，不改观感）。

- [ ] **Step 5: 跑测试看它通过**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_player_action.gd \
  -gselect=test_sword_swing_aims_at_mouse_direction -gexit
```

期望：PASS。

- [ ] **Step 6: 跑全部 combat 相关测试看没破坏其他**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_player_action.gd -gexit
```

期望：全部 PASS（不能因为改了挥剑方向破坏既有 mine/place 测试）。

- [ ] **Step 7: Commit**

```bash
git add scripts/player/player_action.gd tests/unit/test_player_action.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
feat(combat): 挥剑方向跟随鼠标 (替代左右 facing)

_swing_sword() 用 mouse_world - player_pos 算出朝向, 命中中心
点改为玩家中心 + 方向 × SWORD_RANGE_PX/2. 加 last_swing_center
和 mouse_world_override 用于测试.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: HeldItem 工具图标跟着鼠标角度旋转

**Goal**：在 `held_item.gd` 加 `play_swing_directional(target_angle: float)`，挥剑时工具沿鼠标方向 -45° → +45° 划过 90°。保留 `play_swing()` 给挖矿/砍木继续用。

**Files:**
- Modify: `scripts/player/held_item.gd:48-59`
- Test: `tests/unit/test_held_item.gd` (新建)

- [ ] **Step 1: 写一个失败的测试 — 新建 `tests/unit/test_held_item.gd`**

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_play_swing_directional_rotates_toward_angle():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var held: Sprite2D = player.get_node("HeldItem")
	# 给玩家一把木剑让 held 显示
	var inv: Node = player.get_node("PlayerInventory")
	inv.add_item("wood_sword", 1)
	inv.set_hotbar_selection(0)
	await wait_frames(1)
	# 目标角度 = 朝正右 (0 rad). 起手应在 -45°, 然后 tween 到 +45°
	held.play_swing_directional(0.0)
	# 起手帧: rotation ~= deg_to_rad(-45)
	assert_almost_eq(held.rotation, deg_to_rad(-45.0), 0.05)


func test_play_swing_directional_handles_upward_angle():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(2)
	var player = main.get_node("World").get_player()
	var held: Sprite2D = player.get_node("HeldItem")
	var inv: Node = player.get_node("PlayerInventory")
	inv.add_item("wood_sword", 1)
	inv.set_hotbar_selection(0)
	await wait_frames(1)
	# 朝正上 = -PI/2
	held.play_swing_directional(-PI / 2.0)
	assert_almost_eq(held.rotation, -PI / 2.0 - deg_to_rad(45.0), 0.05)
```

- [ ] **Step 2: 跑测试看它失败**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_held_item.gd -gexit
```

期望：FAIL（"function not found: play_swing_directional"）。

- [ ] **Step 3: 在 `held_item.gd` 加 `play_swing_directional`**

把 `scripts/player/held_item.gd:48-59` 整段（`play_swing` 函数）替换为：

```gdscript
func play_swing() -> void:
	# 节奏性挥摆 (挖矿/砍木用): 朝当前 facing 摆 ±75°
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	rotation = 0.0
	_tween = create_tween()
	var dir: float = 1.0 if _facing_right else -1.0
	_tween.tween_property(self, "rotation", deg_to_rad(-30.0 * dir), SWING_DURATION * 0.25)
	_tween.tween_property(self, "rotation", deg_to_rad(SWING_ANGLE_DEG * dir), SWING_DURATION * 0.35)
	_tween.tween_property(self, "rotation", 0.0, SWING_DURATION * 0.40)


func play_swing_directional(target_angle: float) -> void:
	# 定向挥击 (挥剑用): 沿 target_angle 方向, -45° → +45° 划过 90°.
	# target_angle 单位 = 弧度. 正右 = 0, 正下 = +PI/2, 正左 = ±PI, 正上 = -PI/2.
	if not visible:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var dir_sign: float = 1.0 if _facing_right else -1.0
	# 注意: 工具贴图是"竖向"的, 旋转支点在底部中心.
	# 当 target_angle = 0 (鼠标在右), 工具竖直 = -PI/2 时刀尖朝上,
	# 实际想要刀尖朝向 target_angle, 所以基准 = target_angle + PI/2.
	var base: float = target_angle + PI / 2.0
	var start_a: float = base - deg_to_rad(45.0) * dir_sign
	var end_a:   float = base + deg_to_rad(45.0) * dir_sign
	rotation = start_a
	_tween = create_tween()
	_tween.tween_property(self, "rotation", end_a, SWING_DURATION)
```

- [ ] **Step 4: 跑测试**

注意：测试断言里期望的角度是 `target_angle - 45°`，没考虑基准 `+PI/2`。改测试到期望值匹配实际（`base - 45°`）。

把 Task 2 Step 1 的两个 assert_almost_eq 改成：

```gdscript
# test 1 (target=0):
assert_almost_eq(held.rotation, PI / 2.0 - deg_to_rad(45.0), 0.05)

# test 2 (target=-PI/2):
assert_almost_eq(held.rotation, 0.0 - deg_to_rad(45.0), 0.05)
```

再跑：

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_held_item.gd -gexit
```

期望：PASS（注意 facing_right 默认 true，dir_sign=1）。

- [ ] **Step 5: 跑全部测试看没回归**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tail -20
```

期望：失败数 = 之前基线（如有），不增加。

- [ ] **Step 6: Commit**

```bash
git add scripts/player/held_item.gd tests/unit/test_held_item.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
feat(combat): HeldItem 加 play_swing_directional 跟随鼠标角度

挥剑时调用 play_swing_directional(swing_dir.angle()), 工具沿
该角度划过 90° (-45° → +45°). 保留 play_swing() 给挖矿/砍木
继续用节奏性 ±75° 摆动.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: 月牙形挥击拖尾

**Goal**：把 `_spawn_swing_arc()` 从 Line2D 折线换成 Polygon2D 扇形月牙，沿挥击方向覆盖 ±50° 扇形，0.18s 淡出。

**Files:**
- Modify: `scripts/player/player_action.gd:_spawn_swing_arc`（Task 1 已改签名）

- [ ] **Step 1: 重写 `_spawn_swing_arc` 用 Polygon2D**

定位 `scripts/player/player_action.gd` 里 Task 1 临时改过签名的 `_spawn_swing_arc(origin: Vector2, dir: Vector2)`，整段替换为：

```gdscript
func _spawn_swing_arc(origin: Vector2, dir: Vector2) -> void:
	# 月牙扇形拖尾: 沿 dir 方向覆盖 ±50°, 外径 SWORD_RANGE_PX*0.9, 内径 *0.4
	var outer_r: float = SWORD_RANGE_PX * 0.9
	var inner_r: float = SWORD_RANGE_PX * 0.4
	var half_spread: float = deg_to_rad(50.0)
	var steps: int = 14
	var base_angle: float = dir.angle()
	var poly := Polygon2D.new()
	poly.global_position = origin
	# 顶点: 外弧 14 个 + 内弧 14 个 (反向回来)
	var pts: PackedVector2Array = PackedVector2Array()
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var a: float = base_angle - half_spread + (half_spread * 2.0) * t
		pts.append(Vector2(cos(a), sin(a)) * outer_r)
	for i in range(steps + 1):
		var t: float = float(steps - i) / float(steps)
		var a: float = base_angle - half_spread + (half_spread * 2.0) * t
		pts.append(Vector2(cos(a), sin(a)) * inner_r)
	poly.polygon = pts
	poly.color = Color(1.0, 1.0, 1.0, 0.7)
	var parent: Node = get_tree().get_first_node_in_group("effects_root")
	if parent == null:
		parent = get_parent()
	parent.add_child(poly)
	var tween := poly.create_tween()
	tween.tween_property(poly, "modulate:a", 0.0, SWORD_ARC_LIFETIME)
	tween.tween_callback(poly.queue_free)
```

- [ ] **Step 2: 手动启动游戏看效果**

```bash
./run.sh
```

操作：进入世界 → 切到木剑（hotbar 1）→ 鼠标移到玩家四周不同位置 → 左键点 → 看月牙是否朝鼠标方向展开、是否平滑淡出。

期望：
- 月牙是个白色扇形（不是折线）
- 朝鼠标方向，覆盖玩家身前约 100° 扇形
- 0.18 秒内淡出消失
- 切镐/斧时不会出现月牙（因为只在 `_swing_sword` 里调）

如果不喜欢效果（太大/太小/颜色不对），调整 `outer_r`、`inner_r`、`half_spread`、`color` 后再启动看。

- [ ] **Step 3: 跑回归测试**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_player_action.gd -gexit
```

期望：全部 PASS。

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player_action.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
fx(combat): 月牙形挥击拖尾 (Polygon2D 扇形 + α 淡出)

替换原 Line2D 折线为 Polygon2D 扇形, 沿挥击方向 ±50° 展开,
外径 SWORD_RANGE_PX*0.9 内径 *0.4. 0.18s 淡出.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase B：工具贴图重画（任务 4-7）

### Task 4: 扩展 `items_art.gd` 调色板

**Goal**：在 PALETTE 加金属高光/钢色/黑描边的色码字符，给 Task 5-7 用。

**Files:**
- Modify: `scripts/art/items_art.gd:10-41`

- [ ] **Step 1: 在 PALETTE 末尾加新色码**

定位 `scripts/art/items_art.gd` 第 10-41 行 `const PALETTE := { ... }`，在 `"D": Color8(110, 65, 35),` 之后、`}` 之前加：

```gdscript
	# --- 工具重画新增色 (RPG 金属闪风) ---
	"n": Color8(26, 20, 16),       # 通用黑描边
	"e": Color8(40, 50, 65),       # 钢蓝深阴影 (iron blade shadow)
	"E": Color8(95, 115, 135),     # 钢蓝中
	"F": Color8(180, 200, 220),    # 钢蓝高光
	"f": Color8(235, 245, 255),    # 钢蓝极亮闪点
	"v": Color8(70, 70, 78),       # 石质冷灰深 (stone blade shadow)
	"V": Color8(130, 132, 142),    # 石质冷灰中
	"x": Color8(190, 195, 205),    # 石质冷灰高光
	"i": Color8(115, 78, 44),      # 木柄中间纹 (比 h 暗一档)
	"I": Color8(204, 156, 102),    # 木柄反光高光 (比 y 亮一档)
```

- [ ] **Step 2: 验证不破坏现有图标渲染**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd \
  -gtest=res://tests/unit/test_logo_art.gd -gexit
```

如果有 `test_items_art.gd` 也跑：

```bash
find tests -name "test_items*" -exec godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://{} -gexit \; 2>&1 | tail -5
```

期望：PASS（PALETTE 只加不删，旧色码字符仍可用）。

- [ ] **Step 3: Commit**

```bash
git add scripts/art/items_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(tools): 扩展 PALETTE 加金属闪风色码 (钢蓝/石灰/木纹层次)

n(黑描边) e/E/F/f(钢蓝 4 层) v/V/x(石质冷灰 3 层) i/I(木纹中暗+亮高光).
为后续 7 个工具重画用. 不删旧色, 旧贴图保持兼容.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: 重画 3 个木质工具（wood_sword / wood_pickaxe / wood_axe）

**Goal**：木质工具加金属高光 + 黑描边 + 斜柄（pickaxe/axe 改成 45°）。

**Files:**
- Modify: `scripts/art/items_art.gd:43-101`

- [ ] **Step 1: 替换 `_WOOD_SWORD`（已是斜刀身，加 1px 描边 + 3 层金属高光）**

定位第 44-61 行 `const _WOOD_SWORD := [...]`，整段替换：

```gdscript
const _WOOD_SWORD := [
	"............nnn.",
	"...........nyyn.",
	"..........nyYIn.",
	".........nyYIn..",
	"........nyYIn...",
	".......nyYIn....",
	"......nyYIn.....",
	".....nyYIn......",
	"....nyYIn.......",
	"...nggGGn.......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhin........",
	"....nhin........",
	"....nKKn........",
	"................",
]
```

- [ ] **Step 2: 替换 `_WOOD_PICKAXE`（柄从竖直改成 45° 斜柄）**

定位第 64-81 行，整段替换：

```gdscript
const _WOOD_PICKAXE := [
	"...nnnnnnnnn....",
	"..nyYYYYYYIIn...",
	".nyyYYYYYYIIIn..",
	"..nyYYYYYYIIn...",
	"...nnyYYYInn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]
```

- [ ] **Step 3: 替换 `_WOOD_AXE`（斧头 + 45° 斜柄）**

定位第 84-101 行，整段替换：

```gdscript
const _WOOD_AXE := [
	"..nYYYYn........",
	".nYYYYYIn.......",
	"nYYYYYYYIn......",
	"nYYYYYYIIn......",
	"nYYYYYIIn.......",
	"nYYYYIIn........",
	".nYYIIn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
	"................",
]
```

- [ ] **Step 4: 启动游戏看效果**

```bash
./run.sh
```

操作：进入世界 → 打开背包看 wood_sword/wood_pickaxe/wood_axe 图标 → 拿到 hotbar 看握在手里的样子 → 挥几下看旋转。

期望：3 个工具都有黑描边、刃部 / 头部明显金属高光、柄是 45° 斜的（剑保持原对角线）。如果觉得太花/太单/不像可调字符再来。

- [ ] **Step 5: Commit**

```bash
git add scripts/art/items_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(tools): 木质工具重画 (剑/镐/斧, 加描边+金属高光+斜柄)

剑保留对角线刀身, 加 n 描边 + Y/y/I/h 4 层. 镐和斧柄从
竖直改成 45° 斜柄, 头部加 3 层金属高光 + 黑描边.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: 重画 3 个石质工具（stone_sword / stone_pickaxe / stone_axe）

**Goal**：石质工具用冷灰色（`v V x`），木柄沿用新的 `i I` 高光。

**Files:**
- Modify: `scripts/art/items_art.gd:103-161`

- [ ] **Step 1: 替换 `_STONE_SWORD`**

定位第 104-121 行，整段替换：

```gdscript
const _STONE_SWORD := [
	"............nnn.",
	"...........nVVn.",
	"..........nVvVn.",
	".........nVvVxn.",
	"........nVvVxn..",
	".......nVvVxn...",
	"......nVvVxn....",
	".....nVvVxn.....",
	"....nVvVxn......",
	"...nggGGGn......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhIn........",
	"....nhin........",
	"....nKKn........",
	"................",
]
```

- [ ] **Step 2: 替换 `_STONE_PICKAXE`（45° 斜柄 + 石质冷灰头）**

定位第 124-141 行，整段替换：

```gdscript
const _STONE_PICKAXE := [
	"...nnnnnnnnn....",
	"..nVVVVVVVVxn...",
	".nVxxxxxxxxVxn..",
	"..nVxvvvvvVxn...",
	"...nnVvvvVnn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]
```

- [ ] **Step 3: 替换 `_STONE_AXE`**

定位第 144-161 行，整段替换：

```gdscript
const _STONE_AXE := [
	"..nVVVVn........",
	".nVxxxxxn.......",
	"nVxxxxxxxn......",
	"nVxxxvvvVn......",
	"nVxxxvVVn.......",
	"nVxxvVVn........",
	".nVvVVn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
	"................",
]
```

- [ ] **Step 4: 启动游戏看效果**

```bash
./run.sh
```

操作：进入世界 → 用 console / 作弊给自己石剑石镐石斧（或者按现有合成流程取）→ 看图标 + 握持。

期望：3 个石质工具明显比木质冷一点（灰色 vs 棕色），柄是同样的斜向，挥起来风格一致。

- [ ] **Step 5: Commit**

```bash
git add scripts/art/items_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(tools): 石质工具重画 (剑/镐/斧, 冷灰刃 + 斜柄统一)

刃部用 v/V/x 3 层冷灰, 柄沿用 h/i/I + 黑描边. 镐/斧改 45° 斜柄.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: 重画 iron_pickaxe（钢蓝白闪光 + 斜柄）

**Goal**：铁镐用钢蓝白色码（`e E F f`），最闪。

**Files:**
- Modify: `scripts/art/items_art.gd:244-261`

- [ ] **Step 1: 替换 `_IRON_PICKAXE`**

定位第 244-261 行，整段替换：

```gdscript
const _IRON_PICKAXE := [
	"...nnnnnnnnn....",
	"..nEEEEEFfFEn...",
	".nEFFFFFFFFFEn..",
	"..nEeeEEEEEEn...",
	"...nnEeeeFnn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]
```

- [ ] **Step 2: 启动游戏看效果**

```bash
./run.sh
```

操作：合成铁镐（需要铁矿 + 木板 + 工作台）或直接 inv.add_item("iron_pickaxe", 1)。

期望：铁镐刃部明显比石/木闪亮，有白色高光点（`f`），整体偏冷钢蓝，跟木镐/石镐放一排能一眼看出三级差异。

- [ ] **Step 3: Commit**

```bash
git add scripts/art/items_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(tools): 铁镐重画 (钢蓝白闪光 + 斜柄, 跟木/石 3 级区分明显)

刃部 e/E/F/f 4 层钢蓝, 含 f 极亮高光点. 柄统一斜柄风格.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase C：方块贴图重画（任务 8-11）

### Task 8: 地表 4 方块层次升级（grass / dirt / stone / sand）

**Goal**：4 个最常见地表方块加色彩层次 + 上亮下暗 + 细节斑点。

**Files:**
- Modify: `scripts/art/blocks_art.gd:33-79, 217-296`

- [ ] **Step 1: 升级 `_P_GRASS` 调色板**

定位第 33-45 行 `const _P_GRASS := { ... }`，整段替换（加 1 个亮高光色 + 1 个深阴影色）：

```gdscript
const _P_GRASS := {
	"a": Color8(195, 228, 130),  # 草尖极亮高光 (新, 比 m 更亮)
	"g": Color8(125, 173, 90),   # 暖绿基
	"G": Color8(79, 124, 62),    # 深暖绿
	"m": Color8(149, 194, 97),   # 中暖绿
	"y": Color8(220, 220, 120),  # 金黄草尖
	"s": Color8(199, 204, 90),   # 金黄草穗
	"d": Color8(156, 112, 72),   # 暖泥
	"D": Color8(126, 88, 64),    # 泥阴影
	"k": Color8(94, 65, 44),     # 小石子
	"l": Color8(186, 144, 112),  # 泥高光
	"r": Color8(160, 90, 48),    # 红棕根
	"v": Color8(60, 90, 40),     # 草最深阴影 (新)
}
```

- [ ] **Step 2: 升级 `_GRASS` 像素图（顶部草尖 + 下半泥土更分层）**

定位第 217-236 行 `const _GRASS := [...]`，整段替换：

```gdscript
const _GRASS := [
	"asayssayasaayssa",
	"gmgmgmgmgmgmgmgm",
	"Gvggmggvgmggvggm",
	"GGGGGGGGGGGGGGGG",
	"dlddlddldddlddld",
	"DdrDdkDdDrdDdkdr",
	"DDdDDdDDdDDdDDdD",
	"DkDDkDDkDDkDDkDD",
	"dDdDdrDdDdDkDdDd",
	"DDdDDdDDdDdDDDDd",
	"DdrDdkDdDrdDdkdr",
	"DDdDDdDDdDDdDDdD",
	"DkDDkDDkDDkDDkDD",
	"DdDdDrDdDdDkDdDd",
	"DDdDDdDDdDdDDDDd",
	"DDdDDdDDdDDDDDDD",
]
```

- [ ] **Step 3: 升级 `_P_DIRT` + `_DIRT`**

`_P_DIRT`（第 47-56 行附近）整段替换：

```gdscript
const _P_DIRT := {
	"d": Color8(160, 122, 85),   # 暖泥基
	"D": Color8(126, 88, 64),    # 深暗
	"k": Color8(92, 63, 42),     # 石子
	"l": Color8(195, 156, 118),  # 泥高光 (加亮)
	"r": Color8(170, 100, 55),   # 红棕根
}
```

`_DIRT` 像素图（第 237-256 行）整段替换：

```gdscript
const _DIRT := [
	"lddlddldddlddldd",
	"ddddddrdddddddrd",
	"dDdDdDdDdDdDdDdD",
	"DddkddDddrddDddk",
	"dDdDdDdDdDdDdDdD",
	"DdDkDDdDDkDDdDDk",
	"dDdDdDdDdDdDdDdD",
	"DdDdrDdkDdDdDdDr",
	"dDdDdDdDdDdDdDdD",
	"DdDkDDdDDkDDdDDk",
	"dDdDdDdDdDdDdDdD",
	"DdDdDDdkDdDdDdDD",
	"dDdDdDdDdDdDdDdD",
	"DdDkDDdDDkDDdDDk",
	"dDdDdDdDdDdDdDdD",
	"DDdDDDdDDDdDDDDD",
]
```

- [ ] **Step 4: 升级 `_P_STONE` + `_STONE`**

`_P_STONE`（第 58-68 行附近）整段替换：

```gdscript
const _P_STONE := {
	"s": Color8(125, 130, 138),  # 石头基色
	"S": Color8(85, 88, 95),     # 深阴影
	"l": Color8(170, 175, 182),  # 高光
	"L": Color8(195, 200, 208),  # 极亮高光点 (新)
	"k": Color8(50, 52, 58),     # 黑缝
	"w": Color8(155, 160, 168),  # 中间灰
}
```

`_STONE`（第 257-276 行）整段替换：

```gdscript
const _STONE := [
	"lwwslwsswlswswll",
	"wsswswlswswsslww",
	"swswkswssksLswsw",
	"wswskwswswksswsw",
	"sskswSwswSwswssS",
	"wsSswswSswswsSws",
	"sSwskswSswkswSws",
	"wSswswSwswswsSws",
	"swswsLwswsLswswS",
	"wsswswswswswswsw",
	"sSwskswSswkswSws",
	"wSswswSwswswsSws",
	"sskswSwswSwswssS",
	"wsSswswSswswsSws",
	"sSwskswSswkswSwk",
	"wkSswswSwSswswSk",
]
```

- [ ] **Step 5: 升级 `_P_SAND` + `_SAND`**

`_P_SAND`（第 69-79 行附近）整段替换：

```gdscript
const _P_SAND := {
	"s": Color8(225, 198, 130),  # 沙基
	"S": Color8(180, 152, 95),   # 沙阴影
	"l": Color8(245, 222, 165),  # 沙高光
	"L": Color8(255, 240, 195),  # 极亮 (新)
	"k": Color8(140, 115, 70),   # 深暗
	"d": Color8(195, 168, 110),  # 中间色 (新)
}
```

`_SAND`（第 277-296 行）整段替换：

```gdscript
const _SAND := [
	"lslsLlslslLslsls",
	"sdsdsdsdsdsdsdsd",
	"dsdsdsdsdsdsdsds",
	"sdsdsdSdsdsdsSds",
	"dsdsdsdsdsdsdsds",
	"sdsdsdsdSdsdsdsd",
	"dsdsdsdsdsdsdsds",
	"sdSdsdsdsdsdSdsd",
	"dsdsdsdsdsdsdsds",
	"sdsdsdsdSdsdsdsd",
	"dsdsSdsdsdsdsdsd",
	"sdsdsdsdsdsSdsds",
	"dsdsdsdsdsdsdsds",
	"sdsdsdSkdsdsdsds",
	"dsdsdsdsdsdsdsds",
	"SdSdSdSdSdSdSdSk",
]
```

- [ ] **Step 6: 启动游戏看效果**

```bash
./run.sh
```

操作：进入世界 → 看地表草地、挖几块泥土看 dirt、找石头层（往下挖）→ 看效果。

期望：草地顶部有金黄草尖、泥土有暗纹和石子、石头有冷灰层次和零星高光、沙子上亮下暗有颗粒感。

- [ ] **Step 7: Commit**

```bash
git add scripts/art/blocks_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(blocks): 地表 4 方块层次升级 (草/土/石/沙)

每块加 1-2 个高亮/暗色, 像素图重排上亮下暗, 加细密斑点保
留剪影. 4 块色彩冷暖搭配跟现有 HUD 协调.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 9: 木头 5 方块层次升级（log / planks / leaves / leaves_pine / leaves_autumn）

**Goal**：5 个木头/叶子类方块加层次。

**Files:**
- Modify: `scripts/art/blocks_art.gd:80-123, 133-140, 297-357, 396-415`

- [ ] **Step 1: 升级 `_P_LOG`**

定位 `_P_LOG`（第 80-90 行附近）整段替换：

```gdscript
const _P_LOG := {
	"b": Color8(115, 78, 50),    # 树皮基
	"B": Color8(85, 55, 32),     # 树皮深
	"l": Color8(155, 115, 80),   # 木芯亮
	"L": Color8(195, 155, 110),  # 木芯极亮 (新)
	"k": Color8(58, 38, 22),     # 黑暗纹
	"w": Color8(135, 95, 60),    # 中间色 (新)
}
```

`_LOG` 像素图（第 297-316 行）整段替换：

```gdscript
const _LOG := [
	"bBbBkbBbBbkbBbBb",
	"bBwwbBwwBbwwBbwb",
	"BblwBblwbBlwBblw",
	"bBlLwBlLwBlLwBlw",
	"bBLLLwBLLLwBLLwb",
	"bBlLwBlLwBlLwBlw",
	"BblwBblwbBlwBblw",
	"bBwwbBwwBbwwBbwb",
	"bBbBkbBbBbkbBbBb",
	"bBwwbBwwBbwwBbwb",
	"BblwBblwbBlwBblw",
	"bBlLwBlLwBlLwBlw",
	"bBLLLwBLLLwBLLwb",
	"bBlLwBlLwBlLwBlw",
	"BblwBblwbBlwBblw",
	"BbBbkBbBbBkBbBbk",
]
```

- [ ] **Step 2: 升级 `_P_PLANKS` + `_PLANKS`**

`_P_PLANKS` 整段替换：

```gdscript
const _P_PLANKS := {
	"p": Color8(165, 118, 75),   # 木板基
	"P": Color8(125, 85, 50),    # 板缝深
	"l": Color8(195, 152, 105),  # 木板高光
	"L": Color8(220, 178, 130),  # 极亮 (新)
	"k": Color8(80, 50, 25),     # 钉子
	"w": Color8(145, 100, 62),   # 木纹中色 (新)
}
```

`_PLANKS` 像素图（第 396-415 行）整段替换：

```gdscript
const _PLANKS := [
	"lpwpLpwpLpwpLpwp",
	"pwpwpwpwpwpwpwpw",
	"wpwkwpwpwpwpwpwk",
	"PPPPPPPPPPPPPPPP",
	"lpwpLpwpLpwpLpwp",
	"pwpwpwpwkwpwpwpw",
	"wpwpwpwpwpwpwkpw",
	"PPPPPPPPPPPPPPPP",
	"lpwpLpwpLpwpLpwp",
	"pwpwkwpwpwpwpwpw",
	"wpwpwpwpwpwpwpwk",
	"PPPPPPPPPPPPPPPP",
	"lpwpLpwpLpwpLpwp",
	"pwpwpwpwpwpwkwpw",
	"wpwpwkpwpwpwpwpw",
	"PPPPPPPPPPPPPPPP",
]
```

- [ ] **Step 3: 升级 `_P_LEAVES` + `_LEAVES`（橡树叶）**

`_P_LEAVES` 整段替换：

```gdscript
const _P_LEAVES := {
	"l": Color8(105, 158, 70),   # 叶基
	"L": Color8(75, 122, 50),    # 叶深
	"a": Color8(155, 198, 105),  # 叶亮
	"A": Color8(195, 228, 135),  # 极亮 (新)
	"k": Color8(48, 80, 32),     # 暗叶脉
	"y": Color8(220, 215, 130),  # 黄绿斑点 (新)
}
```

`_LEAVES` 像素图（第 317-336 行）整段替换：

```gdscript
const _LEAVES := [
	"AlAlAlAlAlAlAlAl",
	"lalalaLlalaLalaL",
	"alalalalalalalal",
	"laLlaLlaLlaLlaLk",
	"alAlalAlalAlalAl",
	"lalylalalaylalal",
	"alalLalLalalLala",
	"lalalalalalalalk",
	"alAlalAlalAlalAl",
	"lalalalalaylalaL",
	"alalalalalalalal",
	"laLlaLlaLlaLlaLl",
	"alalalalAlalalAl",
	"lalalalalalalalk",
	"alLalLalalLalLal",
	"LlLlLlLlLlLlLlLl",
]
```

- [ ] **Step 4: 升级 `_P_LEAVES_PINE` + `_LEAVES_PINE`**

`_P_LEAVES_PINE` 整段替换：

```gdscript
const _P_LEAVES_PINE := {
	"l": Color8(55, 95, 50),     # 针叶基
	"L": Color8(35, 70, 35),     # 深
	"a": Color8(90, 135, 75),    # 亮
	"A": Color8(120, 168, 95),   # 极亮 (新)
	"k": Color8(20, 45, 22),     # 暗
}
```

`_LEAVES_PINE` 像素图（第 337-356 行）整段替换：

```gdscript
const _LEAVES_PINE := [
	"AlAlAlAlAlAlAlAl",
	"laLlaLlaLlaLlaLl",
	"alalalalalalalal",
	"laLlaLkaLlaLlaLl",
	"alAlalAlalAlalAl",
	"lalalalalalalalk",
	"alalLalalLalalLa",
	"LalalalalalalalL",
	"alAlalAlalAlalAl",
	"lalalalalalkalal",
	"alalalalalalalal",
	"laLlaLlaLlaLlaLl",
	"alalalalalalalal",
	"lalalalalkalalal",
	"alalalLalalalLal",
	"LlLlLlLlLlLlLlLl",
]
```

- [ ] **Step 5: 升级 `_P_LEAVES_AUTUMN` + `_LEAVES_AUTUMN`**

`_P_LEAVES_AUTUMN` 整段替换：

```gdscript
const _P_LEAVES_AUTUMN := {
	"r": Color8(190, 90, 50),    # 红橙基
	"R": Color8(140, 60, 30),    # 深红
	"o": Color8(225, 140, 65),   # 橙亮
	"O": Color8(245, 180, 95),   # 极亮橙黄 (新)
	"y": Color8(220, 195, 110),  # 黄斑
	"k": Color8(85, 35, 20),     # 黑梗
}
```

`_LEAVES_AUTUMN` 像素图（第 357-376 行）整段替换：

```gdscript
const _LEAVES_AUTUMN := [
	"OrOrOrOrOrOrOrOr",
	"roRroRroRroRroRr",
	"orororyrororyror",
	"roRroRroRroRroRk",
	"orOrorOrorOrorOr",
	"rororororokorror",
	"oroRroRorororRor",
	"roroyrororororok",
	"orOrorOrorOrorOr",
	"rorororororyrord",
	"orororororororor",
	"roRroRroRroRroRr",
	"orororororororor",
	"rorororokorrorok",
	"orororRororRoror",
	"RrRrRrRrRrRrRrRr",
]
```

- [ ] **Step 6: 启动游戏看效果**

```bash
./run.sh
```

操作：进入世界 → 看一棵树（log 树干 + leaves 叶子）→ 砍掉得到 planks → 进入秋叶林（如有则看 leaves_autumn）→ 看效果。

期望：树干有明显纵纹年轮、木板有钉子和板缝、3 种叶子色调区分明显但都是层次丰富的"那个叶子"。

- [ ] **Step 7: Commit**

```bash
git add scripts/art/blocks_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(blocks): 木头 5 方块层次升级 (原木/木板/3 种叶)

log 加年轮纵纹, planks 加钉子板缝, 3 种叶子各加 1 层极亮色和
特征斑点 (黄绿/松针/秋叶橙黄).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 10: 矿石 4 方块层次升级（bedrock / deep_stone / coal_ore / iron_ore）

**Goal**：地下/矿石类方块加层次和金属感斑点。

**Files:**
- Modify: `scripts/art/blocks_art.gd`（基岩/深石/煤矿/铁矿的 PALETTE + 像素图）

- [ ] **Step 1: 先定位 4 个常量的行号**

```bash
grep -n "_P_BEDROCK\|_BEDROCK\|_P_DEEP_STONE\|_DEEP_STONE\|_P_COAL_ORE\|_COAL_ORE\|_P_IRON_ORE\|_IRON_ORE" /workspace/teilaruia/scripts/art/blocks_art.gd
```

记下每个常量的起止行（每个一般 10-20 行）。

- [ ] **Step 2: 升级 `_P_BEDROCK` + 像素图**

`_P_BEDROCK` 整段替换：

```gdscript
const _P_BEDROCK := {
	"b": Color8(45, 42, 55),     # 基岩基 (深暗紫灰)
	"B": Color8(25, 22, 30),     # 极深
	"l": Color8(65, 60, 75),     # 高光
	"L": Color8(80, 75, 92),     # 亮高光 (新)
	"k": Color8(15, 12, 18),     # 黑裂纹
	"p": Color8(78, 50, 78),     # 暗紫斑 (新)
}
```

`_BEDROCK` 像素图整段替换：

```gdscript
const _BEDROCK := [
	"lbBblBLbBblBbBbl",
	"bBblBBbBblBkbBpb",
	"BbBlbBbBlbBkbBlb",
	"bBblBBbBplBkbBbb",
	"BbBlbBbBlbBkbBlb",
	"bBblBBpBblBkbBbB",
	"BbBlbBbBlbBkbBlb",
	"bBblBBbBblBkbBbB",
	"BbBlpBbBlbBkbpLb",
	"bBblBBbBblBkbBbB",
	"BbBlbBbBlbBkbBlb",
	"bBblBBbBblBkbBpB",
	"BbBlbBbBlbBkbBlb",
	"bBblBBpBblBkbBbB",
	"BbBlbBbBlbBkbBlb",
	"BBBBBBBBBBBBBBBB",
]
```

- [ ] **Step 3: 升级 `_P_DEEP_STONE` + 像素图**

`_P_DEEP_STONE` 整段替换：

```gdscript
const _P_DEEP_STONE := {
	"s": Color8(95, 85, 78),     # 暖深灰基
	"S": Color8(65, 55, 50),     # 阴影
	"l": Color8(125, 115, 105),  # 高光
	"L": Color8(150, 138, 125),  # 极亮 (新)
	"k": Color8(38, 30, 25),     # 黑缝
	"r": Color8(115, 88, 65),    # 暖矿脉 (新)
}
```

`_DEEP_STONE` 像素图整段替换：

```gdscript
const _DEEP_STONE := [
	"lsslsslsslLsslss",
	"ssrssksslssrsskl",
	"slsslsslsslsslss",
	"sSsslsSsLsslsSss",
	"slssrsslsslsslsk",
	"ssksslsskssrssls",
	"slsslsslsslsslss",
	"sSssLsSsslssrSss",
	"slsskssrsslsslss",
	"ssksslsskssLssls",
	"slsslsslsslsslss",
	"sSssrsSsslssksss",
	"slsslsslsslsslss",
	"ssLsslssrssslsks",
	"slsslsslsslsslss",
	"SSSSSSSSSSSSSSSk",
]
```

- [ ] **Step 4: 升级 `_P_COAL_ORE` + 像素图**

`_P_COAL_ORE` 整段替换：

```gdscript
const _P_COAL_ORE := {
	"s": Color8(125, 130, 138),  # 石底基
	"S": Color8(85, 88, 95),     # 石阴影
	"l": Color8(170, 175, 182),  # 石高光
	"k": Color8(50, 52, 58),     # 黑缝
	"c": Color8(35, 32, 30),     # 煤块基 (暖深)
	"C": Color8(15, 12, 10),     # 煤极深
	"h": Color8(70, 65, 60),     # 煤高光 (反光)
}
```

`_COAL_ORE` 像素图整段替换：

```gdscript
const _COAL_ORE := [
	"lsslsslsslsslssl",
	"ssccccsslsccccss",
	"slcChcccsccChcCs",
	"sscChCccccChCcSs",
	"slccchccccchccss",
	"sssccccsscccccss",
	"slsslsslsslsslss",
	"sccchccsschcCccs",
	"sccCcccCsccChccs",
	"slssccccssccccss",
	"sssssslsslssslss",
	"slsslsslsslsslss",
	"ssccccsslsccccss",
	"slcChcccsccChcCs",
	"sscChCccccChCcSs",
	"sssssslsslSSSSSk",
]
```

- [ ] **Step 5: 升级 `_P_IRON_ORE` + 像素图**

`_P_IRON_ORE` 整段替换：

```gdscript
const _P_IRON_ORE := {
	"s": Color8(125, 130, 138),  # 石底基
	"S": Color8(85, 88, 95),     # 石阴影
	"l": Color8(170, 175, 182),  # 石高光
	"k": Color8(50, 52, 58),     # 黑缝
	"r": Color8(170, 105, 65),   # 铁锈基
	"R": Color8(130, 70, 40),    # 铁锈深
	"t": Color8(210, 155, 100),  # 铁锈高光
	"T": Color8(245, 200, 140),  # 极亮锈点 (新)
}
```

`_IRON_ORE` 像素图整段替换（注意这是放置后的方块版本，不是 icon）：

```gdscript
const _IRON_ORE := [
	"lsslsslsslsslssl",
	"ssrrrrsslsrrrrss",
	"slrTtrrsrtTRRrss",
	"ssrtRrrsstRRRtSs",
	"slrrrTrrrrrtrrss",
	"ssssrrrsRrrrrsss",
	"slsslsslsslsslss",
	"srTtrrrssrtTRrss",
	"srrrtrrRsrtRrrSs",
	"slssrrrrssrrrrss",
	"sssssslsslssslss",
	"slsslsslsslsslss",
	"ssrrTrsslsrtRrss",
	"slrtrrrsrTrRrCss",
	"ssrRrrTssrrRrrSs",
	"sssssslsslSSSSSk",
]
```

- [ ] **Step 6: 启动游戏看效果**

```bash
./run.sh
```

操作：用 iron_pickaxe 往下挖到地下层 → 看 deep_stone、coal_ore、iron_ore、bedrock。

期望：煤矿明显有黑色煤块斑点、铁矿有橙色锈斑和高光点、深石比普通石头暖深一档、基岩最暗有黑裂纹和暗紫斑点。

- [ ] **Step 7: Commit**

```bash
git add scripts/art/blocks_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(blocks): 矿石 4 方块层次升级 (基岩/深石/煤矿/铁矿)

bedrock 加暗紫斑 + 黑裂纹, deep_stone 加暖矿脉, coal_ore
煤斑加反光高光 h, iron_ore 锈斑加 T 极亮高光点.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 11: 家具 4 方块层次升级（workbench / door / torch / slime_torch）

**Goal**：家具/功能类方块加细节。

**Files:**
- Modify: `scripts/art/blocks_art.gd`（workbench/door/torch/slime_torch 的 PALETTE + 像素图）

- [ ] **Step 1: 定位 4 个常量行号**

```bash
grep -n "_P_WORKBENCH\|_WORKBENCH\|_P_DOOR\|_DOOR_CLOSED\|_DOOR_OPEN\|_P_TORCH\|_TORCH\|_P_SLIME_TORCH\|_SLIME_TORCH" /workspace/teilaruia/scripts/art/blocks_art.gd
```

- [ ] **Step 2: 升级 `_P_WORKBENCH` + 像素图**

`_P_WORKBENCH` 整段替换：

```gdscript
const _P_WORKBENCH := {
	"p": Color8(165, 118, 75),   # 木板基
	"P": Color8(125, 85, 50),    # 板缝
	"l": Color8(195, 152, 105),  # 木板高光
	"L": Color8(220, 178, 130),  # 极亮 (新)
	"k": Color8(80, 50, 25),     # 钉子/工具暗
	"g": Color8(135, 138, 145),  # 锯子/锤子金属
	"G": Color8(180, 185, 192),  # 金属高光 (新)
	"w": Color8(145, 100, 62),   # 木纹中色 (新)
}
```

`_WORKBENCH` 像素图整段替换：

```gdscript
const _WORKBENCH := [
	"LpLpLpLpLpLpLpLp",
	"pwpwpwpwpwpwpwpw",
	"PPPPPPPPPPPPPPPP",
	"lplplpgGglplplpl",
	"plkplpgkgplpklpl",
	"lplplpgGglplplpl",
	"PPPPPPPPPPPPPPPP",
	"lplGlplplplgGlpl",
	"plkgkplpkplpkgkl",
	"lplGlplplplgGlpl",
	"PPPPPPPPPPPPPPPP",
	"lplplplplplplplp",
	"PpPpPpPpPpPpPpPp",
	"pPpPpPpPpPpPpPpP",
	"PpPpPpPpPpPpPpPp",
	"PPPPPPPPPPPPPPPP",
]
```

- [ ] **Step 3: 升级 `_P_DOOR` + `_DOOR_CLOSED` + `_DOOR_OPEN`**

`_P_DOOR` 整段替换：

```gdscript
const _P_DOOR := {
	"p": Color8(165, 118, 75),   # 木板基
	"P": Color8(125, 85, 50),    # 板缝
	"l": Color8(195, 152, 105),  # 木板高光
	"L": Color8(220, 178, 130),  # 极亮 (新)
	"k": Color8(60, 40, 22),     # 边框黑
	"h": Color8(195, 175, 95),   # 黄铜把手 (新)
	"H": Color8(230, 215, 130),  # 黄铜把手高光 (新)
	".": Color(0, 0, 0, 0),
}
```

`_DOOR_CLOSED` 像素图整段替换：

```gdscript
const _DOOR_CLOSED := [
	"kkkkkkkkkkkkkkkk",
	"kLplplplplplpLpk",
	"kplplplplplplpLk",
	"kPPPPPPPPPPPPPPk",
	"klplplplplplplpk",
	"kplplhHplplplplk",
	"kPlplhHplplplPPk",
	"klplplplplplplpk",
	"kPPPPPPPPPPPPPPk",
	"klplplplplplplpk",
	"kplplplplplplplk",
	"kPPPPPPPPPPPPPPk",
	"klplplplplplplpk",
	"kplplplplplplplk",
	"kPPPPPPPPPPPPPPk",
	"kkkkkkkkkkkkkkkk",
]
```

`_DOOR_OPEN` 像素图整段替换：

```gdscript
const _DOOR_OPEN := [
	"kkkk............",
	"kLpk............",
	"kplk............",
	"kPPk............",
	"klpk............",
	"kphk............",
	"kPhk............",
	"klpk............",
	"kPPk............",
	"klpk............",
	"kplk............",
	"kPPk............",
	"klpk............",
	"kplk............",
	"kPPk............",
	"kkkk............",
]
```

- [ ] **Step 4: 升级 `_P_TORCH` + `_TORCH`**

`_P_TORCH` 整段替换：

```gdscript
const _P_TORCH := {
	"w": Color8(105, 72, 42),    # 木棒基
	"W": Color8(75, 50, 28),     # 木棒深
	"l": Color8(150, 110, 70),   # 木棒高光
	"f": Color8(255, 240, 130),  # 火焰核心黄
	"F": Color8(255, 195, 75),   # 中焰橙
	"r": Color8(225, 95, 50),    # 外焰红
	"R": Color8(160, 50, 30),    # 暗红 (新)
	".": Color(0, 0, 0, 0),
}
```

`_TORCH` 像素图（保留行数；如原图是 16×16 单帧）整段替换为：

```gdscript
const _TORCH := [
	".......rRr......",
	"......rRfRr.....",
	"......RfFfR.....",
	".....rRfFFFr....",
	".....rRFfFFRr...",
	"......rRfRRr....",
	".......rFr......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WWW......",
]
```

- [ ] **Step 5: 升级 `_P_SLIME_TORCH` + `_SLIME_TORCH`**

`_P_SLIME_TORCH` 整段替换：

```gdscript
const _P_SLIME_TORCH := {
	"w": Color8(105, 72, 42),    # 木棒基
	"W": Color8(75, 50, 28),     # 木棒深
	"l": Color8(150, 110, 70),   # 木棒高光
	"g": Color8(76, 175, 80),    # 史莱姆绿基
	"G": Color8(46, 125, 50),    # 深绿
	"q": Color8(125, 215, 130),  # 高光
	"Q": Color8(195, 245, 200),  # 极亮 (新)
	".": Color(0, 0, 0, 0),
}
```

`_SLIME_TORCH` 像素图整段替换：

```gdscript
const _SLIME_TORCH := [
	"......ggggg.....",
	".....gQqqqQg....",
	"....gqqgggqqg...",
	"....gqgqQqgqg...",
	"....gqgqqqgqg...",
	"....gqqgqgqqg...",
	".....gqqqqqg....",
	"......GGGGG.....",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WlW......",
	".......WWW......",
]
```

- [ ] **Step 6: 启动游戏看效果**

```bash
./run.sh
```

操作：打开工作台合成门和火把 → 放下来看 → 进入有 slime_torch 的洞穴看 → 试开关门。

期望：工作台顶部有锯子锤子高光、门有把手金属点 + 边框、火把有 3 层火焰、史莱姆灯有发光球身。

- [ ] **Step 7: Commit**

```bash
git add scripts/art/blocks_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "$(cat <<'EOF'
art(blocks): 家具 4 方块层次升级 (工作台/门/火把/史莱姆灯)

工作台加锯子锤子金属高光, 门加把手 + 边框, 火把 3 层火焰 +
暗红外焰, 史莱姆灯加极亮高光球.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 收尾

- [ ] **Final check: 跑全部测试**

```bash
godot --headless --path . -s addons/gut/gut_cmdln.gd -gexit 2>&1 | tail -30
```

期望：失败数 = 之前基线，新加的测试都 PASS。

- [ ] **Final check: 启动游戏走一遍主要场景**

```bash
./run.sh
```

操作：
1. 进入新世界
2. 看草地/泥土/沙子（地表）
3. 砍一棵树（log/leaves + axe）
4. 用木板和工作台合成（看 workbench）
5. 挖到石头层（stone）
6. 挖到深石层（deep_stone）+ 用铁镐挖铁矿（iron_pickaxe）
7. 合成火把/门，放下来看
8. 打史莱姆（看挥剑：方向、月牙、工具旋转）

期望：每个场景的方块和工具都符合 spec 描述。

---

## 风险提示给执行者

1. **像素图字符必须存在于 PALETTE**：`grid_to_image` 在字符缺失时会跳过但不报错（结果是透明）。如果某个方块看起来缺一块，先 grep 像素图里的字符是否都在 PALETTE。
2. **PALETTE 加新字符时不能用 `.`**（已被透明色占用）。本计划用的字符（n e E F f v V x i I a A L l y s d r b B w p P g G k c C h H r R t T o O Q q）都已检查过。
3. **like-character 冲突**：注意 grass 用 `a`、leaves 也用 `a`。每个方块独立 PALETTE，所以不冲突，但跨调色板手动复制像素时要换字符。
4. **GUT 测试需先建 class_name 索引**：如果出现 "class not found" 错误，跑：
   ```bash
   godot --headless --editor --quit
   ```
   一次再跑测试。
5. **关于 `_DOOR` 取 `_DOOR_CLOSED`**：现有 `_TEXTURE_ROWS` 字典里 `BlocksArt.DOOR` 应指向 `_DOOR_CLOSED`。任务里只替换 `_DOOR_CLOSED` 和 `_DOOR_OPEN`，不动外面的映射。

---

## 完成定义 (Definition of Done)

- 全部 11 个任务都 commit 了（git log 看应该有 11 个 commit + 之前 spec 的 1 个）
- `godot --headless ... -gexit` 跑测试不增加失败数
- `./run.sh` 启动游戏不崩；剑/镐/斧/方块视觉都符合 spec
- 设计稿在 `docs/superpowers/specs/2026-05-23-tools-and-textures-design.md` 不动
- 计划在 `docs/superpowers/plans/2026-05-23-tools-and-textures.md` 不动
