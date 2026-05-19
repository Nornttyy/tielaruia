# 配方重划 (Demo Phase Combat++) — Design

- **日期**: 2026-05-19
- **状态**: v1 草案,等用户复审
- **作者**: AI 与用户协作

## 1. 背景与动机

Demo 当前 6 个配方 (planks / stick / workbench / wood_sword / wood_pickaxe / wood_axe),足够展示 2x2 与 3x3 合成系统,但暴露三个问题:

1. **死路物品**: `stone` 挖出来无用,`slime_ball` 杀史莱姆掉但无用,门 (door) tile 有但无合成路径
2. **无 tier 进阶**: 杀了一只 slime 之后 (1 hit kill) 玩家再无新目标
3. **配方少觉得空**: 用户在新 E 键面板看到只有 6 个按钮觉得"很乱/不完整"

本 spec 加 **5 个新配方** + 调整既有数据形成 **木 → 石** 工具进阶,让现有 `stone` 和 `slime_ball` 物品有用,门可造,体验版有 ~15-20 分钟内容深度。

## 2. 范围

### 2.1 In Scope (本次)

- ✅ 新增 5 个配方 (door + 3 石器 + slime_torch)
- ✅ ItemDB 新增 4 个物品 (stone_sword / stone_pickaxe / stone_axe / slime_torch)
- ✅ ItemsArt 新增 4 个 16×16 像素图标
- ✅ TileData 调整:
  - 提高 stone 所需 tool_tier (现 1 → 保持 1, 但 stone_pickaxe tier 2 挖更快)
  - slime HP 4 → 6 (让木剑 2 击杀,石剑 1 击杀)
- ✅ Tool speed 与 damage 在 player_action.gd 按 tool_kind+tier 查表
- ✅ slime_torch 是 placeable tile (放下后未来作为光源接 P3 昼夜包;现在只是一个发光像素方块)
- ✅ 更新 RecipeDB 6 + 5 = **11 个配方**

### 2.2 Out of Scope (推迟)

- ❌ 新 tile 类型: 不加 chest/bed/iron_ore 等(避免开新坑)
- ❌ 昼夜系统: slime_torch 现在只是 placeable, 不实际发光; P3 昼夜包接管
- ❌ leaves 用途: 暂不为 leaves/pine_leaves/autumn_leaves 加合成路径 (后续若做染料/食物再说)
- ❌ 防具系统: 不加头盔/胸甲

## 3. 进阶链路

```
log ─┬─→ planks ─┬─→ workbench ─→ (进 3×3)
     │           ├─→ door
     │           ├─→ wood_sword
     │           ├─→ wood_pickaxe  ─→ 挖 stone
     │           └─→ wood_axe
     └─→ stick

stone ─┬─→ stone_sword   (剑 +damage)
       ├─→ stone_pickaxe (镐 +speed)
       └─→ stone_axe     (斧 +speed)

slime_ball + stick → slime_torch (放下来当装饰; 昼夜包做后变光源)
```

**典型一局 ~15 分钟**:
1. 0-2 min: 砍 2-3 棵树, 2x2 合 planks → stick → workbench
2. 2-3 min: 工作台旁 3x3 合 wood_axe + wood_pickaxe + wood_sword
3. 3-5 min: 砍更多树 (有斧子 4×速) + 挖到地下 stone 矿
4. 5-7 min: 回工作台合 stone 三件套
5. 7-12 min: 用石剑一击杀 slime 收集 slime_ball, 合 slime_torch 装饰家
6. 12-15 min: 用 door 围一个房子, 探索地图

## 4. 数据变更详表

### 4.1 ItemDB 新增 (4 项)

```gdscript
"stone_sword":   {"placeable_tile_id": -1, "tool_kind": "sword",   "tool_tier": 2, "max_stack": 1},
"stone_pickaxe": {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 2, "max_stack": 1},
"stone_axe":     {"placeable_tile_id": -1, "tool_kind": "axe",     "tool_tier": 2, "max_stack": 1},
"slime_torch":   {"placeable_tile_id": Tiles.SLIME_TORCH, "tool_kind": "", "tool_tier": 0, "max_stack": 64},
```

### 4.2 TileData 新增 1 项

```gdscript
# 史莱姆灯 — 不实心 (可穿过), 黄绿色发光像素方块
SLIME_TORCH: {
    "solid": false, "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["slime_torch", 100, 1, 1]],
}
```

Tile ID 常量: `SLIME_TORCH := 13`

### 4.3 工具效果表

| 工具 | tier | 挖速倍数 | 攻击伤害 |
|---|---|---|---|
| 徒手 | 0 | 1.0 | 1 |
| wood_sword | 1 | 1.0 | 4 (改自 5) |
| wood_pickaxe | 1 | 1.0 (基础) | 2 |
| wood_axe | 1 | 3.0 (LOG only) | 2 |
| stone_sword | 2 | 1.0 | 7 |
| stone_pickaxe | 2 | 1.5 (STONE only) | 3 |
| stone_axe | 2 | 4.0 (LOG only) | 3 |

`player_action.gd:_tool_speed()` 和 `_swing_sword()` 按 tool_kind + tier 查表。

### 4.4 Slime HP 调整

- 当前: HP=4, CONTACT_DAMAGE=2
- 改: HP=6, CONTACT_DAMAGE=2
- 结果: 木剑 4 dmg × 2 = 8 → 2 击杀; 石剑 7 dmg × 1 = 7 → 1 击杀

