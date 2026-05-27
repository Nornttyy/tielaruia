# 战斗机制改造 设计稿

**日期**：2026-05-27
**范围**：把工具从"按 tier 给固定伤害"升级到"工具差异化角色 + 反应反馈 + 输出爽感"的完整战斗系统
**方案**：分 3 阶段，每阶段独立 spec→plan→实现→测试

---

## 1. 目标

让 demo 里"打史莱姆"和"挖矿"从机械动作变成有手感、有策略、有节奏感的战斗循环：

- **工具有性格**：剑专精单体输出，镐是 AoE 清杂兵，斧只砍树（完全工具化分工）
- **打击有反馈**：击中要么把怪推走、要么自己挨打不会瞬间被秒
- **输出有爽感**：按住就连挥不用狂点，运气好出暴击

非目标：
- 不改方块种类、不动经济、不加新工具种类
- 不动配方
- 不重写 sprite，沿用现有剑/镐/斧贴图
- 阶段 2 + 3 在本 spec 只列大纲，详细设计本 spec **不覆盖**（避免一锅端）

---

## 2. 三阶段路线

| 阶段 | 包含 | 重点 |
|---|---|---|
| **1（本 spec）— 工具差异化** | 剑戳挥交替 / 镐低伤大范围打怪 / 斧只砍树 / 扫击弧多目标伤害 | 工具有性格 |
| 2 — 战斗反应 | 击退 (knockback) / 无敌帧 (i-frames) | 打击有反馈 |
| 3 — 输出爽感 | 按住连挥 (auto-swing) / 暴击 (crit) | 输出有爽感 |

阶段 2、3 完成阶段 1 验收后再单独写 spec。

---

## 3. 阶段 1 总览：工具差异化

四个改动绑在一个阶段，因为它们**共享同一组测试夹具**（伪玩家 + 多只怪 + 一棵树 + 几块石头），分开做测试代码会重复。

### 改动清单

| ID | 改动 | 涉及文件 |
|---|---|---|
| F1 | 剑：戳 ↔ 挥 交替连击 | `player_action.gd`、`held_item.gd` |
| F2 | 扫击弧伤害（挥击命中弧内多目标） | `player_action.gd` |
| F3 | 镐能攻击：低伤大范围、转圈动画 | `player_action.gd`、`held_item.gd` |
| F4 | 斧只能砍树：打怪零伤害 | `player_action.gd` |

### 数据字段新增

`scripts/items/item_db.gd` 的 ItemDef 加一个字段：

```gdscript
"damage_mult": 1.0   # 攻击倍率, 不填默认 0.0 (不能攻击)
```

填充：

| tool_kind | damage_mult |
|---|---|
| sword | 1.0 |
| pickaxe | 0.5 |
| axe | 0.0 |
| (其他) | 0.0 |

为什么不直接用 `tool_kind`：未来想加"匕首/双手剑/十字镐"时不用每个判定都改 if-else。`damage_mult == 0` 直接表示"打不出伤害"，等于以前的"工具不对"。

---

## 4. F1 — 剑：戳 ↔ 挥 交替连击

### 4.1 概念

- **戳 (thrust)**：直线向前突刺。范围远、伤害 80%、只命中 1 个目标（前方最近的怪）。
- **挥 (swing)**：横向 90° 弧。范围近（=现有 `SWORD_RANGE_PX`）、伤害 100%、命中弧内全部目标（见 F2）。

按 1 击戳、按 2 击挥、按 3 击戳... 交替循环。

冷却切换工具（剑→镐→剑）时**重置为戳**（下一击是戳，不延续上一次状态）。

### 4.2 状态字段

`player_action.gd` 加：

```gdscript
var _attack_combo_step: int = 0   # 0 = 下一击是戳, 1 = 下一击是挥
```

### 4.3 触发流程

`_physics_process` 里现有的"持剑 → `_swing_sword()`" 路径改为：

```gdscript
if _current_tool_kind() == "sword":
    _reset_mining()
    var primary_pressed := ...
    if primary_pressed and _attack_cooldown <= 0.0:
        if _attack_combo_step == 0:
            _thrust_sword()
            _attack_combo_step = 1
        else:
            _sweep_sword()
            _attack_combo_step = 0
```

切换工具时（在 `_current_tool_kind` 变化或 hotbar 改变时）调用：

```gdscript
func _reset_combo() -> void:
    _attack_combo_step = 0
```

通过监听 inventory 的 `hotbar_selection_changed` 信号触发；handler 内**不要 `await`**（参见 [feedback_no_async_signal]）。

### 4.4 数值

| 参数 | 戳 | 挥 |
|---|---|---|
| 冷却 | 0.18s | 0.30s |
| 命中半径 | — | `SWORD_RANGE_PX * 0.7` (现状) |
| 戳长度 | `SWORD_RANGE_PX * 1.2` | — |
| 戳宽度（命中带） | `12 px` | — |
| 伤害倍率 | 0.8 × `damage_mult` × `_sword_damage()` | 1.0 × `damage_mult` × `_sword_damage()` |
| 击中目标数 | 1 (最近) | 弧内全部（见 F2） |

