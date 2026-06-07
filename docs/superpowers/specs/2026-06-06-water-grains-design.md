# 活水颗粒 (Living Water Grains) — 设计文档

- 日期: 2026-06-06
- 状态: 已与用户确认方案, 待写实现计划
- 一句话: 让流动/掉落的水看起来"一粒一粒"地流、滚、溅, 更自然 —— **纯视觉叠加, 底层水仍是格子模拟**, 不碰游泳/钓鱼/存档/小地图/联机, 性能可控。

## 目标

- 瀑布、往下掉的水、挖开缺口涌出的水、横向漫流的前沿 → 冒出**一串串小水珠**: 有重力下落、撞地/撞水面溅花、落斜坡顺坡滑一点再融回。
- 水面顶边更**圆润 + 一丝颗粒微光**, 连静水也不那么"方块台阶"。
- 网页版安全 (单线程 + 内存紧)。

## 非目标 (明确不做)

- **不做真颗粒物理水** (把水换成成千上万自由粒子)。理由: 游泳/钓鱼/存档/小地图/联机全靠 `Tiles.is_water(tid)` 的格子判定, 换掉会全线重做; 且满屏粒子物理网页版会卡死。
- 不改水的**流动行为 / 水位 / 找平 / 反应** (water_sim 的模拟逻辑原样不动)。
- 颗粒**不参与碰撞、不造成伤害、不改 tile** —— 纯装饰。

## 背景 (现状)

- 水是 8 档水位的**蓝色 tile**, 由 `water_sim.gd` 模拟 (dirty 列表驱动), 经 `_set_water_tile_fast` 写进 chunk → TileMapLayer 渲染。tile 美术在 `scripts/art/blocks_art.gd` (`WATER=28`, `WATER_L1..L7`)。
- 已有**落水溅花**: `Effects.spawn_splash(world_pos)` (`scripts/fx/effects.gd:86`) 喷 8 颗蓝水滴 (复用 `scenes/fx/block_break_particle.tscn`)。
- `water_sim._step_tile` 的**重力下落分支** (水落进下方空气) 已经在调 `spawn_splash`, 且带护栏: `not _in_settle` (加载找平那一下不喷) + `_tick_n % 4 == 0` (限频) + `not OS.has_feature("web")` (网页不喷)。横向流分支 `_step_water_lateral` / 瀑布也是水"在动"的点。
- 加载瞬间找平期间有 `_in_settle` 开关 (true 时不喷粒子)。

## 设计

四个组件 (A 颗粒 / B 发射器 / C 性能护栏 / D 水面美术), 彼此低耦合。

### A. 水颗粒粒子 `WaterGrainParticle` (纯视觉)

- 新建 `scripts/fx/water_grain_particle.gd` + `scenes/fx/water_grain_particle.tscn` (一个小 `Sprite2D` 或 `ColorRect`, 2~3px 蓝水珠)。
- 接口: `setup(pos: Vector2, vel: Vector2, color: Color)`。
- 行为 (`_process`):
  - 重力: `vel.y += GRAVITY * dt`。
  - 位移: `position += vel * dt`。
  - **撞实心/水面 → 落地**: 查 `chunk_manager.get_tile` 下一步是否实心或水; 是 → 喷一个极小溅花 (1~2 颗) 后 `queue_free`。
  - **顺坡滑**: 落点是斜坡 (一侧低) 时给一点横向 `vel.x` 再消失 (轻量近似, 不做真物理)。
  - 寿命上限 `LIFETIME ≈ 0.6s` 兜底回收。
  - 颜色: 取所在/来源水 tile 的群系色 (蓝/沙漠青/丛林绿/沼泽墨), 用 `blocks_art` 现成色。
- 复用现有 `block_break_particle` 的对象池思路 (`scripts/fx/spark_pool.gd` / `dust_pool.gd` 已有池模式), **颗粒走池** 防频繁 alloc。

### B. 发射器 (挂在 water_sim 的"流动事件"上)

- 不新开扫描循环 —— **直接在 water_sim 已有的流动点调用 `Effects.spawn_water_grains(...)`**:
  1. `_step_tile` 重力下落分支 (水落进空气): 把现有 `spawn_splash` 调用升级/并存为"冒 1~2 颗下落水珠"。
  2. `_step_water_lateral` 横向流的前沿 (流进空气那一步): 冒 1 颗。
  3. 瀑布 (世界生成的 `WATER_SOURCE` 持续往下灌, `_step_source`): 冒下落水珠。
