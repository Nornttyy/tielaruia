# 厨房系统设计（料理 · 钓鱼 · 寿司 · Buff）

- 日期：2026-06-01
- 状态：设计已与用户讨论，待用户复核
- 里程碑归属：M2/M3 玩法扩展（农场 → 厨房闭环 + 临时增益）

## 一句话目标

把「种地 / 打猎 / 钓鱼」得到的生材料，在**做饭工作站**做成**料理大餐**：吃了不仅回更多血，还能获得**短时间超能力（buff）**。同时给玩家加一个**自然慢回血**底层机制。

## 背景：现有相关系统（摸排结论）

| 子系统 | 现状 | 关键文件 |
|---|---|---|
| 食物/消耗 | `food_fill` 字段 → 持右键/F 吃 2 秒 → `hp.heal()` → `consume_current(1)`。`mana_refill` 同理回蓝。无 buff、无 use_effect 字段。 | `item_db.gd`（`is_food`/`food_fill`/`is_mana_potion`/`mana_refill`）、`player_action.gd:846 _update_eat_or_place()` |
| 农作物 | 仅小麦（WHEAT_0..3 = tile 66-69）。`world.gd` 每 60s tick、60% 概率升一阶（~5 分钟熟）。WHEAT_3 挖 → 2-4 小麦 + 1-2 种子。**小麦目前没有任何配方用到。** | `world.gd:88 CROP_GROW_INTERVAL/CHANCE`、`tile_data.gd` WHEAT、`player_action.gd:886` 种植 |
| 动物掉落 | 牛/猪/羊/企鹅死掉 `raw_meat`；`animal_base.gd` 的 `drop_table = [[id,weight%,min,max]]`。 | `animal_base.gd:219 _spawn_drop()`、各 `entities/*.gd` |
| 血量 | `player_health.gd`：`MAX_HEALTH`(var, 起始 100, 上限 400)、`current_health`、`heal(amount)`、`take_damage()`（命中后 `_iframe_timer=0.6s`）。`_physics_process` 已有 iframe + 岩浆扣血 tick。**无自然回血。** | `player_health.gd` |
| 法力 | `player_mana.gd`：`_process` 每秒 +5 自动回蓝（regen 累加器范式可借鉴）。 | `player_mana.gd` |
| 移动/挖矿 | 控制器 `SPEED:=105`(const)，移动用局部 `speed_mul`(水里 0.5)；`JUMP_VELOCITY:=-240`。挖矿 `_update_mining(delta)` 累加 `_mining_progress`。 | `player_controller.gd`、`player_action.gd:353` |
| 工作站/合成 | 配方 dict：`id/grid_size/pattern/output_id/output_count/mirror_ok/[rotate_ok]/[requires]`。`requires:"furnace"` 的配方要玩家身边 ±2 有炉子（`_has_furnace_nearby()`，UI 过滤）。现有「生肉→熟肉」配方 `requires:"furnace"`。 | `recipe_db.gd`、`crafting_panel.gd:737-782`、`player_action.gd:324 _has_workbench_nearby()` |
| 发光方块 | 已有 `Tiles.TORCH`（火把）会发光的放置方块，可作锅发光的实现先例。 | `tile_data.gd` TORCH、`minimap_view.gd:50`、`main_menu.gd:198` |
| 占位美术 | 全程序绘制（`scripts/art/*`），无 PNG。新方块/食物图标都程序画，暖色 + 可识别形状。 | `scripts/art/` |

**当前最大空白**：① 无 buff/状态系统；② 无自然回血；③ 无做饭专用工作站；④ 无鱼/钓鱼/切菜；⑤ 小麦没用。

## 全局玩法蓝图（完整愿望清单）

> 用户点子全部保留。下面是终态，分 3 步落地（见末尾路线图）。

### 新工作站 / 工具
- 🍲 **锅（cooking_pot）**：放置方块，**只能叠在炉子（FURNACE）正上方**那格。锅底有火 → **发暖光**。料理配方 `requires:"pot"`，身边 ±2 有锅才解锁。
- 🎣 **鱼竿（fishing_rod）**：工具。对着水右键 → 等待 → 上钩得「鱼」，偶尔得「紫菜」。
- 🔪 **菜板（cutting_board）** + **菜刀（kitchen_knife）**：菜板是放置台，菜刀是工具；二者配合把「鱼」切成「鱼片」（做刺身/寿司）。

### 新材料
- 🐟 鱼（fish）—— 钓鱼获得
- 🍣 鱼片（fish_slice）—— 鱼在菜板上用菜刀切
- 🌿 紫菜（seaweed）—— **水底生长的水草**，游过去砍掉；钓鱼偶尔副获
- 🌾 米（rice）—— 新作物「稻子」（近水种、像小麦那样生长）收获；米可煮成 米饭
- 🍚 米饭（cooked_rice）—— 米在锅里煮

