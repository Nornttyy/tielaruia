# Host 迁移设计（房主掉线自动换人接力）

> 状态：设计已与用户确认，待写实现计划
> 日期：2026-06-15
> 里程碑：联机健壮性（多人公共房）

## 1. 背景与目标

联机是 WebRTC P2P 星形拓扑：**房主（host）是唯一权威**，所有客户端（client）只跟房主连，
客户端之间**零直连**，互相通信全靠房主转发。公共房（生存房 `teilaruia-PUB-SV-<n>`）由
"谁先进谁当房主"产生 —— 第一个进的人的电脑跑整个世界。

**问题**：房主一走/掉线，他电脑上的世界就没了，所有客户端跟房主的连接断开，整局散掉。
目前代码只是清掉远程实体（`world.gd:_cleanup_remote_on_disconnect`），玩家卡在原地、房里其他人全消失。

**目标**：房主掉线时，自动选一个还在的客户端**接力当新房主**，其他人重连到他，
**几秒内**（弹「正在换房主…」遮罩）恢复同一局游戏。

**非目标（本期不做）**：
- 私人房（房间码）迁移 —— 朋友局散了可手动重开，优先级低，设计兼容但本期不实现/测。
- PvP 对战房迁移 —— 对战局短命，本期不做。
- 真·无感（玩家完全察觉不到）—— P2P 里做不稳；本期接受"短暂换房主中…几秒"。
- 世界状态 100% 一致 —— 接受新房主的世界副本（几乎一致）作为新权威。

## 2. 当前架构（实现依据）

### 2.1 公共房怎么开/抢
- 房号格式 `teilaruia-PUB-<tag>-<index>`（`peerjs_bridge.js:_pubId`，`mp_rooms.gd:public_peer_id`）。
- `enter_public(tag)`（`peerjs_bridge.js:_tryJoinPublic`，从 `_pubIndex=1` 起试）：
  - 房号无人（`peer-unavailable`）→ `_hostPublic` **自己当房主**。
  - 房号有人 → 以 client 身份连上（**加入**）。
  - 房满（收到 `{__full:1}`）/ 幽灵房 → `_nextRoom` 跳下一号。
  - 脑裂保护：host/client 身份翻转 > 6 次 → 换房号重来。
- `is_host`（`network_manager.gd:59`）每帧从 bridge 同步（`is_host = bool(_bridge.is_host())`）。

> **复用点**：`enter_public` 这套"先试着加入、没人就自己当房主"的逻辑，
> 正好是重连 + 选举的现成机制 —— 迁移时让大家重跑 `enter_public` 到**同一个房号**即可。

### 2.2 房主掉线现在走哪
- `peerjs_bridge.js:89-95`：client 到 host 的 DataConnection `close` → `bridge._status = 'disconnected'`。
- `network_manager.gd:_poll_bridge`（每 0.1s）→ 状态变化 emit `status_changed`。
- `world.gd:_on_mp_status_changed`：`disconnected/error` → `_cleanup_remote_on_disconnect()`（只清远程实体，**不回菜单、不重连**）。

> **缺口 ①**：掉线后没有任何自动处理（既不回菜单也不迁移）。这是接入点。

### 2.3 客户端知道房里有谁吗
- client 侧有 `world.gd:_remote_players`（key=peer_id），知道**谁来过**，但**没有加入顺序/时间戳**。
- 全量 peer 列表只有 host 有（`peerjs_bridge.js:get_peer_ids`，`network_manager.gd:_all_peer_ids`）。
- 新人加入：host 收到 `__peer_join` → emit `peer_joined` → `world.gd:_on_peer_joined`。

> **缺口 ②**：没有"接班顺序"。客户端互相失联后无法商量，必须靠房主**提前下发**有序名单。

### 2.4 房主独有职责（新房主要全部接管）
| 职责 | 消息 | 说明 |
|---|---|---|
| 初始握手 | `hello` | seed/世界大小/难度/房间模式 |
| 世界改动快照 | `init_state` | 当前 `chunk_deltas`（挖/放的方块） |
| 实体位置同步 | `ent_pos` | 每 0.2s 广播怪/动物位置+血+朝向+动画 |
| 实体死亡 | `ent_die` | 杀怪后广播 |
| 实体伤害权威 | 收 `ent_dmg` | client 请求 → host 在真怪上 `take_damage` |
| 掉落权威 | 收 `drop_req` → 发 `drop_pos` | client 请求 → host 权威 spawn |
| 时间天气 | `time` | 每 5s |
| 转发玩家消息 | relay | `pos/name/chat/pdead/pres/tile/tile_batch/chest/drop_pick/pkill`（`mp_rooms.gd:_RELAY_TYPES`） |

