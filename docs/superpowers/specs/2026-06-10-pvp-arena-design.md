# 对战房专属系统 + 生命药水 — 设计 spec

> 日期: 2026-06-10
> 状态: 设计已确认, 待实现 (在 git worktree 隔间做, 防与并发 PvP 窗口撞车)

## 背景

并发窗口已建好 PvP 基础: `NetworkManager.is_pvp()`, 击杀榜, 收伤害/死亡/3秒复活, 对战房不掉物品, 开局包 `main.gd:_grant_pvp_loadout` (剑+弓+箭+石头+铁甲)。本批在其上加"对战专属地图 + 战斗便利规则 + 生命药水"。

## 目标 (6 块)

1. **大型对称竞技场** — 对战房用专属固定地图 (非普通世界), 300 格宽 × 35 格高, 多层对称平台 + 中央高台, 两边对称出生。房内人人同图 (固定布局, 不靠随机) = 绝对公平。
2. **天然方块不可破坏 / 玩家放的可破坏** — 对战房里挖竞技场地形挖不动; 只有玩家自己放下的方块能挖。
3. **开局铁镐** — `_grant_pvp_loadout` 加 `iron_pickaxe` (配合挖玩家放的方块)。
4. **生命药水 (新道具, 全游戏通用)** — 喝下瞬间 +50 HP。镜像现有魔力药水 (`is_mana_potion` / 喝药流程)。
5. **对战房消耗品无限** — 对战房里放方块 / 射箭 / 喝生命药水**不消耗** (只对战房; 生存照常消耗)。
6. **不撞车** — 主体逻辑进新文件; 对热文件 (main.gd / player_action.gd) 只做最小局部改; 全程 git worktree 隔间 + 合并。

## 架构

### A. 竞技场 (新文件 `scripts/world/pvp_arena.gd`)
- `static func build(world) -> void`: 在世界坐标某固定区域 stamp 竞技场 (参考 `village_prefab` 的 stamp 方式: 往 `chunk_manager.set_tile` 写)。
- 布局 (300×35, 关于中线左右对称):
  - 底部 2-3 行实心地面 (STONE/PLANKS)。
  - 5 层左右对称的木平台 (WOOD_PLATFORM) 当掩体, 越上越窄。
  - 中央一座高台 (STONE 柱 + 顶平台)。
  - 两端对称出生台 (离中心远, 给弓拉开距离)。
- 钩入: `main.gd` 进对战房 (`is_pvp()`) 的世界初始化后, 调 `PvpArena.build(world)` + 把玩家出生点设到出生台。普通世界生成仍跑 (竞技场盖在其上的固定区域), 或在 pvp 时跳过普通地表填充 — 实现时取最小改动方案 (优先: 正常生成 + 竞技场覆盖一块, 出生点放竞技场内)。

### B. 天然 vs 玩家放置 (照 `_wall_deltas` 那套)
- `chunk_manager` 加 `_pvp_placed: Dictionary` (Vector2i → true), 记录对战房里玩家放下的格。
- 放方块 (player_action 放置成功后): 若 `is_pvp()` → `chunk_manager.mark_pvp_placed(coord)`。
- 挖方块 (player_action 挖掘入口): 若 `is_pvp()` 且 `not chunk_manager.is_pvp_placed(coord)` → 直接 return (挖不动天然地形)。
- 玩家放的格挖掉后: 从 `_pvp_placed` 移除。
- 进/退对战房清空 `_pvp_placed`。

### C. 生命药水 (新道具)
- `item_db._DEFS` 加 `"health_potion"` (tool_kind "", max_stack 99; 标记 heal_amount=50)。
- `item_db` 加 `func is_health_potion(id)` + `func heal_amount(id)` (镜像 `is_mana_potion`)。
- `crafting_panel._ZH_NAMES` 加 `"health_potion": "生命药水"` (规矩: 加 item 必同步中文名)。
- 玩家"喝药"逻辑: 找现有喝魔力药水的分支 (player_action), 加生命药水分支 → `PlayerHealth.heal(50)` (+ 进度条/动画复用)。
- 简单合成配方 (recipe_db): 用常见料 (如 apple ×2 + slime_jelly ×1 → health_potion), 同步 `_ZH_NAMES` output。
- 进 `_grant_pvp_loadout` (开局给几瓶)。

### D. 对战房消耗品无限
- 统一规则: 对战房里这些消耗不扣库存:
  - 放方块: player_action 放置成功后扣 1 的地方 → `if is_pvp(): 不扣`。
  - 射箭: 弓消耗箭的地方 → `if is_pvp(): 不扣`。
  - 喝生命药水: 消耗药水的地方 → `if is_pvp(): 不扣`。
- 实现为各消耗点一个 `if not is_pvp()` 守卫 (最小局部改)。

## 不撞车策略 (关键)
- 新逻辑 (竞技场生成 + placed 记录) 进**新文件** (`pvp_arena.gd`) 和 `chunk_manager` 的独立 dict (低冲突)。
- 对**热文件**只做最小局部改, 且集中可控:
  - `main.gd`: 竞技场 hook (1 处) + 开局包加铁镐/药水 (改 `_grant_pvp_loadout`)。
  - `player_action.gd`: 挖掘 gate (1 处) + 放置不扣 (1 处) + 射箭不扣 (1 处) + 喝生命药水分支 (1 处)。
  - `item_db.gd` / `recipe_db.gd` / `crafting_panel.gd`: 加道具/配方/中文名 (非并发热区, 安全)。
- 全程在 `git worktree` 隔间 (`.claude/worktrees/pvp-arena`) 做, 从主树复制 `.godot` 跑测试, 完成后合并回 main (冲突可见可解, 不会被悄悄卷走)。

## 测试 (GUT)
- 竞技场: `PvpArena.build` 后, 抽查地形写入 (底部实心 / 平台在位 / 左右对称: 中线两侧同 y 同 tile)。
- 天然不可破坏: 模拟 `is_pvp` + 挖天然格 → tile 不变; 挖 `_pvp_placed` 格 → 变 AIR。
- 生命药水: `is_health_potion("health_potion")` true; 喝 → HP +50 (封顶 max); `_ZH_NAMES` 有中文。
- 无限: 对战房放方块/射箭/喝药后库存数不减; 生存模式正常减。
- loadout: `_grant_pvp_loadout` 后背包含 iron_pickaxe + health_potion。
- 真机 (用户): 进对战房看竞技场、挖地形挖不动、放的能挖、药水回血、方块/箭/药无限。

## 风险
- **最大: 与并发 PvP 窗口撞车** → 全程 worktree + 最小热文件改 + 合并时解冲突 (见上)。
- 竞技场覆盖普通地形的边界 / 出生点落点 → 上机调。
- "喝生命药水"/"放置扣库存"/"射箭扣箭" 的确切代码位置实现时 grep 定位 (player_action 较大)。
