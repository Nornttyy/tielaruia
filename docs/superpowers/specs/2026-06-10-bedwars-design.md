# 起床战争 (Bed Wars) 公共房 设计文档

> 状态: 已与用户确认设计 (完整版, 单人混战, 分批做)。
> 前置: 多人公共房 + PvP 战斗 + 对战竞技场 已上线 (见 2026-06-09-public-multiplayer-rooms / pvp-combat / pvp_arena)。

## 目标

新建「起床战争房」公共房: 每人一座出生岛 (床+资源点+商店)。床在能复活, 床被砸再死出局, 最后活着的赢。
资源生成器冒铁/金, 商店买装备。固定地图, 各端本地生成同图。

## 玩法 (单人混战, 非分队)

选单人混战而非红蓝队: 公共房随时进人、人数不定 (1..8), 每人独占一岛最简单、对任何人数都成立。

- 进房 → 按 **加入顺序 (slot)** 分一座岛 (岛 0/1/2…)。岛上: 一张**床** + **铁生成点** + **商店点**。中央大岛冒**金**。
- 🛏️ **床在** → 死了 3s 回自己岛复活。**床被砸** (任何人挖掉) → 床主再死即**出局** (转观战 + 广播)。
- ⚔️ 打架 = 现成 PvP (剑+弓)。地图固定 (BedwarsArena stamp, 各端同坐标 = 公平)。
- ⛲ 资源生成器: 岛上每隔几秒在生成点冒 1 个 `iron_ingot` drop; 中央岛冒 `gold_ingot` (更慢)。
- 🛒 商店: 走到商店点按交互键 → 购买面板, 用铁/金买 方块/剑/弓/盔甲。
- 🏆 胜负: 只剩 1 人没出局 → 全屏"胜利"; 其余出局者看"出局"。

## 关键现状 (实现者必读)

- **床已是现成 tile**: `Tiles.BED=65` (床头, 复活点) + `Tiles.BED_RIGHT=87` (床尾)。砍任一半 player_action 联动消整张。bedwars 用它当"床"。
- **room_mode**: NetworkManager 现有 `room_mode ∈ {survival, pvp}` + `is_pvp()`。`is_pvp()` 被 main(竞技场/装备/复活)、world(不刷怪)、arrow/player_action(打人)、pvp_scoreboard 用。
  - **bedwars 要 combat + 不刷怪 (跟 pvp 同) 但 地图/装备/复活/胜负不同**。所以**不能**简单把 bedwars 塞进 is_pvp()。
  - 方案: 加 `room_mode="bedwars"` + `is_bedwars()`; 加 `combat_enabled()` = `is_pvp() or is_bedwars()` (打人/不刷怪/箭命中玩家用它)。main 里 PvP 专属分支 (PvpArena/PvP 装备/3s 复活) 保持 `is_pvp()`; bedwars 走自己的分支。
- 资源/掉落: `item_drop.tscn` + `iron_ingot`/`gold_ingot` item。世界 spawn drop 见 world `_on_remote_drop_request`/`ItemDropScene`。
- 竞技场 stamp 范式: `scripts/world/pvp_arena.gd` `build(world)` 用 `world._set_tile` + 清背景墙 + minimap mark + 空气墙。bedwars 照此写 `bedwars_arena.gd`。
- 公共房进入: main_menu `enter_public(tag,...)`; tag "BW" → room_mode="bedwars"。固定 seed/永久白天同 pvp。

## 架构

**host 权威 + 各端本地生成同图 + 关键状态 host 广播**。新 `room_mode="bedwars"`。

### 岛屿分配 (slot)
- BedwarsArena 固定 N 座岛 (横排, 中间金岛)。岛 i 在固定坐标。
- 每个玩家一个 **slot (0..MAX-1)**。host 权威分配: 玩家进房 → host 给个空 slot → 广播 `bw_assign {pid, slot}`。各端记 pid→slot, 把该玩家出生点设到岛 slot。本端玩家 = 自己的 slot。
- 床归属: 岛 i 的床属于 slot=i 的玩家。

