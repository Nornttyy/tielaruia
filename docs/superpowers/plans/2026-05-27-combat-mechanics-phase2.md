# 战斗机制阶段 2 战斗反应 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans

**Goal:** 让命中有反应：怪 / 玩家被打都会被推开，玩家受伤后 0.6s 内无敌+闪红，怪 0.2s 内不会被同一波多重伤害叠加。

**Architecture:** 扩展所有 `take_damage(amount, source_pos, knockback)` 加第三个参数（默认 0 兼容旧调）。怪加独立 `_iframe_t` 字段（跟 `_hit_flash` 视觉分离），take_damage 早返回。击退方向用 2D + 向上 0.4 分量，强度按工具 tier 缩放。

**Tech Stack:** Godot 4.3 + GDScript, GUT integration tests

参考 spec: `docs/superpowers/specs/2026-05-27-combat-mechanics-phase2-design.md`

---

## File Structure

**修改的文件**：
- `scripts/player/player_action.gd` — `_thrust_sword` / `_sweep_sword` / `_pickaxe_attack` 调 take_damage 传 knockback 强度
- `scripts/player/player_health.gd` — 加 knockback 参数 + 处理 + i-frame 0.6s + 闪红视觉
- `scripts/entities/slime.gd` — take_damage 加 _iframe_t + 2D 击退方向; _try_hit_player 传 knockback 100
- `scripts/entities/zombie.gd` — 同上; contact damage 传 knockback 130
- `scripts/entities/animal_base.gd` — take_damage 加 _iframe_t + 2D 击退 (动物不主动攻击，所以不传 knockback 给玩家)

**新建**：
- `tests/integration/test_combat_phase2.gd` — 4 个测试

---

## Task 1: 扩展 take_damage 签名加 knockback 参数

**Files:**
- Modify: `scripts/player/player_health.gd:30`
- Modify: `scripts/entities/slime.gd:190`
- Modify: `scripts/entities/zombie.gd:147`
- Modify: `scripts/entities/animal_base.gd:177`

加第三个参数 `knockback: float = 0.0`，先不用，下一步用。

- [ ] **Step 1: 看签名现状**

Run: `grep -n "func take_damage" scripts/player/player_health.gd scripts/entities/slime.gd scripts/entities/zombie.gd scripts/entities/animal_base.gd`

- [ ] **Step 2: 改 4 个签名**

把每个 `func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> bool` 改为：
```gdscript
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool
```

- [ ] **Step 3: 跑 integration test 确保签名兼容**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t1.txt 2>&1; grep "Totals\|Failing\|Passing" /tmp/p2t1.txt | tail -5`
Expected: 67 passing, 0 failing（旧调用没传第三个参数，走默认 0）

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player_health.gd scripts/entities/slime.gd scripts/entities/zombie.gd scripts/entities/animal_base.gd
git commit -m "feat(combat): T1 扩展 take_damage 加 knockback 参数 (默认 0 兼容旧调)"
```

---

## Task 2: 怪加 _iframe_t，take_damage 早返回

**Files:**
- Modify: `scripts/entities/slime.gd`, `scripts/entities/zombie.gd`, `scripts/entities/animal_base.gd`

- [ ] **Step 1: 写测试 — 连击 2 次只 1 次扣血**

新建 `tests/integration/test_combat_phase2.gd`：

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const SlimeScene = preload("res://scenes/entities/slime.tscn")


func _setup_game() -> Dictionary:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var world: Node2D = main.get_node("World")
	var player: Node2D = world.get_player()
	return {
		"main": main,
		"world": world,
		"player": player,
		"action": player.get_node("PlayerAction"),
		"inv": player.get_node("PlayerInventory"),
	}


func _equip_tool(ctx: Dictionary, item_id: String) -> void:
	var inv: Node = ctx["inv"]
	inv.pickup(item_id, 1)
	for i in inv.inventory.slots.size():
		var s = inv.inventory.slots[i]
		if s != null and s.item_id == item_id:
			inv.set_hotbar_selection(i)
			return


