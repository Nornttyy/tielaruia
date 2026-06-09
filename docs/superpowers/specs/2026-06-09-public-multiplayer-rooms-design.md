# 多人公共房 设计文档 (Public Multiplayer Rooms)

> 状态: 已与用户确认设计, 待写实现计划。
> 前置: 自建 PeerJS 信令服务器已上线 (`tielaruia.onrender.com`, 见 `scripts/web/peerjs_bridge.js` 的 `PEER_HOST`)。

## 目标 (Goal)

在主菜单加"公共生存房": 玩家点一下直接进一个共享的生存世界, 不用输房间码。多人(>2)同时在一个房里。一个房满了自动开下一个房。

这一步只做**生存**公共房。PvP / 起床战争 是后续独立项目, 但本设计要把"多人"地基打好供其复用。

## 范围 (Scope)

**本期做:**
1. 联机从"最多 2 人"升级到"多人" (host 中转 / 星形拓扑)。
2. "公共房"加入机制: 固定房号 + 抢占式 host (谁先到谁当 host) + 房满自动顺延到下一号房。
3. 主菜单 UI 重构: 入口叫「多人游戏」, 面板上半「房间」(公共房按钮), 下半「加入房间」(现有输码加入)。
4. 公共生存房用固定地图 (固定 seed / size / difficulty)。
5. 多个远程玩家的 spawn / 移除 (按 peer id 管理)。

**本期不做 (Out of scope):**
- PvP / 玩家互相伤害 (现在 `remote_player.gd` 没有 HP/受击, 留给起床战争项目)。
- 起床战争玩法 (床/商店/资源生成器/分队/胜负)。
- 世界持久化 (host 离开后世界不保存; 固定 seed 保证地图一致, 但建造改动不留存——已与用户确认接受)。
- 房间列表/人数显示等花哨 UI。

## 关键现状 (实现者必读)

当前联机是 **2 人专用**:
- `scripts/web/peerjs_bridge.js`: 单个 `_conn`。host `on('connection')` 直接 `bridge._conn = conn` —— 第二个 client 连进来会覆盖第一个。`send()` 只发给这一条连接。
- `scripts/net/network_manager.gd`: `is_host` 单 bool; `send()` 发给唯一对端; `_route_message` 把消息 emit 成信号, 没有"来自哪个 peer"的概念。host 在 `_poll_bridge` 里 `status=="connected"` 时给唯一 client 发 hello。
- `scripts/world/world.gd`: 单个 `var _remote_player`; `_spawn_remote_player()` 只建一个, 名字写死 `"RemotePlayer"`; `_on_remote_pos` 等直接操作这一个。`remote_pos_received(x,y,facing,anim)` 等信号**不带 peer id**。
- `chat_box.gd`: 用组名 `"remote_player"` 定位对方头顶气泡 (单个)。

多人化要在以上每一层引入 **peer id** 维度。

## 架构 (Architecture)

**星形拓扑 (star) + host 权威 (host-authoritative)**, 沿用现有"host 是世界权威"的模型:

- **host = 中心**。所有 client 只连 host, client 之间不直连。
- client 发给 host 的消息, host **按需转发**给其它所有 client (中转 / relay)。例: client A 挖了方块 → 发给 host → host 应用 + 转发给 B、C。
- host 自己的广播 (时间天气/实体/initial_state) 发给**所有** client。
- 每个玩家用 **peer id** 唯一标识, 每端为"除自己外的每个 peer"维护一个 RemotePlayer。

为什么星形而非全连 (mesh): 沿用 host 权威, client 逻辑简单, 远程玩家/实体只有 host 一个权威源, 不会冲突。代价是 host 多做中转 (8 人量级可接受)。

## 组件与文件 (Components)

### 1. `scripts/web/peerjs_bridge.js` — 多连接 + 公共房抢占 + 转发

