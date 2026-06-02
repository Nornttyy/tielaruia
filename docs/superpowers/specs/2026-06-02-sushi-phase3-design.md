# 寿司系统设计（第 3 步 · 菜板/菜刀 · 稻子/米饭 · 寿司/刺身）

- 日期：2026-06-02
- 状态：设计已与用户讨论通过，待实现
- 归属：厨房系统第 3 步（收官，承接第 1 步料理 + 第 2 步钓鱼，均已上线）

## 一句话目标

做「菜刀 + 菜板」prep 工作站，把钓来的鱼**切成鱼片**；种**稻子**收米、在锅里煮**米饭**；在菜板上做**寿司 + 刺身**（吃了回血 + 强力 buff）。用上第 2 步钓的 9 种海鲜 + 紫菜。

## 复用的现有系统

| 现有 | 用法 |
|---|---|
| 锅/熔炉工作站范式 | 放置 tile + `requires:"xxx"` 配方 + `_has_xxx_nearby()` + UI 过滤（`crafting_panel.gd`）。菜板照此加 `requires:"board"`。 |
| 小麦作物系统 | WHEAT_0..3 tile + `world.gd _tick_crop_growth` + `player_action` wheat_seed 种植 + tile_data drops。稻子（RICE_0..3）整套照抄。 |
| tile 注册 4 处 | `tile_data.gd`(const+_PROPS) + `tileset_builder.gd` tile_ids + `art_cache.gd _build_blocks` tile_ids + `blocks_art.gd`(pattern+palette+_PATTERN_MAP)。 |
| item 注册 4 处 | `item_db.gd` + `crafting_panel.gd _ZH_NAMES` + `items_art.gd _ICONS` + `art_cache.gd` item_icons list（漏=没图，见 commit ebcc748）。 |
| buff/料理 | food `food_fill`+`buff_kind`/`buff_secs`；吃下 `player_action` 触发 `PlayerBuffs.apply`。 |

## 新内容

### A. 菜刀 + 菜板（prep 工作站）
- 🔪 **菜刀 kitchen_knife**：item（`tool_kind:""`, max_stack 64）。配方：`iron_ingot ×1 + planks ×1`（普通合成）。是做菜板的材料。
- 🔪 **菜板 cutting_board**：新 tile（下一个空 id）+ 放置物。配方：`planks ×2 + kitchen_knife ×1`（普通合成）。`solid=true, pickaxe tier 1`，挖掉掉 cutting_board。站 ±2 解锁 `requires:"board"` 配方（`_has_cutting_board_nearby`）。

### B. 稻子 → 米 → 米饭
- 🌾 **稻子**：新 tiles `RICE_0..3`（4 个，像 WHEAT_0..3）。`world.gd _tick_crop_growth` 扩展认 RICE_0/1/2 升阶。RICE_3 挖 → `米 ×2-4 + rice_seed ×1-2`。
- 🌱 **rice_seed**：item（`tool_kind:"seed"`）。`player_action` 加种植分支（持 rice_seed 右键 GRASS 上方 AIR → 种 RICE_0）。来源：`PLANT_GRASS` 掉落表加 `rice_seed`（小概率，跟 wheat_seed 并列）。
- 🍚 **米 rice**：item（材料，food_fill 0 或小）。**米饭 cooked_rice**：item（food_fill 25）。配方：`rice ×2 → cooked_rice`，`requires:"pot"`（锅里煮）。

### C. 切鱼片
- 🍣 **鱼片 fish_slice**：item（食物 food_fill 18，生鱼片）。配方（`requires:"board"`，菜板上切）：`salmon → fish_slice`、`tuna → fish_slice`、`eel → fish_slice`（3 条，任意鱼切片）。

### D. 寿司 + 刺身（菜板做，`requires:"board"`）
所有都是 food（food_fill + buff），都在菜板做：

| id | 中文 | 材料 | food_fill | buff |
|---|---|---|---|---|
| sushi | 寿司 | fish_slice + cooked_rice + seaweed | 70 | speed 60s（外加：见下注） |
| sashimi | 刺身 | fish_slice ×2 | 50 | regen 30s |
| onigiri | 饭团 | cooked_rice + seaweed | 35 | 无 |
| shrimp_sushi | 虾寿司 | sweet_shrimp + cooked_rice | 45 | speed 60s |
| uni_gunkan | 海胆军舰 | sea_urchin + cooked_rice + seaweed | 55 | mining 60s |

> 注：buff 系统当前一个 food 只带 1 个 buff_kind。寿司"跑快+跳高"组合需要扩展（food 支持多 buff）——**简化：寿司给 speed（够爽），不做组合**（避免改 buff 系统）。若以后要组合再扩展 PlayerBuffs/ItemDB。

### 验收（GUT）
- item_db：kitchen_knife/cutting_board/rice/rice_seed/cooked_rice/fish_slice + 5 寿司 存在；food_fill/buff 对。
- tile：CUTTING_BOARD + RICE_0..3 常量、_PROPS、注册 4 处（含 ArtCache block tile_ids + tileset_builder）；ArtCache.block_textures 有图。
- recipe：菜刀/菜板配方；fish_slice 3 条 `requires:"board"`；cooked_rice `requires:"pot"`；5 寿司 `requires:"board"`。
- 作物：RICE_3 drops 含 rice + rice_seed；`world.gd` 认 RICE 升阶；PLANT_GRASS drops 含 rice_seed。
- 图标：所有新 item `ArtCache.get_inventory_icon` 非空（守卫测试加进 test_item_icons_registered）。
- 集成：菜板放下 → `_has_cutting_board_nearby` 解锁 board 配方；菜板上切 salmon → fish_slice；锅煮 rice → cooked_rice；菜板做 sushi（fish_slice+cooked_rice+seaweed）。
- 中文名：所有新 item 有 `_ZH_NAMES`。

### 不做（YAGNI）
- 寿司"组合 buff"（保持单 buff）。
- 龙虾/章鱼/扇贝寿司（先 5 种，用户要再加）。
- 稻子"近水才长"（跟小麦一样到处长，简化）。

## 风格/约束（CLAUDE.md）
- 暖色可识别像素画；加 item 必查 4 处注册 + 加 tile 必查 4 处注册（见上表）。
- signal handler 不加 await；无 GUI 验收全靠 GUT。
