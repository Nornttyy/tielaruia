# Teilaruia · 体验版（Demo）设计规范

- **项目代号**：teilaruia（"泰拉瑞亚"音译）
- **日期**：2026-05-17
- **状态**：草案 v1，待用户复审
- **范围**：项目首个里程碑（原 M1，已扩展为"体验 Demo"）

---

## 1. 项目背景

长期目标：开发一款**类似泰拉瑞亚**的 2D 沙盒游戏，单人为主，准成品质量。

由于完整 Terraria-like 体量过大（数千物品 / 数十 Boss / 多生态），整体采用**垂直切片分期**策略，每个里程碑都是一个完整可玩的游戏：

| 里程碑 | 简称 | 内容 |
|---|---|---|
| **Demo（本 spec）** | 体验版 | 10 方块 + 1 怪物 + 1 NPC + 1 村庄 + 背包 + 6 配方 + 最小存档 |
| M2 | 生存循环 | 日夜、夜晚刷怪、饥饿（可选）、更多方块/工具 |
| M3 | 进度 | 矿物冶炼、铁器、第一个 Boss、NPC 入住系统 |
| M4 | 世界多样性 | 多生态、洞穴/矿脉、地牢 |
| M5 | 视觉完成度 | 光照、视差背景、天气、动画/音效抛光、美术终稿 |

本 spec **只覆盖 Demo**。M2-M5 各自独立 spec → plan → 实施。

---

## 2. 技术选型