戳的命中判定：从玩家中心沿 mouse 方向画一个 12×`SWORD_RANGE_PX*1.2` 的矩形（用 `to_local + AABB 判定`），找矩形内最近的目标。

### 4.5 动画

`held_item.gd` 加 `play_thrust(target_angle: float)`：

- 工具沿 target_angle 方向**向前位移** `SWORD_RANGE_PX * 0.4` 像素再收回（0.15s 内完成）
- 不旋转（不像挥那样转 90°）
- tween 用 `EASE_OUT_BACK` 让突刺有"啪"的弹性感

挥仍走现有 `play_swing_directional`。

### 4.6 sfx

- 戳：`"thrust"` (新 sfx，短促，0.05s 风声) — 占位先复用 `"swing"`，留 TODO
- 挥：现有 `"swing"` 不动

---

## 5. F2 — 扫击弧多目标伤害

### 5.1 现状

`_swing_sword`（第 643-653 行）：用 `center` + `SWORD_RANGE_PX * 0.7` 半径圆形判定，但循环里**已经命中范围内所有目标**了 — 不是只命中一个。

所以 F2 不是"加多目标"，而是把判定**形状**从圆改成扇形弧（避免后方误伤）。

### 5.2 弧形判定

```gdscript
func _is_in_swing_arc(target_pos: Vector2, origin: Vector2, dir: Vector2) -> bool:
    var to_target := target_pos - origin
    var dist := to_target.length()
    if dist > SWORD_RANGE_PX * 1.0:
        return false
    if dist < 4.0:  # 太近也算命中 (贴脸不漏)
        return true
    var angle_to_target := to_target.angle()
    var angle_dir := dir.angle()
    var diff := wrapf(angle_to_target - angle_dir, -PI, PI)
    return abs(diff) <= deg_to_rad(45.0)  # ±45° = 90° 总弧
```

替换 `center.distance_to(...) <= SWORD_RANGE_PX * 0.7` 那行。

### 5.3 弧角度数值

- 剑挥：90° (±45°)
- 镐攻击：见 F3 (更大)

---

## 6. F3 — 镐能攻击：低伤大范围

### 6.1 模式判定：挖矿 vs 攻击

镐有两种模式，按以下**互斥**优先级（每帧只走其中一条）：

1. **挖矿模式**：鼠标对准的 tile 是可挖方块 → 走现有 `_update_mining`
2. **攻击模式**：1 不成立 且 鼠标位置周围 `SWORD_RANGE_PX * 1.5` 半径内有 slimes/animals → 走 `_pickaxe_attack`
3. **idle**：两个都不成立 → 啥都不做（不播动画、不消耗 cooldown）

> 关键：**触发检测以鼠标位置为圆心**（让玩家通过移动鼠标决定意图），但下面的**伤害判定以玩家位置为圆心**（让镐成为 panic AoE 防身武器，怪贴脸就清场，不需要瞄准）。

### 6.2 动画

`play_swing()`（现有的循环摆 ±75°）已经是"转圈圈"的雏形；改成**全周转 360°**（一次完整旋转 0.4s，EASE_IN_OUT）。

`held_item.gd` 加 `play_pickaxe_attack()`：

```gdscript
func play_pickaxe_attack() -> void:
    if not visible:
        return
    if _tween != null and _tween.is_valid():
        _tween.kill()
    rotation = 0.0
    _tween = create_tween()
    var dir := 1.0 if _facing_right else -1.0
    _tween.tween_property(self, "rotation", deg_to_rad(360.0 * dir), 0.4)
    _tween.tween_callback(func(): rotation = 0.0)
```

挖矿仍走现有 `play_swing()`（摆 75°），两者动画**视觉不同**。

### 6.3 数值

| 参数 | 镐攻击 |
|---|---|
| 冷却 | 0.35s（比剑挥慢一点） |
| 命中判定圆心 | **玩家位置**（不是鼠标） |
| 命中半径 | `SWORD_RANGE_PX * 1.5` |
| 弧角度 | 360°（全方位）|
| 伤害倍率 | `damage_mult = 0.5` × `_sword_damage_for_kind("pickaxe")` |
| 击中目标数 | 范围内全部 |

伤害基础值复用剑的 tier 计算（铜镐打怪 ≈ 铜剑的一半），不引入新公式。

---

## 7. F4 — 斧只能砍树

### 7.1 实现

最小改动：`_thrust_sword` / `_sweep_sword` / `_pickaxe_attack` 里都把伤害公式改成

```gdscript
var damage: int = int(round(_sword_damage() * _tool_damage_mult()))
if damage <= 0:
    return
```

`_tool_damage_mult()` 读 ItemDef 的 `damage_mult` 字段。

由于斧的 `damage_mult = 0.0`，`damage` 算出来是 0，直接 return — 即使动画播放、cooldown 走，伤害不会发生。

砍树仍走 `_update_mining` → `_finish_mine` → `_cascade_chop_tree` 路径，不受影响。

