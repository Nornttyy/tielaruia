# PvP 公共对战房 设计文档

> 状态: 已与用户确认设计。前置: 多人公共房已上线 (见 2026-06-09-public-multiplayer-rooms-design.md)。
> 这是起床战争的战斗地基。

## 目标

新建「公共对战房」: 玩家点一下进去, 用剑+弓互相打, 死了回出生点满血复活, 屏幕显示击杀榜。只有这个房能 PvP; 生存房/私人房依旧不能打。

## 范围

**本期做:**
1. 公共对战房: 复用多人公共房机制, 房号 `teilaruia-PUB-PVP-<i>`, 满了顺延。房间带"对战模式"标记 (room_mode="pvp")。
2. 对战房不刷怪 (史莱姆/僵尸/动物全不刷)。
3. 进对战房开局给战斗装备 (替代生存起步包): `iron_sword`×1 + `wood_bow`×1 + `wood_arrow`×99 + `stone`×64 + 穿上 `iron_helmet`/`iron_chest`/`iron_pants`。
4. 打人: 剑(近战) + 弓箭 命中玩家 → 扣血 + 闪红 + 击退。只在 room_mode="pvp" 生效。
5. 死亡: 回出生点满血复活 (几秒后自动), 不掉物品 (装备留着)。
6. 击杀榜: 屏幕角落显示每个玩家击杀数。

**不做 (Out of scope):**
- 法术/法杖打人 (本期只剑+弓; 火球同步复杂, 以后)。
- 队伍/床/商店/资源生成器 (那是起床战争, 复用本期 PvP 地基后另起项目)。
- 玩家之间物理碰撞 (设计上就穿过, 见 [[feedback_no_creature_collision]])。
- 防御/盔甲减伤公式细化 (用现有 defense 字段; 不新增机制)。

## 关键现状 (实现者必读)

- **伤害走"各管各的血"**: 见 [[project_multiplayer_state]]。怪打玩家是各端本地判定打本地玩家 (`PlayerHealth.take_damage` 带 iframe)。PvP 照此: 攻击方判定命中 → 发消息给被打方 → **被打方在自己这端扣自己的血**。不做中央权威 HP。
- 近战命中: `scripts/player/player_action.gd` `_melee_hit_check` 扫 `["slimes","animals"]` 组, 用 `melee_hit_radius()`, 调 `_deal_enemy_damage(target, dmg, src, kb)`。`_deal_enemy_damage` 对 `is_remote` 怪发 `ent_dmg` 消息, 否则本地 `take_damage`。
- 弓箭: `scripts/entities/arrow.gd` 自己检测命中 (扫敌人组)。
- 刷怪: `world._process` 里 `_slime_spawn_timer`/`_animal_spawn_timer` 驱动 (line ~669)。client 已跳过 (host 权威)。
- 起步包: `main.gd._grant_starter_inventory(player)` 给 `wood_pickaxe/axe/sword`。由 `_grant_starter_on_new_game` 在新游戏调。
- 死亡/复活: 玩家死 → `main.gd._notify_remote_death` + 死亡画面; `_on_respawn` → `world.respawn_player()` + `send_player_respawn`。死亡广播现有 `send_player_death`/`pdead` → `remote_player_death_received(peer_id)`。
- 远程玩家: `scripts/entities/remote_player.gd` 有 `set_dead(bool)`; world 用 `_remote_players` 字典 (peer_id→节点), `get_remote_player(peer_id)`。
- 房间/模式: `NetworkManager.enter_public(tag, ...)`; hello 同步 seed/size/diff。PvP 要再加一个 `room_mode` 字段同步。

## 架构

**沿用 host 权威 + 各管各的血**。新增一个"房间模式"维度贯穿: `room_mode ∈ {"survival","pvp"}`。

### room_mode 同步
- `NetworkManager.room_mode: String = "survival"`。
- `enter_public("PVP", ...)` 设 `room_mode="pvp"` (host 端); `enter_public("SV", ...)` 设 "survival"。
- 私人房 host()/join() = "survival"。
- hello 带 `mode` 字段: host 连上发 hello 时塞 `room_mode`; client 收 hello → 设自己的 `room_mode`。这样 client 也知道在 PvP 房。
- `NetworkManager.is_pvp() -> bool { return connected() and room_mode == "pvp" }`。

### 打人 (伤害同步)
- 新消息 `pdmg`: `{type:"pdmg", to:<victim peer_id>, dmg:int, kb:float, sx:float, sy:float, by:<attacker peer_id>}`。
- 攻击方 (本地玩家挥剑/箭命中某远程玩家 sprite):
  - melee: `_melee_hit_check` 在 `is_pvp()` 时**额外扫** `"remote_player"` 组; 命中半径用远程玩家的 `melee_hit_radius()`。命中 → `NetworkManager.send_player_damage(victim_pid, dmg, kb, src)` + 本地给该远程玩家 `flash_hit()` (乐观反馈)。
  - 弓箭: `arrow.gd` 在 `is_pvp()` 时也检测远程玩家命中 → 同样发 `pdmg` + flash。
- host 转发: `pdmg` 是玩家个体消息 → host 收到转发给目标 (现有 relay 机制; `pdmg` 加入可转发类型, 但只需发给 `to` 那个 peer — 用 `send_to`)。
- 被打方收到 `pdmg` 且 `to == my_peer_id`: 调本地 `PlayerHealth.take_damage(dmg, src, kb)` (带 iframe 防连击)。记下 `_last_attacker = by` (用于击杀归属)。
- 防误伤: 所有命中检测 + take_damage 都 `if NetworkManager.is_pvp()` 才生效。