func _spawn_slime_near(ctx: Dictionary, offset: Vector2) -> Node2D:
	var slime = SlimeScene.instantiate()
	ctx["world"].add_child(slime)
	slime.global_position = ctx["player"].global_position + offset
	return slime


# T2: 0.1s 内连续 take_damage(5) 两次, 只扣血 1 次
func test_enemy_iframe_blocks_multi_hit() -> void:
	var ctx: Dictionary = await _setup_game()
	var slime = _spawn_slime_near(ctx, Vector2(24, 0))
	var hp0 = slime.current_health
	slime.take_damage(5, ctx["player"].global_position)
	# 立刻再打一次 - 应该被 iframe 拒
	var ok2: bool = slime.take_damage(5, ctx["player"].global_position)
	assert_eq(slime.current_health, hp0 - 5, "iframe 内的第 2 次伤害不应扣血")
	assert_false(ok2, "iframe 期间 take_damage 应返回 false")
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t2a.txt 2>&1; grep "test_enemy_iframe\|Failed\|Totals\|Passing" /tmp/p2t2a.txt | tail -8`
Expected: 测试失败（第 2 次扣血了，因为还没加 iframe）

- [ ] **Step 3: 实现 slime / zombie / animal_base 的 iframe**

每个文件加常量 + 字段 + 早返回 + _physics_process 递减。

`scripts/entities/slime.gd` — 加在已有 `_hit_flash` 旁：

```gdscript
const ENEMY_IFRAME_SEC := 0.2
var _iframe_t: float = 0.0
```

`_physics_process` 顶部加（找已有 `_hit_flash -= delta` 那段）：

```gdscript
_iframe_t = max(0.0, _iframe_t - delta)
```

`take_damage` 在 `if _is_dying or amount <= 0: return false` 之后加：

```gdscript
if _iframe_t > 0.0:
    return false
_iframe_t = ENEMY_IFRAME_SEC
```

同样改 `zombie.gd` 和 `animal_base.gd`。

- [ ] **Step 4: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t2b.txt 2>&1; grep "test_enemy_iframe\|Failed\|Totals\|Passing" /tmp/p2t2b.txt | tail -8`

- [ ] **Step 5: Commit**

```bash
git add scripts/entities/slime.gd scripts/entities/zombie.gd scripts/entities/animal_base.gd tests/integration/test_combat_phase2.gd
git commit -m "feat(combat): T2 怪加 _iframe_t (0.2s) 防多次同帧扣血"
```

---

## Task 3: 怪的击退方向改 2D + 向上分量

**Files:**
- Modify: `scripts/entities/slime.gd`, `scripts/entities/zombie.gd`, `scripts/entities/animal_base.gd`

把现有水平 `signf(dx)` 替换为 2D 方向 + y -= 0.4 分量；强度从硬编码改用 `knockback` 参数。

- [ ] **Step 1: 写测试 — slime 被打后 velocity 沿远离玩家方向**

加到 `test_combat_phase2.gd`：

```gdscript
func test_enemy_knockback_pushes_away() -> void:
	var ctx: Dictionary = await _setup_game()
	# slime 在玩家右侧, 被打后应被推向更右 (vx > 0)
	var slime = _spawn_slime_near(ctx, Vector2(24, 0))
	var player_pos: Vector2 = ctx["player"].global_position
	# 用 knockback=100 直接调 take_damage 模拟
	slime.take_damage(5, player_pos, 100.0)
	# 预期: vel.x > 0 (远离左侧玩家), vel.y < 0 (向上 0.4 分量)
	assert_gt(slime.velocity.x, 0.0, "slime 应被向右推")
	assert_lt(slime.velocity.y, 0.0, "slime 应被向上推 (y 分量)")
```

- [ ] **Step 2: 跑测试 FAIL or 偶然 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t3a.txt 2>&1; grep "test_enemy_knockback\|Failed\|Totals" /tmp/p2t3a.txt | tail -8`

如果现有 `velocity.x = kb_dir * 90; velocity.y = -80` 已经满足 x>0, y<0，可能 PASS。但**强度仍是 90 不是 100**，下面 step 3 改成用参数。

- [ ] **Step 3: 替换 slime 的击退公式**

在 `scripts/entities/slime.gd:200` 附近找现有的：
```gdscript
if source_pos != Vector2.ZERO:
    var dx: float = global_position.x - source_pos.x
    var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
    velocity.x = kb_dir * 90.0
    velocity.y = -80.0
    _hop_timer = 0.5
