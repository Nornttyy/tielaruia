# 再次缩小方块 TILE_SIZE 12 → 6 — 设计 spec

> 日期: 2026-06-07
> 状态: 设计已确认, 待写实现 plan

## 背景 / 目标

用户要"再次缩小所有方块大小"。上次做过 `TILE_SIZE 16 → 12` (commit `6af9aa5` + 一串修补)。这次 **12 → 6** (×0.5, 整整一半)。

目标: 方块在屏幕上变成现在的一半大, 看到更多世界; **手感不变** (物理跟着等比缩)。

用户已确认:
- 缩的是**真·像素尺寸** (改 `TILE_SIZE`), 不是只拉远相机。
- 目标 **6px** (×0.5)。接受 16px 原图缩到 6px 的细节损失 (材质会偏糊)。
- **相机 `camera_zoom` 先不动** (保持 0.8) → 净效果方块半大小。上线看效果再调。

## 核心痛点

`const TILE_SIZE := 12` 在 **34 个文件**里各写一份 (无共享来源); 物理常量是**写死像素值** (不跟 TILE_SIZE 走)。上次"再次"之痛就是硬编码尺寸散落各处, 漏改导致比例错乱。

## 设计

### 1. 集中 `TILE_SIZE` (根治 34 份重复)

- `scripts/world/chunk_constants.gd` 加 `const TILE_SIZE := 6`。`ChunkConstants` 已是全局 `class_name` (现有 `const BYTES_PER_CHUNK := ChunkConstants.CHUNK_WIDTH * ...` 证明跨脚本引用可行)。
- 34 个文件里 `const TILE_SIZE := 12` → `const TILE_SIZE := ChunkConstants.TILE_SIZE`。
- 收益: 以后再缩只改一个数; 所有"用 TILE_SIZE 算的"坐标/特效定位自动跟缩。

> 34 个文件清单 (grep `const TILE_SIZE`): minimap_view, torch_fx, place_bounce, water_grain_particle, effects, world_lighting, water_sim, darkness_layer, crack_overlay, scenic_director, world, item_drop, animal_base, mimic, friendly_skeleton, imp, spider, fireball, hell_wasp, slime, zombie, mummy, skeleton_king, harpy, slime_ball, arrow, demon_eye, skeleton, king_slime, debug_hud, player_fishing, player_controller, player_action, player_health。

### 2. 写死的世界像素常量 ×0.5 (手动)

物理/尺寸常量是写死像素 (如 `SPEED := 105.0`, `JUMP_VELOCITY := -240.0`, `GRAVITY := 675.0` —— 这些是上次 ×0.75 的产物), 不跟 TILE_SIZE 走, 必须手动减半:

