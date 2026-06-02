# 剑分短剑/阔剑 设计

- 日期：2026-06-02
- 状态：设计已与用户讨论通过，待实现
- 来源：用户"先把剑分为两种，短剑和阔剑"+"造型不能一样"

## 目标

把单一「剑」拆成两类，8 种材料各一把（共 16 把）：
- 🗡️ **短剑（dagger）**：**戳**（单体、范围短）、出手快、伤害小一点。短粗匕首造型。
- ⚔️ **阔剑（broadsword）**：**半圆扫**（扫一片怪）、慢一点、伤害大。又长又宽大剑造型。
- 攻击方式由**剑的种类**决定（短剑永远戳 / 阔剑永远扫），**不再按等级**。
- **造型必须明显不同**（短剑 vs 阔剑一眼能分清，不能只是换色）。

## 现状（摸排）

- 8 把剑：`wood_sword`/`stone_sword`/`copper_sword`/`iron_sword`/`silver_sword`/`gold_sword`/`diamond_sword`/`hell_sword`（tool_kind "sword", tool_tier 1-8, damage_mult 1.0）。
- 攻击逻辑 `player_action.gd:188-195`：`kind=="sword"` → `_current_tool_tier() <= 2` 则 `_thrust_sword()`（戳），否则 `_sweep_sword()`（扫）。**戳/扫两套机制已存在**。
- 戳/扫的伤害 + cooldown 在 `_thrust_sword`/`_sweep_sword`（实现期确认数值）。
- 剑图标：`items_art.gd` 一个剑模板 + 8 套材料调色板（M=边/暗, B=主, F=闪点；木 Y/y/I…钻 N/X/Q…地狱…）。

## 设计

### A. item 拆分（保存档：现有 `<mat>_sword` 留用）
- **`<mat>_sword`（现有 8 把）→ 阔剑**：display 改「X阔剑」，加 `"sword_style": "sweep"`，`damage_mult: 1.2`（变强）。配方不变（output 仍 `<mat>_sword`）。
- **`<mat>_dagger`（新 8 把）→ 短剑**：新 item，`tool_kind:"sword"`, `tool_tier` 同对应材料，`"sword_style": "thrust"`, `damage_mult: 0.8`, `max_stack: 1`。display「X短剑」。
- 8 材料：wood/stone/copper/iron/silver/gold/diamond/hell。

### B. 攻击逻辑（按 sword_style 不按 tier）
- `player_action.gd`：`kind=="sword"` 时，读当前剑的 `sword_style`：
  - `"thrust"`（短剑）→ `_thrust_sword()`
  - `"sweep"`（阔剑）→ `_sweep_sword()`
  - 兜底（老存档无字段）：tier<=2 戳，否则扫（保持现状不崩）。
- ItemDB 加 helper `sword_style(item_id) -> String`（返回 def 的 sword_style，缺省 ""）。
- **短剑出手快**：`_thrust_sword` 的 `_attack_cooldown` 设短（如 0.22s）；`_sweep_sword` 设长（如 0.42s）。实现期读现有值微调。

### C. 美术（2 套新剪影 × 8 材料调色板）
- **新画 2 个 16×16 剑模板**（造型明显不同）：
  - `_DAGGER_SHAPE`：短刀身（占~7 行）、宽、尖头 + 护手 + 短柄。
  - `_BROADSWORD_SHAPE`：长刀身（占~11 行）、**比现有剑更宽** + 大护手 + 柄。
- 每个模板套现有 8 套材料调色板（M/B/F）→ 渲染 16 个图标。复用 items_art 现有调色板键。
- 现有剑图标（`_WOOD_SWORD` 等）→ 改用 `_BROADSWORD_SHAPE`（阔剑造型）。短剑用 `_DAGGER_SHAPE`。
- items_art `_ICONS`：8 个 `<mat>_dagger` → dagger 模板染色；8 个 `<mat>_sword` 改指向 broadsword 模板。

### D. 配方（8 把短剑，省料）
- 短剑配方：比阔剑省 1 格材料（短）。如木短剑 = 2 planks（竖）；铁短剑 = 1 iron_ingot + 1 planks。普通合成（跟现有剑配方同工作台需求）。
- 现有 8 把剑配方保留（= 阔剑）。

### E. 注册 + 中文名
- 16 把中文名进 `crafting_panel.gd _ZH_NAMES`（木短剑/木阔剑/石短剑…）。
- 8 个新 `<mat>_dagger` 进 `art_cache.gd` 的剑图标循环（现有 `for tier in [...]` 那段加 dagger，或单独循环）。

### 验收（GUT）
- ItemDB：8 dagger 存在，`sword_style("wood_dagger")=="thrust"`，`sword_style("wood_sword")=="sweep"`；damage_mult 0.8/1.2。
- 攻击：源码断言 `player_action` 按 `sword_style` 选 thrust/sweep（防回归）；或集成测试持短剑→戳、持阔剑→扫（看 `_sword_attack_is_sweep` 标志）。
- 配方：8 dagger 配方可解析、output 对。
- 图标：16 把 `ArtCache.get_inventory_icon` 非空 + dagger 与 sword 模板**不同**（断言两 ImageTexture 不同尺寸或抽样像素不同，验证造型不一样）。
- 中文名：16 把都有 `_ZH_NAMES`。

### 不做（YAGNI）
- 不加新材料 tier（就现有 8 种）。
- 不改 pickaxe/axe/bow。
- 短剑/阔剑暂不加特殊技能（连击、格挡等），只戳/扫差异。

## 风格/约束（CLAUDE.md）
- 暖色可识别像素画，造型差异明显。加 item 必查 4 处注册（_ZH_NAMES/_ICONS/ArtCache item_icons/(放置物)_ITEM_TO_TILE — 剑非放置物，前 3 处）。
- 现有存档 `<mat>_sword` 不能失效（保留为阔剑）。
