# 群系水系统设计 (Biome Water)

用户需求 (2026-06-02):
1. 水在**每个群系**都要有 (除了**雪原**)
2. 水坑**搞大些** (现在太小)
3. **每个群系水颜色不同** (功能, 非 bug) —— 配色: 自然系
   - 森林 = 清澈蓝 (复用现成 WATER)
   - 沙漠绿洲 = 青绿松石 (turquoise)
   - 丛林 = 翠绿 (emerald)
   - 沼泽 = 浑浊墨绿 (murky)
   - 雪原 = 不放水

## 群系 (world_generator.gd)
`BIOME_FOREST=0 / DESERT=1 / SNOW=2 / JUNGLE=3 / SWAMP=4`。按 x 距 biome center ≤100 判定,
`_biome_at_x(x, centers)`。

## 设计决策

**只新增 3 个"满水"方块** (森林/雪原/默认仍用现成 `Tiles.WATER` 蓝):
- `WATER_DESERT=81` `WATER_JUNGLE=82` `WATER_SWAMP=83`
- 行为同 WATER: 非实心, 不可挖, 4 帧动画, 水位变体 (L1-3) 仍用通用蓝
  (生成的水池是满水 L4 = 群系色; 被 sim 扰动后降级会变通用蓝, 可接受)

**统一水判定** `Tiles.is_water(tid)` (tile_data.gd): 认全部 8 个水 tile。
把散落的 `==WATER or ==WATER_L1..` 都换成它 (player_controller / animal_base /
player_action 钓鱼×2 / minimap)。加新水只改这一处。

`water_sim._liquid_kind` / `_level_of`: 3 个群系水认作 water / L4。

## Step 1 — 水方块 + 染色 + 统一判定 (无生成改动)
- tile_data.gd: 3 常量 + 3 _PROPS (solid:false mineable:false) + `is_water()`
- blocks_art.gd: 3 常量 + 3 biome 调色板 + `get_water_animated_atlas_p(palette)` + _PATTERNS icon
- art_cache.gd: 注册 3 tile (各自染色动画 atlas)
- tileset_builder.gd: tile_ids 加 3 + 4 帧动画注册
- water_sim.gd: _liquid_kind / _level_of 认群系水
- 各处水检测改 Tiles.is_water()
- minimap: 3 群系水色
- 测试: tile 定义 / is_water / sim 认群系水会流

## Step 2 — 生成: 各群系水塘 + 加大
- `_biome_water_tile(biome)`: DESERT→WATER_DESERT, JUNGLE→_JUNGLE, SWAMP→_SWAMP, 其余→WATER
- 现有放水点 (绿洲/洞穴池/地下海/空岛池) 改用 `_biome_water_tile(_biome_at_x(x))`
- **加地表水塘**: forest/jungle/swamp 地表碗状大水塘 (雪原跳过)
- **加大**: WATER_FILL_LEVEL 6→? , OASIS 宽/深加大, WATER_BASIN_MAX_SIZE 加大
- 测试: 生成放群系水 / 雪原无水 / 水塘更大

## 坑
- 加 tile 必同步 tileset_builder.tile_ids (漏了不显示不报错) + _ZH_NAMES? (水不是 item, 但
  crafting_panel 若引用…水不进配方, 跳过)
- 验收靠 GUT (无 GUI)
