# 瀑布（真水版）设计

**日期:** 2026-06-04
**作者:** Claude (与用户 brainstorm 后)

## 目标 (Goal)

给世界加**真水瀑布**: 山崖顶上一个"水源块"永远冒水，水靠现成的液体模拟一格格流下崖面、在崖底积成水潭。
玩家能挖渠引水、用方块堵它改道、把水源块挖掉让它停。稀有的自然景观，不是玩家可造的物品。

## 非目标 (YAGNI)

- **不做**可合成/可放置的"水源"物品（无限水太破坏平衡）。水源只在世界生成时出现，玩家只能挖掉它。
- **不做**单独的"排水块"。靠崖底地形自然溢流 + 现成"薄水不在平地乱铺"规则兜住，不淹世界。
- **不做**自定义瀑布渲染 shader。水源块复用现成水的蓝色视觉（略调亮以便辨认）。

## 架构 (Architecture)

复用现成液体模拟（`water_sim.gd`，4 水位 L1–L4，dirty 列表驱动，重力下流 + 横向防抖）。
新增一个**发射型 tile** `WATER_SOURCE`：它本身不是流动液体（`is_liquid()` 仍返回 false，免得污染游泳/作物判定），
但每隔几拍往正下方灌一格满水、自己永不变少。灌出来的是普通 `WATER`，照常往下流。

数据流：
```
世界生成: 找陡崖 → 崖顶唇放 WATER_SOURCE + 崖底挖小水潭
  ↓ (chunk 加载)
world.gd chunk 唤醒扫描: 把 WATER_SOURCE 也标 dirty (现在只认 is_liquid)
  ↓
water_sim._step_tile 命中 WATER_SOURCE → 每 N 拍往下灌 WATER → 水重力下落 → 崖底积潭
  ↓ (灌出的水改了 tile)
notify_tile_changed 唤醒邻居 → 持续流动; 下方满了没处灌 → 水源歇着 (self-limiting)
  ↓ (玩家挖潭/开渠)
tile 变化唤醒 → 水源重新灌 (renewable)
```

## 组件 (Components)

### 1. 新 tile: `WATER_SOURCE`
- **文件:** `scripts/world/tile_data.gd` — `const WATER_SOURCE := 84`（下一个空 id；当前最大 WATER_SWAMP=83）。
- **注册:** `scripts/world/tileset_builder.gd` `tile_ids` 数组（line ~30）加 `Tiles.WATER_SOURCE`；
  水视觉分支（line ~120）加上它，让它画成水蓝色（可略调亮区分泉眼）。
- **不是 is_liquid:** `water_sim.is_liquid()` / `_liquid_kind()` 对 WATER_SOURCE 仍返回 false/""，
  避免它被当流动水（游泳、作物近水、水岩浆反应都不该把它算进去）。
- **可挖:** 挖掉 → AIR，水源停（不掉落物品，不可放置）。走现成挖掘路径即可（实心 tile）。

### 2. 模拟发射逻辑
- **文件:** `scripts/world/water_sim.gd`
- `_step_tile` 开头优先判 `WATER_SOURCE`：
  - 节流：`_tick_n % SOURCE_TICK_DIVISOR != 0` 时重标 dirty 保活、本拍不灌（细水长流，省 CPU + 别像消防栓）。
  - 正下方是 AIR → 设为 `WATER`(L4)，`notify_tile_changed`，重标自己 dirty。
  - 正下方是未满 WATER → 灌满到 L4，notify，重标自己 dirty。
  - 正下方是满水/实心/岩浆 → 不灌、不重标（歇着；下游变化会再唤醒它）。
  - 永不修改自己的 tile（无限）。
- `const SOURCE_TICK_DIVISOR := 2`（每 2 拍灌一次 ≈ 温柔水流）。

### 3. 唤醒（防"冻在空中"）
- **文件:** `scripts/world/world.gd` chunk 加载唤醒扫描（line ~860）
- 现在条件 `if not water_sim.is_liquid(t): continue` 漏掉 WATER_SOURCE（它不是 liquid）。
  改成 `if not water_sim.is_liquid(t) and t != Tiles.WATER_SOURCE: continue`，让水源也被标 dirty。
