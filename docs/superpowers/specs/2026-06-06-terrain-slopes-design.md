# 地形斜坡 (Terrain Slopes) 设计

**日期**: 2026-06-06
**里程碑**: 视觉打磨 ("方块更像泰拉瑞亚" 第二步; 第一步草须已上线 commit 97b92e1/4583fec)
**状态**: 设计 (待用户复核 → writing-plans)

## 目标

把地形台阶状的拐角自动削成 45° 斜面, 让山坡 / 洞穴边缘顺滑, 不再"方方正正"。
玩家走上去顺着斜面滑上去, 不再一格一格跳。

## 范围 (Scope) — 已与用户确认

- **只世界自动生成斜坡**。玩家挖/放的方块保持方的; **不做"锤子削坡"工具** (那是另一个大功能, 本设计明确排除)。
- 自然地块都能斜: 草 / 泥 / 沙 / 石 / 深石 (后续可扩雪/丛林/沼泽)。
- 斜坡 = **45° 斜面** (4 朝向)。**不做半砖 (half-block)**。
- 玩家可以**挖掉**斜砖 (掉对应材料), 但不能自己**造/改**斜砖。

## 关键架构决定 (已验证可行)

### 1. 斜砖 = 独立 tile id, 不进 autotile

斜砖是**独立的 tile_id**, 实心, 单格 (single-cell), **不放进 `EdgeTemplates.FAMILY_OF`**。

- **为什么**: `world.gd` 渲染/刷新 (`_render_chunk` 约 L911-924, 跨 chunk 约 L988-994) 每处触发
  autotile 刷新都有 `EdgeTemplates.FAMILY_OF.has(tid)` 守卫 → **不在 FAMILY_OF 的砖永不被 autotile 刷新**,
  天然不会被"邻居一变就刷回方块"。非 autotile 砖走 `else: terrain_layer.set_cell(pos, tid, Vector2i.ZERO)`
  渲染 (跟 BED / PLANT_GRASS 同路径)。
- **邻居无缝**: autotile 的 `make_terrain_query` 用 `Tiles.is_solid(...)` 判邻居。斜砖 `solid:true` →
  旁边的普通方块会把斜砖当实心邻居 → 自动跟它拼边相连 (正是想要的)。

### 2. 物理几乎免费 (move_and_slide)

玩家 `player_controller.gd` 用 Godot 内置 `move_and_slide()` (extends CharacterBody2D)。
三角形碰撞 + 内置斜面处理 = 走斜坡基本不用重写走路逻辑。**唯一必改的一行**:

- `floor_max_angle` 当前**未设 = 默认 0.7854 rad (45°)**, 45° 斜面正好卡边界会被当"墙"。
  需在玩家上设到约 **0.90 rad (~51°)**, 让 45° 斜面算地面能走上去。
  (在 `player_controller.gd` `_ready` 设 `floor_max_angle = 0.90`, 或 scene 里设。)

### 3. 斜砖美术 = 程序生成 (复用基础贴图)

不手画每个材质的斜砖。`ArtCache` 用**对角三角形遮罩**从该材质已有的基础 pattern 切出斜砖贴图:
把被削掉的三角区域设透明 + 沿斜边描 1px 高光/暗影。一个遮罩函数 × N 材质 × 朝向, 全部派生。

### 4. 碰撞 = 三角形多边形

`tileset_builder.gd` 已用多边形碰撞 (`add_collision_polygon` + `set_collision_polygon_points`,
方块格 ±6, tile 12×12)。斜砖注册成单格 + 三角碰撞多边形。例 (升向右 ◢, 实心在右下三角):
`PackedVector2Array([Vector2(-6,6), Vector2(6,6), Vector2(6,-6)])` (斜边 (-6,6)→(6,-6))。

## 斜砖朝向 (4 种)

按"实心填充的三角"区分。地面坡 (floor, 人能站上去走) 2 种 + 顶坡 (ceiling, 洞顶/悬垂) 2 种:

| 名字            | 形状 | 实心三角        | 用在               |
|-----------------|------|-----------------|--------------------|
| SLOPE_FLOOR_R   | ◢   | 右下 (升向右)   | 地表向右升 / 洞底  |
| SLOPE_FLOOR_L   | ◣   | 左下 (升向左)   | 地表向左升 / 洞底  |
| SLOPE_CEIL_R    | ◥   | 右上            | 洞顶向右降         |
| SLOPE_CEIL_L    | ◤   | 左上            | 洞顶向左降         |

地表山坡只用 FLOOR_R / FLOOR_L 两种。CEIL_* 留给地下洞顶 (Phase 2b)。

## 生成器铺斜坡规则

