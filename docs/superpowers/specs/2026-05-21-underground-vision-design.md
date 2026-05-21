# Underground Vision & Caves Design

**日期**: 2026-05-21
**Milestone**: Demo (M1) 后续追加

## 一、目标

让"地表 vs 地底"在视觉和玩法上拉开差距：

- 地表：白天看得远，自然亮（沿用 SkyLightGrid）
- 地底：默认黑暗，只有玩家自带微光 + 放置火把扩光
- 地底有探索内容：洞穴、煤矿、铁矿、深层石头、露天洞口
- 火把可合成、可放置、可拆回，并带火焰粒子和光晕呼吸
- 顺手加铁镐（tier 3）作为新进阶装备

## 二、范围

**纳入本 spec**:
1. 全局暗 + Light2D 光照系统
2. 火把 tile + 火焰特效 + 合成 + 放置/回收
3. 地底地形改造：洞穴、煤矿、铁矿、深层石头分层、露天洞口
4. 铁镐（tier 3，合成）

**不在本 spec**:
- 火把"会熄灭/燃料"机制 → 永亮
- 铁剑/铁斧/其他铁制装备
- 矿石专属高级镐 tier 检查（铁矿仍按 tier 2 = 石镐可挖；铁镐先无独占用途）
- 地底专属敌人/生物群

## 三、架构总览

```
World (Node2D)
├── CanvasModulate           ← 全局暗（Color(0.12, 0.08, 0.06)）
├── TerrainLayer (TileMapLayer)
├── Entities
│   └── Player
│       ├── PlayerAura       PointLight2D, 小光圈
│       └── SunAura          PointLight2D, 大光圈，仅头顶天空时启用
├── TorchLights (Node2D)     ← TorchFx 容器（每个火把一个）
├── ChunkManager
└── Camera2D (reparented 到 Player)
```

新增脚本：
- `scripts/world/world_lighting.gd` — 火把光源生命周期管理
- `scripts/fx/torch_fx.gd` + `scenes/fx/torch_fx.tscn` — 火把整体特效（火焰 + 光 + 粒子发射器）
- `scripts/fx/torch_spark_particle.gd` + `scenes/fx/torch_spark_particle.tscn` — 单个火花

新增 art：
- `scripts/art/blocks_art.gd`：DEEP_STONE / COAL_ORE / IRON_ORE / TORCH 调色板 + pattern
- `scripts/art/particles_art.gd`：`get_torch_spark(color)` 1×1 / 2×2 暖色粒子贴图

## 四、第 1 节：光照系统

### 4.1 节点

- **CanvasModulate**（World 子节点，覆盖整个 Canvas）
  - `color = Color(0.12, 0.08, 0.06)` —— 暖洞穴色（偏红橙暗）
- **PlayerAura**（Player 子节点，PointLight2D）
  - `texture` = `ArtCache.radial_gradient(64, 64, Color(1,1,1,1))`（一次性生成柔和径向白渐变）
  - `energy = 0.5`
  - `color = Color(1.0, 0.95, 0.85)`（暖白）
  - 永远启用
- **SunAura**（Player 子节点，PointLight2D）
  - `texture` = `ArtCache.radial_gradient(400, 400, ...)` 大径向渐变
  - `energy` 在 `SUN_ENERGY_OFF (0.0)` ↔ `SUN_ENERGY_ON (1.5)` 之间 lerp
  - `color = Color(1.0, 0.95, 0.80)` 暖日光色

### 4.2 SunAura 切换

`player_controller.gd` 每帧：

```gdscript
var tile_x = int(floor(global_position.x / 16))
var tile_y = int(floor(global_position.y / 16))
var exposed = SkyLightGrid.is_sky_exposed(tile_x, tile_y)
_target_sun_energy = SUN_ENERGY_ON if exposed else SUN_ENERGY_OFF
_sun_aura.energy = lerp(_sun_aura.energy, _target_sun_energy, delta / SUN_FADE_TIME)
# SUN_FADE_TIME = 0.3
```

