# 联机系统全面审计 — bug 清单 (第1轮)

日期: 2026-06-01  来源: mp-full-audit workflow (11 环节 + 对抗式验证)

确认 **41** 个真 bug, 滤掉 14 个误报。

> 已修复: world_size 同步 / 玩家名字 / 实体朝向动画 (本 session 早些提交)


## 1. [HIGH/connect] pending_initial_deltas 断线/返回菜单后未清理，导致旧数据污染新游戏

**现象**: 玩家在多人游戏进行中返回菜单，再重新加入或开启新游戏时，可能看到前一局的 chunk 改动（方块状态）错误地应用到新世界，造成地形数据不一致

**根因**: NetworkManager.disconnect_room() 在断开连接时清理了状态字段 (status/my_room_code/is_host)，但没有清理 pending_initial_deltas 字典。若 client 收到 init_state 消息后在 world 初始化前关闭游戏/返回菜单，pending_initial_deltas 会保留该数据。下次进游戏时 world._setup_multiplayer_callbacks() 会检查到非空 pending_initial_deltas 并错误地应用旧的 chunk deltas 到新世界

**修法**: 在 disconnect_room() 函数中增加一行 'pending_initial_deltas = {}' 来清理待处理的初始化数据。同时在 main.gd 的 _return_to_menu() 中也应该显式调用清理，确保状态重置

**证据**: /workspace/teilaruia/scripts/net/network_manager.gd:298-303; /workspace/teilaruia/scripts/world/world.gd:244-247; /workspace/teilaruia/scripts/net/network_manager.gd:123-127


## 2. [HIGH/world] send_initial_state() sends malformed initial chunk deltas - complete data loss

**现象**: 联机时，client 加入 host 的世界，看不到 host 已经挖过的方块 - host 挖的洞被重新生成了

**根因**: chunk_manager._deltas 的格式是 Dict<int chunk_x, Dict<Vector2i pos, int tile_id>>，但 send_initial_state() 错误地将其视为 Dict<int, PackedInt32Array>，导致在序列化时无法正确访问数据

**修法**: 修改 send_initial_state() 中的序列化逻辑。需要遍历内层字典（Vector2i → tile_id）并转换为 [lx, y, tid, ...] 的数组格式，而不是假设 chunk_deltas[cx] 是 PackedInt32Array

**证据**: /workspace/teilaruia/scripts/net/network_manager.gd:214-225; /workspace/teilaruia/scripts/world/chunk_manager.gd:19; /workspace/teilaruia/scripts/world/world.gd:259


## 3. [HIGH/player] 远程玩家初始出生位置未同步，两端可能不一致

**现象**: 联机时两个玩家在加入时可能出生在不同位置。Host 和 Client 都会各自计算 spawn_point，但出生点的生成依赖于已加载的 chunk 内容，两端加载顺序或时机不同会导致找到的出生点不一致。

**根因**: remote_player 初始生成时被放在本地的 spawn_point 位置（world.gd:444-447），但这个 spawn_point 是每端独立计算的（world.gd:201）。出生点查询（_find_spawn_in_loaded）会根据已加载的 chunk 找第一个合适的地表，两端 chunk 加载时序不同（特别是新连接时）就会算出不同的 spawn_point。没有通过网络同步 remote_player 的真实出生点。

**修法**: Host 在连接建立后（_setup_multiplayer_callbacks）应通过网络消息将自己的 spawn_point（或本地玩家的初始位置）发送给 Client，Client 收到后将 remote_player 初始化到同样的位置，而不是各自计算。

**证据**: scripts/world/world.gd:444-447; scripts/world/world.gd:201; scripts/world/world.gd:800-823


## 4. [HIGH/player] 远程玩家的玩家名字（NameLabel）从未被同步

**现象**: 联机时远程玩家头上没显示对方的玩家名字，或显示为空。remote_player.gd 有 set_player_name(n: String) 方法，但 world.gd 和 network_manager.gd 都没有任何代码调用它或通过网络发送/接收玩家名字。

**根因**: 协议中缺少玩家名字同步机制。Host 的 send_hello 只发 seed + world_size，不包含玩家名字。NetworkManager 没有 "player_name" 或类似的消息类型。Remote player 的 set_player_name 方法存在但从未被调用。

**修法**: 在 hello 消息或新的 player_info 消息中加入发送端的 player_name。Host 连接后调用 send_hello 时应包含 player_name，Client 收到 hello 时提取 player_name 并调用 remote_player.set_player_name()。也应在 _on_remote_pos 时同步名字（或独立的周期同步）。

**证据**: scripts/entities/remote_player.gd:44-46; scripts/net/network_manager.gd:206-211; scripts/net/network_manager.gd:116-171; scripts/autoload/game_settings.gd:91-101


## 5. [HIGH/player] 仅支持 1 个远程玩家（_remote_player 是单个引用，无法扩展到 3+ 人)

**现象**: 架构硬编码只支持 2 人模式（host + 1 client）。如果尝试多个 client 连同一个 host，会出现只显示一个远程玩家，其他玩家位置消失或覆盖的情况。

**根因**: world.gd 用单个 _remote_player 变量存储远程玩家（第 78 行）。_spawn_remote_player 检查 _remote_player != null 就直接返回，不会生成第二个。_on_remote_pos 只调 _remote_player.apply_pos()，无法区分多个远程玩家。实体同步是字典存储（_remote_entities），但玩家特殊处理没用字典。

**修法**: 将 _remote_player 改为字典 _remote_players[player_id] → Node，协议中 pos 消息加入 player_id 或 peer_id 识别。NetworkManager 的 remote_pos_received 信号加 player_id 参数。_on_remote_pos 根据 player_id 找对应的 remote_player 节点并更新。

**证据**: scripts/world/world.gd:78; scripts/world/world.gd:437-447; scripts/world/world.gd:450-454; scripts/net/network_manager.gd:26


## 6. [HIGH/entity] 远程实体允许本端伤害导致血量不同步

**现象**: Client 玩家砍远程怪物时，远程怪物在本端死亡，但 host 端还活着；或血量显示不一致