- 把单个 `_conn` 改为 **host 端连接表** `_conns` (map: peerId → conn); client 端仍是单条到 host 的连接 (`_hostConn`)。
- host `on('connection')`:
  - 若 `_conns` 已达上限 `MAX_PEERS` (默认 8, 含 host 自己算 1 → 实际 client 上限 7, 见下方"满"的定义) → 给该 conn 发一条 `{"__full":1}` 再 `close()` (礼貌拒绝)。
  - 否则加入 `_conns`, 设 `on('data'/'close'/'error')`。`on('close')` 时从 `_conns` 删除并记一条 peer-left 事件。
- `enter_public(roomTag)`: 公共房抢占 + 顺延逻辑 (见下节), 内部决定本端成为 host 还是 client。
- `send(jsonStr)`:
  - host → 发给 `_conns` 里所有连接。
  - client → 发给 `_hostConn`。
- `send_to(peerId, jsonStr)` (host 专用): 只发给某个 peer (转发时排除来源用)。
- 消息入队改造: 进队的每条消息要带**来源 peer id**, 让 GDScript 知道"谁发的"以决定是否转发 + spawn 哪个远程玩家。`pop_messages()` 返回的每项改为 `{"from": "<peerId>", "data": "<原始字符串>"}` 的 JSON (client 端 from 固定为 host 的 id 或常量 `"host"`)。
- **peer 加入/离开事件**: 通过特殊消息暴露给 GDScript, 例如入队 `{"from":"__sys","data":"{\"type\":\"__peer_join\",\"id\":\"...\"}"}` 和 `__peer_leave`。host 端在 `on('connection')`/`on('close')` 触发; client 端把"host 连接 open/close"映射为本端唯一对端的 join/leave。
- 新增查询: `get_peer_count()` (host 当前连接数), `is_host()` 已有。
- 保留现有重试/超时/`_gen` 机制。

### 2. 公共房加入机制 (enter_public)

公共房 = 一排固定房号: `teilaruia-PUB-<tag>-1`, `teilaruia-PUB-<tag>-2` ... (生存房 tag = `SV`)。

`enter_public(tag)` 从 1 号开始循环 (上限 `MAX_ROOMS`, 默认 20):
1. 尝试以 **client** 身份 `connect` 到 `teilaruia-PUB-<tag>-<i>`。
2. 结果分支:
   - **连上且没被拒** → 成为该房 client, 结束。
   - **被拒 (`__full`)** → `i++`, 回到 1 (这房满了, 试下一号)。
   - **`peer-unavailable` (没人开这号房)** → 尝试以 **host** 身份 `new Peer('teilaruia-PUB-<tag>-<i>')` 抢占:
     - 抢占成功 → 成为该房 host, 结束。
     - `unavailable-id` (并发竞争, 别人刚抢到) → 退回 client 再连这号房 (它现在有 host 了); 若又满则 `i++`。
3. 到 `MAX_ROOMS` 还进不去 → `status='error'`, 提示"人太多了, 稍后再试"。

竞争收敛性: 同一房号在服务器上**全局唯一**只能一个 host, 因此并发抢占最终收敛到单一 host, 其余自动变 client → 大家聚到同一个房, 不会分裂。

### 3. `scripts/net/network_manager.gd` — peer 维度 + 转发

- 新增 `enter_public(tag, seed, size, diff)`: 设好固定 `shared_world_seed/size/difficulty` (万一本端成 host 要用), 调 `_bridge.enter_public(...)`。本端最终是 host 还是 client 由 bridge 决定, 用 `is_host()` 读回。
- `_poll_bridge` 消息处理改造: `pop_messages` 现在每条带 `from`。`_route_message(raw, from_peer)` 多一个来源参数。
- **新信号 (带 peer id)**, 替代/补充现有不带 id 的:
  - `peer_joined(peer_id: String)` / `peer_left(peer_id: String)`
  - `remote_pos_received(peer_id, x, y, facing, anim)` (加 `peer_id`)
  - `remote_name_received(peer_id, name)` (加 `peer_id`)
  - `chat_received(peer_id, text)` (加 `peer_id`)
  - `remote_player_death_received(peer_id)` / `remote_player_respawn_received(peer_id)`
  - 实体/tile/时间天气/掉落/箱子等 host→client 广播类**不需要 peer 维度** (host 是唯一权威源), 保持原样。