- client 端**不刷怪**（`world.gd:719-720`），只收 `ent_pos`。新房主接管 = 开始权威刷怪 + 转发。

### 2.5 重连机制
- **缺口 ③**：没有"自动重连到刚才的房"的代码。只有 `host()/join(code)/enter_public(tag)/disconnect_room()`。
- 但 `enter_public` 本身可作为重连入口（重跑即可）。

### 2.6 消息分发
- `network_manager.gd:_route_message`（189-298）：见 2.4 表。
- relay：host 收到 client 的 relay 类消息 → 转给其他 client（`mp_rooms.gd:relay_targets`，除来源）。

## 3. 核心挑战

**客户端之间零直连，房主一走大家互相失联** ⇒ **选举不能在故障发生后协商**。
解决：房主**活着时周期性广播"接班顺序名单"**，每个客户端存下来；房主一走，
各自**用本地存的同一份名单独立算出同一个答案**，无需互相通信。

## 4. 设计

### 4.1 接班名单（roster）广播
- **新消息 `roster`**：host → client，内容是**按加入顺序排列的 peer_id 列表**（含 host 自己在 `[0]`）。
- host 维护 `_roster: Array[String]`：
  - 自己 `my_peer_id()` 放 `[0]`。
  - `peer_joined` 时 append 新 peer_id（保持加入顺序）。
  - `peer_left` 时移除。
- 变化时 + 每 ~5s 心跳，广播一次 `roster`。
- client 收到存到 `world` 的 `_known_roster`。
- **稳定性**：用 peer_id 做身份（PeerJS 分配，连接生命周期内稳定）。

> **"待最久"= 名单里除 host 外最靠前的 = `_known_roster[1]`**（最早进的客户端）。

### 4.2 检测房主掉线（接入点）
- `world.gd:_on_mp_status_changed` 的 `disconnected/error` 分支：
  - 若**不在房主迁移流程中** 且 `room_mode != "pvp"` 且**之前是 client**（非 host 自己关）→ 进入迁移流程 `_begin_host_migration()`。
  - 用 `room_mode`（不是 `is_pvp()/connected()`，后者在断线窗口为 false）判断。沿用本仓库既有教训。

### 4.3 选举新房主（纯逻辑，可单测）
- `_begin_host_migration()`：
  - `var order := _known_roster`（去掉 `[0]` 那个旧 host）→ `successors := order.slice(1)`。
  - `my_rank := successors.find(my_peer_id())`（我在接班队列里第几，0 起）。
  - 找不到自己（名单过期 / 我刚进还没收到 roster）→ 用 `(successors.size() + 1)` 当 rank：
    排在所有已知接班人之后；**即使名单为空也至少等 1×STAGGER**，给"可能有别人先接"留窗口，
    不会 0 秒就抢着当房主（防一堆没名单的新客户端同时自封房主）。
- **错峰**：等待 `my_rank * STAGGER` 秒后重跑 `enter_public(同一房号 index)`。
  - `rank 0`（待最久的幸存者）等 0 秒 → 立刻重开房 → 房号空 → **当新房主**。
  - `rank 1` 等 `STAGGER` 秒 → 重跑 `enter_public` → 此时房号已被 rank0 占 → **加入**。
  - 若 rank0 也掉了（房号仍空）→ rank1 等到点重开 → **当新房主**（**级联兜底**自动成立）。
- `STAGGER` 取 ~2.5s（> 抢占+注册到信令服务器的耗时，防雷鸣惊群 / 脑裂）。
- **这套"先试着加入、没人就当房主"正是 `enter_public` 现成行为** —— 迁移逻辑只需控制
  "等多久 + 重跑 enter_public 到原房号"，选举/重连交给现成机制。

### 4.4 新房主重开房 + 4.5 其他人重连
- 都走**同一个动作**：错峰后 `enter_public(tag, 原 _pubIndex)`。
  - 要点：重开必须锁定**原房号 index**（不要又从 1 开始扫），否则可能落到别的房号、把人拆散。
  - bridge 侧加/改一个"重进指定 index"的入口（实现计划细化）。
- 连上后 `is_host` 由 bridge 自然同步，谁抢到房号谁 `is_host=true`。

### 4.6 状态接管
- **世界**：新房主用自己本地世界副本（同 seed + 已同步的 `chunk_deltas`，与旧房主几乎一致）当新权威。
  - 新房主在 `_on_peer_joined` 时照常发 `hello` + `init_state`（现成）。
  - 重连的 client 收到后，以新房主的 `init_state` 为准（既有逻辑会 apply chunk_deltas）。