**根因**: remote entity 的 take_damage() 方法没有 is_remote 检查。Client 端生成的远程实体允许被本地玩家伤害，伤害结果只在本端生效，host 完全不知道。所有敌人类型 (slime/zombie/spider 等) 都有此问题。

**修法**: 在所有 take_damage() 方法开头加 is_remote 检查：if has_meta("is_remote"): return false。这样 client 端的远程实体无法被伤害，伤害只由 host 处理并通过 ent_pos 广播。

**证据**: /workspace/teilaruia/scripts/entities/slime.gd:226-256; /workspace/teilaruia/scripts/entities/zombie.gd:181-201; /workspace/teilaruia/scripts/player/player_action.gd:1149, 1216


## 7. [HIGH/entity] 远程实体 HP 值从不同步，血条显示错误

**现象**: 看到远程怪物被攻击但血条不掉血，或显示满血

**根因**: Host 的 _mp_broadcast_entities() 在 send_entity_pos 时总是传 hp=0。即使传了正确的 HP 值，client 的 _on_remote_entity_pos() 也不用 _hp 参数 (下划线表示无意使用)，直接 spawn 新实体时用默认 max_health，导致远程实体总是显示满血。

**修法**: 方案 1 (推荐)：移除 HP 同步。既然 client 端实体禁止伤害 (见 bug 1)，就不用显示动态 HP。方案 2：正确同步 HP。host 从实体 current_health 读真实值传给 client，client 在 _on_remote_entity_pos 里 spawn 时设置 current_health。方案 1 简单且符合 host 权威设计。

**证据**: /workspace/teilaruia/scripts/world/world.gd:549-552; /workspace/teilaruia/scripts/net/network_manager.gd:228-233; /workspace/teilaruia/scripts/world/world.gd:308


## 8. [HIGH/entity] 某些敌人类型（King Slime/Mimic）可能在 client 端无法销毁

**现象**: Boss 死了但 client 端还在显示幽灵敌人；或 Mimic 被激活后 client 看不到

**根因**: _spawn_remote_entity() 的 kind 匹配缺少 'king_slime' 和 'mimic' 两个特殊情况。King Slime 和 Mimic 在 host 端 spawn 并被加到 'slimes' 组广播，但 client 收到 ent_pos 时用 kind="slime" 错配，创建普通 slime。当 host 发 ent_die 时，根据 ent_id 删除，但 client 端把普通 slime 删了，留下实际的 king_slime 幽灵。

**修法**: 在 _mp_broadcast_entities 中判定 kind 时加：elif "king_slime" in scene_path_s: kind="king_slime"；elif "mimic" in scene_path_s: kind="mimic"。然后在 _spawn_remote_entity 的 match 中加对应 case："king_slime": scene = KingSlimeScene；"mimic": scene = MimicScene。

**证据**: /workspace/teilaruia/scripts/world/world.gd:515-553; /workspace/teilaruia/scripts/world/world.gd:326-344; /workspace/teilaruia/scripts/entities/king_slime.gd:50-52; /workspace/teilaruia/scripts/entities/mimic.gd:40-41


## 9. [HIGH/entity] 血条显示本端初始化数据，不反映 host 权威状态

**现象**: 看到远程怪物完全显示正确的剩余血量需要它被伤害一次才能更新（虽然 bug 1 阻止了伤害）

**根因**: HealthBar 从 parent.current_health 读取血量。Remote entity spawn 时用默认 current_health（等于 max_health），ent_pos 消息不更新这个值。即使 host 传了 HP，client 也不用。

**修法**: 若要显示正确 HP：(1) 修复 bug 2，让 send_entity_pos 传真实 HP 并 client 应用。(2) 如果 client 端实体禁止伤害（推荐 bug 1 的修复），就索性不显示血条，改成只显示位置。

**证据**: /workspace/teilaruia/scripts/entities/health_bar.gd:68-70; /workspace/teilaruia/scripts/world/world.gd:308-316


## 10. [HIGH/combat] 敌对实体HP从不同步到客户端 (hardcoded 0)

**现象**: 客户端观看主机的敌怪受伤时，敌怪血条不变（因为HP总是0）；击杀敌怪两端看到的HP/死亡时机可能不一致

**根因**: world.gd 行552在广播敌怪位置时，send_entity_pos 的 hp 参数被硬编码为 0，而不是传递实际的 ent.current_health。NetworkManager.send_entity_pos 支持接收 hp 参数，但调用时从未传入真实值。

**修法**: 在 world.gd 的 _mp_broadcast_entities 中，检查每个实体是否有 current_health 属性，如果有则传递给 send_entity_pos。修改行552为：`NetworkManager.send_entity_pos(NetworkManager.entity_id_for(n2d), kind, n2d.global_position.x, n2d.global_position.y, int(n2d.get('current_health', 0)))` (或先判断 has('current_health') 再传)。同时在 world.gd 的 _on_remote_entity_pos 处理这个 hp 值，但注意：远程实体是客户端侧显示，HP由主机权威，客户端收到 hp 后应该同步到远程实体的 current_health（如果有的话）。

**证据**: /workspace/teilaruia/scripts/world/world.gd:549-553; /workspace/teilaruia/scripts/net/network_manager.gd:229-233; /workspace/teilaruia/scripts/world/world.gd:308


## 11. [HIGH/combat] 玩家箭/火球/史莱姆球投射物完全不同步

**现象**: 客户端射出的箭、火球、史莱姆球只在该客户端上显示和碰撞，对方看不见这些投射物；对方被箭/火球击中但对方看不到投射物源

**根因**: 玩家投射物（arrow/fireball/slime_ball）在 player_action.gd 中直接 instantiate + add_child 到 entities_root，没有任何网络同步消息。NetworkManager 没有定义投射物同步的消息类型 (ent_pos 只用于敌怪/掉落物)，player_action.gd 中的 _try_fire_bow / _try_cast_staff / _try_throw_slimeball 都是纯本地生成。