- chunk 加载的 `settle_now()`（≤240 tick 上限）会先把瀑布灌出初始形态；剩下的交实时 sim。

### 4. 世界生成放置
- **文件:** `scripts/world/world_generator.gd`（仿 pond 放置，line ~445 那段）
- 用 `chunk_heights[wx]` 找**陡崖**：某列到右/左 `WATERFALL_SPAN` 列内地表落差 ≥ `WATERFALL_MIN_DROP`（与 pond 的"平地"判定相反）。
- 用 `_hash3(world_seed, wx, <新salt>)` 做确定性稀有 roll（`WATERFALL_CHANCE` 比 pond 更稀有）。
- 只在 forest / jungle 群系（避开沙漠/雪原/已是结构的列）。
- 在崖唇上方一格放 `WATER_SOURCE`，使其正下方是崖面 AIR（水能直落）。
- 崖底挖一个小碗形水潭（仿 pond 填挖，但留**敞口朝低地**让多余水溢走，瀑布才一直流不积成水墙）。
- 常量起始值（可调）：`WATERFALL_CHANCE := 0.04`（稀有）、`WATERFALL_MIN_DROP := 8`、`WATERFALL_SPAN := 4`、
  salt 用没被占的数（如 7790，避开 pond 的 7777/7778/7779）。

### 5. 特效（好看）
- **文件:** `scripts/fx/effects.gd` 新 `spawn_splash(world_pos)`，仿 `spawn_steam_puff`（line 73）。
- 水花要够明显（见 [[feedback-fx-visibility]]：宽≥2px、alpha≥0.8、量足）。
- 触发点：`_step_tile` 里水靠重力下落、撞到实心/满水"落地"时，低概率（节流）在落点喷水花。
  只桌面跑（web 省特效），且限频防刷屏。

### 6. 联机
- 不用加新逻辑。`settle_now()` / `_run_tick()` 已对 client 直接 bail（host 权威）。
  水源发射在 `_step_tile`（sim 内），client 不跑；host 灌的水通过现成 tile 同步发给 client。

## 风险 & 安全

| 风险 | 兜底 |
|------|------|
| 无限水淹世界 | 水源只往**正下方**灌；崖底潭满后水源歇；溢流是薄水(L1)，受现成"平地不铺"防抖规则限制，淌到最近低洼就停 |
| 冻在空中 (历史坑) | chunk 加载唤醒扫描显式加 WATER_SOURCE |
| chunk 加载卡帧 | `SOURCE_TICK_DIVISOR=2` 节流 + `settle_now` 的 240-tick 上限；水源稀有 |
| 污染游泳/作物判定 | WATER_SOURCE **不**算 is_liquid；只在发射逻辑 + 唤醒扫描里特判 |
| 改液体引入回归 | 改 water_sim 前后跑全量；水源逻辑只在 _step_tile 最前面加分支，不动现有流动路径 |

## 测试 (TDD)

1. **水源发射**: 放 WATER_SOURCE，下方 AIR，跑几拍 → 下方出现 WATER；水源 tile 还在（没变少）。
2. **下方满了歇着**: 水源下方已是满 WATER → 跑拍后水源不再产生新 dirty（self-limiting）。
3. **不是 liquid**: `water_sim.is_liquid(WATER_SOURCE) == false`。
4. **重力成柱/积潭**: 水源在高处、下面一段 AIR 再接实地 → settle 后底部积水、有水柱。
5. **唤醒**: 模拟 chunk 加载唤醒扫描，含 WATER_SOURCE 的 chunk → 水源被标 dirty（不冻）。
6. **挖掉停**: 水源 → AIR 后，跑拍不再产水。
7. **世界生成放置**（集成）: 给一个有陡崖的 seed，生成后世界里存在 ≥0…（确定性，至少不报错 + 找得到崖时放得出）。
8. **回归**: 全量 0 failing（尤其 water/液体相关测试）。

## 提交粒度

仿史莱姆等级：每个 task 一个 commit，先写失败测试 → 实现 → 过 → commit，每步给用户 1–3 行报告 + SHA + 累计测试数。