- 复用现有护栏: `not _in_settle` (加载不冒) + 限频 (`_tick_n % N`)。
- **网页版也冒** (现状 splash 是 `not web` 才喷; 颗粒版改为网页也喷但靠 C 的总量上限控成本 —— 这是用户明确想要的效果, 但严格受 C 约束)。

### C. 性能护栏 (硬约束, 网页安全)

集中在 `Effects` autoload:
- `MAX_WATER_GRAINS ≈ 250`: 全局存活颗粒计数; 到顶 `spawn_water_grains` 直接 return (不再生成)。
- 生成限频: 每个流动事件按概率/隔几 tick 才冒 (避免一条瀑布每帧几十颗)。
- 只在**镜头附近 / 已加载 chunk** 生成 (远处流动不冒)。
- `_in_settle` / 加载找平期间不冒。
- **静止水零开销**: 颗粒只挂在 water_sim 的"流动事件"上, 水不动 = 不触发 = 不生成。

### D. 水面圆润 + 颗粒微光 (美术, 独立小件)

- 改 `scripts/art/blocks_art.gd` 里水 tile 的绘制: 顶边画**圆润/波浪起伏** + 一点点亮暗颗粒点, 降低"方块台阶感"。
- ⚠️ **并发注意**: `blocks_art.gd` 近期有别的 session 在改 —— 实现这步前先 `git status`, 只动水相关绘制函数, `git add` 精确路径。
- 此件**可独立后做** (A/B/C 先上, D 作为收尾 polish), 降低一次性改动面。

## 不变项 (回归保障)

- water_sim 模拟逻辑 / 水位 / 找平 / `Tiles.is_water` / 存档格式 / 小地图 / 游泳 / 钓鱼 / 联机 —— **全不动**。
- 颗粒是各端**本地视觉** (跟现有 splash 一样), 不联网同步。

## 测试策略

颗粒"好不好看"靠用户亲眼验收 (无 GUI 自动验收)。能自动测的抽成纯函数:
- `Effects` 加可测的"该不该冒 + 不超上限"判定: 上限到顶返 false / `_in_settle` 时返 false / 计数随生成与回收增减。
- water_sim 发射器调用点: 用 `test_liquid_flow.gd` 的 FakeWorld 模式, 断言"水落进空气时调了发射器", 且 settle 期间 (`_in_settle`) 不调。
- 回归: 跑 `test_water_settles` / `test_load_settled` / `test_liquid_flow` 确认水**行为**没变 (颗粒纯视觉不应影响 tile 结果)。

## 文件清单

新增:
- `scripts/fx/water_grain_particle.gd` + `scenes/fx/water_grain_particle.tscn`
- `tests/unit/test_water_grain_budget.gd` (上限/护栏判定)

修改:
- `scripts/fx/effects.gd` — 加 `spawn_water_grains()` + `MAX_WATER_GRAINS` 计数护栏
- `scripts/world/water_sim.gd` — 在重力/横向/瀑布流动点调发射器 (复用现有护栏)
- `scripts/art/blocks_art.gd` — (D, 可后做) 水 tile 顶边圆润 + 颗粒微光
- `tests/integration/test_liquid_flow.gd` — 加发射器调用点断言

## 风险

- **性能 (网页)**: 靠 C 的硬上限 + 限频 + 仅镜头附近 + 仅流动事件兜住。验收时网页版重点看瀑布密集处帧率。
- **颗粒与 tile 视觉对不齐**: 颗粒坐标用 `(tile + 0.5) * TILE_SIZE` 对齐, 跟 splash 一致。
- **并发**: `blocks_art.gd` / `water_sim.gd` 有别的 session 在动 —— 实现每步前 `git status`, 精确 `git add`, 别卷入 WIP。

## 实现顺序建议

1. A 颗粒粒子 (能独立 spawn 测试)
2. C 护栏 (Effects 计数 + 上限) + B 发射器接到 water_sim 重力分支 (最显眼的瀑布/落水先有效果)
3. B 补横向流 + 瀑布源
4. D 水面圆润 (收尾 polish, 注意并发)