- **实体（怪/动物）**：新房主从"不刷怪的 client"切到"权威刷怪"。
  - 切换点：`is_host` 变 true 后，开始跑刷怪 + `ent_pos` 广播。
  - 现存的远程实体（client 期的影子怪）清掉，由新房主重新刷 —— **怪会"重置"一下**（用户已接受）。
- **玩家自身**：背包/位置/血是本地状态，迁移期间**不动、不丢**。
  - 重连后重新广播自己的 `name/pos`（现成，`_on_peer_joined`/重连握手时发）。

### 4.7 体验（UX）
- 进入迁移 → 显示遮罩「**正在换房主…**」（HUD 层一个全屏半透明 + 文字）。
- 重连成功（`status` 回 `connected`）或当上新房主 → 撤掉遮罩，继续玩。
- 超时（见 4.8 兜底）→ 提示「换房主失败，已转单机」或回菜单。

## 5. 边界情况

1. **接班人也同时掉了**：级联兜底（4.3）—— 下一名次等到点自动重开。
2. **脑裂（俩人同时以为自己该当房主）**：错峰 STAGGER 把同时性打散；bridge 既有脑裂保护（翻转>6→换号）兜最后一层。但换号会拆散人，是**失败态**，遮罩超时后转单机。
3. **迁移途中新房主又掉了**：新房主一旦 `is_host`，对其它人就是"房主掉线"，再触发一次迁移（名单由新房主已重新广播）。
4. **只剩我一个**：`successors` 里只有自己 → 我重开房当房主（一个人的房），或直接转单机继续。取后者更省事：`_known_roster` 去掉 host 后只剩自己 → 不重连，静默转单机（保留世界，继续玩）。
5. **旧房主只是卡顿没真掉**：bridge 的 `close` 事件才触发；短暂卡顿不会误判。若旧房主"回来"了，他会发现房号被占→走 client 流程加入（变成普通客户端）。
6. **名单过期**（我刚进还没收到 roster 就房主掉了）：`my_rank` 兜底排最后，等其他人先选；若没人选我最后兜底当房主。
7. **PvP 房**：本期 `room_mode=="pvp"` 直接**不迁移**（维持现状回菜单/散），4.2 已门控。

## 6. 范围与分期

**本期只做公共生存房（SV）。** 私人房 / PvP 房设计兼容但不实现。

实现分阶段（每阶段可单独验收）：

- **P1 — 名单基建**：host 维护 + 广播 `roster`，client 存 `_known_roster`。无行为变化，纯数据。
  - 验收：GUT 单测 roster 维护（加入/离开顺序正确）；联机抓日志确认 client 收到名单。
- **P2 — 选举 + 重连核心**：掉线检测 → 错峰 → 重跑 enter_public 到原房号 → 遮罩 UI。
  - 验收：GUT 单测纯选举逻辑（给定名单+我的 id → 算出 rank/是否当房主/等待时长）；
    联机真机测：3 人公共房，房主关掉，另两人是否一人接力、一人重连。
- **P3 — 状态接管**：新房主切权威刷怪 + 重发 init_state；重连方以新房主状态为准。
  - 验收：联机真机测：迁移后怪正常刷、方块改动还在、能继续一起玩。
- **P4 — 边界兜底**：级联、只剩一人转单机、超时转单机、迁移途中再掉。
  - 验收：联机真机测各情形不崩、不卡死。
- **P5（可选/以后）**：扩展私人房（同房间码重开）、PvP 房。

## 7. 测试策略

- **能单测的**（纯逻辑，无网络）：
  - roster 维护：加入/离开后顺序正确。
  - 选举：给定 `_known_roster` + `my_peer_id` →（rank、是否当新房主、等待秒数）。
  - 把这块逻辑抽成**纯函数 / 独立类**（不依赖 bridge），方便 GUT 跑。
- **只能真机测的**（沙盒无法测联机）：抢房号时序、重连、状态接管、脑裂 —— 靠用户多设备重度测。
- 沿用约定：`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit`。

## 8. 关键设计决策小结

- **选举靠"提前下发的有序名单 + 错峰重连"**，不靠故障后协商（客户端已互相失联）。
- **重连复用 `enter_public` 现成的"先加入否则当房主"逻辑** —— 迁移代码只管"等多久 + 重跑到原房号"。
- **"待最久"= 名单里最早进的幸存客户端**（`_known_roster` 去 host 后的第一个）。
- **怪会重置一下、世界以新房主副本为准** —— 用户已接受的取舍。
- **PvP / 私人房本期不做**，门控在 `room_mode`。
- 选举纯逻辑**抽成可单测的独立单元**，其余靠真机测。
