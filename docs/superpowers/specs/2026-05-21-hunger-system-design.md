# 饱食度系统 — 设计文档

**Date:** 2026-05-21
**Milestone:** Demo (M1) 增量
**Status:** Approved by user (pending spec review)

## 1. 目标

给玩家加一条"鸡腿条"：随时间被动衰减；过低时给攻击 Debuff；高位时缓慢回 HP；通过吃食物补充。整体偏 Minecraft 式但更轻量——**饿不死**，最差是攻击 -20%。

**为什么现在做：** Demo 已经有 HP/受伤/合成/物品循环，但**受伤后没法回 HP**（`heal()` 函数从未被调用，只有死亡复活会满血）。本 feature 同时引入"饱食 > 80% 缓慢自动回 HP"作为唯一的非死亡回血路径，把现有 `heal()` 接上。

## 2. 范围

**In:**
- `PlayerHunger` 节点（与 `PlayerHealth` 对称）
- HUD 鸡腿条（红心下方，10 颗）
- 2 种食物：`slime_jelly`（史莱姆 100% 掉，原现有 `slime_ball` 改名）、`apple`（leaves 5% 掉）
- 右键长按 1s 进食
- 饱食 < 30% → 攻击 ×0.8、鸡腿条抖动
- 饱食 ≥ 80% → 每 5s 自动 +1 HP
- 存档持久化 + 死亡复活时满鸡腿

**Out (推迟):**
- 烹饪系统 / 烤架 tile
- 床、药品、护甲（其他回血路径）
- 多档 Debuff、Buff 图标
- 受伤/挖矿等行为额外消耗饱食度
- 食物特殊效果（中毒、buff）

## 3. 数据模型

### `scripts/player/player_hunger.gd`（新文件）

```gdscript
extends Node

signal hunger_changed(current: int, maximum: int)

const MAX := 100
const DEPLETE_PER_SEC := 100.0 / (10.0 * 60.0)  # ≈ 0.1667，10 分钟掉满
const HUNGRY_THRESHOLD := 30                     # < 30 → 攻击 debuff + 抖动
const HEAL_THRESHOLD := 80                       # ≥ 80 → 自动回 HP
const HEAL_INTERVAL_SEC := 5.0
const HEAL_AMOUNT := 1
const HUNGRY_ATK_MULT := 0.8

var current: float = float(MAX)
var _heal_timer: float = 0.0
var _last_emit_int: int = MAX                   # 上次发信号时的整数值，跨整数才发

@onready var _health: Node = get_parent().get_node_or_null("PlayerHealth")

func _physics_process(delta: float) -> void:
    current = max(0.0, current - DEPLETE_PER_SEC * delta)
    _tick_heal(delta)
    _maybe_emit()

func consume(amount: int) -> void:
    if amount <= 0:
        return
    current = min(float(MAX), current + float(amount))
    _maybe_emit()

func refill_full() -> void:
    current = float(MAX)
    _heal_timer = 0.0
    _maybe_emit()

func get_attack_multiplier() -> float:
    return HUNGRY_ATK_MULT if int(current) < HUNGRY_THRESHOLD else 1.0

func is_hungry() -> bool:
    return int(current) < HUNGRY_THRESHOLD

func _tick_heal(delta: float) -> void:
    if _health == null or not _health.is_alive():
        return
    if int(current) < HEAL_THRESHOLD:
        _heal_timer = 0.0
        return
    if _health.current_health >= _health.MAX_HEALTH:
        _heal_timer = 0.0
        return
    _heal_timer += delta
    if _heal_timer >= HEAL_INTERVAL_SEC:
        _heal_timer -= HEAL_INTERVAL_SEC
        _health.heal(HEAL_AMOUNT)

func _maybe_emit() -> void:
    var cur_i := int(current)
    if cur_i != _last_emit_int:
        _last_emit_int = cur_i
        hunger_changed.emit(cur_i, MAX)

func emit_state() -> void:
    # 公共方法：加载存档或 HUD 绑定时强制同步一次
    _last_emit_int = -1
    _maybe_emit()
```

