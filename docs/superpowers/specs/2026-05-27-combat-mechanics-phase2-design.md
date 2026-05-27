# 战斗机制阶段 2 战斗反应 设计稿

**日期**：2026-05-27
**范围**：击退（双向）+ 无敌帧（玩家 0.6s / 怪 0.2s）+ 玩家受伤闪红 sprite
**前置**：阶段 1（[2026-05-27-combat-mechanics-design.md](./2026-05-27-combat-mechanics-design.md)）已完成

---

## 1. 目标

让命中"有反应、有反馈"：被打中的不只是数字往下走，还要被推开、看得见血红一闪。同时玩家被一堆史莱姆围住不会瞬间被秒。

非目标：
- 不重写 AI（怪 AI 仍按 phase 1 的方式跑，只是受击时多了"停下来被推一下"的状态）
- 不加 dodge / 闪避（用 i-frame 自动处理多次接触）
- 不动伤害数值（damage 计算保持阶段 1）
- 阶段 3（auto-swing + 暴击）不覆盖

---

## 2. 现状盘点

| 实体 | i-frame | 击退 |
|---|---|---|
| 玩家 (`player_health.gd`) | ✅ 0.5s（`IFRAMES_SEC`），有 `is_invulnerable()` 早返回 | ❌ 完全没有，take_damage 只扣血 |
| 史莱姆 (`slime.gd`) | ❌ 无，多次扣血同帧能叠加 | ⚠️ 简版：水平 90px/s + y -80, 硬编码 |
| 僵尸 (`zombie.gd`) | ❌ 同上 | ⚠️ 水平 80 / y -100 |
| 动物 (`animal_base.gd`) | ❌ 同上 | ⚠️ 水平 120 / y -100 |

三个怪文件都已有 `_hit_flash`（**视觉闪红 0.15s**），但跟 i-frame 是两件事，不能复用：闪红只控 sprite.modulate，不阻挡再次扣血。

---

## 3. 改动概览

| ID | 改动 | 文件 |
|---|---|---|
| K1 | 击退强度按攻击者 tier 缩放，扩展 `take_damage` 加 `knockback: float = 0.0` 参数 | `player_action.gd`、`slime.gd`、`zombie.gd`、`animal_base.gd`、`player_health.gd` |
| K2 | 击退方向用 2D（不只水平） | 同上 4 个 take_damage |
| K3 | 玩家被怪打也被击退（slime/zombie contact damage 加 knockback） | `slime.gd`、`zombie.gd`、`player_health.gd`、`player_controller.gd` |
| I1 | 怪加 `_iframe_t`（独立于 `_hit_flash`），take_damage 早返回 | slime/zombie/animal |
| I2 | 玩家 i-frame 0.5s → 0.6s | `player_health.gd` const |
| I3 | 玩家 i-frame 期间 sprite 闪红（透明度脉动） | `player_health.gd` + 玩家 sprite |

---

## 4. K1 击退强度公式

### 4.1 攻击者 → knockback 强度

| 攻击源 | 强度（px/s 速度） |
|---|---|
| 剑（戳） | 60 + tier × 15 |
| 剑（挥） | 80 + tier × 20 |
| 镐（AoE） | 30 + tier × 8 |
| 史莱姆触碰玩家 | 100（固定）|
| 僵尸触碰玩家 | 130（固定）|
| 水扣血（slime） | 0（不击退）|

`tier` = 1..5。例如：
- 木剑（t1）挥击 = 80 + 20 = 100 px/s
- 银剑（t4）挥击 = 80 + 80 = 160 px/s
- 钻石剑（t5）挥击 = 80 + 100 = 180 px/s

### 4.2 接口扩展

把 `take_damage(amount, source_pos, knockback)` 加第三个参数：

```gdscript
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool
```

`knockback = 0` 表示"不击退"（兼容旧调用，比如水扣血、debug 杀怪）。

---

## 5. K2 击退方向

### 5.1 公式

```gdscript
var dir: Vector2 = (target_pos - source_pos).normalized()
# 加一点向上分量，避免纯水平推 (看起来生硬)
dir.y -= 0.4   # 向上 40%
dir = dir.normalized()
velocity = dir * knockback
```

**为什么加 y - 0.4**：纯水平推容易撞墙，加一点向上让怪能跳过 1 格高的地形。也让画面更"弹"。

### 5.2 边界情况

- `source_pos == Vector2.ZERO`（无来源）→ 不击退（保持现有 if-guard）
- `source_pos == target_pos`（同位置贴脸）→ 无方向 → 向上击退 `Vector2(0, -1) * knockback`

---

## 6. K3 玩家被击退

### 6.1 实施

`player_health.gd.take_damage` 现在只扣血。加：

```gdscript
# 在 _iframe_timer 设置后:
if knockback > 0.0 and source_pos != Vector2.ZERO:
    var player_node: Node = get_parent()
    if player_node is CharacterBody2D:
        var target_pos: Vector2 = (player_node as Node2D).global_position
        var dir: Vector2 = (target_pos - source_pos).normalized()
        dir.y -= 0.4
        dir = dir.normalized()
        (player_node as CharacterBody2D).velocity = dir * knockback
```

不需要单独 signal — 玩家受击直接通过其 `velocity` 字段（CharacterBody2D 标准）推。

### 6.2 slime/zombie 攻击玩家时