**修法**: 需要为投射物增加网络同步协议。可选方案：(1) 扩展 send_entity_pos 支持投射物（ent_pos 消息中增加 "vx"/"vy" 速度字段，或新增 "proj" 消息类型）；(2) 在生成投射物时调用 NetworkManager 发送初始位置+方向+伤害；(3) 只同步伤害结果（如 "entity_damaged" 消息），而不同步投射物本身可视化。建议方案2较简单：player_action.gd 中 arrow/fireball/slimeball 生成后，立刻调 NetworkManager.send_projectile(...) 或类似。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:1374-1388; /workspace/teilaruia/scripts/player/player_action.gd:1411-1421; /workspace/teilaruia/scripts/player/player_action.gd:1454-1467; /workspace/teilaruia/scripts/net/network_manager.gd:24-34


## 12. [HIGH/combat] 玩家受伤不会回传主机（单向伤害同步）

**现象**: 客户端玩家受伤时，主机端的远程玩家没有相应的受伤表现（被击退、闪红等）；玩家血量改动两端不一致

**根因**: player_health.gd 的 take_damage 方法在客户端和主机上都会执行（当被敌怪/投射物击中），但只有主机是权威。问题是：(1) 客户端的玩家受伤后没有向主机发送伤害消息；(2) NetworkManager 没有定义玩家伤害/血量同步的消息类型（只有 ent_pos 用于远程玩家位置，但 ent_pos 没有 hp）；(3) 远程玩家是纯动画展示，没有 take_damage 或 current_health 属性。

**修法**: 需要为玩家伤害增加同步。建议：(1) 在 player_health.gd 的 take_damage 方法末尾，如果是客户端且已连接，调用 NetworkManager.send_player_damage(amount, source_pos, current_health) 回传；(2) 在 network_manager.gd 中增加 signal player_health_changed(hp, max_hp) 和对应的消息处理；(3) 主机订阅该信号并在本地更新远程玩家的血条显示（或其他 UI 反馈）。注意：血量值本身由主机权威（防止客户端作弊），客户端只通知主机发生伤害，主机决定最终扣血。

**证据**: /workspace/teilaruia/scripts/player/player_health.gd:123-161; /workspace/teilaruia/scripts/entities/remote_player.gd:1-47; /workspace/teilaruia/scripts/net/network_manager.gd:24-34


## 13. [HIGH/combat] 远程敌怪和投射物碰撞检测两端不一致（无权威方）

**现象**: 客户端看不到对方射出的投射物，所以即使敌怪被对方的箭/火球击中，客户端那边看不到碰撞反馈（敌怪血条不变，敌怪不会被击退等）

**根因**: 这是上面两个 bug 的组合效应：(1) 投射物不同步导致客户端看不到对方的投射物；(2) 即使主机侧的投射物击中敌怪并扣血，敌怪 HP 也不会被同步回客户端（bug 1），所以客户端的远程敌怪表现不会变化。

**修法**: 解决方案与 bug 2 + bug 1 相同：(1) 实现投射物网络同步（bug 2 的修复）；(2) 实现敌怪 HP 同步（bug 1 的修复）。这样客户端既能看到对方的投射物，也能看到敌怪被击中后的 HP 更新。

**证据**: /workspace/teilaruia/scripts/entities/arrow.gd:59-76; /workspace/teilaruia/scripts/entities/fireball.gd:62-75; /workspace/teilaruia/scripts/entities/slime_ball.gd:67-80


## 14. [HIGH/drops_inv] 客户端挖矿掉落物宿主端无同步

**现象**: 客户端挖掉方块，掉落物在客户端可见并可捡，但宿主端看不到这个掉落物，且宿主端无法在掉落物生成地点看到任何物品。

**根因**: player_action.gd 的 _spawn_drop() 仅在本地生成 ItemDrop 节点，不发送任何网络消息。宿主端收到客户端的 tile 变化消息后，只更新地形数据，不会调用 _spawn_drop() 生成掉落物。掉落物生成逻辑完全在挖矿端本地。

**修法**: 需要在客户端挖掉方块时发送独立的 drop_pos 消息给宿主端，或者让宿主端在接收到对端的挖矿 tile 消息后，根据该 tile 类型查询 Tiles.drops_for() 生成掉落物并同步给客户端。推荐方案：在 player_action.gd 的 _finish_mine() 中，对于网络连接情况，立刻发送 drop_pos 消息；宿主端则在 _on_remote_tile() 中也生成本地掉落物副本。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:588-599; /workspace/teilaruia/scripts/world/world.gd:420-427; /workspace/teilaruia/scripts/world/world.gd:1277-1330


## 15. [HIGH/drops_inv] 箱子内容无联机同步

**现象**: 在箱子中放入或取出物品时，只有操作端看到内容变化，另一端的箱子内容不变。双人分别打开同一个箱子，修改不会互相影响。

**根因**: ChestStorage 是完全本地的 autoload，chest_panel.gd 修改箱子内容后只更新本地的 ChestStorage._chests 字典，network_manager.gd 中没有任何发送箱子变化的消息，world.gd 也没有接收和应用箱子变化的信号处理。箱子内容改动完全不经过网络层。

**修法**: 需要在 network_manager.gd 中添加 send_chest_change(tile_coord: Vector2i, slot_idx: int, item_id: String, count: int) 消息；在 chest_panel.gd 的 _apply_click() 和 _shift_transfer() 中调用此发送函数；在 world.gd 中添加相应的接收信号和处理函数 _on_remote_chest_change()，应用远端的箱子修改。存档时需要注意：chest_contents 只在宿主端有权威性，客户端加入时需通过初始状态同步宿主的所有箱子内容。

**证据**: /workspace/teilaruia/scripts/autoload/chest_storage.gd:1-194; /workspace/teilaruia/scripts/ui/chest_panel.gd:270-277; /workspace/teilaruia/scripts/net/network_manager.gd:1-320; /workspace/teilaruia/scripts/world/world.gd:200-247


## 16. [HIGH/drops_inv] 客户端后捡拾与宿主端广播竞态导致重复刷出掉落物

