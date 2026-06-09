# PvP 公共对战房 Implementation Plan

> REQUIRED SUB-SKILL: subagent-driven-development 或 executing-plans。Steps 用 `- [ ]`。
> 设计: docs/superpowers/specs/2026-06-09-pvp-combat-design.md

**Goal:** 公共对战房 — 剑+弓打人, 各管各血, 死了回出生点满血复活, 击杀榜, 不刷怪, 战斗开局包。

**Architecture:** host 权威 + 各管各的血 + 新增 `room_mode` ("survival"/"pvp") 贯穿。攻击方判定命中→发 `pdmg`→被打方扣自己血。

**测试前提:** 先 `godot --headless --editor --quit`。单测 `godot --headless -s addons/gut/gut_cmdln.gd -gselect=<file.gd> -gexit 2>&1 | grep -v libfontconfig`。

---

## Task 1: room_mode + is_pvp + hello 同步

**Files:** `scripts/net/network_manager.gd`, `tests/unit/test_network_protocol.gd`

- [ ] 测试: hello payload 带 mode; 解析 hello 设 room_mode; enter_public("PVP") 设 room_mode="pvp"; is_pvp() 仅 connected+pvp 为真。
- [ ] 加 `var room_mode := "survival"`; `func is_pvp() -> bool: return connected() and room_mode == "pvp"`。
- [ ] `enter_public(tag, ...)`: `room_mode = "pvp" if tag == "PVP" else "survival"`。
- [ ] `host()`/`join()`: `room_mode = "survival"`。
- [ ] `_hello_payload` 加 `"mode": room_mode`; `send_hello` 传; hello case 解析 `room_mode = String(data.get("mode","survival"))` + `hello_received` 信号加 mode 参数 (或单独存 room_mode, 信号不变以减少改动 — 选: 存 room_mode 字段, 信号不加参, main_menu 不依赖)。
- [ ] `disconnect_room()` 重置 `room_mode="survival"`。
- [ ] commit `feat(pvp): NetworkManager room_mode + is_pvp + hello 同步对战模式`

## Task 2: pdmg/pkill 消息 + 击杀计分

**Files:** `scripts/net/network_manager.gd`, `tests/unit/test_network_protocol.gd`

- [ ] 信号: `player_damaged(to_pid, dmg, kb, sx, sy, by_pid)`, `kill_scored(killer_pid, victim_pid)`。
- [ ] `send_player_damage(to_pid, dmg, kb, x, y)`: send `{type:"pdmg", to, dmg, kb, sx, sy, by:my_peer_id()}`。
- [ ] `send_kill(killer_pid, victim_pid)`: send `{type:"pkill", killer, victim}`。
- [ ] `_route_message` 加 `pdmg` → emit player_damaged; `pkill` → emit kill_scored。
- [ ] host 转发: `pdmg`/`pkill` 加进可转发类型 (`pdmg` 只需到 `to`; 简单起见 pkill 广播给所有)。pdmg 用 `send_to(to, ...)`; 在 `_relay_if_needed` 特判 pdmg: 只发给 `to`。
- [ ] 测试: pdmg payload 带 by; route pdmg emit; route pkill emit。
- [ ] commit `feat(pvp): pdmg/pkill 消息 + 路由 + 击杀计分信号`

## Task 3: 对战房不刷怪 + 战斗开局包

**Files:** `scripts/world/world.gd`, `scripts/main.gd`, `tests/...`

- [ ] world `_process` 刷怪段: `if NetworkManager != null and NetworkManager.is_pvp(): ` 跳过 slime/zombie/animal (作物/门照常)。
- [ ] `main.gd._grant_starter_inventory`: `if NetworkManager and NetworkManager.is_pvp(): _grant_pvp_loadout(player) else 原起步包`。
- [ ] `_grant_pvp_loadout(player)`: inv.pickup iron_sword×1, wood_bow×1, wood_arrow×99, stone×64; set_armor("helmet",{item_id:"iron_helmet",count:1}) 同理 chest/pants。
- [ ] 测试: 纯逻辑 — pvp loadout 物品清单 (可把清单抽成常量数组测); 不刷怪靠手测/集成。
- [ ] commit `feat(pvp): 对战房不刷怪 + 开局战斗装备包`