slime.gd 攻击玩家路径（`_try_hit_player`）：

```gdscript
hp.take_damage(CONTACT_DAMAGE, global_position, 100.0)  # 加 knockback=100
```

zombie 同理（130）。

---

## 7. I1 怪的 i-frame

### 7.1 加状态字段

每个怪 (`slime.gd` / `zombie.gd` / `animal_base.gd`) 加：

```gdscript
const ENEMY_IFRAME_SEC := 0.2
var _iframe_t: float = 0.0
```

`_physics_process` 顶部递减：

```gdscript
_iframe_t = max(0.0, _iframe_t - delta)
```

`take_damage` 顶部检查：

```gdscript
if _iframe_t > 0.0:
    return false  # 在 i-frame 中, 本次不算
_iframe_t = ENEMY_IFRAME_SEC
```

放在 `if _is_dying or amount <= 0: return false` 之后。

### 7.2 跟 `_hit_flash` 的关系

`_hit_flash` 控视觉（sprite 染红 0.15s），是 UX 反馈。
`_iframe_t` 控逻辑（拒绝再次伤害 0.2s），是规则。

两者**独立维护**，不复用同一个 timer。

---

## 8. I2 + I3 玩家 i-frame 改进

### 8.1 时长 0.5 → 0.6

`player_health.gd:10`：

```gdscript
const IFRAMES_SEC := 0.6   # 0.5 → 0.6
```

### 8.2 闪红视觉

玩家在 i-frame 期间 sprite 透明度脉动（10Hz 闪红）。

实施：`player_health.gd._physics_process` 维护一个 t 变量 + 写 sprite.modulate：

```gdscript
func _physics_process(delta: float) -> void:
    if _iframe_timer > 0.0:
        _iframe_timer = max(0.0, _iframe_timer - delta)
        _update_iframe_flash()
    elif _was_in_iframe:
        _clear_iframe_flash()
        _was_in_iframe = false

var _was_in_iframe: bool = false

func _update_iframe_flash() -> void:
    _was_in_iframe = true
    var player: Node = get_parent()
    var sprite: Node = player.get_node_or_null("Sprite")  # or whatever name
    if sprite == null:
        return
    # 10Hz 方波: 在 (1.0, 0.5, 0.5) 红色 vs 正常间切换
    var t: float = (IFRAMES_SEC - _iframe_timer) * 10.0  # 每 0.1s 翻转
    sprite.modulate = Color(1.6, 0.6, 0.6) if int(t) % 2 == 0 else Color.WHITE


func _clear_iframe_flash() -> void:
    var player: Node = get_parent()
    var sprite: Node = player.get_node_or_null("Sprite")
    if sprite != null:
        sprite.modulate = Color.WHITE
```

> 找正确的 sprite 节点名 — 实施时先 grep `get_node` in player_controller / player_art 看玩家 sprite 的具体路径。

---

## 9. 测试

新文件 `tests/integration/test_combat_phase2.gd`，4 个测试：

| 测试 | 期望 |
|---|---|
| `test_enemy_iframe_blocks_multi_hit` | 拿剑挥 2 次（间隔 < 0.2s）只扣血 1 次（第 2 次在 iframe 中被拒）|
| `test_enemy_knockback_pushes_away` | 拿剑打 slime → slime velocity 沿"远离玩家"方向 |
| `test_player_iframe_blocks_multi_hit` | 玩家被 2 只 slime 同时打，只扣 1 次血 |
| `test_player_knockback_pushes_away` | 玩家被 slime 撞 → 玩家 velocity 沿"远离 slime"方向 |

---

## 10. 实现顺序（写 plan 时参考）

1. **T1**：扩展所有 take_damage 签名加 knockback 参数（兼容旧调用，默认 0）
2. **T2**：怪加 `_iframe_t` + take_damage 早返回 + 测试 multi-hit 被阻
3. **T3**：怪 take_damage 用 2D 方向计算 knockback (替换 signf 水平公式)
4. **T4**：剑/镐攻击调 take_damage 传 knockback 强度 (按公式)
5. **T5**：slime/zombie 攻击玩家传 knockback (100 / 130)
6. **T6**：player_health.take_damage 加 knockback 处理 (设玩家 velocity)
7. **T7**：player_health 加 i-frame 闪红视觉 + 时长 0.6s
8. **T8**：全套测试 + smoke 不破

每步 1 commit。

---

## 11. 风险

| 风险 | 缓解 |
|---|---|
| 击退把怪推到墙里穿模 | 用 `move_and_slide` 后 velocity 自动归零, 不会穿墙 (现有怪都用 move_and_slide) |
| 玩家被击退打断 inventory 操作 | 不会, 击退只改 velocity, 不阻挡按键 |
| i-frame 期间 hit_flash 不显示 → 用户以为没打中 | hit_flash 跟 iframe 独立, 但 iframe 早返回阻止了 hit_flash 触发 — 解决: 在早返回前播 hit_flash, 让玩家知道 "命中但护甲挡了" |
| sprite.modulate 闪红跟受伤红字撞色 | 字是 `Color(1, 0.35, 0.35)` 暗红, sprite 闪是 `Color(1.6, 0.6, 0.6)` 亮红 — 视觉区分够 |
| _grant_starter_inventory 改了之后影响 test_save_chunks (阶段 1 残留) | 不在本 spec 范围, 单独 issue |