**现象**: 客户端捡起一个掉落物后，在发送 drop_pick 消息到达宿主端前，宿主端的 0.2 秒定时广播又把该物品重新发送给客户端，导致物品在客户端短暂复活或出现两份。

**根因**: 客户端捡起 is_remote 掉落物时（item_drop.gd line 105）调用 mark_drop_picked_up()，标记 ent_id 到 _picked_up_drop_ids；但宿主端的定时广播（world.gd line 555-562）无条件遍历所有掉落物并发送，不检查是否已被标记为已捡。如果 drop_pick 消息在广播消息之后到达宿主端，宿主端没有及时删除掉落物节点，导致下一个广播周期仍会发送该物品坐标。

**修法**: 宿主端在 _mp_broadcast_entities() 中遍历掉落物前，先检查 _picked_up_drop_ids 字典，跳过已被标记为捡过的物品。或者使用更严格的消息序号机制确保 drop_pick 消息被及时处理。同时，宿主端在收到 drop_pick 后，应立刻从场景中 queue_free 掉落物，不等下一帧。

**证据**: /workspace/teilaruia/scripts/items/item_drop.gd:102-108; /workspace/teilaruia/scripts/world/world.gd:555-562; /workspace/teilaruia/scripts/world/world.gd:375-383


## 17. [HIGH/time_world] Client continues to advance TimeOfDay.time independently — causes 昼夜漂移 desync

**现象**: Over a multiplayer session, client's daytime slowly drifts from host's daytime. After 20-30 minutes of play, host and client are in different day/night cycles. Lighting (darkness), monster spawns, and visual sky differ between players.

**根因**: TimeOfDay 是 autoload (singleton), 每端的 _process 都在 delta 时间增加 time。Host 每 5 秒广播当前 time，但 client 收到之前已经自己推进了约 5 秒的时间，导致累积误差。没有机制强制 client 的 time 与 host 同步。

**修法**: 修改 TimeOfDay._process，检查 NetworkManager.is_host。Client 跳过自动推进时间（_process 改为 pass 或删掉），完全依赖 host 的 time 广播。或改为每帧发 time（而非 5s 一次），确保同步频率足够高。

**证据**: /workspace/teilaruia/scripts/world/time_of_day.gd:29-32; /workspace/teilaruia/scripts/world/world.gd:503-508; /workspace/teilaruia/scripts/world/world.gd:430-434


## 18. [HIGH/time_world] Torch/lighting tiles placed locally not synced during initial_state — client 看不到 host 放的火把光

**现象**: 联机时，host 放的火把在 host 屏幕上闪烁发光，但 client 屏幕完全黑。或者反过来，client 走进 host 挖的深矿洞，应该漆黑但光线一切正常。

**根因**: TORCH tile 被正确广播（通过 tile 消息），但火把光源的计算在 WorldLighting.on_chunk_loaded 和 on_tile_placed 时执行。Client 在 initial_state 应用时走 _on_chunk_loaded，但如果没有完整触发 world_lighting.on_chunk_loaded，光源数据就没建立。此外，WorldLighting 需要 TORCH tile_id，如果 initial_state 中没有某个 TORCH，就永远不会 on_tile_placed 该火把。

**修法**: 确认 initial_state 应用时走的 _on_chunk_loaded（line 286）正确触发了 world_lighting.on_chunk_loaded。如有问题，补充显式 world_lighting.rebuild_lights_for_chunk(cx) 或类似调用。或确保所有 tile 改动都走 _set_tile → on_tile_placed，包括 initial_state 应用的 tile。

**证据**: /workspace/teilaruia/scripts/world/world.gd:1320-1322; /workspace/teilaruia/scripts/world/world.gd:747-748


## 19. [HIGH/time_world] 床睡眠复活点 bed_spawn_point 不同步 — host 和 client 复活在不同地点

**现象**: 联机时，一个玩家睡过床设置复活点，另一个玩家死亡后复活到错误的位置（默认 spawn_point 而非床点）。或两个玩家睡不同的床，复活点混淆。

**根因**: world.bed_spawn_point 是本地变量，player 调 world.sleep_in_bed(tile) 时修改。没有通过网络同步给对方。SaveManager 会存档 bed_spawn_point，但联机游戏中不经过 save，对方也没有机制接收更新。

**修法**: Player 调 sleep_in_bed 后，向 host 发网络消息（新的 msg type："bed_sleep" 或扩展现有 hello/init_state）。Host 接收 + 广播给 client，两端同步 bed_spawn_point。或者，host 权威：client sleep 时发消息给 host，host 设自己的 bed_spawn_point + 广播。

**证据**: /workspace/teilaruia/scripts/world/world.gd:71; /workspace/teilaruia/scripts/world/world.gd:583-595; /workspace/teilaruia/scripts/world/world.gd:1127-1131


## 20. [HIGH/death] 玩家死亡不通知对方

**现象**: 本地玩家死亡时，对方客户端看不到死亡画面，对方看到的远程玩家仍在活动。对方不知道玩家已死，位置消息停止时会看起来卡住。

**根因**: 网络协议中没有定义玩家死亡消息。player_health.gd 发出 died 信号（第160行），但只连接到 main.gd 的 _death_screen.show_death()，没有广播给对方。

**修法**: 添加 player_death 消息类型到协议（包含玩家是否存活状态）。在 player_health.gd 的 died 信号中调用网络管理器广播死亡消息。remote_player.gd 接收到消息后显示死亡视觉效果。

**证据**: /workspace/teilaruia/scripts/main.gd:413-414; /workspace/teilaruia/scripts/net/network_manager.gd:24-34; /workspace/teilaruia/scripts/entities/remote_player.gd:1-47


## 21. [HIGH/death] 玩家复活不通知对方

**现象**: 本地玩家按复活按钮后，对方客户端看不到玩家位置的跳变和复活动画。对方远程玩家可能停留在死亡位置，或位置突然闪跳回出生点。

