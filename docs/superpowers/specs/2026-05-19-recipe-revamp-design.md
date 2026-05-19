# 配方重划 + Terraria 风 UI — Design

- **日期**: 2026-05-19
- **状态**: v2 草案 (Terraria 对齐), 等用户复审
- **作者**: AI 与用户协作

## 1. 背景与动机

Demo 当前 6 个配方,UI 是居中弹窗遮住整个游戏。三大问题:

1. **死路物品**: stone / slime_ball / door 都不可造或用不了
2. **居中弹窗不像泰拉瑞亚**: 用户期望"开背包看到列表 + 世界仍可见"那种横排/竖排列表
3. **配方数量"太少觉得乱"**: 11 个分层后会更有结构

本 spec 做 **两件事**:
- **A**: 配方表对齐 Terraria 格式 (去掉"木棍"中间品, 工具直接用 planks; 数值对齐)
- **B**: UI 重排为 Terraria 风 (背包 + 配方列表 都在左上角, 世界可见)

## 2. 范围

### 2.1 In Scope

**配方/物品改造**:
- ✅ 删除 `stick` 物品 (Terraria 无)
- ✅ Leaves 改成只掉自己 (不再掉 stick)
- ✅ 新增 4 个物品: stone_sword / stone_pickaxe / stone_axe / slime_torch
- ✅ 新增 1 个 tile: SLIME_TORCH (暂不发光,P3 昼夜包接管)
- ✅ 重写 RecipeDB 为 **10 个配方** (4 个 2×2 + 6 个 3×3)
- ✅ ItemsArt 新增 4 个 16×16 图标
- ✅ Slime HP 4→6 (让木→石进阶有感)
- ✅ Tool tier 与速度/伤害查表

**UI 重排 (Terraria 风)**:
- ✅ CraftingPanel 从居中弹窗 → 左上角锚定 (anchor top-left)
- ✅ 半透明面板背景 (世界仍可见)
- ✅ 背包 4×9 显示在面板顶部
- ✅ 配方列表为**纵向列表**, 每行: [输出图标 32px] [名字] [材料 简写] [一键合成 hint]
- ✅ 当前选中 = 黄色边框高亮 (鼠标 hover 即"选中")
- ✅ 不可合成 = 灰显 + 不响应点击
- ✅ 关闭仍为 E

### 2.2 Out of Scope

- ❌ Terraria 的多种工作站 (anvil, furnace) — demo 只有 workbench
- ❌ 工具菜单滚轮选中机制 — 直接点列表行就好,无需 Terraria 那种"滚到中间放大"
- ❌ 防具/弓箭/食物
- ❌ 昼夜联动 (slime_torch 现在不发光)

## 3. 进阶链路 (Terraria 对齐)

```
log ─→ planks ─┬─→ workbench
               ├─→ door
               ├─→ wood_sword
               ├─→ wood_pickaxe ─→ 挖 stone
               ├─→ wood_axe
               └─→ (作为石器手柄)

stone ─┬─→ stone_sword   (2 stone + 1 plank 手柄)
       ├─→ stone_pickaxe (3 stone + 2 plank 手柄)
       └─→ stone_axe     (3 stone + 2 plank 手柄)

slime_ball + plank → slime_torch (3 个)
```

Terraria 没有 stick, 所有工具直接用 planks 或 planks+矿石 → 我们也是。

## 4. 数据变更详表

### 4.1 ItemDB 改动

**删除**: `stick` (Terraria 无)

**新增 4 项**:
```gdscript
"stone_sword":   {"placeable_tile_id": -1, "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1},
"stone_pickaxe": {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1},
"stone_axe":     {"placeable_tile_id": -1, "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1},
"slime_torch":   {"placeable_tile_id": Tiles.SLIME_TORCH, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
```

最终 ItemDB: log/planks/dirt/grass/stone/sand/leaves(×3)/workbench/door/slime_ball/wood_sword/wood_pickaxe/wood_axe/stone_sword/stone_pickaxe/stone_axe/slime_torch = **18 项**

### 4.2 LEAVES drops 调整

去掉 stick 后:
```
LEAVES.drops: [["leaves", 100, 1, 1]]    # 不再 20% 掉 stick
LEAVES_PINE.drops: [["pine_leaves", 100, 1, 1]]
LEAVES_AUTUMN.drops: [["autumn_leaves", 100, 1, 1]]
```

### 4.3 TileData 新增

```gdscript
const SLIME_TORCH := 13
SLIME_TORCH: {
    "solid": false, "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["slime_torch", 100, 1, 1]],
}
```