## Task 4: 打人命中 (剑 + 弓)

**Files:** `scripts/entities/remote_player.gd`, `scripts/player/player_action.gd`, `scripts/entities/arrow.gd`

- [ ] remote_player: `func melee_hit_radius() -> float: return 8.0`; `func flash_hit()` (modulate 闪红 0.15s 回正)。
- [ ] player_action `_melee_hit_check`: `if NetworkManager and NetworkManager.is_pvp():` 额外遍历 `get_tree().get_nodes_in_group("remote_player")`, 命中半径内 → `NetworkManager.send_player_damage(rp.peer_id, dmg, kb, tip)` + `rp.flash_hit()`。
- [ ] arrow.gd: 命中检测里 pvp 时也扫 remote_player → 同样发伤害 + flash + 箭消失。
- [ ] 测试: 集成 — 实例化远程玩家在范围内, 调命中, 断言 send_player_damage 被调 (用 watch 或假 NM)。
- [ ] commit `feat(pvp): 剑+弓命中远程玩家 → 发伤害 + 闪红`

## Task 5: 收伤害扣血 + 死亡 pkill + 自动复活

**Files:** `scripts/main.gd` (或新 `scripts/player/player_pvp.gd`), `scripts/player/player_health.gd`

- [ ] 接 `NetworkManager.player_damaged`: `if to == my_peer_id and is_pvp(): player.PlayerHealth.take_damage(dmg, Vector2(sx,sy), kb); _last_attacker_pid = by`。
- [ ] 玩家死亡 (PlayerHealth 血到 0 / 现有死亡信号): pvp 时 → `NetworkManager.send_kill(_last_attacker_pid, my_peer_id)` (killer 空跳过) + 启 3s Timer → `world.respawn_player()` + `send_player_respawn`; **不掉物品**, 不弹常规死亡画面。
- [ ] 测试: 集成 — emit player_damaged(to=me) → 本地血减; 死亡 → send_kill 调。
- [ ] commit `feat(pvp): 收伤害扣本地血 + 死亡记击杀 + 几秒自动满血复活`

## Task 6: 击杀榜 UI + 主菜单对战房入口

**Files:** `scripts/ui/pvp_scoreboard.gd` (新), `scripts/ui/main_menu.gd` (+ .tscn), `scripts/locale/strings_*.gd`

- [ ] `pvp_scoreboard.gd` (CanvasLayer): 右上角 VBox, 监听 `kill_scored` → 字典 peer→kills, 刷新显示 "名字 ×N"。只 is_pvp 显示。main.gd 进游戏时建 (照 chat_box)。
- [ ] main_menu 房间区加 `PublicPvpButton` ("⚔️ 公共对战房") → `enter_public("PVP", PUBLIC_SV_SEED, ...)` (对战房也用固定 seed, 同一张图)。复用公共房进游戏流程 (host 用固定 seed 进; client 等 hello)。
- [ ] locale: `mp_public_pvp` 4 语言。
- [ ] 测试: 集成 — 按钮存在 + 回调; kill_scored → 榜单数字。
- [ ] commit `feat(pvp): 击杀榜 UI + 主菜单对战房入口`

## Task 7: 回归 + 部署
- [ ] `-gdir=res://tests/unit` 全绿。
- [ ] `./run.sh --rebuild` 桌面冒烟 (主菜单有对战房按钮)。
- [ ] push → 网页手测 2-3 人对打 (剑/弓扣血/死亡复活/击杀榜)。

---

## Self-Review
- room_mode 同步 (T1) ✅ · 打人伤害 (T2,T4,T5) ✅ · 不刷怪+装备 (T3) ✅ · 死亡复活+击杀榜 (T2,T5,T6) ✅ · 入口 (T6) ✅
- 各管各血/iframe 复用 ✅ · 仅 pvp 生效门控贯穿 ✅
- 已知靠手测: 真 WebRTC 多人对打、命中手感、UI 布局。