```

替换为：
```gdscript
# 2D 方向击退 + 向上 0.4 分量; 强度按 knockback 参数 (无传入 → 不推)
if knockback > 0.0 and source_pos != Vector2.ZERO:
    var to_self: Vector2 = global_position - source_pos
    var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
    dir.y -= 0.4
    dir = dir.normalized()
    velocity = dir * knockback
    _hop_timer = 0.5
```

注意：**`knockback` 是参数名，由 take_damage 签名传入**（T1 加的）。如果没传 → knockback=0 → 不击退。

- [ ] **Step 4: 同样改 zombie.gd 和 animal_base.gd**

`zombie.gd:154-158`：
```gdscript
if source_pos != Vector2.ZERO:
    var dx: float = global_position.x - source_pos.x
    var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
    velocity.x = kb_dir * 80.0
    velocity.y = -100.0
```

替换为：
```gdscript
if knockback > 0.0 and source_pos != Vector2.ZERO:
    var to_self: Vector2 = global_position - source_pos
    var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
    dir.y -= 0.4
    dir = dir.normalized()
    velocity = dir * knockback
```

`animal_base.gd:188-192` 同模式（移除旧硬编码 120/-100，用参数）。

- [ ] **Step 5: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t3b.txt 2>&1; grep "test_enemy_knockback\|Failed\|Totals" /tmp/p2t3b.txt | tail -8`

预期：现在传 knockback=100 → vel.x ≈ 70.7, vel.y ≈ -70.7（dir = (1, -0.4) 归一化 = (0.928, -0.371)，× 100 = (92.8, -37.1)）。

- [ ] **Step 6: Commit**

```bash
git add scripts/entities/slime.gd scripts/entities/zombie.gd scripts/entities/animal_base.gd tests/integration/test_combat_phase2.gd
git commit -m "feat(combat): T3 怪击退改 2D 方向 + 向上 0.4 分量 + 用 knockback 参数"
```

---

## Task 4: 剑/镐攻击调 take_damage 传 knockback 强度

**Files:**
- Modify: `scripts/player/player_action.gd` (`_thrust_sword` / `_sweep_sword` / `_pickaxe_attack`)

- [ ] **Step 1: 加击退强度公式 helper**

在 player_action.gd 加常量 + 函数：

```gdscript
# 击退强度: 工具 + tier 决定
const KB_THRUST_BASE := 60.0
const KB_THRUST_TIER := 15.0
const KB_SWEEP_BASE := 80.0
const KB_SWEEP_TIER := 20.0
const KB_PICKAXE_BASE := 30.0
const KB_PICKAXE_TIER := 8.0

func _thrust_knockback() -> float:
    var tier: int = _current_tool_tier()
    return KB_THRUST_BASE + KB_THRUST_TIER * float(tier)

func _sweep_knockback() -> float:
    var tier: int = _current_tool_tier()
    return KB_SWEEP_BASE + KB_SWEEP_TIER * float(tier)

func _pickaxe_knockback() -> float:
    var tier: int = _current_tool_tier()
    return KB_PICKAXE_BASE + KB_PICKAXE_TIER * float(tier)
```

放在 `_tool_damage_mult` 旁边。

- [ ] **Step 2: 改 _thrust_sword 调用**

找到现有：
```gdscript
if best != null and best.has_method("take_damage"):
    best.take_damage(damage, player.global_position)
```

改为：
```gdscript
if best != null and best.has_method("take_damage"):
    best.take_damage(damage, player.global_position, _thrust_knockback())
```

- [ ] **Step 3: 改 _sweep_sword 调用**

找到现有：
```gdscript
if target.has_method("take_damage"):
    target.take_damage(damage, player.global_position)
```

改为：
```gdscript
if target.has_method("take_damage"):
    target.take_damage(damage, player.global_position, _sweep_knockback())
```

