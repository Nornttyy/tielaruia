# 流体流动设计：岩浆流动 + 水/岩浆反应

日期：2026-05-31
里程碑：M2（环境互动，"更像泰拉瑞亚"系列之一）

## 目标

让岩浆像水一样流动（慢吞吞、有深浅），并实现"水碰岩浆 → 岩浆变石头"的经典互动。

水当前已有流动（`scripts/world/water_sim.gd`：4 水位、重力下流、横向铺平、体积守恒、dirty 列表驱动）。岩浆当前是静态方块（`LAVA = 56`，非实心、不可挖、踩到每 0.5s 扣血）。

## 已定需求（来自用户）

1. **岩浆流速 = 慢吞吞**：比水慢（黏糊糊感）。
2. **水 + 岩浆 = 普通石头**：岩浆那格变 `STONE`，挨着的水扣掉一格；冒一下白烟。**不用黑曜石**（OBSIDIAN 已存在于世界生成中，本特性不涉及）。
3. **岩浆有深浅**：跟水一样 4 个深浅，需新增 `LAVA_L1/L2/L3` 方块（程序绘制）。

## 选定方案

**方案 A：把 `water_sim.gd` 升级成通用「流体引擎」**，同时管水和岩浆。
水和岩浆共用"重力下流 + 横向铺平 + 体积守恒"逻辑，差异仅为：流速（岩浆慢）、互相反应。一份代码维护两种流体，避免 `lava_sim.gd` 复制带来的双份维护。

（已否决方案 B：复制 `lava_sim.gd` —— 重复代码，流动规则改一处要改两处。）

## 实现细节

### 1. 新增方块（`scripts/world/tile_data.gd`）

```
const LAVA_L1 := 71   # 1/4 岩浆
const LAVA_L2 := 72   # 2/4 岩浆
const LAVA_L3 := 73   # 3/4 岩浆
# LAVA = 56 仍表示满格 (4/4)
```

- 编号 71/72/73 当前空闲（现有最大 id = 70）。
- `Tiles.is_solid()` 对这三个返回 `false`（镜像 `LAVA`，保持非实心可穿过）。
- 若有 `is_liquid` / `is_lava` / 岩浆伤害判定的辅助函数（见 `player_health.gd` 的 `_check_lava_damage` 用 `== Tiles.LAVA`），需扩展为包含 `LAVA_L1..L3`——**流动的浅岩浆站上去也要扣血**。

### 2. 岩浆深浅美术（`scripts/art/blocks_art.gd`）

新增 `get_lava_level_atlas(level: int)`，镜像现有 `get_water_level_atlas`：
- 复用现有 `_LAVA` pattern + `_P_LAVA` 调色板。
- 用 `_clip_water_top`（已存在，通用）把顶部 `(4 - level) * 4` 行清成透明，模拟低液位。
- 岩浆**不需要 4 帧动画**（水有，岩浆保持单帧即可，少做动画）；输出 16×16 单帧即可，或复用现有单帧 atlas 流程。
- 越浅可略微调暗（可选润色，非必须）。

在 `scripts/autoload/art_cache.gd`：
- 把 `LAVA_L1/L2/L3` 加入需要构建贴图的 tile 列表（见现有 `BlocksArt.WATER_L1...` 那段）。
- 在贴图构建的 `elif` 链里加三个分支：`block_textures[id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(n))`，`block_icons[id] = BlocksArt.get_texture(...)`（或用满格岩浆 icon）。

### 3. TileSet 注册（`scripts/world/tileset_builder.gd`）

- 把 `Tiles.LAVA_L1, Tiles.LAVA_L2, Tiles.LAVA_L3` 加进 `tile_ids` 数组（**漏加 = 方块不显示也不报错**，见项目坑）。
- 碰撞由 `Tiles.is_solid()` 门控，岩浆非 solid → 自动无碰撞、可穿过。无需额外处理。
- 岩浆不加动画帧（不进 line 113 的水动画分支）。

### 4. 流体引擎升级（`scripts/world/water_sim.gd`）

**液位辅助通用化**：现有 `_level_of` / `_tile_for_level` 只认水。改为液种感知：
- 新增 `_liquid_kind(tid)` → 返回 `WATER` / `LAVA` / `NONE`。
- `_level_of(tid)` 扩展认 `LAVA / LAVA_L1..L3`（满=4，L3=3，L2=2，L1=1）。
- `_tile_for_level(kind, L)` 按液种返回对应 tile（水返回 WATER_*，岩浆返回 LAVA_*）。