### 料理（锅里做；各有 food_fill，部分带 buff）
| 料理 | 材料 | 回血 | Buff |
|---|---|---|---|
| 🍖 熟肉 cooked_meat | 生肉 ×1 | 50 | 无 |
| 🍞 面包 bread | 小麦 ×3 | 30 | 🏃 跑得快 |
| 🍄 蘑菇汤 mushroom_soup | 蘑菇 ×2 | 30 | ❤️ 慢慢回血 |
| 🥧 苹果派 apple_pie | 苹果 ×2 + 小麦 ×1 | 45 | 🦘 跳得高 |
| 🍢 烤肉串 meat_skewer | 生肉 ×2 + 蘑菇 ×1 | 60 | ⛏️ 挖得快 |
| 🍲 蘑菇炖肉 mushroom_stew | 生肉 ×1 + 蘑菇 ×2 | 65 | ⛏️ 挖得快 |
| 🍯 苹果酱 apple_jam | 苹果 ×3 | 35 | ❤️ 慢慢回血 |
| 🍮 果冻布丁 jelly_pudding | 史莱姆果冻 ×2 + 苹果 ×1 | 40 | 🦘 跳得高 |
| 🐟 烤鱼 grilled_fish | 鱼 ×1 | 45 | 🏃 跑得快 |
| 🍚 米饭 cooked_rice | 米 ×2 | 25 | 无 |
| 🐟 刺身 sashimi | 鱼片 ×2 | 50 | ❤️ 慢慢回血 |
| 🍣 寿司 sushi | 鱼片 ×1 + 紫菜 ×1 + 米饭 ×1 | 70 | 🌟 豪华（跑得快 + 跳得高 同时） |

### 系统
- **Buff 系统**（4 种：跑得快 / 跳得高 / 挖得快 / 慢慢回血）+ 屏幕 buff 图标。
- **自然慢回血**（被打后短时暂停）。
- **锅发光**。

---

## 第 1 步（本 spec 实现范围）：厨房基础 + 超能力

目标：做完即可玩到「叠锅做饭 → 吃料理变强 → 平时慢慢回血」。**不含**鱼/钓鱼/菜板/寿司/刺身/米（落在第 2、3 步）。

### A. 自然慢回血（player_health.gd）

- 新常量：`REGEN_INTERVAL := 2.0`（每 2 秒回一次）、`REGEN_AMOUNT := 1`（回 1 点）、`REGEN_DELAY_AFTER_HIT := 4.0`（被打后 4 秒内不回）。
- 新变量：`_regen_t: float`、`_since_hit_t: float`。
- `take_damage()` 成功扣血时 `_since_hit_t = 0.0`。
- `_physics_process(delta)`：`_since_hit_t += delta`；若 `is_alive()` 且 `current_health < MAX_HEALTH` 且 `_since_hit_t >= REGEN_DELAY_AFTER_HIT`，累加 `_regen_t`，每满 `REGEN_INTERVAL` 调 `heal(REGEN_AMOUNT)`。
- 注意：`heal()` 内不要重置 iframe（现有 `heal` 末尾有 `_iframe_timer = 0.0`，自然回血若复用要避免清掉受击无敌；实现时让自然回血直接改 `current_health` + emit，或给 heal 加一个 `reset_iframe := true` 默认参数，自然回血传 false）。**实现任务需处理此细节。**

### B. Buff 系统（新组件 player_buffs.gd）

新节点 `PlayerBuffs`（挂在 Player 下，与 PlayerHealth/PlayerMana 同级，autoload 不需要）。

- 数据：`_active: Dictionary` = `{ kind:String -> remaining:float }`，外加每 kind 的固定强度（写死在组件常量里，不必每次传）。
- 4 种 kind 常量：
  - `"speed"`：移动倍数 `SPEED_MUL := 1.4`
  - `"jump"`：跳跃倍数 `JUMP_MUL := 1.3`
  - `"mining"`：挖矿倍数 `MINING_MUL := 1.8`
  - `"regen"`：每 `BUFF_REGEN_INTERVAL := 1.0` 秒回 `BUFF_REGEN_AMOUNT := 2`（比自然回血快）
- 公共 API：
  - `apply(kind:String, secs:float) -> void`：设/刷新该 kind 的 `remaining = secs`（同种刷新、不同种叠加），emit `buffs_changed`。
  - `is_active(kind) -> bool`
  - `speed_mul() -> float` / `jump_mul() -> float` / `mining_mul() -> float`：无 buff 返回 1.0。
  - `remaining(kind) -> float`（给 HUD 倒计时）
  - 信号 `buffs_changed`。