- [ ] **Step 4: 改 _pickaxe_attack 调用**

同样找 `target.take_damage(damage, origin)` 改为 `target.take_damage(damage, origin, _pickaxe_knockback())`。

- [ ] **Step 5: 跑 phase 1 测试不破**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t4.txt 2>&1; grep "Totals\|Failed" /tmp/p2t4.txt | tail -5`
Expected: 67+ 通过, 仅 phase 1/2 测试可能因为击退导致 slime 飞走影响命中 → 如有失败需调整测试

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_action.gd
git commit -m "feat(combat): T4 剑/镐攻击传 knockback 强度 (按 tier 缩放)"
```

---

## Task 5: slime / zombie 攻击玩家传 knockback

**Files:**
- Modify: `scripts/entities/slime.gd` (`_try_hit_player`), `scripts/entities/zombie.gd` (类似函数)

- [ ] **Step 1: 改 slime contact damage 传 knockback=100**

找到 slime.gd 的 `hp.take_damage(CONTACT_DAMAGE, global_position)`，改为：
```gdscript
hp.take_damage(CONTACT_DAMAGE, global_position, 100.0)
```

- [ ] **Step 2: 改 zombie contact damage 传 knockback=130**

找到 zombie.gd 类似行，加 `, 130.0`。

- [ ] **Step 3: Commit**

```bash
git add scripts/entities/slime.gd scripts/entities/zombie.gd
git commit -m "feat(combat): T5 slime/zombie 撞玩家传 knockback 100/130"
```

---

## Task 6: player_health 加 knockback 处理 + i-frame 0.6s

**Files:**
- Modify: `scripts/player/player_health.gd`

- [ ] **Step 1: 写测试 — 玩家被打后 velocity 沿远离 source 方向**

加到 `test_combat_phase2.gd`：

```gdscript
func test_player_knockback_pushes_away() -> void:
	var ctx: Dictionary = await _setup_game()
	var player: CharacterBody2D = ctx["player"]
	var hp: Node = player.get_node("PlayerHealth")
	# 模拟 source 在玩家左侧 → 应推向右
	var src: Vector2 = player.global_position - Vector2(30, 0)
	hp.take_damage(3, src, 100.0)
	await wait_frames(1)   # 让 take_damage 设的 velocity 生效
	# 预期 vel.x > 0 (远离左侧 source), vel.y < 0 (向上分量)
	assert_gt(player.velocity.x, 0.0, "玩家应被向右推")
	assert_lt(player.velocity.y, 0.0, "玩家应被向上推")


func test_player_iframe_blocks_multi_hit() -> void:
	var ctx: Dictionary = await _setup_game()
	var player: CharacterBody2D = ctx["player"]
	var hp: Node = player.get_node("PlayerHealth")
	var hp0: int = hp.current_health
	hp.take_damage(3, ctx["player"].global_position + Vector2(20, 0))
	var ok2: bool = hp.take_damage(3, ctx["player"].global_position + Vector2(20, 0))
	# i-frame 期间第 2 次伤害应被拒
	assert_eq(hp.current_health, hp0 - 3, "iframe 期间不应再扣血")
	assert_false(ok2)
```

- [ ] **Step 2: 跑测试 FAIL**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t6a.txt 2>&1; grep "test_player_knockback\|test_player_iframe\|Failed\|Totals" /tmp/p2t6a.txt | tail -10`

- [ ] **Step 3: 改 player_health.gd 加 knockback**

修改 `IFRAMES_SEC` 0.5 → 0.6:
```gdscript
const IFRAMES_SEC := 0.6
```

修改 `take_damage` 在 `_iframe_timer = IFRAMES_SEC` 之后加：

```gdscript
# 击退: 沿 (player_pos - source_pos) 方向 + 向上 0.4 分量
if knockback > 0.0 and source_pos != Vector2.ZERO:
    var player_node: Node = get_parent()
    if player_node is CharacterBody2D:
        var target_pos: Vector2 = (player_node as Node2D).global_position
        var to_self: Vector2 = target_pos - source_pos
        var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
        dir.y -= 0.4
        dir = dir.normalized()
        (player_node as CharacterBody2D).velocity = dir * knockback
