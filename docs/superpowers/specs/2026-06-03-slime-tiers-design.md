# 史莱姆等级系统设计（颜色 tier + 大小分裂）

- 日期：2026-06-03
- 状态：已确认，待写实现计划
- 范围：只动**普通史莱姆**（`slime.gd` / 史莱姆刷怪 / slime 染色）。**不碰**史莱姆王 Boss（`king_slime.gd`）、王冠、变蓝逻辑 —— 那是另一个窗口的活。

## 一句话

给普通史莱姆加两个维度：**颜色 = 强弱（按深度刷）** + **大小 = 分裂**（大史莱姆打死裂成同色小史莱姆）。越深越强，打爆一只大的总收获多。

## 现状（已查）

- `slime.gd`：`BASE_MAX_HEALTH=25`、`CONTACT_DAMAGE=6`、跳着追玩家、`_die()` 掉 1-2 个 `slime_jelly`、`queue_free`。无颜色/大小概念，无 `setup()`。
- 染色机制：史莱姆/王都用 `sprite.modulate` 染色（王满血染 `Color(0.7,0.8,1.1)` 亮蓝；受击闪白/红后恢复）。**用 modulate 染颜色 tier 是现成机制**，不用重画 pattern。
- 美术：`slime_art.gd` 基色蓝（PALETTE g=Color8(70,130,205)）。**不重画 pattern**，只在实例上 modulate 染色。
- 刷怪：`world.gd` 白天地表刷蓝史莱姆（`_try_spawn_slime` → `_spawn_surface_creature`，`MAX_SLIMES=4`）。**目前只地表刷**；地下夜里刷的是僵尸/蜘蛛/恶魔眼。地狱 `y_tile >= 220`（`HELL_DEPTH`）刷地狱怪。
- 掉落物 `slime_jelly` 已存在（`item_db`），**不需要新物品**。

---

## 设计

### 1. 颜色 tier（4 档，`color_tier` 0-3）

实例上 `sprite.modulate` 染色（蓝是原色不染；绿/红/紫染色）。各 tier 给 HP/伤害/掉落乘数（基准 = 现在的 HP25/伤6）：

| tier | 颜色 | modulate（近似, 实现时调） | HP×  | 伤害× | jelly/只 |
|---|---|---|---|---|---|
| 0 | 🟢 绿 | `Color(0.55, 1.25, 0.55)` | 0.6 | 0.7 | 1 |
| 1 | 🔵 蓝 | `Color.WHITE`（原色） | 1.0 | 1.0 | 1 |
| 2 | 🔴 红 | `Color(1.5, 0.55, 0.55)` | 1.8 | 1.5 | 2 |
| 3 | 🟣 紫 | `Color(1.2, 0.6, 1.5)` | 2.8 | 2.2 | 3 |

> modulate 是乘色，从蓝底乘出来的绿/紫可能偏闷 —— 实现阶段先试 modulate，**太丑就退而用 slime_art 加 tinted palette**（但优先 modulate，少碰 slime_art = 少跟那个窗口撞）。具体 tint 值实现时调到好看。

**受击闪光要恢复到 tier 染色**（不是恢复白色）—— 跟 king_slime 一样：存 tier tint，闪白/红后 `modulate = tier_tint`。

### 2. 大小（3 档，`size` 0-2）

| size | 名 | sprite scale | HP× | 伤害× | 死亡 |
|---|---|---|---|---|---|
| 2 | 大 | 1.5 | 1.5 | 1.2 | **分裂成 2 只中**（同色 size=1） |
| 1 | 中 | 1.0 | 1.0 | 1.0 | **分裂成 2 只小**（同色 size=0） |
| 0 | 小 | 0.65 | 0.5 | 0.8 | 不分裂, 正常死 |

**最终属性** = 基准(HP25/伤6) × color_mult × size_mult，`_ready`/`setup` 里算。

### 3. 颜色 × 大小组合

一只史莱姆有 `color_tier` + `size` 两个值，由 `setup(color_tier, size)` 设。`setup` 设 modulate(tier) + scale(size) + max_health/contact_damage(两个乘数相乘)。spawn 时 / 分裂时调。

### 4. 分裂（`_die`）

`_die()` 里：先掉 jelly，**若 `size > 0`**：在死亡点附近 spawn **2 只 SlimeScene**，各 `setup(color_tier, size-1)`，给一点随机水平速度散开（像泰拉瑞亚炸开）。再 `queue_free`。

> 联机：分裂出的小史莱姆走现有 host 权威 spawn 路径（跟王召小兵 `_spawn_minions` 同款，host spawn）。client 端不自己分裂（`has_meta("is_remote")` 跳过）。

### 5. 刷怪（按深度定颜色）

- **地表（白天, 现有 `_try_spawn_slime`）**：颜色 **70% 绿 / 30% 蓝**；大小随机偏大（多出大/中，给分裂乐趣，如 40% 大 / 40% 中 / 20% 小）。
- **新增 地下刷史莱姆**（按玩家深度 `py_tile` 定颜色）：
  - 浅地下（`py_tile` 30–100）：蓝
  - 深地下（100–180）：红
  - 极深（180–220, 接近地狱）：紫
  - 地狱（≥220）：**不刷史莱姆**（地狱归地狱怪）
- 地下刷复用地表 `_spawn_surface_creature` 的"玩家附近找地"逻辑，加深度→颜色映射 + 上限（跟夜怪共享或独立小上限，防刷爆）。

### 6. 掉落

每只死了掉 `slime_jelly`（数量按颜色 tier，见上表）。分裂出的小史莱姆也各自掉 → 清完一只大的总收获 ≈ 1 大 + 2 中 + 4 小 各自的 jelly（打 7 只的奖励）。数量实现时可微调防过多。

---

## 不做（YAGNI）

- 不动史莱姆王 Boss / 王冠 / 变蓝（别的窗口的活）。
- 不加新掉落物（只用现成 slime_jelly）；稀有掉落（如按颜色掉别的）以后再说。
- 不重画 slime pattern（只 modulate 染色）。
- 不做无限分裂（最多 大→中→小 两层）。

## 架构 / 单元边界

- **`slime.gd`**：加 `setup(color_tier, size)`（设 modulate/scale/stats）+ tier-tint 受击恢复 + `_die` 分裂逻辑。一个文件内自洽。
- **史莱姆刷怪（`world.gd`）**：地表 70/30 + 大小；新增地下按深度刷。
- **染色**：纯实例 `sprite.modulate`，不碰 slime_art pattern。
- **掉落**：复用现有 `_spawn_drop("slime_jelly")`。

## 测试（GUT，无 GUI 全靠测试）

- `setup(tier, size)`：modulate / scale / max_health / contact_damage 按 tier+size 正确（绿弱、紫强、大血多）。
- 分裂：大史莱姆 `take_damage` 致死 → 场上多出 2 只同色中史莱姆；小史莱姆死 → 不分裂。
- 深度→颜色：给定 py_tile，刷怪选的颜色对（地表绿/蓝、深处红、极深紫；地狱不刷）。
- 掉落：死了掉 slime_jelly。

## 执行约定

- 在 `sky-island` 隔间分支做，小步 TDD，每任务报告 + commit + 累计测试数。
- 染色/刷怪改动若碰到 slime_art / 刷怪公共函数，留意别跟改"剑/王"的窗口撞（merge 前 `git merge-tree` 干跑）。
