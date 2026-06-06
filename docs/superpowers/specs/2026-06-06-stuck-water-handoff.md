# 交接: 加载后"能流却不流"的卡水 bug (给改水系统的窗口)

**日期:** 2026-06-06
**报告人:** 用户 ("水进入游戏后明明位置可以流动但是没有流动") + Claude(空岛窗口) 诊断
**归属:** 水系统最近大改的窗口 (8档细水位 63cdf82 / 连通找平 4d9a11f / 加载流完 a7d17ad)。
空岛窗口不动液体代码 (memory: "改液体前必看"), 仅交诊断。

## 现象
新世界加载后, 地表有水块**下面就是空气、本该往下掉, 却一直不流**。

## 复现
`tests/integration/test_water_settles.gd` 现在就是**红的** (seed 42): 地表悬空水 ~2 处 (样例 `(62,138)(63,138)`) + 深处 ~92 处。

## 精确诊断 (关键)
对卡住的 `(62,138)` 实测 (boot seed 42, 跑 200 帧实时 sim 后):
- tile = `WATER`(满水, level 8); 正下方 `(62,139)` = `AIR`; 左 = STONE, 右 = WATER。
- `water_sim.tile_can_still_flow(t, nbs)` = **true** — 水模拟自己也认为这块能流。
- 但跑满 200 帧实时 sim 后**仍卡住** → 说明它**从没被 mark_dirty** (dirty 的话实时 sim 60+ tick 早流走了)。

**结论**: 不是"sim 不会流"(它会), 是这些 tile **没被叫醒**。怀疑链:
chunk 加载 settle / 连通找平 把相邻水流走、给这块腾出"下方空气", 但**没把这块重新 mark_dirty**
(notify_tile_changed 没覆盖到 / 连通找平直接改 tile 没走唤醒) → settle 这一轮已处理过它、不再回头 →
实时 sim 也因为它不 dirty 而不碰它 → 永久卡住。

## 建议排查方向
1. 连通找平 / load-settle 改 tile 后, 凡是"某 tile 下方变成 AIR"或"邻居液位变了", 都要 notify_tile_changed/mark_dirty。
2. 或 settle 收尾再扫一遍, 把 tile_can_still_flow=true 但没流的补 dirty。
3. SETTLE_MAX_TICKS(400) 是否被大水体吃满提前退出, 剩下没流完。

## 另: 水密度
用户也说"水密度有点高"。地表水洼/湖 (POND_CHANCE / OASIS / 地形水) 是这边的。
空岛窗口的瀑布 (WATER_SOURCE, WATERFALL_CHANCE=0.08, ~1/30 chunk) 很稀, 不是主因。