- **host 转发逻辑**: host 收到某 client 的消息时:
  - `pos` / `name` / `chat` / `pdead` / `pres` (玩家个体状态) → host 转发给**除来源外**的所有 client (用 `send_to`), 并在转发包里塞上 `from` peer id, 让其它 client 知道是谁。本端 host 也照常 emit 信号显示这个远程玩家。
  - `tile` / `tile_batch` / `chest` / `drop_req` 等世界改动 → host 先在自己世界应用 (权威), 再广播给所有 client (含来源? tile 来源端已自行改, 故发给除来源外; 但简单起见可全发, client 端幂等应用)。沿用现有"host 权威"路径, 只是把"发给唯一 client"换成"发给所有 client"。
- 发送类 `send_*` 改造: host 调 `send()` 时底层 bridge 自动群发; client 调 `send()` 发给 host。绝大多数 `send_*` 函数签名不变, 仅底层 fan-out 行为变了。新增 host 转发用的内部方法。
- `disconnect_room` 清理多 peer 状态。

### 4. `scripts/world/world.gd` — 多个远程玩家

- `var _remote_player` (单个) → `var _remote_players: Dictionary` (peer_id → RemotePlayer 节点)。
- 接 `peer_joined(peer_id)` → `_spawn_remote_player(peer_id)`; `peer_left(peer_id)` → 移除并 `queue_free` 该节点。
- `_on_remote_pos(peer_id, ...)` 等改为按 `peer_id` 找对应 RemotePlayer; 若该 peer 还没 spawn (位置消息先于 join 到) → 懒创建。
- RemotePlayer 节点名用 `"RemotePlayer_<peer_id>"`; 名字标签用该 peer 的玩家名。
- host 离开 (client 端 `peer_left` 来源是 host / status→disconnected): 触发"房主走了"流程 → 提示 + 回主菜单 (见错误处理)。

### 5. `scripts/entities/remote_player.gd` — 支持多实例

- 已是独立场景, 多实例基本 OK。需要: 每个实例存自己的 `peer_id`; 加入 `"remote_player"` 组改为带 id 的方式, 让 `chat_box` 能定位**特定** peer 的头顶气泡 (见下)。
- 气泡定位: `chat_box._bubble_over` 现在用组名 `"remote_player"` (单个)。改为按 peer_id 找对应 RemotePlayer 节点 (world 提供 `get_remote_player(peer_id)` 查询)。

### 6. `scripts/ui/main_menu.gd` (+ 主菜单 .tscn) — UI 重构

- 入口按钮文案: 「多人游戏」(替换现有"加入房间"/"联机"入口文案, 走 `Locale.t` key)。
- `MultiplayerPanel` 分两区:
  - **上半「房间」**: 公共房按钮区。本期放一个 🌍「公共生存房」按钮。预留位置 (以后 PvP / 起床战争 加按钮)。
  - **下半「加入房间」**: 现有 `JoinRow` (输码 + 加入按钮), 加个小标题「加入房间」。
- 「公共生存房」点击 → 走 `enter_public("SV", ...)` 流程进游戏 (见数据流)。
- 仅 web (`OS.has_feature("web")`) 显示公共房按钮; 桌面隐藏 (联机本就 web only)。

## 数据流: 点公共生存房 → 进游戏