**根因**: respawn_player() 函数（world.gd 第1135行）没有向对方发送复活消息。它只在本地处理：传送位置、回满血、清怪物。无法协议通知。

**修法**: 在 respawn_player() 末尾（第1217行之后）添加网络广播，向对方发送复活消息，包含玩家现在的位置和生命值。

**证据**: /workspace/teilaruia/scripts/world/world.gd:1135-1217; /workspace/teilaruia/scripts/main.gd:465-469


## 22. [HIGH/death] 床复活点不同步多人游戏

**现象**: 如果 client 睡过床设置了复活点，然后死亡，会从默认出生点复活而不是床位置，因为 host 不知道 client 的 bed_spawn_point 改变。反之亦然。

**根因**: world.bed_spawn_point 是本地状态，不在网络协议中同步。sleep_in_bed() 设置（world.gd 第584行），但只存档到本地 SaveData，多人时对方不知道。

**修法**: 添加网络消息 player_sleep（在 sleep_in_bed() 中调用）或在玩家位置消息中包含床复活点标志。host 同步时应包含或维护每个玩家的 bed_spawn_point。

**证据**: /workspace/teilaruia/scripts/world/world.gd:71, 584; /workspace/teilaruia/scripts/net/network_manager.gd:1-320


## 23. [HIGH/death] Host 死亡导致 Client 接收不到位置更新

**现象**: Host 玩家死亡时，death_screen 显示并调 `get_tree().paused = true`。此时 host 的 _physics_process 停止（第576行的检查会被跳过），player_controller 不再发位置更新。Client 看到 host 卡住，停止移动。

**根因**: death_screen.show_death() 设置 paused=true（第40行），使得 world 的 _physics_process 暂停，player_controller 的位置发送也暂停。虽然 NetworkManager 设置 process_mode=ALWAYS，但 player_controller 可能没有，导致位置消息无法发出。

**修法**: player_controller 应设置 process_mode=ALWAYS（或自定义逻辑在 paused 时仍能发送最后一次死亡位置）。或者在显示死亡屏时，立刻发送一条 player_death 消息告诉对方玩家已死，而不是让位置停止变化。

**证据**: /workspace/teilaruia/scripts/ui/death_screen.gd:40; /workspace/teilaruia/scripts/player/player_controller.gd:检查是否设置 process_mode


## 24. [HIGH/death] 死亡时清怪物只在本地执行（可能导致 Client 继续看到怪物）

**现象**: respawn_player() 第1199-1204 行清除地图所有 slime。如果 client 死亡复活，client 清了本地怪物，但 host 还在广播怪物位置，client 会重新生成它们。

**根因**: 清怪物操作是本地的，没有网络通知。host 端不知道 client 要求清怪，继续广播怪物。

**修法**: 只有 host 应该处理复活逻辑和清怪。Client 接收到对方复活消息时，本端不要重新创建对方的怪物副本，或清除对方视野内的本地怪物副本。

**证据**: /workspace/teilaruia/scripts/world/world.gd:1199-1204


## 25. [HIGH/chest_npc] Chest content changes not synchronized in multiplayer

**现象**: When one player puts items into or takes items from a chest, the other player does not see the inventory changes. Both players see the same chest tile, but chest contents are completely unsynchronized.

**根因**: ChestStorage is a local autoload that stores chest contents only in memory on each player's instance. When chest_panel.gd modifies chest contents via ChestStorage.get_slots(tile), the changes are never broadcast to the remote player. Only tile changes (destruction/placement) are sent via NetworkManager.send_tile_change(), but chest inventory data is not included in any network message.

**修法**: 添加新的网络协议消息类型 'chest_inventory' 或 'container_contents'，在 chest_panel 中每次修改后立刻发送更新。host 权威方式：只有 host 接收并同步 chest 修改给 client；或双向同步：两端各自记录更改，同步到对端。建议 host 权威以避免冲突。具体：(1) NetworkManager 添加 send_chest_contents(tile, slots_array) 方法；(2) ChestStorage 修改操作后回调通知网络；(3) World 在收到 remote_chest_contents 时应用到本地 ChestStorage。

**证据**: /workspace/teilaruia/scripts/autoload/chest_storage.gd:1-200; /workspace/teilaruia/scripts/ui/chest_panel.gd:270-277; /workspace/teilaruia/scripts/ui/chest_panel.gd:282-308; /workspace/teilaruia/scripts/ui/chest_panel.gd:346-361; /workspace/teilaruia/scripts/net/network_manager.gd:24-35


## 26. [HIGH/chest_npc] Mimic (dead person chest trap) only spawns on host, not visible to client

**现象**: When a player right-clicks on MIMIC_CHEST tile, the trap triggers: explosion effect, damage dealt. However, the Mimic creature only appears on the host player's screen. On the client, only the tile destruction is synced, but no Mimic entity is created.

**根因**: When host player triggers mimic trap via player_action._trigger_mimic_trap() (line 1485-1501), it calls world.spawn_mimic_at_tile() which instantiates the Mimic and adds it to entities_root. Then world._set_tile() broadcasts the tile change. However, client receives the tile change but has NO code path that spawns a Mimic in response. The client's world only spawns Mimic if its own spawn timer creates one randomly, which won't happen at the exact trapped tile. Mimic entity is in 'slimes' group and should be synced by world._mp_broadcast_entities() (line 517 broadcasts 'slimes'), but the spawn happens locally without a remote entity create message.

**修法**: 两种方案：(1) Host 权威方案：host 触发陷阱后，发送新消息 'spawn_mimic' 包含坐标，client 收到后在同位置 spawn Mimic，然后后续通过 ent_pos 同步位置。(2) Tile-变化触发方案：client 收到 MIMIC_CHEST→AIR 的 tile_change，检测如果是 MIMIC_CHEST 消失，则在该位置自动 spawn Mimic。建议方案(1)更清晰。具体：NetworkManager.send_spawn_entity(kind, x, y) 和对应 remote_spawn_entity_received 信号。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:1485-1501; /workspace/teilaruia/scripts/world/world.gd:978-986; /workspace/teilaruia/scripts/world/world.gd:515-553; /workspace/teilaruia/scripts/entities/mimic.gd:40; /workspace/teilaruia/scripts/net/network_manager.gd:24-35