效果：玩家走到天空下时 0.3s 内日光淡入；钻进洞穴时 0.3s 内淡出。

### 4.3 火把光（在第 2 节细化）

### 4.4 性能

- 一次性纹理生成（径向渐变）通过 `ArtCache` 缓存（已有 autoload）
- 火把光数量 = 视野内 TorchFx 数量（受 chunk 加载范围控制，VIEW_RADIUS ≈ 1-2 chunk，单 chunk 64×WORLD_HEIGHT ≈ 数千格但典型 <30 个火把）
- 不做额外的剔除；Godot 的 Light2D 自带视锥剔除

## 五、第 2 节：火把 + 火焰特效

### 5.1 新 Tile

`scripts/world/tile_data.gd`:
```gdscript
const TORCH := 14
# ...
TORCH: {
    "solid": false,
    "mineable": true,
    "tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
    "drops": [["torch", 100, 1, 1]],
},
```

### 5.2 新 Item

`scripts/items/item_db.gd`:
```gdscript
"torch": {"placeable_tile_id": Tiles.TORCH, "tool_kind": "", "tool_tier": 0, "max_stack": 99},
"coal":  {"placeable_tile_id": -1,         "tool_kind": "", "tool_tier": 0, "max_stack": 99},
```

### 5.3 合成

`scripts/crafting/recipe_db.gd` 加：
```gdscript
{
    "id": "torch",
    "grid_size": Vector2i(1, 2),
    "pattern": [
        ["coal"],
        ["log"],
    ],
    "output_id": "torch",
    "output_count": 4,
    "mirror_ok": false,
},
```

### 5.4 放置规则

玩家手持 `torch` + 现有放置键（沿用 PlayerAction 现有放置逻辑） →
- 目标格必须是 AIR
- 目标格必须有"支撑"：下/左/右 至少一面是 solid（避免漂浮火把）
- `World._set_tile(x, y, Tiles.TORCH)`

### 5.5 TorchFx 节点

`scenes/fx/torch_fx.tscn`（根 Node2D）：

```
TorchFx (Node2D)
├── Flame (Sprite2D)        2-frame flicker animation
├── Light (PointLight2D)    暖橙黄光圈
└── SparkTimer (Timer)      0.12-0.20s 触发一次
```

`scripts/fx/torch_fx.gd` 关键逻辑：
- `_ready()`：初始化 Flame 帧 0 + Light energy 1.2 + SparkTimer 启动
- `_process(delta)`：
  - Flame 帧切换：累计时间 ≥ 0.15s 切换 frame 0/1，并 scale.y ±0.1 微跳
  - Light 呼吸：`light.energy = base_energy + sin(time*8)*0.10 + randf_range(-0.05, 0.05)`
- `_on_spark_timer_timeout()`：
  - 随机重置 SparkTimer 间隔 0.12-0.20s
  - 实例化 `TorchSparkParticle` 加到 `effects_root`
  - 起点 = `global_position + Vector2(randf_range(-1, 1), -4)`（火焰顶上方）

### 5.6 TorchSparkParticle

`scripts/fx/torch_spark_particle.gd`（Sprite2D）：
- `lifetime = 0.8`
- 初速度 `vel.y ∈ [-80, -40]`，`vel.x ∈ [-15, 15]`
- 重力 `200`（弱）
- 颜色随机：90% 在 `Color(1.0, 0.9, 0.4)` 黄 ↔ `Color(1.0, 0.5, 0.2)` 橙间 lerp；5% 红 `Color(1.0, 0.3, 0.1)`
- 后半段（_age > lifetime/2）alpha lerp 到 0
- 贴图通过 `ParticlesArt.get_torch_spark(color)` 拿 2×2 暖色像素

### 5.7 生命周期管理

`scripts/world/world_lighting.gd`（World 子节点）：