- **玩家** (`player_controller.gd`): `SPEED / JUMP_VELOCITY / GRAVITY / SWIM_GRAVITY / SWIM_UP_SPEED / SWIM_MAX_SINK / ROPE_CLIMB_SPEED / KNOCKBACK_VX / HOOK_FLY_SPEED / HOOK_PULL_SPEED / HOOK_RELEASE_DIST / PLAYER_BODY_HEIGHT / PLAYER_AURA_TEX_SIZE / SUN_AURA_TEX_SIZE / SHAKE_MAX_OFFSET`。(`HOOK_MAX_DIST_TILES` 是"格"单位 → **不动**。)
- **怪物** (各 entities): 移动速度 / 跳跃 / 攻击距离 / 击退 等写死像素值。
- **其它**: 掉落物拾取半径 (`item_drop.gd`) / FX 粒子大小&位移 (`effects.gd`, fx/*) / 光照半径 (`world_lighting.gd`, `darkness_layer.gd`) / 手持物缩放 (`held_item.gd`) / 小地图每格像素 (`minimap_view.gd`)。

> ⚠️ **手持物 `TOOL_SIZE` 是用户敏感值**: 上次 16→12 后用户反馈"工具太小", 把 `TOOL_SIZE 0.7 → 1.0` 调大过 (commit `6af9aa5`)。这次手持物理应跟世界等比缩, 但**先保持当前 `TOOL_SIZE` 不动 (不 ×0.5)**, 上线让用户看; 嫌大再调。宁可工具偏大也别再触发"太小"反馈。

**判断规则** (每个数字过一遍):
- **缩 ×0.5**: 世界里的像素 —— 位置、尺寸、速度 (px/s)、距离、半径、碰撞框。
- **不动**: 时间 (秒)、数量、角度、能量值、alpha、以"格 (tile)"为单位的阈值、UI/屏幕固定像素 (见下)。

### 3. 美术贴图缩到 6px

- `tileset_builder.gd`: `texture_region_size` `Vector2i(12,12)` → `Vector2i(6,6)`; 水动画帧偏移等用到 12 的同步改。
- `art_cache.gd`: `_smart_resize_atlas_16_to_12` 改成缩到 6 (改名/改目标尺寸); 16px 原图 → 6px (细节损失已接受)。
- **碰撞多边形**: tileset_builder 里实心/斜坡/门/平台的 `±6` 顶点 → `±3` (6px 框); `player.tscn` 碰撞框 (现 10×22 一带) 同步减半。
- **UI 库存图标** (`block_icons`) 仍用 16px 原图 —— 不是世界里的东西, **不缩**。

### 4. 相机不动

- `GameSettings.camera_zoom` 保持 0.8 不改。净效果: 方块屏幕上半大小。
- `world.gd:55` 注释里 `MINIMAP_VIEW_TILES_X` 的算式注释 (1280/0.8/12) 顺手更新为 /6, 值是否要调上线看 (视野格数变化)。

### 5. 测试

- 更新写死尺寸期望的测试 (上次改过的同批): `test_chunk_streaming` (×12 → ×6), `test_combat_phase1` (距离/Vector2), `test_mine_drop_pickup` (`*12+6` → `*6+3`), `test_workbench_prompt` (`/12.0` → `/6.0`), `test_animal_auto_step` (TILE_SIZE 常量)。
- 跑相关测试确认无回归。

### 6. 兜底: 全仓搜剩余硬编码

上次漏改硬编码 `16/8` 跟了好几个修补 commit。本次计划**专列一步**: `grep` 全仓找可疑的裸数字尺寸 (`* 12`, `+ 6`, `/ 12`, `12.0`, 直接写 `6`/`12` 的偏移/半径), 人工过一遍判断要不要缩。

## 数据流 / 不变量

- `TILE_SIZE` 单一来源 → 所有 tile↔world 坐标换算一致。
- 物理等比 ×0.5 → 玩家"几格能跳多高 / 走多快"不变 (手感不变)。
- 存档/世界数据用**格坐标**, 不受像素缩放影响 → 老存档兼容。

## 测试策略 (GUT)

- 单元: `ChunkConstants.TILE_SIZE == 6`; 抽查几个文件 `TILE_SIZE` 引用到同一来源 (== 6)。
- 集成: 上述更新后的尺寸测试全绿; tileset region size == 6; 跑 water/tile/combat/streaming 等无回归。
- 真机 (用户): 跑 `./run.sh --rebuild`, 看方块变小、人物走跳手感不变、掉落物能捡、钩爪/小地图正常。

## 风险

1. **漏改硬编码** (最大风险): 靠第 6 步 grep 兜底 + 真机验收。
2. **跨脚本 const 引用**: 已验证 `ChunkConstants.X` 全局可用; 个别文件若已 `const ChunkConstants = preload(...)` 不冲突。
3. **6px 太小**: 细节糊 / 可能轻微次像素模糊 —— 用户已接受; 真嫌小可事后调 `camera_zoom` 放大补偿 (一行)。
4. **碰撞减半**: ±3 顶点 + player.tscn 要对齐, 否则玩家卡块/穿墙。整体等比缩, 风险可控。
5. **并发 session**: 仓库有其它窗口在 main 提交 (角色美术/水下植物) —— 改前 `git status` 看清, 只 `git add` 精确文件。