**设计要点：**
- `current` 用 float 累计避免小 delta 被截断；HUD 用 int。
- 信号只在跨整数边界时 emit，减少 HUD 重绘。
- 回血只在 Hunger 一侧调 `PlayerHealth.heal()`，Health 不知道 Hunger 存在（保持单向依赖）。

## 4. 进食交互

**位置：** `scripts/player/player_action.gd`（项目里右键放置方块的入口）。

**状态机（每帧）：**

```
idle ─(右键按下 + 当前 hotbar = 食物 + current < MAX)→ eating
eating ─(右键松开 / 切换 hotbar / 玩家死亡)→ idle (eat_t 清零)
eating ─(eat_t >= 1.0)→ 触发 + eat_t 清零（保持 eating，连续按可连吃）
```

**触发动作：**
1. `PlayerHunger.consume(food_fill)`
2. `PlayerInventory` 当前格子扣 1 个
3. 若扣后为 0 且仍按住右键，退出 eating（无物品可吃）

**冲突隔离：** 食物的 `placeable_tile_id == -1`，所以走原代码路径**不会触发放置**，天然互斥。

**视觉反馈：** 进食中复用 `floating_prompt.gd` 在玩家头顶显示"吃 …"，松开消失。

## 5. ItemDB 扩展

**`scripts/items/item_db.gd`：**

```gdscript
# 新增字段：food_fill (int, 0 表示非食物)
"slime_jelly": {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 40},
"apple":       {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 64, "food_fill": 25},
```

**新增函数：**

```gdscript
func is_food(item_id: String) -> bool:
    var def = get_def(item_id)
    return def != null and def.get("food_fill", 0) > 0

func food_fill(item_id: String) -> int:
    var def = get_def(item_id)
    return 0 if def == null else def.get("food_fill", 0)
```

**`slime_ball` → `slime_jelly` 重命名：**
- `item_db.gd` 里删除 `slime_ball` 条目
- `scripts/entities/slime.gd` 掉落字符串 `"slime_ball"` → `"slime_jelly"`
- 任何其它 grep 出来的 `slime_ball` 字符串全替换（合成配方目前不含它）

**`tile_data.gd` apple 掉落：**

leaves 三种 tile（`LEAVES`、`LEAVES_PINE`、`LEAVES_AUTUMN`）的 drops 表里加 5% 概率掉 1 个 `apple`。具体实现看 `tile_data.gd` 现有的 drops 结构（实现阶段对齐）。

## 6. 攻击 Debuff 接线

在玩家攻击实际计算伤害的地方（`player_action.gd` / `player_controller.gd`，实现阶段定位）：

```gdscript
var base_dmg: int = ...                      # 现有伤害计算
var mult: float = hunger.get_attack_multiplier()
var final_dmg: int = max(1, int(round(base_dmg * mult)))
```

`max(1, ...)` 保底：饿坏时 1 伤害的工具不能被四舍五入到 0。

**只动攻击伤害，不动挖矿速度/移动速度。** 与"单档轻度 Debuff"一致。

## 7. HUD

### `scripts/ui/hunger_hud.gd`（新文件）

镜像 `health_hud.gd` 的结构：
- 常量与红心一致：`HEART_SIZE=10`、`HEART_SCALE=2`、`HEART_SPACING=2`、`PAD=8`
- 10 颗鸡腿，每颗 10 点 = 满/半/空三态
- `bind(hunger_node)` 监听 `hunger_changed`
- **位置：** 锚定在红心**正下方**（hud.tscn 调整 `HungerHUD` 的 anchor/offset）
- **抖动：** 当 `cur < HUNGRY_THRESHOLD` 时，整条左右轻微偏移（每 0.5s 切换 ±1px）。实现：内部 `_shake_timer` + `_shake_offset`，`_draw` 时 x 加偏移。`cur ≥ 30` 时清零。

### `scripts/ui/hud.gd` 改动

`bind_player` 函数加 4 行：

```gdscript
var hg: Node = player.get_node_or_null("PlayerHunger")
if hg != null:
    hunger_hud.bind(hg)
```

### `scenes/hud.tscn` 改动

新增 `HungerHUD` 节点，挂 `hunger_hud.gd`，位置在 `HealthHUD` 下方 +4px 间距。

