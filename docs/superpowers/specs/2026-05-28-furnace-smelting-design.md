# 熔炉 + 冶炼 设计稿

**日期**：2026-05-28
**范围**：加 furnace tile + 5 种金属锭 + cooked_meat + 6 个冶炼配方
**风格**：Terraria 风（无 UI 面板，靠"附近有炉子"检测让冶炼配方出现在合成面板）

---

## 1. 目标

让矿石变有用：现在矿挖一堆但 silver_sword 等仍用 raw ore，没"冶炼"的乐趣。加熔炉 + 锭让 mine → smelt → craft 三层进阶感清晰。

---

## 2. 玩法流程

1. 玩家造熔炉（8 stone → 1 furnace），放在地上
2. 走到熔炉 ≤ 2 格内（跟 workbench 同范围）
3. 按 E 开合成面板 → **冶炼配方自动出现**
4. 摆 3 个 iron_ore 到 3×3 → 出 1 个 iron_ingot
5. 锭可以用来后期 craft 更高级武器（本 spec 不实现 ingot→武器，留 M3）

**关键**：跟 workbench 一样的 detection 模型，**不开新 UI 面板**。

---

## 3. 改动清单

### 3.1 新 tile

| ID | 名字 | 行为 |
|---|---|---|
| 51 | FURNACE | 实心方块, 挖了掉 furnace item, "炉子在附近"检测用 |

### 3.2 新 items（6 个 ingot/cooked + 1 furnace）

| item_id | 名字 | 用途 |
|---|---|---|
| furnace | 熔炉 | 放置 (placeable_tile_id = Tiles.FURNACE) |
| iron_ingot | 铁锭 | 收集材料 (M3 升级武器用) |
| copper_ingot | 铜锭 | 同上 |
| tin_ingot | 锡锭 | 同上 |
| silver_ingot | 银锭 | 同上 |
| gold_ingot | 金锭 | 同上 |
| cooked_meat | 熟肉 | food_fill = 50 (raw_meat 30 的 1.66x) |

### 3.3 新配方（7 个）

| Recipe ID | Pattern | 输出 | requires |
|---|---|---|---|
| furnace | 3×3 全 stone (8 stone 摆 □ 形, 中间空) | 1 furnace | "workbench" |
| iron_ingot | 3×3, 3 个 iron_ore 摆任意 | 1 iron_ingot | "furnace" |
| copper_ingot | 3×3, 3 个 copper_ore | 1 copper_ingot | "furnace" |
| tin_ingot | 3×3, 3 个 tin_ore | 1 tin_ingot | "furnace" |
| silver_ingot | 3×3, 3 个 silver_ore | 1 silver_ingot | "furnace" |
| gold_ingot | 3×3, 3 个 gold_ore | 1 gold_ingot | "furnace" |
| cooked_meat | 2×2, 1 个 raw_meat | 1 cooked_meat | "furnace" |

「Pattern 3×3 3 个矿石摆任意」用一行 3 列 + mirror_ok / rotate_ok 实现。

### 3.4 加 `requires` 字段到 recipe

`scripts/crafting/recipe_db.gd` 每个 recipe dict 加 `"requires": "" / "workbench" / "furnace"`。所有老配方默认 ""。

### 3.5 RecipeMatcher 过滤

`scripts/crafting/recipe_matcher.gd` 或 `crafting_panel.gd` 改：
- `_refresh_recipes()` 时查"附近"有什么台子（workbench / furnace 都可能）
- 配方 `requires == ""` 或 玩家在对应台旁 → 显示
- 否则隐藏

`_has_furnace_nearby()` 跟现有 `_has_workbench_nearby()` 同模式。

---

## 4. 文件清单

| 修改 | 改什么 |
|---|---|
| `scripts/world/tile_data.gd` | 加 `const FURNACE := 51` + `_PROPS` 入口 (solid=true, drops=[["furnace",100,1,1]]) |
| `scripts/art/blocks_art.gd` | 加 `_FURNACE` pattern (16x16, 灰石身 + 内部红火光) + `_P_FURNACE` palette + `_PATTERN_MAP` 注册 |
| `scripts/world/tileset_builder.gd` | tile_ids 列表加 Tiles.FURNACE |
| `scripts/autoload/art_cache.gd` | _ITEM_TO_TILE 加 `"furnace": BlocksArt.FURNACE` |
| `scripts/items/item_db.gd` | 加 7 个新 items (5 ingot + cooked_meat + furnace) |
| `scripts/ui/crafting_panel.gd` | 加 `_has_furnace_nearby()` + 配方过滤 + 中文名 |
| `scripts/art/items_art.gd` | 加 5 个 _XXX_INGOT 和 _COOKED_MEAT pattern + _ICONS 注册 |
| `scripts/autoload/art_cache.gd` (二改) | _build_items 列表加 6 个新 id |
| `scripts/crafting/recipe_db.gd` | 加 `requires` 字段 + 7 个新配方 |
| `scripts/crafting/recipe_matcher.gd` | 接收 nearby 信息过滤 |

---

## 5. 实现顺序

1. T1: tile FURNACE + pattern + 注册 + tileset
2. T2: 7 个 items + 中文名 + ingot ASCII pattern + 注册
3. T3: furnace 配方 (8 stone)
4. T4: recipe_db `requires` 字段 + recipe_matcher / crafting_panel 过滤
5. T5: 6 个冶炼配方
6. T6: `_has_furnace_nearby` + 显示逻辑
7. T7: 测试 + smoke

---

## 6. 风险

| 风险 | 缓解 |
|---|---|
| Recipe pattern 3 ore 摆任意 → 玩家不知道怎么放 | 用单行 3 (水平 3 个) + mirror_ok + rotate_ok=true 覆盖横/竖布局 |
| 玩家在 workbench 旁 (3x3 模式) 但不在 furnace 旁 → 冶炼配方不显示 | 文档明示玩家要"两个都在附近", 或允许 furnace 兼任 workbench |
| 老存档 furnace 不存在 → 老用户用矿做 sword 不受影响 (recipes 不动) | 保留所有现有矿石直接 craft 配方; 锭只是额外材料路径 |