```

- [ ] **Step 4: 跑测试 PASS**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t6b.txt 2>&1; grep "test_player_knockback\|test_player_iframe\|Totals" /tmp/p2t6b.txt | tail -10`

- [ ] **Step 5: Commit**

```bash
git add scripts/player/player_health.gd tests/integration/test_combat_phase2.gd
git commit -m "feat(combat): T6 玩家 i-frame 0.5→0.6 + take_damage 处理 knockback velocity"
```

---

## Task 7: 玩家 i-frame 闪红视觉

**Files:**
- Modify: `scripts/player/player_health.gd`

- [ ] **Step 1: 找玩家 sprite 节点路径**

Run: `grep -n "AnimatedSprite\|Sprite2D\|sprite\|@onready" scripts/player/player_controller.gd | head -10`

记录正确的 sprite node name（可能是 `Sprite` / `AnimatedSprite2D` / `Sprite2D`），后面 modulate 用。

- [ ] **Step 2: 加闪红逻辑**

修改 `_physics_process`:

```gdscript
var _was_in_iframe: bool = false


func _physics_process(delta: float) -> void:
    if _iframe_timer > 0.0:
        _iframe_timer = max(0.0, _iframe_timer - delta)
        _update_iframe_flash()
    elif _was_in_iframe:
        _clear_iframe_flash()
        _was_in_iframe = false


func _update_iframe_flash() -> void:
    _was_in_iframe = true
    var sprite: Node = _player_sprite()
    if sprite == null:
        return
    # 10Hz 方波: 0.1s 红 / 0.1s 正常
    var t: float = (IFRAMES_SEC - _iframe_timer) * 10.0
    sprite.modulate = Color(1.6, 0.6, 0.6) if int(t) % 2 == 0 else Color.WHITE


func _clear_iframe_flash() -> void:
    var sprite: Node = _player_sprite()
    if sprite != null:
        sprite.modulate = Color.WHITE


func _player_sprite() -> Node:
    var player: Node = get_parent()
    return player.get_node_or_null("AnimatedSprite2D")   # 改成 step 1 找到的正确名
```

- [ ] **Step 3: 跑 smoke 不破**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t7.txt 2>&1; grep "Totals\|Failed" /tmp/p2t7.txt | tail -5`

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player_health.gd
git commit -m "feat(combat): T7 玩家 i-frame 期间 sprite 10Hz 闪红"
```

---

## Task 8: 全套测试 + smoke 验收

- [ ] **Step 1: 跑全套 integration**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit > /tmp/p2t8int.txt 2>&1; grep "Totals\|Failed\|Passing" /tmp/p2t8int.txt | tail -8`

预期：71+ 通过（67 phase 1 + 4 phase 2），0 失败。

- [ ] **Step 2: 跑全套 unit**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit > /tmp/p2t8unit.txt 2>&1; grep "Totals\|Failed\|Passing" /tmp/p2t8unit.txt | tail -8`

预期：跟阶段 1 结尾相同 — 2 个 pre-existing fail (iron_ore + save_chunks)，phase 2 不引入新失败。

- [ ] **Step 3: 报告**

如果都过，给用户：
```
阶段 2 done. 4 个 commit, 4 个新 GUT 测试, 击退 + iframe 全过.
打史莱姆: 史莱姆会被推飞, sprite 抖一下.
被史莱姆撞: 玩家被推走 + 0.6s 红闪 + 无法再被打.
```

---

## Self-Review

**Spec 覆盖检查**：
- K1 击退强度按 tier — T4 ✓
- K2 击退方向 2D — T3 ✓ (怪) + T6 ✓ (玩家)
- K3 玩家被怪击退 — T5 ✓ (传) + T6 ✓ (收)
- I1 怪 iframe — T2 ✓
- I2 玩家 iframe 0.6 — T6 ✓
- I3 玩家闪红 — T7 ✓

**Placeholder**：每步都有具体代码块和 grep / commit 命令。

**类型一致**：`knockback: float = 0.0` 在 4 个 take_damage 都同名同默认值。