1. 玩家在主菜单点「公共生存房」。
2. `NetworkManager.enter_public("SV", PUBLIC_SV_SEED, PUBLIC_SV_SIZE, PUBLIC_SV_DIFF)`。
3. 主菜单轮询 NetworkManager 状态:
   - **本端成 host** (status=hosting/connected 且 `is_host()`): 用固定 seed/size/diff 启动世界, 进游戏, 开始接受 join。
   - **本端成 client**: 等 `hello` (host 发来固定 seed/size/diff) → 用收到的参数启动世界 (复用现有 `_start_multiplayer_game`)。
4. 进游戏后, 每有人加入 → `peer_joined` → spawn 远程玩家; 离开 → `peer_left` → 移除。

固定常量 (放 NetworkManager 或新 `mp_rooms.gd`):
```
PUBLIC_SV_SEED = 20260609   # 公共生存房固定地图
PUBLIC_SV_SIZE = 1          # 中
PUBLIC_SV_DIFF = 1          # 普通
MAX_PEERS = 8               # 含 host, 即每房最多 8 人
MAX_ROOMS = 20              # 公共房顺延上限
```

## 错误处理 (Error handling)

- **房主走了** (client 收到 host 连接断开): 弹提示「房主离开了, 房间已重开」→ 断开 → 回主菜单。玩家可再点公共生存房重新进 (新的人当 host)。本期不做"自动选新 host 接管"。
- **房全满** (顺延到 `MAX_ROOMS` 仍进不去): 提示「现在人太多啦, 等会儿再来」。
- **免费服务器在睡** (首次连慢): 复用现有重试/超时 + 友好提示 ("联机服务器忙, 正在重试…")。
- **抢占竞争** (`unavailable-id`): bridge 内部自动退回 client, 不报错给用户。
- **非 web 平台**: 公共房按钮不显示; 万一调到 `enter_public` 走现有 `_emit_no_bridge_error`。

## 测试策略 (Testing)

GUT 跑在桌面 headless, **没有真 WebRTC**。策略:
- 把"纯逻辑"抽成可测函数, 不碰 JavaScriptBridge:
  - `enter_public` 的房号顺延决策 (输入: 每号房的"连上/被拒/无人"结果序列 → 输出: 最终落在几号房 / 是否成 host)。抽成纯函数测。
  - host 转发决策: 给定 (消息类型, 来源 peer) → 应转发给哪些 peer (除来源 / 全部 / 不转发)。纯函数测。
  - `pop_messages` 新格式 (`{from,data}`) 的解析 + `_route_message(raw, from_peer)` 分发 (用假数据直接喂, 不经 bridge)。
- world 层: `_remote_players` 字典的 spawn/移除 (模拟 emit `peer_joined`/`peer_left`/`remote_pos`, 断言节点数 + 位置)。集成测在桌面用 NetworkManager 的"假 bridge"或直接 emit 信号。
- 沿用现有联机集成测的桌面 stub 思路 (NetworkManager 在非 web 是 no-op, 测试直接 emit 信号驱动)。

## 实现注意 (Gotchas)

- 信号签名改了 (加 peer_id) → 所有现有连接点 (`world.gd`, `chat_box.gd`, `main_menu.gd`) 同步改, 否则参数不匹配运行时报错。
- `chat_box.gd` 的组名定位单 `"remote_player"` 必须改 peer-id 定位, 否则多人时气泡冒错人头上。
- host 转发别把消息发回来源 (回声) → 远程玩家抖动/重复。
- JSON 大数: peer id 是字符串, 安全; entity_id 仍用现有低 28 位方案。
- 不要给 signal handler 加 `await get_tree().process_frame` (项目级坑)。

## 后续 (Future, 不在本期)

- PvP 地基: `remote_player` 加 HP/受击, player_action 近战/弓箭命中远程玩家 (起床战争前置)。
- 起床战争: 床/复活规则/分队/商店/资源生成器/地图/胜负 (独立大项目, 复用本期多人地基)。
- 世界持久化 / host 迁移 (host 走了世界接力)。