## 27. [HIGH/chest_npc] Crafting table (workbench) recipes are not synchronized in multiplayer

**现象**: When two players are playing together, each player has their own crafting UI. Any recipes crafted by one player do not appear or sync to the other player. Crafting is a purely local operation with no network messages sent.

**根因**: The crafting_panel.gd handles all crafting logic locally (inventory slot manipulation, recipe checking, output generation). No network messages are sent when a recipe is crafted. Each player maintains their own player inventory, and crafting modifies the local inventory without broadcasting the changes. The initial_state sync only includes world tiles and existing entities, not player inventory or crafting state.

**修法**: 玩家背包物品本身应当同步（但当前也没有），或者至少在联机 mode 下禁用合成台与工作台功能以避免玩家误解。若要实现合成同步，需要：(1) 检测玩家背包变化时，发送 'player_inventory_change' 消息到 host；(2) Host 权威验证配方并回复成功/失败；(3) 两端都只听从 host 的背包快照同步。但这需要重构整个背包同步架构。当前建议：在联机模式下禁用合成台使用，或显示警告提示只是本地合成。

**证据**: /workspace/teilaruia/scripts/ui/crafting_panel.gd:1-900; /workspace/teilaruia/scripts/net/network_manager.gd:24-35; /workspace/teilaruia/scripts/player/player_inventory.gd:1-200


## 28. [HIGH/chest_npc] Chest destruction items are spawned locally with no remote synchronization