```gdscript
var _torches: Dictionary = {}  # Vector2i tile_coord → TorchFx node

func on_tile_placed(x: int, y: int, tid: int) -> void:
    if tid == Tiles.TORCH:
        _spawn_torch(x, y)

func on_tile_removed(x: int, y: int, old_tid: int) -> void:
    if old_tid == Tiles.TORCH:
        _despawn_torch(x, y)

func _spawn_torch(x, y): ...  # 实例化 TorchFx 到 TorchLights 节点
func _despawn_torch(x, y): ...  # 查 _torches，free 掉
```

`World._set_tile` 改为额外发信号或直接调 `world_lighting.on_tile_placed/removed`。

### 5.8 Chunk 卸载

`World._on_chunk_unloaded(cx)` 中：扫描该 chunk 范围内 `_torches` 字典，全部 free 掉。
重新加载时：`_on_chunk_loaded(c)` 扫描 chunk 数据中所有 TORCH tile，调用 `_spawn_torch`。

### 5.9 视觉资产

- `BlocksArt._P_TORCH` 调色板 + `_TORCH` 16×16 pattern：木棍底（暖深棕） + 顶部小火苗（暖红/橙），整体简约（细节由 TorchFx 节点叠加在 tile 上）
- `BlocksArt.get_palette(TORCH)` 返回火焰暖色（碎块特效用）

## 六、第 3 节：地底地形

### 6.1 新 Tile

```gdscript
const COAL_ORE := 15
const IRON_ORE := 16
const DEEP_STONE := 17
```

属性（`tile_data.gd`）：
```gdscript
DEEP_STONE: {
    "solid": true, "mineable": true,
    "tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
    "drops": [["stone", 100, 1, 1]],
},
COAL_ORE: {
    "solid": true, "mineable": true,
    "tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
    "drops": [["coal", 100, 1, 1]],
},
IRON_ORE: {
    "solid": true, "mineable": true,
    "tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},  # 石镐+ 才能挖
    "drops": [["iron_ore", 100, 1, 1]],
},
```

### 6.2 world_generator 改造

新增三个 noise：
```gdscript
var cave_noise = FastNoiseLite.new()
cave_noise.seed = world_seed + 2
cave_noise.noise_type = FastNoiseLite.TYPE_PERLIN
cave_noise.frequency = 0.06
cave_noise.fractal_octaves = 2

var coal_noise = FastNoiseLite.new()
coal_noise.seed = world_seed + 3
coal_noise.noise_type = FastNoiseLite.TYPE_PERLIN
coal_noise.frequency = 0.12

var iron_noise = FastNoiseLite.new()
iron_noise.seed = world_seed + 4
iron_noise.noise_type = FastNoiseLite.TYPE_PERLIN
iron_noise.frequency = 0.10
```

每列地形填充逻辑改为：

```gdscript
for y in height:
    var tid: int
    if y < surf:
        tid = Tiles.AIR
    elif y == surf:
        tid = Tiles.SAND if is_sand_col else Tiles.GRASS
    elif y < surf + DIRT_DEPTH:
        tid = Tiles.SAND if is_sand_col else Tiles.DIRT
    elif y >= height - BEDROCK_ROWS:
        tid = Tiles.BEDROCK
    else:
        # 石头 / 深石分层
        var deep_threshold = surf + int((height - surf) * DEEP_STONE_RATIO)  # 0.5
        var base_stone = Tiles.DEEP_STONE if y >= deep_threshold else Tiles.STONE
        tid = base_stone

    # 矿石覆盖（仅在 STONE / DEEP_STONE tile 上）
    if tid == Tiles.STONE or tid == Tiles.DEEP_STONE:
        var cn = coal_noise.get_noise_2d(float(world_x), float(y))
        var inn = iron_noise.get_noise_2d(float(world_x), float(y))
        if cn > COAL_THRESHOLD:  # 0.55
            tid = Tiles.COAL_ORE
        elif tid == Tiles.DEEP_STONE and inn > IRON_THRESHOLD:  # 0.65（铁更稀且仅深层）
            tid = Tiles.IRON_ORE

    # 洞穴覆盖（除 BEDROCK 外都能挖空，包括 DIRT/STONE/矿石）
    if tid != Tiles.BEDROCK and tid != Tiles.AIR and y > surf:
        var cv = abs(cave_noise.get_noise_2d(float(world_x), float(y)))
        if cv > CAVE_THRESHOLD:  # 0.55
            tid = Tiles.AIR

    c.tiles[local_x][y] = tid
```

