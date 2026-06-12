# 地狱恶魔领主 (Demon Lord) Boss 设计

第 3 个 Boss，地狱主题。复用现有 Boss 框架（boss_bar 自动找 group、spawn_boss 派发、召唤道具 tool_kind=summon、ItemDrop 掉落）。

## 玩法
- **会飞**：无地面重力，悬浮在玩家上方 ~5 格高度盘旋逼近（不是地面走怪）。
- HP ≈ 1800（× enemy_hp_multiplier）。在 `boss` group → boss_bar 自动显示。
- 大体型 → 必须实现 `melee_hit_radius()`（见 reference_melee_hit_radius，否则近战打不中）。
- **三招**（都有前摇 telegraph，照 skeleton_king 的 windup→active 节奏）：
  1. **火球弹幕**：朝玩家扔 3 颗火球（复用 `fireball.gd`）。远距优先。
  2. **俯冲冲刺**：蓄力 → 朝玩家位置猛冲一段（DASH）。
  3. **召唤小兵**：每 ~6s 召 1 imp + 1 hell_wasp，场上小兵 cap 5（复用 `imp.tscn`/`hell_wasp.tscn`）。
- **残血狂暴**（HP < 40%）：出招冷却减半 + 火球变 5 颗扇形。
- 接触伤害 18。

## 召唤
- 新道具 **`demon_heart`（恶魔之心）**：`tool_kind="summon"`, `summon_boss="demon_lord"`。
- 配方（工作台）：3×3，地狱水晶围心形 + 中心 hell_stone。`hell_crystal` ×4 + `hell_stone` ×1。
- player_action 现有"持召唤道具右键→spawn_boss"通用逻辑，无需改；world.spawn_boss 加 `demon_lord` case。

## 掉落（神装，各自掷骰）
- `demon_trident`（恶魔三叉戟）：近战 sword，tool_tier 9，damage_mult 1.4，sword_style sweep。掉率 35%。
- `inferno_staff`（烈焰法杖）：法杖，连发追踪火球。掉率 30%。
- `demon_wings`（恶魔之翼）：accessory（持有即生效）= 二段跳 + 滑翔（空中按住跳缓降）。掉率 25%（最稀有）。
- `demon_helmet`/`demon_chest`/`demon_pants`（恶魔盔甲）：armor_slot，defense 14/22/14（略高于骷髅套 12/20/12）。各 40%。为将来"套装特效"埋料。
- `hell_crystal` ×3~6 保底。

## 恶魔之翼 accessory
- 把 player_controller `_has_cloud_boots()` 泛化为 `_has_double_jump_gear()` = has cloud_boots **或** demon_wings。
- 新增滑翔：持有 demon_wings + 在空中下落 + 按住 jump → `velocity.y` 限到缓降速度（如 ≤ 60）。

## 登记清单（每个新 item 必做，照 CLAUDE.md）
1. `item_db.gd` `_DEFS`：6 件 + demon_heart 共 7 条。
2. `crafting_panel.gd` `_ZH_NAMES`：7 个中文名。
3. `items_art.gd` `_ICONS` + `art_cache.gd` 写死清单：7 个图标。
4. `recipe_db.gd`：demon_heart 配方。
5. 掉落写在 `demon_lord.gd` 死亡。

## 文件
- 新建：`scripts/entities/demon_lord.gd`、`scenes/entities/demon_lord.tscn`、`scripts/art/demon_lord_art.gd`。
- 改：`world.gd`(spawn_boss case + spawn_demon_lord)、`item_db.gd`、`crafting_panel.gd`、`items_art.gd`、`art_cache.gd`、`recipe_db.gd`、`player_controller.gd`(翼)。
- 测试：`tests/integration/test_demon_lord.gd`（spawn/受伤/死亡掉落/召唤道具/配方）、翼的二段跳测试归 player_controller 测试。

## 分步（每步一报告 + commit + 测试数）
- **T1 物品**：7 件 item + 中文名 + 图标 + 配方 + 登记。测试：item 存在 / 配方出 demon_heart / 召唤道具字段对。
- **T2 Boss 本体**：demon_lord.gd + art + tscn + spawn_boss + 掉落 + boss group + melee_hit_radius。测试：召唤出现 / 扣血 / 死亡掉落。
- **T3 恶魔之翼**：滑翔 + 二段跳泛化。测试：持翼能二段跳 + 缓降。
