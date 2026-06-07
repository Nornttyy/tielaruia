# 群系水流动保色 — 设计 spec

> 日期: 2026-06-07
> 状态: 设计已确认, 待写实现 plan

## 背景 / 问题

三种群系水 (沙漠青绿 `WATER_DESERT`、丛林翠绿 `WATER_JUNGLE`、沼泽墨绿 `WATER_SWAMP`) 一流动就变回普通蓝水。

根因 (`scripts/world/water_sim.gd`):
- 水流模拟内部只认 **水位数字** 1–8。`_level_of()` 把三种群系满水都映射成 `8`, 颜色信息在这一步丢失。
- 水流动后用 `_tile_for_level(kind, L)` 把数字翻译回 tile, 这个函数**只产出普通蓝水** (`WATER` + `WATER_L1..L7`), 根本没有"群系薄水"这种 tile。
- 整片找平 `_level_body()` 只在 `L >= 8` (满格) 时用 `full_tile` 还原颜色; 薄水 (L1–7) 仍走 `_tile_for_level` → 蓝。
- 渲染层 (`art_cache.gd`) 完全靠 tile id 选贴图, 没有独立染色层 → tile id 是蓝水, 画出来就是蓝。

## 颜色规则 (已与用户确认)

**水的颜色 = 它当前所在群系的颜色** (不是"它从哪来的")。
- 沙漠水流进平原 → 变蓝; 流进丛林 → 变绿。
- 群系由 x 列决定 (`WorldGenerator._biome_at(x, seed)`), 是种子算出的静态竖带, 每台机器结果一致。
- 用户**明确否决**了"只有满水才染色, 薄水仍蓝"的折中 → 薄水也要按群系染色。

## 核心设计: 彩色水只活在画面上, 数据永远存普通水

**一句话**: 水的**数据 (chunk / 存档 / 联机)** 永远只存"普通水 + 第几档"; **画**那一刻按列查群系, 把 `terrain_layer` 的 cell 换成对应颜色的薄水贴图。21 张彩色薄水 tile 只出现在 `terrain_layer` 这个 TileMapLayer 里, **从不进 `chunk_manager` 数据 / 存档 / 联机**。

### 为什么这么设计 (取舍)

水流模拟历史上踩过"孤儿水 / 震荡"坑, 极其脆弱 (见 [[project_water_sim]])。本设计的最高优先级是 **`water_sim.gd` 一行不改**:
- 模拟、`_level_of`、`is_water`、存档、联机、小地图全部不碰 → 零回归风险。
- 彩色 tile id 永不进数据 → 不用给它们加行为表 (solid/mineable), 不用扩 `is_water`, 存档体积不变, 联机协议不变。
- 各机器按列自己染色, 天然一致 (群系是种子决定的)。

被否决的替代方案:
- **方案二 (数据存彩色)**: 让模拟/`_set_water_tile_fast` 把彩色 id 写进数据。改动散到模拟、存档、联机、行为表多处, 跟脆弱的水模拟纠缠, 风险高。
- **方案三 (单独图层 + shader 按 x 染色)**: 要把水从公共 `terrain_layer` 拆出来 + 写 shader, 跟项目"程序画朴素贴图"风格不搭, web 兼容 / 光照叠加有坑, 改动并不小。

## 实现组成

### 1. 美术: 21 张群系薄水贴图

`scripts/art/blocks_art.gd`:
- 把 `get_water_level_atlas(level)` 复制成 `get_water_level_atlas_p(level: int, palette: Dictionary)`, 多收一个调色板参数 (现在写死 `_P_WATER`)。原函数可改为 `return get_water_level_atlas_p(level, _P_WATER)` 复用。
- 调色板直接用现成的 `_P_WATER_DESERT` / `_P_WATER_JUNGLE` / `_P_WATER_SWAMP`。

### 2. tile id 常量 (两个文件保持一致, 空号 94–114)

当前两文件 id 均连续占用 0–93。新增 21 个连号:

| 常量名 | id |
|---|---|
| `WATER_DESERT_L1` .. `WATER_DESERT_L7` | 94–100 |
| `WATER_JUNGLE_L1` .. `WATER_JUNGLE_L7` | 101–107 |
| `WATER_SWAMP_L1`  .. `WATER_SWAMP_L7`  | 108–114 |

- 在 `scripts/world/tile_data.gd` (`Tiles`) 和 `scripts/art/blocks_art.gd` (`BlocksArt`) **都**加这 21 个常量, 数值必须对齐。
- **不需要**给它们加 `tile_data.gd` 的行为表 (`solid`/`mineable`) 条目 —— 它们永不作为数据 tile 被查询。(保守起见可不加; 若担心边角查询崩, 可统一映射到普通水行为, 见风险小节。)

### 3. tileset + art_cache 注册 (老坑: 漏了不显示也不报错, 见 [[feedback_tileset_registration]])