### 7.2 拿着斧子点空 / 点怪

- 斧子是 tool_kind == "axe"，不走 sword 的攻击分支，也不走 pickaxe 的攻击分支
- 所以拿着斧子左键 = 走挖矿分支（`_update_mining`）
- 挖矿分支检查 `required_tool_tier`：非 LOG 的方块需要 pickaxe → 斧挖石头进度归零（现有逻辑已经处理）
- **新增**：斧拿着对空气 / 对怪左键，不应该出现挖矿摆动动画（看起来像在挖空气很奇怪）

修复：`_update_mining` 进 mining 摆动前检查 tool_kind == "axe" 且鼠标 tile 不是 LOG（或不是树底），就早 return 不播动画。

---

## 8. 测试 (GUT integration)

新文件 `tests/integration/test_combat_phase1.gd`，6 个测试：

| 测试 | 期望 |
|---|---|
| `test_sword_combo_alternates` | 连续按 3 次左键，combo_step 序列 = 0→1→0；前 2 击伤害比 = 0.8 |
| `test_thrust_hits_only_nearest` | 戳前方两只 slime（一前一后排成线），只有近的那只扣血 |
| `test_sweep_hits_all_in_arc` | 玩家身前 90° 弧内放 3 只 slime（左 30°、正前、右 30°），挥一刀全扣血 |
| `test_sweep_misses_behind` | 玩家身后放 1 只 slime，挥一刀不扣血 |
| `test_pickaxe_damages_enemies` | 拿铜镐 + 鼠标位置附近（不对方块）有 slime → 攻击模式触发，slime 扣血 = 剑伤害的 50%（向下取整）|
| `test_pickaxe_prefers_mining_over_attack` | 拿铜镐 + 鼠标对准 STONE tile + 旁边有 slime → 走挖矿模式，slime 不扣血 |
| `test_pickaxe_aoe_360` | 玩家四周 8 方向各放 1 只 slime（半径 `SWORD_RANGE_PX * 1.4`），镐攻击一次 8 只全扣血 |
| `test_axe_zero_damage_on_enemies` | 拿铜斧对着 slime 攻击 → slime HP 不变 |
| `test_combo_resets_on_hotbar_switch` | 戳一次（combo_step=1）→ 切到镐再切回剑 → 下一击仍是戳（combo_step=0）|

`test_combat_phase1.gd` 复用 `tests/integration/` 已有的 player + slime spawn helper；如无则在 `tests/integration/helpers/` 加一个 `combat_fixture.gd`。

---

## 9. 用户能感受到的变化

跑 `./run.sh` 后：

1. 拿木剑左键点史莱姆：第 1 下"啪"突刺出去（直线短促），第 2 下"唰"横扫（90° 弧）
2. 一只史莱姆排队过来，挥一刀**全打到**（之前可能漏后面的）
3. 拿铜镐对着史莱姆点：镐子转一圈，附近的史莱姆都扣 1 血（剑铜是 5 伤，镐铜就是 2 伤）
4. 拿斧子点史莱姆：动画转，史莱姆**不扣血**，只能用来砍树
5. 切到镐再切回剑：下一击是戳，不会延续上一次的挥

---

## 10. 不在范围 / 后续工作

- **击退 / 无敌帧**：阶段 2，单独 spec
- **auto-swing / 暴击**：阶段 3，单独 spec
- **弓 / 远程武器**：M3 以后
- **戳的 sfx 独立音效**：本 spec 复用 swing，sfx 资源是阶段 1 完成后的微调

---

## 11. 风险 / 已知问题

| 风险 | 缓解 |
|---|---|
| 镐攻击和挖矿模式切换误判 | F3.1 优先级：方块在鼠标 tile 就挖矿，怪在范围内才攻击；测试 `test_pickaxe_prefers_mining_over_attack` |
| `_attack_combo_step` 切工具不重置 → 玩家拿剑切到镐再切回，下一击是上次的挥 | F1.3 监听 hotbar_selection_changed 信号触发 reset；signal handler 不要 await（[feedback_no_async_signal]）|
| 戳的"前方最近"判定，鼠标偏一点点会让最近的怪不被选中 | 矩形判定带宽 12px 已经比 sprite 宽，鼠标偏 ±6px 仍能命中 |
| 玩家拿斧打怪挥半天没反应，玩家以为 bug | F4.2 早 return 不播动画 + UI 提示「这个工具打不动」(后续做，本 spec 仅停动画)|

---

## 12. 实现顺序建议（写 plan 时参考）

1. F4（斧只砍树）— 1 行 if，最简单，先把"哪些工具不能攻击"的护栏立起来
2. F1.2 + F1.3（combo_step 状态 + 切换）— 不动伤害公式
3. F1.4（thrust 数值 + 矩形判定）
4. F1.5（thrust 动画）
5. F2（弧形判定替换圆）
6. F3.1（镐攻击优先级）
7. F3.2（pickaxe_attack 动画）
8. F3.3（镐伤害公式）
9. 测试一次性写完 8 个

每步 commit，每步跑 `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit`。