### 死亡 + 复活 + 击杀
- 被打方血到 0 → 本地死亡。死亡时广播 `pkill {type:"pkill", killer:<_last_attacker>, victim:<my_peer_id>}` (除了现有 pdead 视觉)。
- 所有端收 `pkill` → 击杀榜 `killer` 计数 +1 (字典 peer_id→kills)。
- PvP 房死亡 = 几秒后自动回出生点满血复活 (不弹"你死了点复活"按钮, 不掉物品)。复活后广播 `pres`。
  - 实现: 死亡流程在 PvP 房分支 → 不显示常规死亡掉落 + 启动 ~3s Timer → `world.respawn_player()` (满血) + `send_player_respawn`。
- 击杀榜 UI: 新 `scripts/ui/pvp_scoreboard.gd` (CanvasLayer), 右上角列 `名字 ×击杀数`, 只在 `is_pvp()` 显示。监听 `kill_scored(killer_pid, victim_pid)` 信号刷新。本地玩家用本地名, 远程用 `remote_player_name`/peer_id。

### 不刷怪 + 给装备
- `world._process` 刷怪段: `if NetworkManager.is_pvp(): 跳过 slime/zombie/animal 刷新` (作物/门照常)。
- 开局装备: `main.gd._grant_starter_inventory(player)` 在 `is_pvp()` 时改发 PvP loadout (见范围 3), 用 `inv.pickup(...)` + `inv.set_armor(slot, {...})`。

## 组件与文件

- **Modify** `scripts/net/network_manager.gd`: `room_mode` 字段 + `is_pvp()` + `enter_public` 设 mode + hello 带 `mode` + `send_player_damage` + `pdmg`/`pkill` 路由 + `kill_scored`/`player_damaged` 信号。
- **Modify** `scripts/web/peerjs_bridge.js`: `enter_public` 已支持任意 tag (PVP 直接复用); 无需大改 (确认 tag 透传)。
- **Modify** `scripts/player/player_action.gd`: melee 命中扫 `remote_player` 组 (pvp 时); 命中发 `send_player_damage`。
- **Modify** `scripts/entities/arrow.gd`: pvp 时检测远程玩家命中 → 发伤害。
- **Modify** `scripts/entities/remote_player.gd`: `flash_hit()` (受击闪红); `melee_hit_radius()` (供命中检测)。
- **Modify** `scripts/player/player_health.gd` 或 `main.gd`: 收到 `pdmg` → 本地 take_damage; 死亡时广播 pkill + PvP 自动复活分支。
- **Modify** `scripts/world/world.gd`: pvp 时不刷怪。
- **Modify** `scripts/main.gd`: pvp loadout; pvp 自动复活。
- **Modify** `scripts/ui/main_menu.gd` (+ .tscn): 房间区加「⚔️ 公共对战房」按钮 → `enter_public("PVP", ...)`。
- **Create** `scripts/ui/pvp_scoreboard.gd`: 击杀榜 UI。
- **Modify** `scripts/locale/strings_*.gd`: `mp_public_pvp` 文案 (4 语言)。
- **Create** `tests/unit/test_pvp_combat.gd` / 扩 `test_network_protocol.gd`: room_mode + pdmg 路由 + 击杀计分纯逻辑。

## 数据流: 一次击杀

1. A 在对战房挥剑命中 B 的远程 sprite → A 端: `send_player_damage(B, 8, kb, srcA)` + B 的 sprite 闪红。
2. host 收 `pdmg(to=B)` → `send_to(B, ...)` 转给 B (若 A 是 host 则直接发 B; 若 A 是 client, host 中转)。
3. B 端收 `pdmg(to=B自己)` → `PlayerHealth.take_damage(8, src, kb)` (iframe 内忽略) + 记 `_last_attacker=A`。
4. B 血到 0 → B 广播 `pkill(killer=A, victim=B)` + 进入死亡。所有端击杀榜 A+1。
5. B 端 ~3s 后 `respawn_player()` 满血 + 广播 `pres` → 各端 B 的 sprite 复活显示。

## 错误处理
- `pdmg` 的 `to` 不是自己 → 忽略 (转发途中经过的端不扣血)。
- 非 pvp 房收到 `pdmg` (异常/老消息) → 忽略。
- `_last_attacker` 为空 (自杀/掉虚空) → pkill 不计给任何人 (killer 空则跳过)。
- host 离开 → 沿用公共房逻辑 (client 回菜单)。
- iframe 防连击 (剑连挥 / 多人同时打) 复用 PlayerHealth 现有无敌帧。

## 测试策略
- 纯逻辑 (headless 可测): `room_mode`/`is_pvp` 切换; `pdmg` 路由 (`to==me` 才处理); 击杀榜计分 (pkill → 字典+1, 空 killer 不计); pvp loadout 物品清单正确。
- 命中检测 / arrow / UI: 桌面集成测 (实例化玩家+远程玩家, 模拟命中调 send_player_damage), 真机网页手测 2-3 人对打。
- 复用现有联机集成测风格 (信号驱动)。

## 后续
- 法术打人 / 更多武器。
- 队伍 + 床 + 商店 + 资源生成器 + 胜负 = 起床战争 (复用本期 PvP + 多人地基)。