常量：
```gdscript
const DIRT_DEPTH := 6            # 已有
const BEDROCK_ROWS := 2          # 已有
const DEEP_STONE_RATIO := 0.5    # 地表往下 50% 起为 DEEP_STONE
const COAL_THRESHOLD := 0.55
const IRON_THRESHOLD := 0.65
const CAVE_THRESHOLD := 0.55
```

### 6.3 露天洞口

不需要单独逻辑。洞穴 noise 在 `y > surf` 处生效，意味着洞穴可能从 `surf+1`（即地表正下一格）开始挖空，再向上没有约束 —— 那就形成"地表下一格就是空腔"，玩家可以看到洞口在地表附近。

进一步：若 cave_noise 阈值在 `surf+1..surf+3` 都通过，会形成一段斜面缺口暴露在天空下 —— 这正是用户想要的"露天洞口"。

### 6.4 出生点保护

新增"出生点保护半径"：在 `_find_spawn_in_loaded` 选定出生点后，世界 `_ready` 阶段调用一次 `_clear_spawn_caves(spawn_point, radius=2)`，强制把出生点周围 5×5 范围内 AIR 之外的洞穴洞口填回 STONE/DIRT —— 保证玩家不至于一出生就掉洞里。

> 实现细节：spawn 选定后扫该 chunk 内 spawn_point 周围 5×5 tiles，若是 AIR 但 y > spawn_y（也就是地表以下被挖空），按原始非洞穴生成回填。
> 简化版：不实现 —— 让 cave_noise 自然分布；如果运行时发现出生点太坑爹再加。**建议先不实现，看实际效果。**

### 6.5 视觉

`scripts/art/blocks_art.gd` 新增：

```gdscript
const _P_DEEP_STONE := {
    "s": Color8(102, 88, 78),    # 暖深灰基（STONE 的 156 → 102, 降 35%）
    "S": Color8(72, 60, 52),     # 更深阴影
    "l": Color8(125, 108, 96),   # 暖高光（不发亮）
    "k": Color8(48, 36, 28),     # 暖深裂纹
    "L": Color8(140, 122, 108),  # 暖凸起
    "m": Color8(88, 75, 66),
    "b": Color8(60, 50, 42),
}

const _P_COAL_ORE := {
    # 沿用 STONE 底色 (s/S/l/k/L/m/b)，加 c 系列煤色
    "s": Color8(156, 144, 136),  # 暖灰基（同 STONE）
    "S": Color8(122, 110, 102),
    "l": Color8(182, 168, 158),
    "k": Color8(92, 80, 72),
    "L": Color8(204, 191, 181),
    "m": Color8(138, 125, 116),
    "c": Color8(50, 40, 35),     # 煤块基（暖底，不死黑）
    "C": Color8(28, 22, 20),     # 煤块阴影
    "h": Color8(80, 65, 55),     # 煤块边缘高光
}

const _P_IRON_ORE := {
    # 沿用 STONE 底色，加 r 系列铁锈色
    "s": Color8(156, 144, 136),
    "S": Color8(122, 110, 102),
    "l": Color8(182, 168, 158),
    "k": Color8(92, 80, 72),
    "m": Color8(138, 125, 116),
    "r": Color8(168, 100, 60),   # 铁锈基
    "R": Color8(130, 70, 40),    # 铁锈阴影
    "h": Color8(200, 140, 90),   # 铁锈高光
}
```