### 4.5 RecipeDB 新增 5 项

#### door (2×3 板)
```
PP
PP
PP
```
- grid_size: 2×3 (注: 当前 RecipeMatcher 用 Vector2i(cols, rows), 但所有现有 recipe 都是方形 2×2 或 3×3)
- **决策**: door 配方占 3×3 模板的左 2 列, mirror_ok=true
- output: 1 door

#### stone_sword (3×3)
```
.S.
.S.
.K.    K = stick
```
- output: 1 stone_sword

#### stone_pickaxe (3×3)
```
SSS
.K.
.K.
```
- output: 1 stone_pickaxe

#### stone_axe (3×3)
```
SS.
SK.
.K.
```
- output: 1 stone_axe, mirror_ok=true

#### slime_torch (2×2)
```
B.    B = slime_ball
K.    K = stick
```
- output: 4 slime_torches, mirror_ok=true

## 5. 美术工作量

新增 5 个 16×16 图标 (放 items_art.gd):
1. `stone_sword` — 灰色刀身 + 木柄
2. `stone_pickaxe` — 灰色十字头 + 木柄
3. `stone_axe` — 灰色斧头 + 木柄
4. `slime_torch` (item 图标) — 绿色顶 + 木棍
5. `slime_torch` (作为 block tile in BlocksArt) — 16×16 暗木棍 + 顶部发光绿色

注: 4/5 复用同一图标更省事; 但 ArtCache.get_inventory_icon 对 placeable 物品默认查 BlocksArt 纹理, 所以做 block tile 那张就行。

## 6. 文件改动清单

- `scripts/world/tile_data.gd`:
  - 加 `SLIME_TORCH := 13` 常量
  - 加 SLIME_TORCH 到 _PROPS
- `scripts/art/blocks_art.gd`:
  - 加 `SLIME_TORCH := 13` 常量
  - 加 _P_SLIME_TORCH 调色板 + _SLIME_TORCH pattern
  - 加 _PATTERN_MAP + _PALETTES 条目
- `scripts/art/items_art.gd`:
  - 加 _STONE_SWORD / _STONE_PICKAXE / _STONE_AXE 三个 16×16 pattern
- `scripts/items/item_db.gd`:
  - 加 4 个物品 def
- `scripts/autoload/art_cache.gd`:
  - _build_blocks: 加 SLIME_TORCH
  - _build_items: 加 3 个石器
  - _ITEM_TO_TILE: 加 slime_torch
- `scripts/world/tileset_builder.gd`:
  - tile_ids 加 SLIME_TORCH (非实心 → 不加碰撞)
- `scripts/crafting/recipe_db.gd`:
  - 加 5 个 _RECIPES 条目
- `scripts/player/player_action.gd`:
  - _swing_sword 按 tool tier 取伤害
  - _tool_speed 按 tool kind+tier 取倍率
- `scripts/entities/slime.gd`:
  - MAX_HEALTH 4 → 6
- `tests/unit/test_item_db.gd`:
  - test_all_known_items_present 加 4 项
- `tests/unit/test_recipe_db.gd` (新, 若不存在):
  - 验证 11 个 recipe 都能 RecipeMatcher.find_match 命中

## 7. 测试策略

### 7.1 单元
- ItemDB 14 → 18 个物品 (test_item_db.gd 扩列表)
- 5 个新 recipe 各做一个 find_match 命中测试 (类似既有 wood_sword 测)

### 7.2 集成
- test_full_loop.gd 不必改 (现有流程能跑通即可)
- 新增 test_stone_tier_loop.gd:
  - 挖 stone (有 wood_pickaxe) → 工作台合 stone_sword → 一击杀 slime

### 7.3 手动验收
- E 面板看到 11 个按钮 (3 行: 2x2 一行 4 个, 3x3 一行 6 个)
- 杀史莱姆需要 2 hit (木剑) 或 1 hit (石剑)
- stone_torch 放下后是绿色顶部的方块

## 8. 风险与决策

| 风险 | 缓解 |
|---|---|
| door 配方 2×3 不是方形, 现有 RecipeMatcher 对方形 grid 平移匹配 — 验证可行 | 直接在 3×3 grid 摆 2 宽 3 高图案, RecipeMatcher 已支持 (bbox + 平移) |
| 加 SLIME_TORCH 后 P3 昼夜包要重做光逻辑 | 现在 slime_torch 只是普通可放置 tile, 不接 SkyLightGrid; P3 加 "light_source" 字段时再扩 |
| 14 + 4 = 18 个物品, hotbar 9 格放不下 | 主背包 27 格已够, hotbar 是选当前手持; 不冲突 |

## 9. 验收门禁

- [ ] 11 个配方在 E 面板按钮中均可见
- [ ] 不在工作台旁: 只有 4 个 2×2 配方亮 (planks / stick / workbench / slime_torch)
- [ ] 在工作台旁: 11 个全亮 (素材够时)
- [ ] 木剑 2 hit 杀 slime, 石剑 1 hit
- [ ] stone_axe 比 wood_axe 砍树明显更快
- [ ] door 可造可放 (3×3 配方)
- [ ] 全部 GUT 测试通过, 含 4 个新物品 + 5 个新 recipe 命中测

## 10. 修订

- **v1 (2026-05-19)** — 草案, 11 个配方 + 4 个新物品 + 1 个新 tile
