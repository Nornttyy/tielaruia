# 钓鱼系统设计（第 2 步 · 鱼竿 + 海鲜 + 烤鱼）

- 日期：2026-06-02
- 状态：设计已与用户讨论，待用户复核
- 归属：厨房系统第 2 步（承接 `2026-06-01-cooking-kitchen-design.md`，第 1 步已实现上线）

## 一句话目标

做一根**鱼竿**，对着水甩竿钓鱼：等待 → 看浮标下沉/鱼线抖（**不弹「!」文字**）→ 点一下收竿，钓上 **9 种海鲜**（寿司料）。钓到的鱼能在锅里做成**烤鱼**（即时回报）。海鲜攒着给第 3 步做寿司。

## 背景：可复用的现有系统（摸排结论）

| 现有 | 用法 | 位置 |
|---|---|---|
| 水检测 | `_is_water_tile(tid)` 判 WATER/WATER_L1/L2/L3；`Tiles.WATER=28`、`WATER_L1=34`、`L2=35`、`L3=36` | `player_controller.gd:156`、`tile_data.gd` |
| 持道具右键触发动作 | grappling_hook 范式：`if slot.item_id=="grappling_hook" and just: player.fire_grappling_hook()`（在 `_update_eat_or_place`） | `player_action.gd` |
| 投射物视觉范式 | 钩爪用 `Line2D`(绳) + `Sprite2D`(钩头)，`top_level`，挂 `effects_root`（浮标可照搬） | `player_controller.gd` fire_grappling_hook / _spawn_hook_line/head |
| 加物品进背包 | `inventory.pickup(item_id, count)` | `player_inventory.gd:47` |
| 计时累加范式 | 吃食物 `_eat_t += delta; if >= DUR`（钓鱼等待/咬钩计时照此） | `player_action.gd` _update_eat_or_place |
| 权重随机掉落 | 掉落表 `[item_id, weight, ...]`（权重相对，不必凑 100） | `animal_base.gd`、`tile_data.gd` _PROPS drops |
| buff 系统 | `PlayerBuffs.apply(kind, secs)`（烤鱼给 speed buff 用） | `player_buffs.gd`（第 1 步已做） |
| 锅做饭 | 配方 `requires:"pot"`，`_has_cooking_pot_nearby` 解锁（烤鱼在锅做） | `recipe_db.gd`、`crafting_panel.gd`（第 1 步已做） |
| 程序图标 | `items_art.gd` `_ICONS` 16×16，新海鲜各画一个 | `items_art.gd` |

## 新内容

### A. 鱼竿（fishing_rod）
- item：`tool_kind:"fishing"`、`max_stack:1`、`placeable_tile_id:-1`。
- 配方（参考木弓 planks+wool）：`planks ×3`（竿身）+ `wool ×2`（鱼线），3×3 形状，普通合成（不需工作站）。
- 中文名「鱼竿」；程序画图标（木竿 + 一段线 + 小钩）。

### B. 钓鱼机制（新组件 `PlayerFishing`）

新节点 `PlayerFishing`（挂 Player 下，与 PlayerHealth/PlayerBuffs 同级），管状态机 + 浮标视觉。`player_action` 在持鱼竿右键时调它。

**状态机**（`_process(delta)` 推进）：
- `idle`：无事。
- 玩家持鱼竿**右键** → `on_rod_click(aim_tile)`：
  - 若 `idle`：检查 `aim_tile` 是水（`_is_water_tile`）且 `in_reach` → 进 `waiting`，在 `aim_tile` 水面生成浮标 + 一条从玩家(竿尖)到浮标的 `Line2D`。否则：浮动提示「要对着水」+ 轻音效，不进状态（**不弹文字弹窗**，用现有 floating_prompt 或音效）。
  - 若 `biting`（咬钩窗口内）：**收竿成功** → roll 收获表 → `inventory.pickup(catch_id,1)` + 收竿音效 + 飘字「钓到 X」→ 清浮标 → `idle`。
  - 若 `waiting`：再点 = 收竿（提前）→ 空收（鱼还没咬，无收获）→ `idle`（不惩罚，可再甩）。
- `waiting`：随机等 `BITE_WAIT = randf_range(2.0, 5.0)` 秒，浮标轻微上下浮动（视觉）。到时 → `biting`。
- `biting`：**浮标猛地下沉几 px + 鱼线一抖**（视觉），配轻「咚/plop」音效（**无任何文字/「!」**）。开 `REEL_WINDOW = 1.5` 秒窗口。窗口内玩家右键 → 成功（见上）。超时未点 → `escape`：浮标弹回、无收获、回 `idle`（可再甩）。
- 取消：玩家走远（离浮标 > N tile）/ 切走鱼竿 / 死亡 → 清浮标回 `idle`。

**浮标视觉**：`Sprite2D`（红白浮标，程序画）+ `Line2D`（细线，竿尖→浮标），均 `top_level`，挂 `effects_root`（仿钩爪 `_spawn_hook_line/head`）。