### 4.4 工具效果表

| 工具 | tier | 挖速倍数 | 攻击伤害 |
|---|---|---|---|
| 徒手 | 0 | 1.0 | 1 |
| wood_sword | 1 | 1.0 | 4 |
| wood_pickaxe | 1 | 1.0 | 2 |
| wood_axe | 1 | 3.0 (LOG only) | 2 |
| stone_sword | 2 | 1.0 | 7 |
| stone_pickaxe | 2 | 1.5 (STONE only) | 3 |
| stone_axe | 2 | 4.0 (LOG only) | 3 |

实现在 `player_action.gd`:
- `_swing_sword` 按 tool tier (1 vs 2) 取伤害 (4 或 7)
- `_tool_speed(tool_kind, tile_id)` 按 tool tier + 目标 tile 查表

### 4.5 Slime HP

4 → 6
- 木剑 4 dmg × 2 击 = 8 → 杀
- 石剑 7 dmg × 1 击 = 7 → 杀

### 4.6 RecipeDB (10 个配方, 重写)

#### 2×2 (4 个, 任意位置可造)
```
planks: 1 log → 4 planks
  pattern: [["log",""],["",""]]

workbench: 4 planks → 1 workbench
  pattern: [["planks","planks"],["planks","planks"]]

slime_torch: 1 plank + 1 slime_ball → 3 torches
  pattern: [["slime_ball",""],["planks",""]]   # ball 在上, plank 在下 (像火把柄)

door: 6 planks → 1 door
  pattern: [["planks","planks"],
            ["planks","planks"],
            ["planks","planks"]]
  grid_size: Vector2i(2, 3)
  注: 这个虽然 2 宽 3 高, 但 grid 是 2×2 模式 → 装不下!
```

**修正决策**: door 改放到 3×3 桶里 (需要工作台), 因为 demo 2×2 grid 是 2 行 2 列, 装不下 3 行的图案。Terraria 木门也是 workbench 配方。

#### 3×3 (6 个, 需工作台)
```
door: 6 planks (2 cols × 3 rows)
  pattern: [["planks","planks",""],
            ["planks","planks",""],
            ["planks","planks",""]]
  mirror_ok: true (左右对称都行)

wood_sword: 3 planks (3 vertical)
  pattern: [["","planks",""],
            ["","planks",""],
            ["","planks",""]]

wood_pickaxe: 5 planks (T-shape: 3 top + 2 vertical handle)
  pattern: [["planks","planks","planks"],
            ["",      "planks",""],
            ["",      "planks",""]]

wood_axe: 5 planks (L-shape + 2 vertical handle)
  pattern: [["planks","planks",""],
            ["planks","planks",""],
            ["",      "planks",""]]
  mirror_ok: true

stone_sword: 2 stone + 1 plank handle
  pattern: [["","stone", ""],
            ["","stone", ""],
            ["","planks",""]]

stone_pickaxe: 3 stone head + 2 planks handle
  pattern: [["stone","stone","stone"],
            ["",     "planks",""],
            ["",     "planks",""]]

stone_axe: 3 stone head + 2 planks handle (L)
  pattern: [["stone","stone",""],
            ["stone","planks",""],
            ["",     "planks",""]]
  mirror_ok: true
```

总计: 3 个 2×2 + 7 个 3×3 = **10 个配方**

## 5. UI 重排详图

### 5.1 当前 (旧)
```
┌─────[ESC overlay 居中 -------]──────┐
│      [合成 & 背包]                   │
│      [配方按钮一排]                  │
│      [背包 4×9]                      │
│      [按 E 关闭]                     │
└──────────────────────────────────────┘
游戏被弹窗 全部遮挡
```

### 5.2 新 (Terraria 风)
```
┌─背包 4×9 grid (顶) ──┐
│ [ ][ ][ ][ ][ ][ ]   │  ← 左上角锚定, ~360x144
│ [ ][ ][ ][ ][ ][ ]   │
│ [ ][ ][ ][ ][ ][ ]   │
│ [ ][ ][ ][ ][ ][ ]   │
└──────────────────────┘
┌─配方列表 ────────────┐
│ ✋ 徒手 / 🛠 工作台旁│  ← 当前状态指示
├──────────────────────┤
│ [icon] planks  1原木 │  ← 高亮 (mouse hover)
│ [icon] workbench 4板 │
│ [icon] slime_torch …│
│ [icon] door     6板 │  ← 灰 (没工作台)
│ [icon] wood_sword …│  ← 灰
│ ...                 │
└──────────────────────┘
                      [世界仍可见 →]
```

