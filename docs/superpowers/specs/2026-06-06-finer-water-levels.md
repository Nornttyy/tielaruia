# 细水位 (Finer water levels) — 水更像真水

用户反馈 (2026-06-06): 水不像真水. 具体: ①不会摄平 ②连通的水高低不一 ③一格一格台阶.
根因: 水只有 4 档高度 → 水面凑不平, 台阶粗. 真水要细水位.

选择: 水位 4 档 → **8 档** (每档 16px/8 = 2px, 水面平滑度翻倍). 岩浆保持 4 档 (黏稠).

## 改动 (一个连贯改动, 因为 sim 产出的新 level tile 必须有贴图否则崩)

新增 4 个 tile: `WATER_L4=88 / WATER_L5=89 / WATER_L6=90 / WATER_L7=91`.
现有 WATER(满=level8) + WATER_L1/L2/L3 保留 (含义不变, 数值在 8 档体系里).

1. **tile_data.gd**: +4 常量 + 4 _PROPS (非实心/不可挖, 同 WATER) + is_water() 加这4个.
2. **blocks_art.gd**: +4 常量; `get_water_level_atlas(level)` 支持 1-7, clip = (8-level)*2 行;
   +4 _PATTERNS icon (复用 _WATER + _P_WATER).
3. **art_cache.gd**: 注册 L4-L7 (各自 level atlas 动画).
4. **tileset_builder.gd**: tile_ids +4 + 4 帧动画.
5. **water_sim.gd**: **按液种 MAX** (水 8 / 岩浆 4):
   - `_level_of`: 水 full=8, L7=7..L1=1; 岩浆 full=4, L3=3..L1=1.
   - `_tile_for_level(kind, L)`: 水 L>=8→WATER, 7→L7..1→L1; 岩浆不变.
   - `_step_tile`/`_step_source`: `maxlv = 8 if water else 4`; 满水/转移用 maxlv;
     `mini(L, maxlv - below_L)`. 横向找平规则结构不变 (只是档更细 → 更平).

## 验收 (GUT)
- test_finer_water: 一桶水填进容器, 水面高低差 ≤ 1 档 (8 档 → 比 4 档平);
  连通水找平; 不震荡 (settle 后 _dirty 空); 岩浆仍 4 档照常流.
- 复用 test_liquid_flow (下落/横流/遇水变石/挖墙流出 — 全要过, 数值改 8 档).
- 游泳/钓鱼 走 Tiles.is_water 自动覆盖.
- smoke 6/6.

## 坑
- _level_of/_tile_for_level 水岩浆共用 → 必须按 kind 分 MAX, 别一刀切.
- 加 tile 必同步 tileset_builder.tile_ids + art_cache (漏了不显示/崩).
- 别引入"孤儿水/震荡" (历史踩过), settle 后必须静.

## 第2步: 连通水域整体找平 (真·水平面) — 2026-06-06 续

发现: 逐格整数水位单靠横流只能形成"相邻差≤1的斜坡", 做不到全局一样高.
方案: 加"整片找平" — 把连通水体当一整块, 总量从底往上重灌, 顶层那行均分.

`water_sim.gd`:
- `_level_body(cm, sx, sy, visited)`: 洪水填充连通水体 → 收总量 → 按 y 从大到小(底→顶)
  逐行灌, 满行给 8, 部分行均分(余数给前几格 → 差≤1), 上面留空. 写回(满格沿用群系色).
- `_level_bodies_from(cells)`: 对 cells 里每个未访问连通水体调 _level_body.
- settle_now: 逐格流到稳 → 找平 → 再流再找平, 分轮 (≤12) 收敛到纯平.
- _run_tick: 实时一批水流到 dirty 空 (刚安静) → 找平它们的水域 (settle 期间跳过).

安全 (逐条防历史坑):
- 只重排【现有水格】, 不往新格灌 → 不造孤儿水.
- 从底往上灌 → 每个水格下面必是水/实心 → 不悬空.
- 总量守恒; 幂等 (已平→want==cur→不动→不发dirty→不抖); 大水体(>6000格)跳过防卡.
- 配合横流: 铺开↔找平 收敛. 验证: 16单位/8格容器 → [2,2,2,2,2,2,2,2] 纯平.

验收: test_finer_water 6/6 (含 找平纯平 / body守恒+不悬空 / 幂等 / 群系色保留);
liquid 16/16; smoke 6/6 (60s不崩+实时找平无失控).