| 项 | 决策 |
|---|---|
| 引擎 | **Godot 4.3+** |
| 语言 | **GDScript** |
| 工作流 | 我（AI）写所有文本（脚本 + `.tscn` + `.tres`），用户不需打开编辑器 |
| 物理 | Godot 内建（`CharacterBody2D.move_and_slide()`） |
| 地形 | `TileMapLayer`（Godot 4.3 新 API） |
| 噪声 | `FastNoiseLite`（Godot 内建） |
| 存档 | `ResourceSaver` / `ResourceLoader` |
| 测试 | [GUT](https://github.com/bitwes/Gut) |
| 美术 | M1 全部用纯色 + 简单几何占位，AI 生成美术推迟到 M5 前 |

**选 Godot 的理由**：相比 Bevy/macroquad，Godot 内建 tilemap、动画、UI、场景系统对 2D 沙盒游戏支持成熟，预估总进度提速 2-3 倍。GDScript 热重载快、社区教程多、Terraria-like 规模下性能够用。

---

## 3. 范围

### 3.1 体验版包含

#### A. 十种方块

| ID | 名称 | 类别 | 行为 |
|---|---|---|---|
| 0 | air（空气） | — | 占位 |
| 1 | grass（草方块） | 自然 | 顶部地表；徒手可挖；掉落 dirt（80%）或自身（20%） |
| 2 | dirt（泥土） | 自然 | 地下浅层；徒手可挖；掉落自身 |
| 3 | stone（石头） | 自然 | 地下深层；**需木镐**；掉落 cobblestone（M1 简化：直接掉 stone item） |
| 4 | sand（沙子） | 自然 | 局部斑块；徒手可挖；掉落自身；**不受重力影响**（M1 简化，避免实现下落 tile） |
| 5 | log（原木） | 自然 | 树木躯干；徒手可砍（慢），木斧快 3 倍；掉落自身 |
| 6 | leaves（树叶） | 自然 | 树木顶部；徒手秒砍；30% 几率掉落 1 log 作为"树苗"占位（暂不发芽） |
| 7 | planks（木板） | 合成 | 玩家放置；徒手秒挖；掉落自身 |
| 8 | workbench（工作台） | 合成 | 玩家放置；占用 1 格；与之相邻或站在其上按 E 打开 3×3 合成 UI |
| 9 | door（门） | 合成 | 玩家放置；占用 2 tile 高；点击切换开/关；关时阻挡，开时可穿过。**实现采用"tile 标记 + 同位 Door scene"混合模型**——见下方说明 |
| 10 | bedrock（基岩） | 系统 | 世界最底 2 行；**不可破坏**；标记世界边界 |

> 共 10 种 + air 占位。门和基岩需要特殊行为代码。
>
> **门的实现模型**：tile id 9 在 TerrainLayer 上占一个 cell（门底），用于存档/快速查询"此处有门"。同时在 `Entities` 节点下挂一个 `Door` scene（CharacterBody2D + Area2D）位于相同坐标，承担：(a) 开/关状态、(b) 玩家点击交互、(c) 视觉绘制门顶（占位用 1 个延伸到上方的矩形）、(d) 开门时禁用碰撞体。放置/破坏门时，tile 和 scene 必须同步增删（由 `tile_interaction.gd` 统一处理）。

#### B. 一种怪物：史莱姆

- **HP**：6（木剑 3 击；徒手 6 击）
- **AI**：状态机，2 个状态
  - `Idle`：原地随机停 1-3 秒
  - `Hop`：朝玩家方向小弹跳（每跳 32 px 远、24 px 高），CD 0.5s
- **检测范围**：曼哈顿距离 < 12 tile 时切换到 Hop
- **接触伤害**：1 点 / 接触 0.5s 内不重复
- **掉落**：0-2 个 `slime_ball` 物品（M1 暂无用途，验证掉落系统）

#### C. 一种 NPC：村民

- 站在村庄某间屋子内，**不移动**（M2 加 AI）
- 玩家靠近 < 2 tile + 按 E → 弹出对话框
- 对话内容：从 **10 句词条池**随机选 1 句，每次互动重摇
- 词条由 spec § 11 给出
- 不交易、不接任务、不能被攻击（友好实体）

#### D. 一种建筑：村庄

- 世界生成时在出生点周边 50 tile 半径内放置
- 由 **2 间小屋** 组成，固定预制布局（不随机化）
  - 每间小屋 5×4 tile，木板墙体 + 木板地板 + 门
  - 屋顶用木板平铺（M1 不做斜屋顶）
- 1 个村民固定生成在第一间屋子内
- 第二间屋子留空（M2 NPC 入住扩展锚点）
- 布局由 `resources/prefabs/village.json` 描述（见 § 7.2）

#### E. 背包

- **热键栏（Hotbar）**：9 格，始终显示在屏幕底部中央
- **主背包**：27 格，按 `E` 切换显示
- 打开主背包时显示 **2×2 合成网格** + 输出槽（同 Minecraft）
- 物品堆叠：默认上限 64；工具/装备类不堆叠
- 数字键 1-9 / 鼠标滚轮 切换热键栏当前选择
- 鼠标左键拖拽移动；右键放 1 个；Shift+左键快速转移到对侧

#### F. 六个合成配方

| # | 名称 | 在哪合成 | 形状 | 输出 |
|---|---|---|---|---|
| 1 | 木板 | 背包 2×2 | 1 log | 4 planks |
| 2 | 棍子 | 背包 2×2 | 2 planks（竖排） | 4 sticks |
| 3 | 工作台 | 背包 2×2 | 4 planks（2×2 填满） | 1 workbench（作为可放置物品） |
| 4 | 木剑 | 工作台 3×3 | 2 planks（竖排上 2） + 1 stick（下） | 1 wood_sword |
| 5 | 木镐 | 工作台 3×3 | 3 planks（顶行） + 2 sticks（中柱） | 1 wood_pickaxe |
| 6 | 木斧 | 工作台 3×3 | 3 planks（L 形） + 2 sticks（柱） | 1 wood_axe |

> 用户口述"5 个配方"——棍子作为隐式第 6 条。形状遵循 Minecraft 习惯，支持左右镜像。

#### G. 工具行为

- **木镐**：能挖 stone（无镐时 stone 挖不动）；其他可挖方块速度同徒手
- **木斧**：砍 log 速度 ×3；砍其他无加成
- **木剑**：攻击伤害 ×2（默认 1 → 2）
- **无耐久度**：M1 简化，工具永久使用
- **挖掘范围**：玩家中心 4 tile 内
- **攻击范围**：玩家朝向前方 1.5 tile 内圆形

#### H. 死亡与复活（Minecraft 风格）

1. 玩家 HP ≤ 0 触发死亡
2. 背包全部物品（热键栏 + 主背包 + 合成网格 + 输出槽）在死亡位置生成 ItemDrop 堆
3. ItemDrop 30 秒后 `queue_free()`
4. 玩家位置 = 世界出生点（世界生成时确定，地表平坦位置），HP 满
5. 短暂无敌 2 秒防卡死亡循环

#### I. 史莱姆刷新

- 世界生成时**预放**：地表随机放 3 只（作为引导，让玩家立刻能看到怪）
- **动态刷新**：每 5 秒，地图当前史莱姆 < 8 只时，尝试在满足条件的位置生成 1 只
  - 条件：距离玩家曼哈顿 ≥ 16 tile，且 `dark[x,y] == true`，且为空气格，且下方为实心
  - 单次最多尝试 30 个候选位置，全失败则跳过本次
- "暗"定义见 § 3.1.J

#### J. "暗"的定义（**待用户确认**）

由于 M1 不做光照系统，"暗"用最简化版本：

- 维护一张布尔网格 `sky_exposed[x][y]`，与 TerrainLayer 等大
- 每秒重算一次（或方块变动时局部重算）：每列从 y=0 向下扫描，遇到第一个非空气方块后，本列所有下方 tile 标为 `sky_exposed = false`
- "暗" = `!sky_exposed`
- 室内（如木屋内）也算暗，因为屋顶挡住天光
- **不做任何渲染变化**——屏幕不变黑，只是逻辑上有"暗区"标记

> 若用户希望屏幕真正变暗（视觉光照），需把光照从 M5 提前到 Demo，工作量约翻倍。等用户复审决定。

#### K. 最小存档

- 单存档槽：`user://save.tres`
- 触发：按 ESC 出菜单点 "保存并退出"，或按 `F5` 立即保存
- 启动时如有存档自动加载
- 存档内容：
  - 玩家位置、HP、朝向
  - 背包/热键栏/合成网格内所有物品
  - TerrainLayer 完整 tile 数据（1024×256 = 262144 cells，序列化为 RLE 压缩字节串）
  - Entities 列表：每个 Slime/Villager/Door/ItemDrop 的位置和状态
  - 出生点坐标
  - 世界种子（用于稳定恢复）

### 3.2 体验版**不**包含（推迟到后续里程碑）

- 日夜循环、月相（M2）
- 视觉光照、火把光源（M5）
- 矿物冶炼、铁/金/钻装备（M3）
- 多生态、洞穴系统、矿脉（M4）
- 沙子重力下落 / 水流 / 熔岩（M2+）
- 多种敌人、Boss、Boss 召唤物（M3+）
- NPC 移动 AI / 交易 / 任务 / 入住条件（M2+）
- 音效音乐（M5）
- 美术终稿（M5）
- 多种武器（弓、魔法）、护甲（M3+）
- 树木自然生长 / 季节（M4+）
- 多人联机（明确不做）

---

## 4. 架构

### 4.1 目录结构

```
teilaruia/
├── project.godot
├── CLAUDE.md
├── docs/
│   └── superpowers/specs/2026-05-17-teilaruia-demo-design.md  ← 本文件
├── scenes/
│   ├── main.tscn                       # 根
│   ├── world/
│   │   ├── world.tscn
│   │   └── door.tscn
│   ├── player/player.tscn
│   ├── entities/
│   │   ├── slime.tscn
│   │   ├── villager.tscn
│   │   └── item_drop.tscn
│   └── ui/
│       ├── hud.tscn                    # 血条 + 热键栏
│       ├── inventory.tscn              # 主背包 + 2×2 合成
│       ├── crafting_table_ui.tscn      # 3×3 合成
│       ├── dialogue.tscn               # NPC 对话框
│       └── debug_hud.tscn              # FPS / 坐标
├── scripts/
│   ├── autoload/
│   │   ├── tile_data.gd                # 全 tile 属性表
│   │   ├── item_database.gd            # 加载 items/*.tres
│   │   ├── recipe_database.gd          # 加载 recipes/*.tres
│   │   └── save_manager.gd
│   ├── world/
│   │   ├── world.gd
│   │   ├── world_generator.gd
│   │   ├── tile_interaction.gd         # 挖/放逻辑
│   │   ├── village_placer.gd
│   │   ├── sky_light_grid.gd           # § 3.1.J 的暗格计算
│   │   └── slime_spawner.gd
│   ├── player/
│   │   ├── player_controller.gd
│   │   ├── player_health.gd
│   │   └── player_action.gd
│   ├── entities/
│   │   ├── slime_ai.gd
│   │   ├── villager.gd
│   │   ├── door.gd
│   │   ├── damageable.gd               # 接口
│   │   └── item_drop.gd
│   ├── inventory/
│   │   ├── item.gd                     # Item Resource class
│   │   ├── inventory.gd                # 库存容器逻辑
│   │   ├── recipe.gd                   # Recipe Resource class
│   │   └── crafting.gd                 # 形状匹配
│   ├── ui/
│   │   ├── hud.gd
│   │   ├── inventory_ui.gd
│   │   ├── crafting_table_ui.gd
│   │   ├── slot.gd
│   │   └── dialogue.gd
│   └── debug/debug_hud.gd
├── resources/
│   ├── tiles/
│   │   └── teilaruia_tileset.tres      # 10 tiles 的 TileSet
│   ├── items/
│   │   ├── grass.tres
│   │   ├── dirt.tres
│   │   ├── stone.tres
│   │   ├── sand.tres
│   │   ├── log.tres
│   │   ├── leaves.tres
│   │   ├── planks.tres
│   │   ├── workbench.tres
│   │   ├── door.tres
│   │   ├── stick.tres
│   │   ├── wood_sword.tres
│   │   ├── wood_pickaxe.tres
│   │   ├── wood_axe.tres
│   │   └── slime_ball.tres
│   ├── recipes/
│   │   ├── planks.tres
│   │   ├── stick.tres
│   │   ├── workbench.tres
│   │   ├── wood_sword.tres
│   │   ├── wood_pickaxe.tres
│   │   └── wood_axe.tres
│   └── prefabs/
│       └── village.json
└── tests/
    ├── unit/
    │   ├── test_inventory.gd
    │   ├── test_crafting.gd
    │   ├── test_world_generator.gd
    │   ├── test_tile_data.gd
    │   ├── test_save_manager.gd
    │   └── test_sky_light_grid.gd
    └── integration/
        └── test_smoke.gd
```

### 4.2 运行时节点树

```
Main (Node2D)
├── World (Node2D, scenes/world/world.tscn)
│   ├── Camera2D                        # 跟随玩家
│   ├── BackgroundLayer (TileMapLayer)  # M1 空，M5 用
│   ├── TerrainLayer (TileMapLayer)     # 主层
│   ├── Player (CharacterBody2D)
│   ├── Entities (Node2D)
│   │   ├── Slime ×N
│   │   ├── Villager ×1
│   │   ├── Door ×N（自动收集）
│   │   └── ItemDrop ×N
│   ├── Structures (Node2D)             # 村庄锚点（占位空 Node2D）
│   └── SlimeSpawner (Timer + Node)
└── UI (CanvasLayer)
    ├── HUD                             # 始终显示
    ├── InventoryUI                     # 按 E 切换 visible
    ├── CraftingTableUI                 # 接触工作台显示
    ├── DialogueUI                      # NPC 互动显示
    └── DebugHUD                        # 按 F3 切换
```

### 4.3 Autoload 单例（在 project.godot 注册）

| Autoload | 职责 |
|---|---|
| `TileData` | 全 tile 属性（可挖标志、所需工具、掉落表、碰撞） |
| `ItemDatabase` | 启动时加载 `resources/items/*.tres` 到 `Dictionary<String, Item>` |
| `RecipeDatabase` | 启动时加载 `resources/recipes/*.tres`，按形状索引 |
| `SaveManager` | `save()` / `load()` 接口；信号 `save_completed`、`load_completed` |

---

## 5. 关键技术决策

| 主题 | 决策 | 理由 / 备选 |
|---|---|---|
| Tile 系统 | `TileMapLayer`（Godot 4.3 新 API），不分 chunk | 1024×256 = 262k cell，Godot 单层渲染完全够 |
| 世界尺寸 | 1024 tile 宽 × 256 tile 高（16 px → 16384×4096 px） | Demo 够大；同时可全保存 |
| 噪声 | `FastNoiseLite`（Godot 内建 Perlin/Simplex） | 不引外部库 |
| 物理 | Godot 内建 `CharacterBody2D` + `move_and_slide()` | 不引 Rapier；Godot 2D 物理对 tile 游戏够用 |
| 物品定义 | `class_name Item extends Resource` + `.tres` 文件 | 数据驱动；热重载；M2 新物品零代码 |
| 配方匹配 | 形状匹配 + 镜像 + 留白 | Minecraft 风格；与 2×2 和 3×3 grid 兼容 |
| 掉落物 | `Area2D` + 简单弹性运动 + 30s 自毁 | 简单可靠 |
| 存档格式 | `ResourceSaver.save()` 到 `user://save.tres` | Godot 原生；tile 数据用 PackedByteArray + RLE |
| Tile RLE | `[u16 tile_id, u16 count]` 重复序列 | 262k cell 中大部分是 air 和 stone，压缩率高 |
| 输入映射 | `InputMap` 预定义动作名（move_left / jump / interact / attack / inventory / hotbar_1..9） | 改键时只动 InputMap，业务代码不动 |
| 暗格计算 | 每秒重算 + 方块变动时局部重算 | O(world width × height) 约 262k 操作，秒级可行 |
| 史莱姆上限 | 全局 ≤ 8 只 | 防止性能问题 |
| 测试 | GUT 单元 + headless 集成 | 纯逻辑模块走 TDD |

---

## 6. 关键数据流

### 6.1 挖方块

```
Input(LMB) → player_action.gd.try_mine(target_tile)
  ├── 检查距离 ≤ 4 tile，否则 return
  ├── 查 TileData：是否可挖？需要什么工具？
  │     未达工具要求 → 播放"叮"音效占位 + return
  ├── 累计挖掘进度（基于工具速度），达到阈值后：
  │     TerrainLayer.set_cell(coord, -1)        # 移除
  │     SkyLightGrid.invalidate_column(coord.x) # 触发暗格重算
  │     drops = TileData.drops_for(tile_id, tool)
  │     for drop in drops:
  │         spawn ItemDrop at coord
```

### 6.2 放方块

```
Input(RMB) → player_action.gd.try_place(target_tile)
  ├── 当前热键槽是 placeable 物品？否则 return
  ├── 目标格为空气 + 距离 ≤ 4 + 不与玩家碰撞？
  ├── 特殊：door 占 2 格高，检查上方也是空气
  ├── TerrainLayer.set_cell(coord, tile_id)
  ├── 库存扣 1
  └── SkyLightGrid.invalidate_column(coord.x)
```

### 6.3 合成

```
玩家拖拽物品到 2×2 (或 3×3) 网格
  ├── crafting.gd.find_match(grid_snapshot)
  │     遍历 RecipeDatabase，比对形状（支持镜像，对位匹配）
  ├── 找到匹配 → 输出槽显示预览
  ├── 玩家拾取输出 → 各输入槽 -1 → 再次 find_match 更新预览
  └── Shift+点击输出 → 循环合成至材料不足
```

### 6.4 死亡复活

```
PlayerHealth.take_damage(n) → hp -= n
  ├── if hp <= 0:
  │     for each item in inventory:
  │         spawn ItemDrop at player.position (各物品散开 ±16 px)
  │     inventory.clear_all()
  │     player.position = World.spawn_point
  │     hp = MAX_HP
  │     start invincible_timer(2.0s)
```

### 6.5 史莱姆刷新

```
SlimeSpawner.Timer (每 5s 触发):
  if current_slime_count >= 8: return
  for try in 1..30:
    pick random (x, y) within world bounds
    if manhattan_distance(player, (x,y)) < 16: continue
    if not dark[x,y]: continue
    if TerrainLayer.get_cell(x,y) != AIR: continue
    if TerrainLayer.get_cell(x, y+1) == AIR: continue   # 下方需实心
    spawn Slime at (x*16, y*16)
    return
```

### 6.6 NPC 对话

```
玩家走近 Villager < 2 tile → UI 提示"按 E 对话"
按 E → DialogueUI.show(villager.pick_random_line())
玩家移动 / 再按 E / 按 ESC → DialogueUI.hide()
```

### 6.7 存档（保存）

```
SaveManager.save():
  snapshot = {
    "player": player.serialize(),
    "inventory": inventory.serialize(),
    "world_seed": world.seed,
    "spawn_point": world.spawn_point,
    "tiles": rle_encode(TerrainLayer.get_used_cells_with_data()),
    "entities": [e.serialize() for e in entities],
    "version": 1
  }
  ResourceSaver.save(snapshot, "user://save.tres")
```

### 6.8 存档（加载）

```
SaveManager.load():
  snapshot = ResourceLoader.load("user://save.tres")
  if snapshot.version != 1: panic / migrate
  apply snapshot to world / player / inventory / entities
  SkyLightGrid.recompute_full()
```

---

## 7. 资源约定

### 7.1 Item Resource 字段

```gdscript
class_name Item extends Resource

@export var id: String                  # 唯一 ID，如 "wood_sword"
@export var display_name: String        # 显示名
@export var icon: Texture2D             # UI 图标（M1 用占位）
@export var max_stack: int = 64
@export var placeable_tile_id: int = -1 # -1 = 不可放置
@export var tool_type: String = ""      # "pickaxe" / "axe" / "sword" / ""
@export var tool_tier: int = 0          # 0=徒手, 1=木
@export var damage: int = 1
```

### 7.2 Recipe Resource 字段

```gdscript
class_name Recipe extends Resource

@export var id: String
@export var grid_size: Vector2i         # (2,2) 或 (3,3)
@export var pattern: Array              # 二维数组，存 Item.id 或 ""
@export var allow_mirror: bool = true
@export var output_item: Item
@export var output_count: int = 1
@export var requires_workbench: bool = false
```

### 7.3 village.json 格式

```json
{
  "anchor_offset": [0, 0],
  "houses": [
    {
      "rect": [-6, -3, 5, 4],
      "wall_tile": "planks",
      "floor_tile": "planks",
      "door": [-4, -3],
      "villager": [-4, -2]
    },
    {
      "rect": [3, -3, 5, 4],
      "wall_tile": "planks",
      "floor_tile": "planks",
      "door": [5, -3]
    }
  ]
}
```

> 坐标相对村庄锚点（出生点附近选定的地表位置）。

---

## 8. 扩展点（为 M2-M5 预留）

| 扩展点 | 预留方式 | 未来用法 |
|---|---|---|
| 新 tile 类型 | `TileData` 加常量 + TileSet 加 atlas | M2 加矿物零业务代码 |
| 新物品 | 新 `.tres` 文件 | M3 加铁器零业务代码 |
| 新配方 | 新 `.tres` 文件 | M3 加冶炼配方只需新 Recipe |
| 新敌人 | `damageable.gd` 接口 + 新 scene | M3 加多种敌人共用伤害逻辑 |
| 新 NPC 行为 | `villager.gd` 当前是简单脚本 | M2 加 AI 时改为 FSM |
| 视觉光照 | `SkyLightGrid` 已存在数据层 | M5 仅加渲染管线 |
| 日夜 | `World` 留 `time_of_day: float` 字段（M1 始终 0.5） | M2 接入光照颜色 |
| 多生态 | `WorldGenerator` 改为按 biome 切换噪声参数 | M4 |
| 存档版本 | 存档已带 `version` 字段 | M2+ 加 migration |

---

## 9. 测试策略

### 9.1 TDD 必须覆盖（纯逻辑模块）

| 模块 | 测试要点 |
|---|---|
| `inventory.gd` | 加/扣/堆叠/分堆/转移/边界（满栈/不可堆叠物） |
| `crafting.gd` | 形状匹配 / 镜像 / 留白 / 不匹配 / 跨 grid size |
| `world_generator.gd` | 同种子结果稳定（snapshot）；基岩在底；出生点是地表 |
| `tile_data.gd` | 工具/掉落查表 |
| `save_manager.gd` | 存读对称：随机世界 → save → load → 状态等价 |
| `sky_light_grid.gd` | 顶层 air 是亮的；挖洞后下方暗格更新 |

### 9.2 集成测试（headless Godot）

- `test_smoke.gd`：启动 Main 场景 → 跑 10 秒模拟 → 不崩溃 → FPS ≥ 60
- 模拟脚本：随机移动 + 随机点击 + 随机按键

### 9.3 手动验收（在 § 10）

---

## 10. 验收标准

Demo 完成的定义（DoD）：

1. ✅ 启动游戏 5 秒内进入可玩界面（无加载条 / 直接进世界）
2. ✅ 1080p 分辨率下，全程 ≥ 60 FPS（i5-8 代以上 CPU + 集成显卡）
3. ✅ 可连续游玩 10 分钟无崩溃、无内存泄漏（任务管理器内存稳定）
4. ✅ 完整流程可走通：
   - 砍 1 棵树 → 得 log
   - 合成 → 4 planks → 4 sticks → 工作台
   - 放工作台 → 合成木镐 + 木剑
   - 挖石头 → 得 stone
   - 找到村庄 → 与村民对话 → 看到随机词条
   - 被史莱姆打死 → 在出生点复活 → 回去捡掉落物
5. ✅ 保存 → 退出 → 重启 → 加载存档 → 世界 + 背包 + 玩家位置完全一致
6. ✅ 所有 § 9.1 的单元测试通过
7. ✅ 集成 smoke test 通过

---

## 11. 村民对话词条池

按用户要求 10 句随机：

```gdscript
const VILLAGER_LINES = [
  "今天天气真不错。",
  "听说东边的山上有大块石头。",
  "你看起来像个新来的。",
  "晚上小心点，那些黏糊糊的东西很烦人。",
  "我以前也想去探险，后来腰扭了。",
  "你有没有多余的木板？开个玩笑。",
  "我们村只有两间屋子，住起来挺挤的。",
  "如果你有镐子，可以挖出很有用的东西。",
  "门关好啊，黏糊糊的东西不会开门，但说不定哪天就会了。",
  "再见。"
]
```

> M3 加村民系统时，对话池会扩展为按 NPC 角色分组。

---

## 12. 美术约定（M1 占位）

- **方块**：单色 16×16 像素方块，色板：
  - grass = 绿色 `#4caf50`
  - dirt = 棕色 `#8b5a2b`
  - stone = 灰色 `#9e9e9e`
  - sand = 米色 `#f4d35e`
  - log = 深棕 `#5d4037`
  - leaves = 深绿 `#2e7d32`
  - planks = 浅棕 `#a87445`
  - workbench = 棕橙 `#bf6f3a` + 顶部黑边
  - door = 暗棕 `#6d4c41`
  - bedrock = 深灰 `#424242`
- **玩家**：白色 12×24 矩形，朝向用一个 4×4 黑色"眼"标记
- **史莱姆**：绿色 16×12 圆角矩形
- **村民**：蓝色 12×24 矩形 + 红色头顶
- **门开/关**：开 = 棕色细条；关 = 棕色全方块

所有占位图用 `script tool` 在启动时程序绘制为 `ImageTexture`，**不需要 PNG 文件**。M5 替换为 AI 生成精美像素。

---

## 13. 输入映射

在 `project.godot` 的 `InputMap` 配置：

| 动作 | 默认键 |
|---|---|
| move_left | A / ← |
| move_right | D / → |
| jump | Space / W / ↑ |
| interact | E |
| attack | 鼠标左键 |
| use | 鼠标右键 |
| hotbar_1 .. hotbar_9 | 数字键 1-9 |
| hotbar_prev / next | 鼠标滚轮 |
| save_quick | F5 |
| toggle_debug | F3 |
| pause_menu | ESC |

---

## 14. 待用户在复审时确认的假设

| ID | 假设 | 默认选择 | 影响 |
|---|---|---|---|
| Q1 | 暗格定义用"无天光直射"简化版，不做视觉光照 | 是 | 若否，光照从 M5 提前到 Demo，工作量约翻倍 |
| Q2 | sand 不受重力 | 是 | 简化物理；M2 可加 |
| Q3 | stone 直接掉 stone item（无 cobblestone 中间态） | 是 | M3 冶炼系统加 cobblestone |
| Q4 | 工具无耐久 | 是 | 简化背包压力；M2 可加 |
| Q5 | 树叶不发芽（树苗系统推迟） | 是 | M4 |
| Q6 | 单存档槽，不做存档列表 UI | 是 | Demo 够用；M2 可加 |
| Q7 | 史莱姆全局上限 8 只 | 是 | 性能保险；可调 |
| Q8 | 村庄固定 2 间屋子，不随机化 | 是 | M3 NPC 入住时再加随机化 |

---

## 15. 风险与缓解

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| Godot 4.3 TileMapLayer API 不稳定 | 中 | 中 | `project.godot` 锁定为 Godot 4.3.x；CI 上跑 headless 验证 |
| 1024×256 tile 渲染性能不达标 | 低 | 高 | 启用 TileMapLayer 视口剔除；最坏可改 512×128 |
| 存档/加载 RLE 编解码 bug 致数据丢失 | 中 | 高 | TDD 覆盖；加 backup（旧存档保留为 .bak） |
| 史莱姆 AI 卡墙 | 中 | 低 | Hop 失败后回 Idle；超时强制 reposition |
| 合成形状匹配 + 镜像 + 留白逻辑复杂出 bug | 高 | 中 | 大量单元测试覆盖所有 6 配方的合法/非法案例 |
| 暗格全图重算每秒一次太慢 | 低 | 中 | 改为增量重算；预算 5ms/帧 |

---

## 16. 不在 Demo 的未来工作（路线提示）

- **M2 生存循环**：日夜（带颜色变化）+ 夜晚刷怪强化 + 火把（光照初版）+ 沙子重力 + 树苗生长
- **M3 进度**：矿物冶炼 + 铁器装备 + 第一个 Boss（"史莱姆王"复用 slime AI 扩大版）+ NPC 入住条件（玩家盖房 → NPC 自动入住）
- **M4 世界多样性**：洞穴生成 + 矿脉 + 多生态切换 + 地牢预制结构
- **M5 视觉完成度**：真实光照 + 视差背景 + 天气 + 动画系统 + 音效音乐 + AI 生成美术替换占位

---

## 17. 文档状态

- **v1（2026-05-17）** — 草案，等待用户复审
- 之后任何变更：本文件新增"变更日志"章节

---

## 18. 实施进度

- ✅ **P1 Foundation** — tag `demo-p1-foundation` — 2026-05-17
  - GUT 9.3.0 接入 + 23 个自动化测试通过
  - TileData (→ autoload `Tiles`，规避内建类冲突) + WorldGenerator + SkyLightGrid
  - TileSetBuilder 程序构建 (含实心物理 polygon)
  - Player CharacterBody2D + 4 状态动画 + coyote time
  - World 场景 (1024×256 tile + 玩家出生 + 相机平滑跟随)
  - Debug HUD (FPS / Pos / Tile / Dark，F3 切换)
  - 用户验收方式：信任 smoke integration test (3 个)，不开编辑器
- ✅ **P1.5 Atmosphere & Feel** — tag `demo-p1.5-feel` — 2026-05-18
  - 视差云 3 层 + 玩家 jump/land/walk 尘埃
  - Effects autoload (block_break / place_bounce / jump_dust / land_dust / walk_puff)
  - CrackOverlay 挖进度裂纹 4 阶段框架
  - FloatingPrompt 「按 E」提示框架 (API: show_prompt/hide_prompt)
  - 57 个测试全过
  - P2 接 5 个 hook 即可接通 mining/place 的视觉反馈
- ✅ **P2 Items + Interaction + Crafting** — tag `demo-p2-items` — 2026-05-18
  - 挖/放/掉落/拾取/热键栏 UI (9 格图标 + 计数 + 高亮)
  - Inventory (36 槽) + ItemDB (14 物品) + RecipeDB (6 配方) + RecipeMatcher (镜像 + 平移 + 边界)
  - 2×2 内置合成 (按 C) + 3×3 工作台合成 (按 E + chebyshev ≤ 2)
  - 工具 tier 强制 (徒手不挖石、木镚开锁 stone、木斧砍 LOG ×3)
  - 接通 P1.5 视觉：挖进度裂纹 + 块破碎粒子 + 放下弹动
  - 114 个自动化测试全过 (整局闭环 + 60s 长跑)
- ⏳ **P3** — 内容 + 持久化 (史莱姆 / 村民 / 门 / 存档 / 主背包 UI / 拖拽 / shift-move)