- `scripts/world/tileset_builder.gd` 的 `tile_ids` 数组加这 21 个 (水无碰撞, 走现有水分支)。
- `scripts/autoload/art_cache.gd` 加染色分支: 对这 21 个 id 用 `get_water_level_atlas_p(level, water_palette_for(对应满水 id))` 生成贴图。

### 4. "画水查色"纯函数 (放 `Tiles` / `tile_data.gd`, 好单测)

```gdscript
# tile id → 第几档 (0 = 不是水). 满水(含群系满水) = 8
func water_level(id: int) -> int

# (档位, 群系) → 该画的彩色 visual tile id. 平原/雪原等无特殊水的群系 → 返回普通蓝水 id
func biome_water_visual(level: int, biome_id: int) -> int
```

- `water_level` 覆盖 `WATER`(8) / `WATER_L1..L7` / `WATER_DESERT/JUNGLE/SWAMP`(8)。
- `biome_water_visual`: 群系 = 沙漠/丛林/沼泽且 level 1–7 → 返回对应 `WATER_*_L{level}`; level 8 → 返回对应满水 id; 其他群系 → 返回普通 `WATER` / `WATER_L{level}`。

### 5. 两个画水入口各加一句 (抽成一处实现)

在 `scripts/world/world.gd` 加:
```gdscript
# 存进数据的是普通水 stored_id; 画到屏幕前按列换成所在群系的彩色 visual id
func _display_water_tile(x: int, stored_id: int) -> int:
    var lvl := Tiles.water_level(stored_id)
    if lvl <= 0:
        return stored_id   # 不是水, 原样
    return Tiles.biome_water_visual(lvl, WorldGenerator._biome_at(x, world_seed))
```

两处调用:
- **`_set_water_tile_fast`** (`world.gd:1857`): `chunk_manager.set_tile` 仍存 `stored_id` (普通水); 但 `terrain_layer.set_cell` 用 `_display_water_tile(x, stored_id)`。
- **区块加载批量画** (`world.gd:938` 一带): 写 `terrain_layer.set_cell` 前, 若是水 tile 走 `_display_water_tile`。

### 6. 明确不动

- `scripts/world/water_sim.gd` —— 一行不改。
- 存档 / 联机 / 小地图 —— 照旧存 / 传 / 读普通水 id。
- `world_generator.gd` —— 不改; 它仍把群系满水 `WATER_DESERT/JUNGLE/SWAMP` 写进数据, `_display_water_tile` 会正确归一化 (满水那 3 个 id `water_level` = 8, 按列重新选色, 同色, 无副作用)。

## 数据流

```
数据层 (chunk_manager / 存档 / 联机):  WATER, WATER_L1..L7  (+ 世界生成的 WATER_DESERT/JUNGLE/SWAMP 满水)
                                         │
                       _display_water_tile(x, stored_id)   ← 按 x 列查群系
                                         ▼
画面层 (terrain_layer TileMapLayer):  WATER / WATER_L3 / WATER_DESERT_L3 / WATER_JUNGLE_L5 ...
```

## 测试 (GUT, 无 GUI)

单元 (`tests/unit/`):
- `water_level()`: `WATER`→8, `WATER_L3`→3, `WATER_DESERT`→8, 石头→0。
- `biome_water_visual()`: (3, 沙漠)→`WATER_DESERT_L3`; (8, 丛林)→`WATER_JUNGLE`; (3, 平原)→`WATER_L3`; (5, 沼泽)→`WATER_SWAMP_L5`。
- art_cache 对 21 个新 id 都有非空贴图 (防漏注册)。

集成 (`tests/integration/`):
- 在沙漠列放水让它流一档, 断言对应 `terrain_layer` cell 的 source id = `WATER_DESERT_L{n}`, 而 `chunk_manager.get_tile` 仍是普通 `WATER_L{n}` (验证"数据普通 / 画面彩色"分离)。
- 平原列同样放水 → cell 仍是普通蓝水 id (验证非群系不染色)。

## 风险 / 注意

1. **id 撞号** (老坑): 94–114 必须在两个文件里完全对齐, 且确认没被别的 WIP 占用 (实现前再 `grep` 一次)。
2. **漏注册** ([[feedback_tileset_registration]]): tileset_builder + art_cache 任一漏掉 → tile 不显示也不报错。21 个都要加。
3. **边角查询彩色 id**: 理论上彩色 id 不进数据, 但若有代码误读 `terrain_layer.get_cell` 当数据用 (而非读 `chunk_manager`), 会拿到没有行为表的彩色 id。实现时 grep 一遍 `terrain_layer.get_cell`; 如确有, 给 21 个 id 补普通水行为映射兜底。
4. **性能**: `_display_water_tile` 每次画水多一次 `_biome_at` (噪声/查表)。水流频繁刷新, 但 `_biome_at` 很轻; 如profile有压力可按 chunk 缓存"列→群系"。先不优化 (YAGNI)。
```