- 左上角整块, 不挡视野中心
- 半透明背景 (`Color(0,0,0,0.4)`)
- 每个配方一行 = [40×40 输出图标] + [配方名] + [材料简写] + [hover 高亮黄边]
- 点击行 = 一键合成 (素材足时)
- 灰显: 缺素材 或 (3×3 配方 + 不在工作台旁)

### 5.3 实现细节

CraftingPanel 节点改造:
```
CanvasLayer
  └ TopLeftAnchor (Control, anchor PRESET_TOP_LEFT)
     └ Panel (PanelContainer, semi-transparent bg)
        └ VBox
           ├ Title "背包 & 合成"
           ├ Status label (✋/🛠)
           ├ InventoryGrid (4×9 子 panel)
           ├ Separator
           ├ RecipeListVBox (10 行)
           └ CloseHint "按 E 关闭"
```

不再用 CenterContainer 让面板居中; 改 `set_anchors_preset(PRESET_TOP_LEFT)` + 边距 16px。

## 6. 美术工作量

新增图标 (放 ItemsArt 或 BlocksArt):
- `stone_sword` (16×16): 灰刀身 + 木柄
- `stone_pickaxe` (16×16): 灰镐头 + 木柄
- `stone_axe` (16×16): 灰斧头 + 木柄
- `slime_torch` BlocksArt (16×16): 暗木棍 + 顶部黄绿史莱姆胶 (作为 placeable tile 自动复用为物品图标)

## 7. 文件改动清单

修改:
- `scripts/world/tile_data.gd`: 加 SLIME_TORCH 常量+ _PROPS; LEAVES drops 去掉 stick
- `scripts/art/blocks_art.gd`: 加 SLIME_TORCH 常量+调色板+pattern+映射
- `scripts/art/items_art.gd`: 加 3 个石器 pattern
- `scripts/items/item_db.gd`: **删除 stick**; 加 4 个新物品
- `scripts/autoload/art_cache.gd`: tile_ids 加 SLIME_TORCH; item_icons 加 3 石器; _ITEM_TO_TILE 加 slime_torch
- `scripts/world/tileset_builder.gd`: tile_ids 加 SLIME_TORCH
- `scripts/crafting/recipe_db.gd`: 重写为 10 个配方 (全部去 stick)
- `scripts/player/player_action.gd`: 攻击/挖速按 tool tier 查
- `scripts/entities/slime.gd`: MAX_HEALTH 6
- `scripts/ui/crafting_panel.gd`: 大改 — 列表式布局, 左上角锚定
- `scenes/ui/crafting_panel.tscn`: 删除居中 CenterContainer, 改 TopLeftAnchor 结构

测试改动:
- `tests/unit/test_item_db.gd`: 删 stick, 加 4 新物品
- `tests/unit/test_tile_data.gd`: 加 SLIME_TORCH 测
- 既有合成集成测试 (test_craft_loop / test_workbench_3x3 / test_full_loop): 重写, 用 planks 代替 stick

## 8. 风险与缓解

| 风险 | 缓解 |
|---|---|
| 删 stick 破多个测试 | 必须更新 6+ 个测试文件 (大改) |
| Door 配方在 3×3 grid, 不在 2×2 (导致需要工作台才能造门) | Terraria 也是 workbench → 设计一致 |
| UI 重排可能挡 hotbar (hotbar 在底部, 不挡) | 左上角面板, hotbar 在屏幕底中 → 不重叠 |
| 配方列表 10 行可能太长 | 试运行后调字号; 必要时分两栏 |

## 9. 验收门禁

- [ ] 10 个配方按钮可见, 列表式纵向布局, 左上角
- [ ] 世界在面板背后可见 (半透明)
- [ ] 木剑 2 击 / 石剑 1 击杀 slime
- [ ] stone_axe 砍树明显比 wood_axe 快 (4×)
- [ ] door 在工作台旁可造可放 (6 planks)
- [ ] stick 物品完全消失 (背包里没有, 没人掉)
- [ ] 全部 GUT 测试过 (含 4 个新物品 + 10 个 recipe 命中测)

## 10. 修订历史

- **v1 (2026-05-19)** — 11 配方含 stick 中间品, 居中弹窗 UI
- **v2 (2026-05-19)** — 删 stick (Terraria 对齐) → 10 配方; UI 改左上角锚定列表式 (Terraria 风)