**岩浆慢速**：水每 `TICK_INTERVAL = 0.12s` 流一步。岩浆每 **3 个 tick**（≈0.36s）才流一步：
- 加 tick 计数器 `_tick_n`。
- `_step_tile` 处理岩浆格时，若 `_tick_n % LAVA_TICK_DIVISOR != 0`（`LAVA_TICK_DIVISOR = 3`），**跳过本步但把该格重新标 dirty**（保证下个该轮的 tick 会处理它），这样岩浆不会因为 dirty 被清掉而停住。

**流动逻辑**：完全复用现有"重力下流 → 下方部分填充 → 横向往低位邻居均衡"三段逻辑，唯一改动是把硬编码的 WATER tile 换成"按当前格液种取对应 tile"。

**不同液种不混合**：转移目标只接受 `AIR` 或**同液种**的未满格。异种相邻 → 进入反应（见下），不互相填充。

### 5. 水 + 岩浆 = 石头

在 `_step_tile` 里，处理一个流体格时先做反应检查（早于流动）：
- 当前格是**岩浆**，4 邻居里有任意**水**格 → 当前岩浆格变 `Tiles.STONE`；那格水扣 1 级（L1 → AIR）；`notify_tile_changed` 双方 + 邻居；冒白烟；return（本格已固化，不再流动）。
- 当前格是**水**，4 邻居里有任意**岩浆**格 → 那个岩浆格变 `STONE`；当前水扣 1 级；同样通知 + 冒烟。

任一方向触发都能固化，逻辑对称即可。`STONE` 是实心 → tileset 会给它碰撞（玩家能站上去过岩浆湖）。

### 6. 冒烟特效（`scripts/fx/effects.gd`）

新增 `spawn_steam_puff(world_pos: Vector2)`：复用现有尘土粒子写法（参考 `spawn_walk_puff` / `spawn_jump_dust`），改成偏白灰、向上飘的小股蒸汽。轻量，几颗粒子即可（遵循 FX 可见性：alpha 够、数量够）。

### 7. 多人 / 性能

- 沿用现有 `MAX_TILES_PER_TICK = 300` 上限与 `begin_tile_batch` / `end_tile_batch` 批量广播，岩浆不额外加负担。
- 岩浆走 host-only 模拟（同水），client 收 tile_change 广播。
- 设置 tile 复用 `world._set_water_tile_fast`（它只是设 tile + 跳过重逻辑）；若命名不合适可在 `world.gd` 改名/加 `_set_liquid_tile_fast` 泛化，但功能不变。

## 验收（GUT 集成测试，无 GUI）

新建 `tests/integration/test_liquid_flow.gd`：

1. **岩浆下流**：放满格 LAVA，下方 AIR，跑足够 tick → 岩浆移到下方。
2. **岩浆铺平变薄**：放满格 LAVA，下方堵死、两侧 AIR，跑 tick → 出现 LAVA_L* 向两侧扩散，体积守恒。
3. **岩浆比水慢**：同时放水和岩浆，跑 1 个 tick → 水已动、岩浆未动（验证 cadence）。
4. **水+岩浆→石头**：LAVA 紧挨 WATER，跑 tick → 岩浆格变 STONE，水少一格。
5. **体积守恒**：岩浆流动前后总"液量"不增不减（固化除外，固化是预期消耗）。
6. **浅岩浆烫伤**：玩家站在 LAVA_L1 上 → `_check_lava_damage` 仍扣血。

## 范围之外（YAGNI）

- 岩浆点燃/烧毁方块或物品（无火焰蔓延）。
- 黑曜石产物（用普通石头）。
- 岩浆发光照明（留给"真光照"那块单独做）。
- 下雨累积岩浆之类的岩浆生成源（岩浆只来自世界生成的地狱区）。

## 涉及文件清单

- `scripts/world/tile_data.gd`：加 3 个常量 + `is_solid` / 岩浆判定扩展
- `scripts/art/blocks_art.gd`：加 `get_lava_level_atlas`
- `scripts/autoload/art_cache.gd`：注册 3 个新贴图
- `scripts/world/tileset_builder.gd`：`tile_ids` 加 3 个
- `scripts/world/water_sim.gd`：液种通用化 + 岩浆慢速 + 反应
- `scripts/fx/effects.gd`：`spawn_steam_puff`
- `scripts/player/player_health.gd`：岩浆伤害判定含 LAVA_L*
- `tests/integration/test_liquid_flow.gd`：新建测试