- `_process(delta)`：每个 kind `remaining -= delta`，到 0 删除并 emit；`"regen"` 活跃时累加器回血（调 player_health 的自然回血同款路径，不清 iframe）。
- 接线：
  - 控制器移动：`velocity.x = dir * SPEED * speed_mul * _buffs.speed_mul()`（在现有 `speed_mul`(水) 基础上再乘 buff）。
  - 控制器跳跃：起跳 `JUMP_VELOCITY * _buffs.jump_mul()`。
  - `player_action._update_mining`：进度增量 `* _buffs.mining_mul()`。
  - 控制器/动作通过 `get_parent().get_node_or_null("PlayerBuffs")` 拿引用并缓存。

### C. ItemDB 新字段 + 吃料理触发 buff

- food 定义新增可选字段：`"buff_kind": String`、`"buff_secs": float`。无此字段 = 纯回血食物。
- ItemDB 加查询：`food_buff_kind(item_id)`、`food_buff_secs(item_id)`。
- `player_action._update_eat_or_place` 吃完 food 后（`hp.heal(...)` 那行附近）：若该 food 有 buff_kind → `_buffs.apply(kind, secs)`。
- **吃料理的触发条件需放宽**：现有逻辑「血满则不能吃」（`current_health >= MAX_HEALTH` 直接 return）。带 buff 的料理**血满也应能吃**（为了拿 buff）。实现：若 food 有 buff，则即便血满也允许吃（回血部分按上限截断）。

### D. 锅（cooking_pot）工作站 + 发光

- `tile_data.gd`：新 tile `COOKING_POT := 74`（74 为下一个空号，LAVA_L3=73 之后）。属性：`solid=true`、`mineable=true`、镐 tier 1、挖掉掉 `cooking_pot` 物品。**务必同步 `tileset_builder.gd` 的 tile_ids 数组**（否则不显示也不报错）。
- `item_db.gd`：`"cooking_pot"` = `{placeable_tile_id: Tiles.COOKING_POT, tool_kind:"", tool_tier:0, max_stack:64}`。
- 合成配方（在炉子上炼，需 iron）：`cooking_pot` = 例如 3 iron_ingot 弧形（U 字底），`requires:"furnace"`。
- **放置约束**：`player_action.try_place()` 特判 `cooking_pot` —— 仅当目标格下方那格 `== Tiles.FURNACE` 才允许放（否则给个失败反馈/不放）。
- **做饭检测**：新增 `_has_cooking_pot_nearby()`（仿 `_has_furnace_nearby()`，找 ±2 的 `COOKING_POT`）；料理配方 `requires:"pot"`，UI 过滤同 furnace 范式（`crafting_panel.gd`）。
- **发光**：照 `Tiles.TORCH` 的发光先例，锅放置时附暖色 `PointLight2D`（橙黄、半径适中），挖掉时清除。实现任务需定位火把发光的具体挂法并复用。
- 美术：`scripts/art` 程序画——铁锅黑灰圆肚 + 锅底橙黄火苗，暖色、可识别。

### E. 8 道基础料理（recipe_db + item_db + 中文名 + 美术）

实现 8 道（材料/回血/buff 见上表，均只用现有材料 生肉/小麦/苹果/蘑菇/史莱姆果冻）：

1. 🍖 熟肉 cooked_meat — 生肉 ×1 — 回 50 — 无 buff
2. 🍞 面包 bread — 小麦 ×3 — 回 30 — 🏃 跑得快
3. 🍄 蘑菇汤 mushroom_soup — 蘑菇 ×2 — 回 30 — ❤️ 慢慢回血
4. 🥧 苹果派 apple_pie — 苹果 ×2 + 小麦 ×1 — 回 45 — 🦘 跳得高
5. 🍢 烤肉串 meat_skewer — 生肉 ×2 + 蘑菇 ×1 — 回 60 — ⛏️ 挖得快
6. 🍲 蘑菇炖肉 mushroom_stew — 生肉 ×1 + 蘑菇 ×2 — 回 65 — ⛏️ 挖得快
7. 🍯 苹果酱 apple_jam — 苹果 ×3 — 回 35 — ❤️ 慢慢回血
8. 🍮 果冻布丁 jelly_pudding — 史莱姆果冻 ×2 + 苹果 ×1 — 回 40 — 🦘 跳得高

- 熟肉：把现有 `cooked_meat` 配方的 `requires` 从 `"furnace"` 改 `"pot"`（做饭搬到锅；炉子只管炼金属）。
- 其余 7 道：新 item（food_fill + buff_kind/secs）+ 新配方（`requires:"pot"`）+ `_ZH_NAMES` 中文名 + 程序画图标。
- buff 时长建议：跑/跳/挖 = 60s，回血 = 30s（数值可调）。
- **务必**给每个新 item 同步 `crafting_panel.gd` 的 `_ZH_NAMES`（面包/蘑菇汤/苹果派/烤肉串/蘑菇炖肉/苹果酱/果冻布丁/锅），否则面板显示英文 id。

