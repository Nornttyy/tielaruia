# 自适应预加载（按设备性能）设计

**日期:** 2026-06-04
**作者:** Claude (与用户 brainstorm 后)

## 目标 (Goal)

开局加载界面里**测一下这台设备多快**，按测速结果决定**预加载多大一片世界**：强机一次生成一大片(逛很久不卡)，
网页/弱机生成小一片(加载快、不爆内存)。把"边玩边现算地块"的卡顿降到几乎没有，且**不用玩家手动选大小**。

## 非目标 (YAGNI)

- **不**设世界边界 / 不做有限世界(用户已选自适应方案, 边界是另一件事)。
- v1 **不**做"超远探索也绝不卡"的摊帧/后台线程生成。先把"开局一大片不卡 + keep 住不卸"做扎实。
  逛出预载大片之外仍会现算 1 个 chunk(偶发小顿), 但因为预载够大 + 在离屏 radius 外生成, 平时逛不到。
- **不**改世界内容/大小/种子 → 联机安全(大家同一个世界, 只是各自预载多少不同)。

## 架构 (Architecture)

现状: `chunk_manager.ensure_loaded(cx)` 加载 `cx ± VIEW_RADIUS(=2)`; 玩家跨 chunk 时 `_check_chunk_load`
调 ensure_loaded + `unload_far_from(pcx, VIEW_RADIUS+1)`。半径是写死的 const 2 → 窗口小 → 边走边现算。

改成: 半径变成 **chunk_manager 的实例变量 `view_radius`**(默认仍 2), 开局按测速调大。
开局加载界面: 先生成几个 chunk 计时 → `LoadPlanner.plan_view_radius()` 算半径 → 设 `chunk_manager.view_radius`
→ `ensure_loaded(spawn)` 一次把 `±view_radius` 全生成(进度条)。运行时 ensure/unload 都用这个实例半径。

数据流:
```
加载界面 run_init_step:
  1) 生成出生点 ±2 基准 chunk, Time.get_ticks_msec 计时 → per_chunk_ms
  2) LoadPlanner.plan_view_radius(per_chunk_ms, is_web, cores) → radius
  3) chunk_manager.view_radius = radius
  4) ensure_loaded(spawn_cx) 生成 ±radius (进度条 by chunk)
运行时 _check_chunk_load:
  跨 chunk → ensure_loaded(pcx)(±radius) + unload_far_from(pcx, radius+1)
  (radius 大 → 离屏老远就备好 + keep 住, 逛着不卡)
```

## 组件 (Components)

### 1. LoadPlanner (新, 纯函数好测) — `scripts/world/load_planner.gd`
```
const TARGET_PRELOAD_MS := 2000.0   # 开局愿意花在预生成上的预算 (~2s)
const MIN_RADIUS := 2
const MAX_RADIUS_WEB := 5            # 网页保守 (内存 + 单线程)
const MAX_RADIUS_DESKTOP := 16
static func plan_view_radius(per_chunk_ms: float, is_web: bool, cores: int) -> int
```
- `budget_chunks = TARGET_PRELOAD_MS / max(per_chunk_ms, 0.5)`; `radius = budget_chunks / 2`(两边分)。
- `cores >= 8` 时 `radius += 2`(多核略加成)。
- cap = is_web ? MAX_RADIUS_WEB : MAX_RADIUS_DESKTOP; `clampi(radius, MIN_RADIUS, cap)`。
- 纯函数: 喂(ms, web, cores)出 int, 不碰引擎状态 → 单测。

### 2. chunk_manager 半径实例化 — `scripts/world/chunk_manager.gd`
- 加 `var view_radius: int = ChunkConstants.VIEW_RADIUS`(默认不变, 向后兼容)。
- `ensure_loaded` 用 `view_radius` 取代 `ChunkConstants.VIEW_RADIUS`。
- 加 `func loaded_count() -> int`(测试数已加载 chunk 用)。
- 不删 const VIEW_RADIUS(当默认值/别处引用)。

### 3. 测速 + 预载 wiring — `scripts/world/world.gd`
- `run_init_step` 里(现在 line ~192 调 `ensure_loaded(0)`那步)改成:
  - 先 `var t0 = Time.get_ticks_msec()`; 生成基准几个 chunk(就用现有 ensure_loaded(0) 的 ±2); `var per = (Time.get_ticks_msec()-t0)/5.0`。
  - `chunk_manager.view_radius = LoadPlanner.plan_view_radius(per, OS.has_feature("web"), OS.get_processor_count())`。
  - 再 `ensure_loaded(0)` 一次(此时 radius 大 → 补齐大片)。
- `_check_chunk_load` 的 `unload_far_from(pcx, ChunkConstants.VIEW_RADIUS + 1)` 改成 `chunk_manager.view_radius + 1`。
- **进度**: 预载大片可能上百 chunk, 不能卡一帧。复用现有 `_run_async_load` 的 await 分帧:
  把预载拆成"每帧生成 N 个 chunk"的 init step, 进度条推进(见 main.gd 集成)。

### 4. 加载界面集成 — `scripts/main.gd`
- `_run_async_load` 已有分阶段 + 进度条 + await process_frame。给 world 多加一个 init step "预生成世界(自适应)",
  内部分帧生成 `±view_radius` 的 chunk, 每帧 set_progress 推进。慢机 radius 小→快; 强机 radius 大→进度条多走会。

## 风险 & 安全

| 风险 | 兜底 |
|------|------|
| 预载太多卡死加载 / 爆内存(尤其网页) | TARGET_PRELOAD_MS 预算封顶 + web cap=5; 分帧生成不卡帧; 半径来自实测速度 |
| 测速不准(首 chunk 含 warmup) | 平均多个 chunk; 预算制(差就少载)而非精确 |
| 改 chunk 加载核心引回归 | view_radius 默认仍=2(不设就跟现在一样); 全量回归 + 冒烟 + 联机相关测试 |
| 联机两端世界不一致 | 不碰世界内容/种子, 只改各自"预载多少" → 世界仍 seed-确定一致 |
| keep_radius 变大→老不卸→内存涨 | radius 有 cap; unload_far 仍在 radius+1 外卸, 只是窗口大了 |

## 测试 (TDD)

1. **plan_view_radius 快机大半径**: per=2ms → radius 接近 cap(桌面 16)。
2. **plan_view_radius 慢机小半径**: per=400ms → radius=MIN(2)。
3. **plan_view_radius 网页封顶**: 快(per=2ms)但 is_web=true → radius ≤ 5。
4. **plan_view_radius 边界**: per=0/负 不崩(走 max(.,0.5)); 结果永在 [MIN, cap]。
5. **chunk_manager view_radius 生效**: 设 view_radius=4, ensure_loaded(0) → loaded_count = 9 (±4)。
6. **默认向后兼容**: 不设 view_radius → 默认 2 → ensure_loaded(0) loaded_count=5 (±2)。
7. **集成/冒烟**: boot_to_game 照常启动(3/3); 全量 0 failing。

## 提交粒度

仿瀑布/史莱姆: 每 task 一 commit, 先写失败测试→实现→过→commit, 每步给用户 1-3 行报告 + SHA + 累计测试数。