`world_generator.gd` 有每列地表高度 `chunk_heights[wx]`。生成后加一道**后处理**:

- 比较相邻列高差。**正好差 1 格**的台阶 → 在拐角放对应 floor 斜砖 (升向高的那侧)。
- 差 ≥ 2 格的陡坎: 本期保持台阶 (后续可叠多块斜砖, 非本期)。
- 斜砖的"材质" = 该列地表材质 (草顶用草斜砖, 露石处用石斜砖)。
- **跨 chunk 边界**: 相邻列可能在另一 chunk; 用 `_surface_y_of_column` / 重算邻列高度, 别只读本 chunk dict
  (踩过的坑见 [memory: surface noise dup] — 高度公式有多份, 取高度要一致)。

## 挖掘 / 掉落

斜砖 `mineable:true`, 挖掉 → 掉对应材料 1 个 (草斜砖掉 dirt, 石斜砖掉 stone…), 变 AIR。
工具 tier 跟对应材质一致 (石斜砖要镐)。不可被玩家放置 (item 不映射到斜砖)。

## 登记清单 (每个新斜砖 tile 必须同步, 见 [memory: tileset registration] [memory: items chinese])

每个 SLOPE_* tile_id 要同步加到:
1. `tile_data.gd`: const + `_PROPS` (solid:true, mineable:true, tool_tiers, drops)
2. `blocks_art.gd`: const + `_PATTERN_MAP` (或 ArtCache 程序生成路径)
3. `tileset_builder.gd`: tile_ids 列表 (漏了 tile 不显示也不报错!) + 三角碰撞分支
4. `art_cache.gd`: `_build_blocks` 列表 (程序遮罩生成斜砖贴图)
5. `minimap_view.gd`: `_TILE_COLORS` (用对应材质色)
6. 斜砖**不进** `edge_templates.gd` FAMILY_OF (故意的)

## 分阶段实施 (每步独立可验收)

### Phase 2a — 打通一套 (地表草斜坡)
最小闭环, 只 **2 个 tile**: GRASS_SLOPE_FLOOR_R / _L。
- 加这 2 tile 全套登记 + 三角碰撞 + ArtCache 遮罩生成草斜砖贴图。
- `floor_max_angle` 调到 0.90。
- 生成器: 地表草地"差 1 格台阶"铺草斜砖。
- **验收 (GUT 集成测试)**:
  - 斜砖进了 tileset (source 存在 + 有三角碰撞多边形, 顶点数=3)。
  - 造一个 1 格台阶地形 → 生成器在拐角放了 GRASS_SLOPE_FLOOR_R/L。
  - 玩家放在斜砖底端朝坡走 → 几帧后 global_position.y 上升 (走上去了, 没被当墙挡住)。
  - 挖斜砖 → 掉 dirt + 变 AIR。

### Phase 2b — 铺开
- 加泥/沙/石/深石 floor 斜砖 (复用 2a 的遮罩+碰撞+生成逻辑, 换材质)。
- 加 CEIL_* 顶坡 + 地下洞穴墙削坡 (洞顶/洞底拐角)。
- 验收: 各材质斜砖生成 + 显示 + 可走 + 可挖。

### Phase 2c — 打磨
- 斜边 1px 高光/暗影调好看。
- 斜砖跟邻接方块接缝更顺 (必要时给斜砖也配少量"朝向变体")。
- 陡坎 (差≥2) 叠多段斜坡 (可选)。

## 风险 / 待解

- **R1 走路手感**: move_and_slide 走 45° 斜面理论 OK, 但本项目走路有自定义逻辑 (跳/钩爪/绳子/云靴),
  斜面上跳跃/下坡可能有抖动。2a 必须实测玩家在斜面行走 + 跳 + 落地。若抖, 微调 floor_snap_length。
- **R2 斜砖 + 水**: 水流模拟只认 AIR/实心。斜砖 solid → 水把它当实心挡住 (可接受, 本期不做"水顺斜面流")。
- **R3 怪物走斜坡**: 史莱姆跳/动物 auto-step 遇斜砖行为待观察 (怪也 move_and_slide?), 2b 再管, 不阻塞 2a。
- **R4 跨 chunk 边界高度**: 取邻列高度要用统一公式 (见生成器规则), 否则 chunk 缝斜坡错位。
- **R5 存档**: 斜砖是普通 tile id, 存档按 tile id 存取, 无需特殊处理 (确认 save 走 tile id)。

## 明确不做 (YAGNI)
- 玩家锤子削坡 / 半砖 / 斜砖再细分朝向变体 (2c 才按需) / 水顺斜面流 / 斜坡上的草须特殊处理。