## 8. 美术

**`scripts/art/items_art.gd`：**
- 新增 `slime_jelly` 16×16：绿色果冻方块 + 浅黄高光（区别于原 slime_ball 的蓝紫弹球感）
- 新增 `apple` 16×16：红色主体 + 棕色梗 + 一片小绿叶高光

**`ArtCache` 新增三张鸡腿 10×10：**
- `drumstick_full`：完整鸡腿，棕褐肉身 + 浅黄高光
- `drumstick_half`：左半边
- `drumstick_empty`：灰色轮廓

**纹理风格遵循已有反馈** [[feedback-warm-detailed-textures]]：暖色为主，可识别形状，**不要**随机散点。

## 9. 存档

**`scripts/world/world.gd` 保存/读取段（实现阶段定位行号）：**

```gdscript
# 保存
save_data.hunger = player.get_node("PlayerHunger").current

# 读取
var hg = player.get_node("PlayerHunger")
hg.current = save_data.get("hunger", float(hg.MAX))
hg.emit_state()  # 触发一次 HUD 同步
```

**死亡复活段（world.gd:140 附近 `revive_full()` 调用旁）：**

```gdscript
if hp != null and hp.has_method("revive_full"):
    hp.revive_full()
var hg = player.get_node_or_null("PlayerHunger")
if hg != null:
    hg.refill_full()
```

**初始值：** 新游戏开局 `current = MAX`。

## 10. 测试

### `tests/unit/test_player_hunger.gd`（新文件）

| # | 断言 |
|---|------|
| 1 | 初始 `current == MAX (100)` |
| 2 | 调 `_physics_process(1.0)` 60 次后 current 在 `[89, 91]` 内（1 分钟掉约 10） |
| 3 | `consume(30)` 时 80 + 30 → 100（不溢出）；50 + 30 → 80 |
| 4 | `consume(0)` / `consume(-5)` 时 current 不变 |
| 5 | `get_attack_multiplier()`：current=29 → 0.8，current=30 → 1.0，current=100 → 1.0 |
| 6 | 回血计时器：current=90、HP=10 → 5s 后 HP=11；current=70 → 5s 后 HP 不变 |
| 7 | 回血计时器：HP 已满 → 不触发 heal |
| 8 | `refill_full()` 重置 current 并发 `hunger_changed` 信号 |
| 9 | `hunger_changed` 信号只在跨整数时发 |
| 10 | `is_hungry()`：current=29 → true，current=30 → false |

### `tests/integration/test_eat_food.gd`（新文件）

| # | 断言 |
|---|------|
| 1 | 玩家手拿 slime_jelly + current=50 + 模拟按右键 1.0s → current=90、背包扣 1 |
| 2 | 按右键 0.5s 后松开 → current 不变、物品不扣 |
| 3 | current=100 时按右键 1.0s → 不触发、物品不扣 |
| 4 | 手拿 slime_jelly 按右键 1.0s → 不会在世界放置 tile（确认与放置互斥） |

合计 14 个新断言；不动现有 `test_craft_*` / `test_player_health` 等。

## 11. 验收清单

- [ ] 新游戏开局鸡腿满；10 分钟后掉光
- [ ] 鸡腿 < 3 颗时鸡腿条左右抖动 + 攻击伤害 ×0.8（手工对一次史莱姆验证）
- [ ] 鸡腿 ≥ 8 颗 + 受伤 → HP 每 5s 回 1，回满后停
- [ ] 手拿 slime_jelly/apple 长按右键 1s → 吃掉 + 鸡腿涨
- [ ] 砍 leaves 偶尔掉 apple
- [ ] 杀史莱姆掉 slime_jelly（替代旧 slime_ball）
- [ ] 存档/读档保留鸡腿值；死亡复活满鸡腿
- [ ] 单测 + 集成测试全绿（合计 14 新断言）

## 12. 关联记忆

- [[project-demo-spec]] — Demo (M1) 范围，本 feature 是其增量
- [[feedback-warm-detailed-textures]] — 鸡腿和食物图标的纹理风格约束
- [[feedback-respawn-minecraft]] — 死亡复活时同时满鸡腿（与满血对称）