### 床 + 复活 + 出局
- 床被破 (挖到 BED/BED_RIGHT): 走现有 tile 同步 (`tile`/`tile_batch` 广播)。host 检测某岛床没了 → 标记该 slot "无床"。
- 玩家死: 若自己 slot 床在 → 3s 回岛复活 (同 pvp 自动复活但回自己岛); 床没了 → **出局** (广播 `bw_out {pid}`), 转观战 (隐藏/不可动, 或踢到旁观)。
- 胜负: host 数"未出局玩家", 剩 1 → 广播 `bw_win {pid}`; 各端弹 胜利/出局 UI。

### 资源生成器
- 每岛生成点 + 中央金点。host 权威: 每 interval 在生成点 spawn drop (经现有 drop 同步广播给各端)。只 host 跑生成 (client 收同步)。

### 商店
- 岛上商店点 (一个特殊 tile 或标记)。玩家靠近按交互 → 开 `bedwars_shop.gd` 购买面板 (CanvasLayer)。
- 买: 扣背包里 iron/gold → 给物品 (方块/剑/弓/盔甲)。本地操作 (各管各背包, 不需同步; 物品进背包后用现有挖/放/战斗同步)。

## 组件与文件

- **Create** `scripts/world/bedwars_arena.gd`: stamp 地图 (N 岛 + 床 + 生成点标记 + 商店点 + 中央金岛); 返回各 slot 出生坐标 + 生成点坐标。
- **Create** `scripts/net/bedwars_manager.gd` (或并入 main): slot 分配 / 床状态 / 出局 / 胜负 (host 权威 + 广播); 资源生成 tick。
- **Create** `scripts/ui/bedwars_shop.gd`: 购买面板 (CanvasLayer)。
- **Create** `scripts/ui/bedwars_hud.gd`: 显示各岛床状态 + 剩余人数 + 胜利/出局横幅。
- **Modify** `scripts/net/network_manager.gd`: room_mode "bedwars" + `is_bedwars()` + `combat_enabled()`; 新消息 `bw_assign`/`bw_out`/`bw_win` (+ 资源生成走现有 drop)。
- **Modify** `scripts/main.gd`: bedwars 分支 (建 BedwarsArena + bedwars 装备包 + bedwars 死亡/复活/出局 + 建 shop/hud)。
- **Modify** `scripts/world/world.gd`, `arrow.gd`, `player_action.gd`: 把 `is_pvp()` 的"打人/不刷怪"门控换成 `combat_enabled()` (pvp + bedwars 都生效)。
- **Modify** `scripts/ui/main_menu.gd` (+ .tscn): 房间区加「起床战争房」按钮 → `enter_public("BW",...)`。
- **Modify** `scripts/locale/strings_*`: `mp_public_bedwars` + shop/hud 文案。
- **Tests**: bedwars_arena 生成、slot 分配纯逻辑、床破→出局判定、combat_enabled。

## 分批做 (每批可玩 + 推送)

- **Phase 1 (地基, 先能玩)**: room "BW" + combat_enabled 重构 (打人/不刷怪在 bedwars 也生效) + BedwarsArena 地图 (岛+床) + bedwars 装备包 (木剑+一叠方块) + 主菜单入口。先当"有床有岛的对战场"玩 (床/复活先按 pvp 3s 复活, 不判出局)。
- **Phase 2 (起床规则)**: slot 分配 + 床归属 + 床破→出局 + 回自己岛复活 + 胜负 UI。
- **Phase 3 (资源)**: 铁/金生成器。
- **Phase 4 (商店)**: 购买面板。

## 错误处理
- 人满/中途进/离开: 复用公共房 (满顺延、host 走散房)。出局者离开释放 slot。
- 床破检测: host 权威 (host 看 tile 状态); client 只收 bw_out 结果。
- 非 bedwars 房收到 bw_* 消息 → 忽略。

## 测试策略
- 纯逻辑 headless: combat_enabled 真值表; slot 分配 (空位挑选); 床破→该 slot 失去复活; 胜负 (剩 1 人)。
- 地图: bedwars_arena 生成岛/床在位 (boot_to_game + build, 同 pvp_arena 测法)。
- 商店: 扣资源给物品纯逻辑。
- 真机网页手测多人对战。

## 后续 (不在本期)
- 红蓝队模式 / 更多岛 / 更丰富商店 / 排行榜。