pattern 设计（参考 _STONE 风格，3 簇矿斑）：
- **DEEP_STONE**：STONE 同构，但用更多 m/b/k，凸起 LL 改为 mm + l 极少，裂纹 kkkk 更密集
- **COAL_ORE**：STONE 底，左上 + 右中 + 左下 3 个 3×3 区域换成 c/C/h 簇
- **IRON_ORE**：STONE 底，3 个 3×3 簇换成 r/R/h，分布偏分散

详细 16×16 pattern 在实现阶段定，对齐 `_STONE` 的"凸块 + 裂纹 + 散点"结构。

### 6.6 矿石碎块特效

`BlocksArt.get_palette(tile_id)` 加 COAL_ORE / IRON_ORE / DEEP_STONE 调色板 → `effects.spawn_block_break` 会自动用对的颜色画碎片。

## 七、铁镐（顺带）

### 7.1 新 Item

`item_db.gd`:
```gdscript
"iron_ore":     {"placeable_tile_id": -1, "tool_kind": "", "tool_tier": 0, "max_stack": 99},
"iron_pickaxe": {"placeable_tile_id": -1, "tool_kind": "pickaxe", "tool_tier": 3, "max_stack": 1},
```

### 7.2 配方

`recipe_db.gd`:
```gdscript
{
    "id": "iron_pickaxe",
    "grid_size": Vector2i(3, 3),
    "pattern": [
        ["iron_ore", "iron_ore", "iron_ore"],
        ["",         "planks",   ""],
        ["",         "planks",   ""],
    ],
    "output_id": "iron_pickaxe",
    "output_count": 1,
    "mirror_ok": true,
},
```

### 7.3 现状

铁镐 tier 3，但本次没有要 tier 3 才能挖的方块。**目的是奖励玩家"挖到了铁"，作为进度可见的装备升级**；后续可以加 tier-3 专属 tile（如金矿、钻石）。

如未来要让铁镐挖得更快，可以扩展 `tool_tiers` 的语义（现在是 binary 能不能挖；后续可改为速度倍率）。本 spec 不动该机制。

## 八、配置常量集中

`scripts/world/lighting_constants.gd`（新文件）或塞到 world_lighting.gd 顶部：
```gdscript
const DARK_COLOR := Color(0.12, 0.08, 0.06)
const PLAYER_AURA_RADIUS := 64.0
const PLAYER_AURA_ENERGY := 0.5
const SUN_AURA_RADIUS := 400.0
const SUN_ENERGY_ON := 1.5
const SUN_ENERGY_OFF := 0.0
const SUN_FADE_TIME := 0.3
const TORCH_LIGHT_RADIUS := 96.0
const TORCH_LIGHT_ENERGY := 1.2
const TORCH_LIGHT_COLOR := Color(1.0, 0.7, 0.3)
```

## 九、测试计划

新增/修改测试：

- `tests/unit/test_world_generator.gd`（新增）：
  - 给定固定 seed，生成 chunk 0
  - 断言至少有 N 个 AIR tile 在地下（洞穴生效）
  - 断言至少有 1 个 COAL_ORE tile（煤矿生效）
  - 断言至少有 1 个 IRON_ORE tile（铁矿生效）
  - 断言深度 ≥ deep_threshold 处只出现 DEEP_STONE / IRON_ORE / COAL_ORE / AIR / BEDROCK
  - 断言 BEDROCK 永远不被 cave_noise 挖空
- `tests/unit/test_recipe_db.gd`：加 torch、iron_pickaxe 配方存在性断言
- `tests/unit/test_item_db.gd`：加 torch、coal、iron_ore、iron_pickaxe item 存在性
- `tests/unit/test_tile_data.gd`：加 TORCH/COAL_ORE/IRON_ORE/DEEP_STONE 属性 + drops 断言
- `tests/integration/test_torch_lifecycle.gd`（新增）：
  - 模拟 World._set_tile(0, 50, TORCH) → 断言 TorchLights 下出现一个 TorchFx 节点
  - 再 set_tile(0, 50, AIR) → 断言 TorchFx 被释放