### F. Buff HUD（屏幕看得见）

- 在血条附近加一排 buff 小图标，监听 `buffs_changed`。
- 每个活跃 buff 显示一个 ~16px 程序画徽章（跑鞋 / 心 / 上箭头 / 镐）+ 一条随时间缩短的倒计时条或渐隐。
- 遵循「FX 要够明显」：图标 ≥ 16px、对比清楚。
- 接入现有 HUD 场景（与 health_hud/mana_hud 同层级）。

### 第 1 步验收（GUT 测试）

- **item_db**：8 道料理 + cooking_pot 存在；food_fill 正确；带 buff 的料理 `food_buff_kind/secs` 正确；纯食物（熟肉）无 buff 字段。
- **recipe_db**：8 道料理配方可解析、`requires=="pot"`；cooking_pot 配方 `requires=="furnace"`；图案/产出正确。
- **player_buffs**：`apply` 后 `is_active`；到期消失；同 kind 刷新时长；不同 kind 叠加；`speed/jump/mining_mul` 在有/无 buff 下取值正确；regen buff 随时间回血。
- **player_health 自然回血**：被打后 `REGEN_DELAY` 内不回；之后按 `REGEN_INTERVAL` 回 `REGEN_AMOUNT`；不超过 MAX；自然回血不清除受击 iframe。
- **集成**：吃带 buff 料理 → 回血 + buff 生效 + 消耗 1；血满也能吃 buff 料理；放置 cooking_pot 仅在炉子上方成功、别处失败；`_has_cooking_pot_nearby` 正确解锁料理配方。
- 中文名：新 item 都有 `_ZH_NAMES` 条目（可用断言遍历）。

### 第 1 步不做（明确排除）

鱼 / 钓鱼竿 / 紫菜 / 米 / 米饭 / 菜板 / 菜刀 / 鱼片 / 烤鱼 / 刺身 / 寿司 —— 全部留给第 2、3 步。

---

## 路线图：第 2、3 步（本 spec 仅登记，不在此实现）

### 第 2 步 —— 钓鱼 + 水材料
- 鱼竿（fishing_rod）工具 + 钓鱼机制（对水右键 → 等待计时 → 概率上钩 鱼/紫菜）。
- 紫菜：水底生长的可砍水草（新 tile，仿 PLANT_GRASS 但在水中）+ 钓鱼副获。
- 稻子作物（rice）：近水可种、像小麦生长，收获得「米」。
- 米饭：米在锅里煮。
- 烤鱼料理。
- 各自 GUT 验收。

### 第 3 步 —— 寿司大餐（切菜）
- 菜板（放置台）+ 菜刀（工具）：把「鱼」切成「鱼片」（新合成/交互范式）。
- **多种寿司**（材料齐后实现，数值待定）：
  | 寿司 | 材料 | 回血 | Buff |
  |---|---|---|---|
  | 🍣 鱼肉寿司 fish_sushi | 鱼片 + 紫菜 + 米饭 | 70 | 🌟 跑得快 + 跳得高 |
  | 🍣 豪华双拼寿司 deluxe_sushi | 鱼片 ×2 + 紫菜 + 米饭 | 90 | 🌟 跑得快 + 跳得高 + 挖得快 |
  | 🍣 素寿司 veggie_sushi | 蘑菇 + 紫菜 + 米饭 | 50 | ⛏️ 挖得快（无鱼也能做） |
  | 🍙 饭团 onigiri | 米饭 + 紫菜 | 35 | 无（简单管饱） |
  | 🐟 刺身 sashimi | 鱼片 ×2 | 50 | ❤️ 慢慢回血 |
- 各自 GUT 验收。

## 开放问题 / 实现期需确认

1. `heal()` 末尾 `_iframe_timer = 0.0` 与自然回血/regen buff 的交互（见 §A 末），实现时择一处理并写注释。
2. 火把发光的具体挂载点（哪个脚本在 tile 放置时 spawn light），锅复用同一路径。
3. cooking_pot 放置失败时的反馈方式（音效/提示），保持与现有放置手感一致，不加 async。
4. buff HUD 接入的具体 HUD 场景节点路径。
5. tile 74 是否确为下一个空号（实现前再核 `tile_data.gd` + `tileset_builder.gd`）。

## 风格 / 约束提醒（来自 CLAUDE.md）

- 所有 .tscn/.tres/美术由 AI 直接写文本/程序画，用户不开编辑器。
- 暖色调、可识别形状。屏幕 FX 够明显。
- signal handler 不加 `await get_tree().process_frame`（拆帧用 Timer）。
- 加 item 必同步 `_ZH_NAMES`；加 tile 必同步 `tileset_builder.gd`。
- 无 GUI 验收，全靠 GUT integration test。
