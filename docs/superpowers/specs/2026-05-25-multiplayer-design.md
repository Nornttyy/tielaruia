# 联机游玩 (WebRTC P2P) 设计

## 背景

游戏部署在 GitHub Pages (https://nornttyy.github.io/tielaruia/), 静态托管,
没有自己的后端服务器. 但 Godot 4 HTML5 export 支持 WebRTCMultiplayerPeer,
可以走"点对点 (P2P)"直连, 不需要中间服务器转发游戏数据.

只缺一个"信令" (signaling) — 双方交换 SDP/ICE 用. 用免费公共信令 (PeerJS
官方 broker) 解决.

## 目标

- 两个小朋友坐两台电脑, 同 WiFi 或公网都能玩
- A 创建房间 → 得 6 位"房间码" → 发给 B
- B 输入码 → 加入
- 两人看到同一个世界 + 看到对方走动 / 挖方块 / 放方块
- 不付钱, 不租服务器

## 技术栈

- **传输**: WebRTC DataChannel (Godot `WebRTCMultiplayerPeer` + `WebRTCPeerConnection`)
- **信令**: PeerJS 公共 broker (`https://peerjs.com`, 免费, 不需要账号)
- **网络模型**: Host 权威 (host 运行 world 模拟, client 发输入 → host 广播状态)
- **MultiplayerAPI**: Godot 高层 RPC (`@rpc("authority", "call_remote", ...)`)

## 架构

### 节点树新增

```
Main
├── NetworkManager (新, autoload)            # WebRTC 连接 + signaling + RPC 路由
├── MultiplayerPanel (新, CanvasLayer)        # 联机 UI (Host/Join 选择 + 输入房间码)
└── World
    └── Entities
        ├── Player (本地玩家, peer_id=local_id)
        └── RemotePlayer_<peer_id> (新, 每个远程玩家一个)  # 不接键盘, 只跟服务器位置
```

### 文件新增

```
scripts/net/
  network_manager.gd        # autoload. 管 WebRTCMultiplayerPeer + PeerJS 信令 JS bridge.
  network_sync.gd           # 帮 World 同步 tile_set / 实体生死 (RPC 转发)
  remote_player.gd          # 远程玩家 sprite (不响应输入, 只跟 buffered position)

scenes/ui/
  multiplayer_panel.tscn    # 联机入口面板 (Host/Join/取消)

assets/js/
  peerjs_bridge.js          # JavaScriptBridge: 跟 Godot 通讯, 用 PeerJS 建立 RTCPeerConnection
```

## Phase 切片

### Phase A (本 spec session): 入口 + 占位
- 主菜单加 "联机" 按钮
- 点击 → MultiplayerPanel 弹出
- Panel 暂时只显示 "联机功能开发中, 敬请期待 (Phase B 即将到来)"
- 不连真网络
- 测试: panel 弹出 + 取消按钮回主菜单

### Phase B: WebRTC + PeerJS 信令
- assets/js/peerjs_bridge.js 写 JS 端: 创建 RTCPeerConnection + 连 PeerJS broker
- NetworkManager.gd 调用 JavaScriptBridge 走 peerjs_bridge.js
- Host: 调 PeerJS 注册一个随机 peer_id (6 位字母数字 e.g. "x7k9a2"), 显示给用户
- Join: 输入对方 peer_id, PeerJS 帮助建立 RTCPeerConnection
- Godot 接管 DataChannel → MultiplayerAPI
- 测试: 本机 2 个浏览器标签互相连, 见 `multiplayer_peer_connected` 信号

### Phase C: 玩家位置同步
- 玩家加入 → RPC `spawn_remote_player(peer_id, position)` 给所有 peer
- 每帧 10Hz, 客户端 RPC `update_position(peer_id, pos, facing)`
- RemotePlayer 用 buffer + interpolation 平滑显示远端位置
- 测试: A 走动, B 屏幕看到 A 的小人移动

### Phase D: 世界状态同步
- 挖方块: Player A 调 `world._set_tile(x, y, AIR)` → 同时 broadcast RPC
- 放方块: 同上
- Host 权威: 客户端发请求, host 验证后广播
- ChunkManager._deltas 在 host 上累积, 新加入的 client 拉一份 snapshot
- 测试: A 挖个方块, B 看到方块消失

### Phase E: 实体同步
- Slime / Cow / Drop spawn → RPC `spawn_entity(type, pos, id)`
- Entity 位置更新, host 每 100ms 广播
- 死亡: RPC `despawn_entity(id)`
- 测试: A 看到 slime 移动, B 同步看到

### Phase F: 时间/天气同步
- TimeOfDay.time 由 host 控制, 每 1s 广播给 client
- Weather.state 切换时广播
- 测试: A 进雨天, B 也下雨

### Phase G: 存档
- Host 用单机存档系统存
- Client 不存
- Host 可恢复, client 重连自动同步
- 测试: A 存档, 关闭重开"继续", B 重连后状态同步

## 风险点

- **PeerJS 公共 broker 不稳**: 高峰期可能连不上. Plan: 后续可以选支付 PeerServer Cloud
- **NAT 穿透失败**: 同 WiFi 几乎不会失败; 公网 ~80% 成功. 失败时用 TURN 服务器中转 (要钱)
- **桌面端 HTML5 / 手机端**: 桌面 Chrome/Safari 都支持 WebRTC. 手机也支持但触屏控制可能要改 UI
- **作弊**: host 权威能挡客户端作弊, 但 host 本身能作弊. 朋友之间随意
- **同步抖动**: 网络抖动会让远程玩家显得"瞬移". 用 0.1s buffer + interpolation 平滑

## 测试策略

- Unit 测试用 mock MultiplayerPeer (Godot 提供 OfflineMultiplayerPeer)
- 集成测试: 同进程开 2 个 SceneTree (host + client) 跑 spawn/move/dig 流程
- 手测: 本机 2 个浏览器标签, 长时间游玩
- 手测: 不同电脑, 同 WiFi
- 手测: 不同电脑, 公网

## 不在范围

- 语音聊天
- 文字聊天 (留给后续)
- 房间列表 (只能输入房间码, 不浏览房间)
- 队友 / 公会
- 超过 4 人 (P2P 数据传输量随人数平方增长, 实测 4 人内稳)