- `tests/unit/test_sky_light_grid.gd`：现有测试不受影响（验证）

光照视觉效果（CanvasModulate / 渐变粒子）不易自动化测试，依赖目检。

## 十、变更文件清单

**新增**:
- `scripts/world/world_lighting.gd`
- `scripts/world/lighting_constants.gd`（或合并）
- `scripts/fx/torch_fx.gd`
- `scripts/fx/torch_spark_particle.gd`
- `scenes/fx/torch_fx.tscn`
- `scenes/fx/torch_spark_particle.tscn`
- `tests/unit/test_world_generator.gd`
- `tests/integration/test_torch_lifecycle.gd`

**修改**:
- `scenes/world/world.tscn` —— 加 CanvasModulate 节点
- `scripts/world/world.gd` —— 接入 world_lighting；chunk 加载/卸载触发 torch spawn/despawn；调用 spawn_caves 保护（如启用）
- `scripts/world/world_generator.gd` —— 洞穴/矿石/分层逻辑
- `scripts/world/tile_data.gd` —— TORCH/COAL_ORE/IRON_ORE/DEEP_STONE 常量 + 属性
- `scripts/items/item_db.gd` —— torch/coal/iron_ore/iron_pickaxe items
- `scripts/crafting/recipe_db.gd` —— torch 和 iron_pickaxe 配方
- `scripts/player/player_controller.gd` —— SunAura energy lerp（每帧或节流查 SkyLightGrid）；player 节点下挂 PlayerAura/SunAura
- `scripts/art/blocks_art.gd` —— 4 个新调色板 + 4 个新 pattern + `get_palette` 分支
- `scripts/art/particles_art.gd` —— `get_torch_spark(color)`
- `scripts/world/tileset_builder.gd` —— 新增 TORCH/COAL_ORE/IRON_ORE/DEEP_STONE 加入 TileSet

## 十一、风险与折中

1. **CanvasModulate 全图变暗** —— 注意 UI 层 (CanvasLayer) 不会被 CanvasModulate 影响（CanvasLayer 不在主 World canvas 下），背包/暂停菜单等不会变暗。✅
2. **天空层 (cloud_layer)** —— 如果在主 canvas 内会被压暗，导致云变黑。需要把 CloudLayer 移到独立 CanvasLayer 或者排除在 CanvasModulate 范围外。实现时核对。
3. **TorchFx 数量爆炸** —— 玩家狂放火把时；视野外通过 chunk 卸载自动清理；同 chunk 内若 >50 个可能掉帧，先不预先优化，遇到再做。
4. **spawn 落进洞穴** —— 第 6.4 节备选方案。先不实现，跑起来观察。
5. **铁矿 tier 2 = 石镐能挖** —— 等于"石镐 → 铁矿 → 铁镐"是合理进度链；但需要先有石镐才能得铁，符合既有 tier 体系。✅

## 十二、实施顺序（建议给 writing-plans 的提示）

按以下顺序最不容易破坏现有功能：

1. **地形扩展**（最独立）：新 Tile 常量 + tile_data 属性 + blocks_art 调色板/pattern + tileset_builder + world_generator 改造 + item_db + recipe_db。测试：生成确定性 + 配方 + tile 属性。
2. **铁镐配方**：item + recipe + test。
3. **光照基础**：CanvasModulate + PlayerAura + SunAura + SkyLightGrid 联动。手动看视觉。
4. **火把 tile + 静态光**：放下 TORCH tile + 简单 PointLight2D（不带粒子）。
5. **火把动效**：TorchFx 完整版（火焰 2 帧 + 光呼吸 + 火花粒子）。
6. **集成测试**：torch_lifecycle、chunk 加载/卸载触发 torch 重建。