**公共 API（给测试 + player_action）**：`on_rod_click(aim_tile:Vector2i) -> void`、`state() -> String`、`is_fishing() -> bool`、`_force_bite()`（测试用，跳过等待）、信号 `caught(item_id:String)`。

### C. 9 种海鲜 + 紫菜（收获）

`item_db` 新增（都 `placeable_tile_id:-1, tool_kind:"", max_stack:64`；`food_fill` = 生吃回血；紫菜 0 = 纯材料不可吃）：

| id | 中文 | food_fill | 收获权重 |
|---|---|---|---|
| salmon | 三文鱼 | 25 | 20 |
| tuna | 金枪鱼 | 28 | 20 |
| octopus | 章鱼 | 22 | 20 |
| sea_urchin | 海胆 | 20 | 20 |
| lobster | 龙虾 | 38 | 20 |
| eel | 鳗鱼 | 26 | 20 |
| sweet_shrimp | 甜虾 | 15 | 18 |
| scallop | 扇贝 | 18 | 18 |
| seaweed | 紫菜 | 0（材料） | 15 |

- **收获表 = 权重随机**（相对权重，不必凑 100；想调稀有度改数字即可）。实现：`PlayerFishing` 内常量 `CATCH_TABLE = [["salmon",20],["tuna",20],...]`，收竿时按权重和随机抽 1 个。
- 每种**自己的 16×16 程序图标**（暖色、可识别：三文鱼橙肉白纹、金枪鱼红肉、龙虾红壳大钳、海胆紫刺、章鱼粉红多腕、鳗鱼细长褐、甜虾粉、扇贝扇形壳、紫菜墨绿片）。
- **必须**同步 `crafting_panel.gd` `_ZH_NAMES` 中文名（漏了显英文 id）。
- 这 9 种全是第 3 步寿司/刺身的料。

### D. 烤鱼（grilled_fish，锅里做，即时回报）
- item：`food_fill:45`、`buff_kind:"speed"`、`buff_secs:60.0`（复用第 1 步 buff 系统）。
- 配方（`requires:"pot"`）：`salmon → grilled_fish`、`tuna → grilled_fish`、`eel → grilled_fish`（3 条单材料配方，任意一种鱼都能烤）。
- 中文名「烤鱼」+ 程序图标。

### 验收（GUT）
- **item_db**：9 海鲜 + fishing_rod + grilled_fish 存在；food_fill 对；紫菜 food_fill=0（`is_food` false）；grilled_fish buff=speed。
- **recipe_db**：fishing_rod 配方可解析；3 条烤鱼配方 `requires=="pot"` 且 output grilled_fish。
- **PlayerFishing 状态机**（单测，组件 + 假 inventory/health 兄弟节点）：
  - `on_rod_click` 对水 → `waiting`；对非水 → 仍 `idle`。
  - `waiting` → `_force_bite()` → `biting`；`biting` 内 `on_rod_click` → 成功，`caught` 信号发出 + 收获是 9 种之一。
  - `biting` 超过 `REEL_WINDOW` → `escape` → `idle`，无 `caught`。
  - 收获表权重抽样：跑多次覆盖到多种 id（断言抽到的都在 9 种集合里）。
- **图标**：9 海鲜 + 鱼竿 + 烤鱼 `ItemsArt.get_icon` 能渲染（16px）。
- **集成**：持鱼竿对水右键 → 组件进 `waiting`；`_force_bite()` + 再右键 → 背包多 1 个海鲜。
- 中文名：新 item 都有 `_ZH_NAMES` 条目。

### 不做（留第 3 步）
菜板 / 菜刀 / 鱼片 / 米 / 稻子 / 米饭 / 寿司各种 / 刺身。紫菜本步只能钓到+攒着，用处在第 3 步。

## 实现期需现场确认（非阻塞）
1. 浮标"甩出去"是直接落在瞄准水格（MVP），还是抛物线飞过去（更帅但 YAGNI）——默认直接落点。
2. floating_prompt「要对着水」的具体调用方式（用现有 group `floating_prompt` 还是只播音效）——以现有提示范式为准。
3. `PlayerFishing` 节点加进 `player.tscn` 的 ext_resource id 取未占用值。
4. 鱼竿右键同时是"甩竿"和"收竿"——`player_action` 持鱼竿 `just` 右键时统一调 `on_rod_click`，由组件按状态决定。

## 风格 / 约束（来自 CLAUDE.md）
- .tscn/.tres/美术由 AI 直接写文本/程序画；暖色、可识别形状。
- signal handler 不加 `await get_tree().process_frame`（拆帧用 Timer / `_process` 累加）。
- 加 item 必同步 `_ZH_NAMES`；加 tile（本步无新 tile）才需同步 tileset_builder + art_cache。
- 无 GUI 验收，全靠 GUT。