**现象**: When a chest is destroyed, its contents are spawned as ItemDrop entities. On the host, the chest is destroyed and items appear on the ground. On the client, the chest tile disappears (via tile sync) but the item drops that appear are determined by what's in the client's local ChestStorage (which differs from the host's). This creates item count mismatches.

**根因**: When player_action._finish_mine() detects a chest (line 484-489), it calls ChestStorage.clear(tile) to get the contents and spawns ItemDrop for each item. This happens on the LOCAL player only. The tile destruction IS synced (broadcast via _set_tile), but the item drops are spawned independently on each side based on each side's own ChestStorage state. Since ChestStorage contents aren't synced (bug #1), the drops will differ.

**修法**: 修复 bug #1 (chest 同步)后，本 bug 自动解决。若仍需单独处理：chest 被破坏时，由 host 权威决定掉落物，而不是各自算。具体：host 破坏 chest → 清空 ChestStorage → 向 client 发送最终的掉落物列表；或 host 不立刻清空，先发 'chest_destroyed_at_tile' 消息到 client，两端都从同步的最新 ChestStorage 内容生成 drops。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:484-489; /workspace/teilaruia/scripts/autoload/chest_storage.gd:28-33; /workspace/teilaruia/scripts/world/world.gd:554-562


## 29. [HIGH/init_order] Early network messages missed when world._setup_multiplayer_callbacks not yet connected

**现象**: In multiplayer, client receives pos/tile/entity messages before world finishes loading, causing remote player/entities to not appear or tiles to not update.

**根因**: 在异步加载流程 (_run_async_load) 中，World 的 defer_init=true 使得 _ready() 跳过初始化；_setup_multiplayer_callbacks 仅在 run_init_step(3)(_step_spawn_player) 时才被调用。但 NetworkManager._process 每 0.1s 轮询消息，这期间收到的 pos/tile_received 信号没有 handler 连接，信号虽然发出但无人接收。只有 initial_state_received 被特殊处理存入 pending_initial_deltas。

**修法**: 在 _apply_initial_state 之前，检查是否有 pending 的 pos/tile/ent_pos 消息（需要 NetworkManager 维护消息队列或记录），或在 NetworkManager 侧增加消息缓冲机制，将 step 0-2 期间的信号消息先存起来，等 _setup_multiplayer_callbacks 连接后再重放。另一种方案是将回调连接提前到 World._ready()，即使 defer_init=true 也要早期连接信号。

**证据**: /workspace/teilaruia/scripts/main.gd:94; /workspace/teilaruia/scripts/world/world.gd:115-116; /workspace/teilaruia/scripts/world/world.gd:208-213; /workspace/teilaruia/scripts/net/network_manager.gd:36, 74; /workspace/teilaruia/scripts/net/network_manager.gd:122-127


## 30. [HIGH/init_order] Water simulation may run on both client and host in paused state, causing desync

**现象**: If pause menu is opened and NetworkManager continues polling, water_sim._process is stopped (paused) on client but host may have sent tile_batch messages. When unpause occurs, client's water state is inconsistent with host.

**根因**: water_sim.gd 在 _process 中检查 is_mp_client (line 25) 以跳过客户端的模拟。但 process_mode 默认遵守 paused 状态。当树被暂停时，water_sim._process 停止，但 NetworkManager 继续工作，可能在 _on_remote_tile_batch 中调用 _set_water_tile_fast，修改世界状态。解冻后 water_sim 恢复运行，但状态已不一致。

**修法**: 方案 1: 暂停时停止 NetworkManager 消息处理（改为 DEFAULT process_mode 或检查 tree.paused）；方案 2: 在 NetworkManager 接收消息时检查树是否暂停，暂停则缓冲消息直到解冻；方案 3: 在 world._on_remote_tile_batch/remote_tile 中检查是否暂停，暂停则缓冲变化。

**证据**: /workspace/teilaruia/scripts/world/water_sim.gd:21-31; /workspace/teilaruia/scripts/world/world.gd:420-427; /workspace/teilaruia/scripts/net/network_manager.gd:56


## 31. [MEDIUM/player] LERP_SPEED = 8.0 可能导致远程玩家跟随滞后

**现象**: 远程玩家移动显示有延迟。消息频率 0.1s 一次（10Hz），但 LERP_SPEED=8.0 意味着每秒收敛幅度 8x，实际在两个位置更新间隔中（0.1s），位移只有 0.8 倍的差距，需要多帧才能完全到达新位置，导致远程玩家看起来滑行缓慢。

**根因**: remote_player.gd 中 LERP_SPEED 定义为 8.0，注释说"0.1s 内大致到位"，但数学上 delta*8 在 0.1s 时只有 0.8（被 clamp 到 1.0 才完全到位）。若 delta < 60fps 帧时长（16.67ms），则 t = delta*8 < 0.133，需要多帧累积。

**修法**: 将 LERP_SPEED 增加到 16.0 或更高（如 20.0），使远程玩家在 0.1s 内快速到达新位置，避免滑行感。也可改为距离-based lerp：计算当前到目标的距离，每帧移动固定像素（如 200px/s）直到到达。

**证据**: scripts/entities/remote_player.gd:10; scripts/entities/remote_player.gd:26; scripts/net/network_manager.gd:37


## 32. [MEDIUM/player] 朝向字段映射可能有符号问题（facing >= 0 与 flip_h 逻辑反向）

**现象**: 远程玩家的朝向显示可能反向或不正确。本地玩家发送 facing_int 为 1（右）或 -1（左），但 apply_pos 用 facing >= 0 判断，会将 -1 判作 false，0 也判作 false，只有 1+ 才为 true。

**根因**: player_controller.gd:109 发送 facing_int = 1 if _facing_right else -1，remote_player.gd:37 接收时用 _facing_right = facing >= 0，这导致 facing=-1 和 facing=0 都被当作面向左。如果意外发送了 0，会被错误解释。

**修法**: 改为明确的值对应：facing = 1（右）或 -1（左），接收端用 _facing_right = (facing > 0) 或 _facing_right = (facing == 1) 以更清晰。现有代码逻辑上没问题但可以更明确。

**证据**: scripts/player/player_controller.gd:109; scripts/entities/remote_player.gd:37; scripts/entities/remote_player.gd:31


## 33. [MEDIUM/drops_inv] 掉落物初始广播延迟导致客户端接不到刚生成的物品

**现象**: 客户端加入游戏或宿主端刚挖出物品时，客户端可能在掉落物消失前收不到该物品的位置信息，导致无法捡拾。

**根因**: 宿主端每 0.2 秒才在 _mp_broadcast_entities() 中广播一次所有掉落物位置（line 511-512）。如果客户端加入或宿主端刚生成掉落物，在下一个 0.2 秒周期到来前，客户端无法获知该物品存在。掉落物生命周期仅 30 秒（line 7 in item_drop.gd），且有 0.4 秒拾取延迟（line 8），在网络延迟下容易漏掉新生成的物品。

**修法**: 宿主端应在 _spawn_drop() 后立刻发送一条 drop_pos 消息给客户端，而不只依赖定时广播。这样新生成的物品能立刻被客户端接收。定时广播用作心跳/重连机制，确保位置更新。或者增加 initial_state 消息中的掉落物列表，让客户端加入时直接获得宿主当前的所有掉落物。

**证据**: /workspace/teilaruia/scripts/world/world.gd:82; /workspace/teilaruia/scripts/world/world.gd:510-512; /workspace/teilaruia/scripts/items/item_drop.gd:7-8


## 34. [MEDIUM/time_world] 天气 weather.state 状态机在 client 端不推进 — 永远晴天而不随 host 切换

**现象**: 联机时，host 屏幕上天气在变化（虽然目前仅 clear 状态），client 屏幕也应该跟着变。如果未来恢复雨天，两端天气会分别独立演变。

**根因**: weather.gd _process 被注释掉不推进状态（用户要求删雨）。Host 通过 send_time_weather 每 5s 广播 weather.state。Client 收到后调 weather.force_state。但如果网络延迟或消息丢失，client 的 weather 就不会更新。此外，weather 是 world 的子节点，不是 autoload，两端各自创建一个独立的 weather 对象，没有共享状态。

**修法**: 无需修复（雨天已删）。但如果未来恢复天气系统，需确保 client 的 weather 状态完全由 host 驱动，不运行自己的 _process 状态机推进。或改为每帧发 weather 消息（代价高），或用心跳确保同步。

**证据**: /workspace/teilaruia/scripts/world/weather.gd:29-31; /workspace/teilaruia/scripts/world/world.gd:507-508; /workspace/teilaruia/scripts/world/world.gd:430-434


## 35. [MEDIUM/chest_npc] Workbench location check is local only, not synchronized

**现象**: The crafting grid size (2x2 or 3x3) is determined by whether a workbench tile exists within 2 tiles of the player. In multiplayer, each player has independent workbench proximity checks, which is technically correct but could cause confusion if workbench proximity is destroyed.

**根因**: player_action._has_workbench_nearby() checks the local chunk_manager for WORKBENCH tiles within range. Since all tiles ARE synced via network, this works correctly. However, if a player destroys a workbench right as another player is opening the crafting menu, there could be timing issues.

**修法**: 无需修复。由于 tile 同步是立刻的，workbench 检查会自动准确。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:324-335


## 36. [MEDIUM/chest_npc] Villager dialogue is local only and not synchronized

**现象**: When a player opens dialogue with a villager (NPC), only that player sees the dialogue box. The dialogue text is random per call and not shared. This is acceptable for NPCs as they are static and dialogue-only.

**根因**: Villagers are spawned at the same deterministic positions on both host and client (VillagePlacer uses world seed). However, when player_action._try_open_workbench_or_close() detects a nearby villager and calls dialogue_box.open(random_line()), only that player's dialogue_box becomes visible. No network message is sent to sync the dialogue interaction.

**修法**: 无需修复。村民对话是装饰性且不影响游戏状态，本地处理是合理的。若需同步（例如显示对话者身份），可发送 'npc_dialogue_opened' 消息，但对于当前游戏设计不必要。

**证据**: /workspace/teilaruia/scripts/player/player_action.gd:269-275; /workspace/teilaruia/scripts/ui/dialogue_box.gd:15-22


## 37. [MEDIUM/init_order] Process mode conflict: NetworkManager continues polling while world paused, causing deltas applied to frozen state

**现象**: When pause menu opens (tree.paused=true), world._process stops but NetworkManager._process continues (process_mode=ALWAYS). Remote tile/entity messages continue arriving and being applied to a paused, frozen world state. Visual desync occurs when unpause happens because the state was modified while paused.

**根因**: NetworkManager 的 process_mode=ALWAYS (line 56) 是有意设计为在暂停菜单中能 poll 房间码。但这导致当树被暂停时，world._process (monster spawn/water sim/time sync) 停止，而 NetworkManager 继续接收并应用网络消息。如果 host 在暂停时玩家在对端继续活动，这些变化会被应用到冻结的世界，导致解冻后不同步。

**修法**: 需要决策：(1) 暂停时也停止接收网络消息 — 改 NetworkManager 为 ALWAYS 仅在 main menu 显示时有效；(2) 暂停时缓冲消息，解冻时回放；(3) 两端约定暂停时停止发送变化通知。目前设计有歧义。

**证据**: /workspace/teilaruia/scripts/net/network_manager.gd:53-56; /workspace/teilaruia/scripts/world/world.gd:477; /workspace/teilaruia/scripts/main.gd:461


## 38. [MEDIUM/init_order] Missing null check in _on_initial_state for chunk_manager during world loading transitions

**现象**: Race condition where initial_state message arrives while world is transitioning between init steps, chunk_manager exists but is in unstable state.

**根因**: 在 main.gd 的 _run_async_load 中，每个 step 之间有 'await get_tree().process_frame'。在这些 process_frame 中，NetworkManager 可能 poll 并发出 initial_state_received。若此时 chunk_manager 已创建但 ensure_loaded(0) 未完成，_apply_initial_state 可能尝试访问未初始化的 chunk 或 tile map。

**修法**: 添加状态标志 (e.g., world._init_complete=false/true) 以延迟应用 initial_state 直到所有 init steps 完成。或在 _apply_initial_state 中添加完整防御：检查 chunk_manager/chunk 的有效性，失败时将 deltas 重新入队以待稍后重试。

**证据**: /workspace/teilaruia/scripts/main.gd:106-107; /workspace/teilaruia/scripts/world/world.gd:272-286; /workspace/teilaruia/scripts/world/world.gd:283


## 39. [MEDIUM/init_order] No message buffering for tile/entity messages before callbacks connected

**现象**: Client may miss the first remote player position update or tile changes if they arrive during world loading (steps 0-2). Unlike initial_state which is buffered in pending_initial_deltas, remote_pos_received, remote_tile_received, remote_entity_pos_received are emitted with no handler yet.

**根因**: 在 network_manager.gd 中，remote_pos/remote_tile/remote_entity_pos 等信号直接 emit，没有缓冲逻辑。只有 initial_state 特殊处理存储在 pending_initial_deltas。signal emit 无人接收则直接丢弃。

**修法**: 在 NetworkManager 中为 remote_pos/remote_tile/remote_entity_pos/remote_entity_die/remote_drop_* 等添加待处理消息队列（类似 pending_initial_deltas）。在消息抵达时先缓存，直到 world 调用显式方法（如 flush_pending_messages() 或检查时自动回放）才发送信号或直接应用。

**证据**: /workspace/teilaruia/scripts/net/network_manager.gd:123-127; /workspace/teilaruia/scripts/net/network_manager.gd:156-170; /workspace/teilaruia/scripts/world/world.gd:223-240


## 40. [LOW/entity] Entity ID 用 instance_id 低 28 位，两端实体 ID 会不同但巧合碰撞风险

**现象**: 极小概率两个不同实体被识别为同一个，导致错误同步

**根因**: entity_id_for() 对所有实体用 instance_id & 0xFFFFFFF，只保留低 28 位。虽然 host 内的 instance_id 理论不重复（对象唯一），但低 28 位的哈希碰撞概率非零。概率 < 1/2^28 ≈ 0.0000004%，实际游戏中极难触发，但理论存在。

**修法**: 若 JSON 库支持大数，直接传整个 instance_id。若必须压缩，考虑用 CRC32 或其他哈希避免简单掩码碰撞。但鉴于概率极低，当前做法可接受作为 TODO。

**证据**: /workspace/teilaruia/scripts/net/network_manager.gd:250-253


## 41. [LOW/liquid] Client 端接收水/岩浆 tile_batch 后, 不会触发 water_sim 的二次流动计算

**现象**: Host 产生了一轮岩浆流动 tile 变化, 打包成 tile_batch 广播给 client。但 client 在应用这些 tile 变化时(通过 _on_remote_tile_batch), 只是调用 _set_water_tile_fast(from_remote=true), 这会禁止再次广播。客户端不知道这些新水位会不会导致邻近的液体继续流动。虽然 client 本来就不该运行自己的水流模拟(line 25-27), 但这个设计意味着 client 看到的液体停在 host 说的位置, 无法自主推演下一步流动

**根因**: 设计上 client 被动接收 host 的流水结果。但一旦 tile_batch 到达时机晚于 host 一个逻辑帧, client 就会看到一个「过时的状态快照」。例如: host 第 N 个 tick 把岩浆从 (0,0) 移到 (0,1), 第 N+1 个 tick 把它从 (0,1) 移到 (0,2)。如果网络延迟导致 client 只收到第 N+1 的结果, 就会看到岩浆在 (0,2), 跳过了 (0,1), 这在视觉上是传送

**修法**: 这不是 bug, 而是设计约束。如果要求 client 有流畅的液体动画, 需要 host 频繁广播(每个 water_sim tick 都发), 这会增加网络开销。可以接受的方案是 host 的 water_sim 保持当前逻辑(高频流动), client 只被动接收, 然后由客户端做一个平滑过渡(lerp 液体位置)。或者让 client 也跑 water_sim, 但用 host 广播的世界状态作为「校准点」(周期性同步以防飘移)

**证据**: /workspace/teilaruia/scripts/world/world.gd:406-417; /workspace/teilaruia/scripts/world/world.gd:1390-1406
