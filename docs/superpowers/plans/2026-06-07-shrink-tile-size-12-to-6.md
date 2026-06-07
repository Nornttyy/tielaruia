# 再次缩小方块 TILE_SIZE 12 → 6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把方块像素尺寸 12 → 6 (×0.5, 半大小), 手感不变 (所有世界像素量等比缩), 包含每个生物的精灵缩放 + 碰撞。

**Architecture:** ① 把 `TILE_SIZE` 集中到 `ChunkConstants` 一处 (=6), 34 文件引用它 → tile 派生坐标自动缩。② 写死的世界像素量全部 ×0.5 (物理/速度/碰撞/半径/精灵 scale)。③ 美术贴图缩到 6px。④ 相机不动 → 净效果半大小。

**Tech Stack:** Godot 4.3 + GDScript + GUT。

**Spec:** `docs/superpowers/specs/2026-06-07-shrink-tile-size-12-to-6-design.md`

**核心缩放规则 (每个数字过一遍):**
- **×0.5**: 世界里的像素量 —— 位置/尺寸/速度(px/s)/距离/半径/碰撞框/精灵 scale。
- **不动**: 时间(秒)、数量、角度、能量、alpha、以"格(tile)"为单位的量 (`* TILE_SIZE` 或 `_TILES` 常量自动跟缩)、UI 面板固定像素、FX 可见性下限 (见 Task 9)。
- 不确定就先 ×0.5, 标记上机看 (Task 11)。

**测试前置 (每次跑 GUT 前):** `godot --headless --editor --quit` 建索引。单文件用 `-gselect=<文件名>`。`libfontconfig` 警告无视。godot 在 `/root/.local/bin/godot` (PATH 里有)。

**⚠️ 并发**: 仓库有其它 session 在 main 提交。每步只 `git add` 列出的精确文件, 禁用 `-am`/`-A`/`.`。

**⚠️ 这是大改, 必须上机迭代 (Task 11)。** 上次 16→12 改完跟了 7 个修补 commit。本 plan 尽量一次到位, 但战斗半径/FX/手持物等敏感值留到上机调。

---

## 文件结构 (改动总览)

| 区域 | 文件 | 任务 |
|---|---|---|
| 常量来源 | `chunk_constants.gd` + 34 个 `const TILE_SIZE` 文件 | T1 |
| 美术/tileset/碰撞模板 | `tileset_builder.gd`, `art_cache.gd` | T2 |
| 玩家物理+场景 | `player_controller.gd`, `player.tscn` | T3 |
| 玩家动作 (战斗半径) | `player_action.gd` | T4 (敏感) |
| 怪物物理常量 | `scripts/entities/*.gd` | T5 |
| 怪物场景 (碰撞+精灵scale) | `scenes/entities/*.tscn` + slime `_SIZE_SCALE` | T6 |
| 掉落物 | `item_drop.gd` | T7 |
| 光照 + 黑暗网格 | `world_lighting.gd`, `torch_fx.gd`, `darkness_layer.gd` | T8 |
| FX 粒子 (可见性敏感) | `effects.gd`, `fx/*` | T9 (敏感) |
| 测试更新 | `tests/integration/*` | T10 |
| 硬编码兜底 + 上机 | 全仓 | T11 |

---

## Task 1: 集中 TILE_SIZE 到 ChunkConstants (=6)

**Files:**
- Modify: `scripts/world/chunk_constants.gd`
- Modify: 34 个含 `const TILE_SIZE := 12` 的文件 (见下 grep)
- Test: `tests/unit/test_tile_size_central.gd` (新建)

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_tile_size_central.gd`:

```gdscript
# TILE_SIZE 集中到 ChunkConstants, 值 = 6, 各文件引用同一来源。
extends GutTest


func test_chunk_constants_tile_size_is_6() -> void:
	assert_eq(ChunkConstants.TILE_SIZE, 6, "ChunkConstants.TILE_SIZE 应 = 6")


func test_representative_files_reference_central() -> void:
	# 抽查几个文件的 TILE_SIZE 都 = 6 (引用到同一来源)
	assert_eq(load("res://scripts/world/world.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/world/water_sim.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/entities/slime.gd").TILE_SIZE, 6)
	assert_eq(load("res://scripts/player/player_controller.gd").TILE_SIZE, 6)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_tile_size_central.gd -gexit`
Expected: FAIL — `ChunkConstants.TILE_SIZE` 不存在 / 现值 12

- [ ] **Step 3: ChunkConstants 加 TILE_SIZE**

`scripts/world/chunk_constants.gd` 在 `const VIEW_RADIUS := 2` 后加:

```gdscript
const TILE_SIZE := 6   # 方块像素尺寸 (单一来源). 12→6 全局缩小, 改这一个数即可
```

- [ ] **Step 4: 34 文件改成引用 (sed)**

把每个文件里的 `const TILE_SIZE := 12`(可能带行尾注释) 改成 `const TILE_SIZE := ChunkConstants.TILE_SIZE`。`ChunkConstants` 是全局 class_name, 无需 preload。

Run:
```bash
cd /workspace/teilaruia
grep -rl "const TILE_SIZE := 12" scripts/ | while read f; do
  sed -i 's/const TILE_SIZE := 12\(.*\)$/const TILE_SIZE := ChunkConstants.TILE_SIZE\1/' "$f"
done
```

- [ ] **Step 5: 确认没有遗留 `:= 12` 的 TILE_SIZE**

Run: `grep -rn "const TILE_SIZE := 12" scripts/ ; echo "剩余: $?"`
Expected: 无输出 (全部已改)。再 `grep -rln "const TILE_SIZE := ChunkConstants.TILE_SIZE" scripts/ | wc -l` 应为 34。

- [ ] **Step 6: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_tile_size_central.gd -gexit`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/world/chunk_constants.gd tests/unit/test_tile_size_central.gd $(grep -rl "ChunkConstants.TILE_SIZE" scripts/)
git commit -m "refactor(scale): TILE_SIZE 集中到 ChunkConstants 并设 6 (12→6 第一步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 美术贴图缩 6px + 碰撞模板减半

**Files:**
- Modify: `scripts/world/tileset_builder.gd` (region/tile_size/碰撞顶点)
- Modify: `scripts/autoload/art_cache.gd` (resize 函数泛化 16→6)
- Test: `tests/unit/test_tileset_region_6.gd` (新建)

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_tileset_region_6.gd`:

```gdscript
# tileset region 缩到 6px。
extends GutTest


func test_tileset_region_is_6() -> void:
	var ts: TileSet = load("res://scripts/world/tileset_builder.gd").build()
	assert_eq(ts.tile_size, Vector2i(6, 6), "TileSet tile_size 应 6x6")
	# 抽一个 source 的 region
	var src := ts.get_source(Tiles.DIRT) as TileSetAtlasSource
	assert_eq(src.texture_region_size, Vector2i(6, 6), "atlas region 应 6x6")


func test_resize_to_6() -> void:
	# 16px 原图缩到 6px: 1 cell → 6x6
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.RED)
	var tex := ImageTexture.create_from_image(img)
	var out: ImageTexture = ArtCache._smart_resize_atlas(tex, 6)
	assert_eq(out.get_width(), 6)
	assert_eq(out.get_height(), 6)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_tileset_region_6.gd -gexit`
Expected: FAIL — region 是 12 / `_smart_resize_atlas` 不存在

- [ ] **Step 3: art_cache resize 泛化为任意目标尺寸**

`scripts/autoload/art_cache.gd`: 把 `_smart_resize_atlas_16_to_12` 改名 `_smart_resize_atlas`, 加目标参数 `n`, 索引映射动态算 (均匀采样 16→n):

```gdscript
# 16x16 → n×n 智能缩放 (每 cell). 用途: TileSet region=n 前先把 16px pattern 缩成 n。
static func _smart_resize_atlas(tex: ImageTexture, n: int = ChunkConstants.TILE_SIZE) -> ImageTexture:
	var src: Image = tex.get_image()
	var w_cells: int = src.get_width() / 16
	var h_cells: int = src.get_height() / 16
	if w_cells <= 0 or h_cells <= 0:
		return tex
	# 均匀采样: dst 第 i 个 → src round(i*15/(n-1)), 含两端 (0 和 15)
	var map_n: PackedInt32Array = PackedInt32Array()
	for i in n:
		map_n.append(int(round(float(i) * 15.0 / float(n - 1))))
	var dst := Image.create(w_cells * n, h_cells * n, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for cy in h_cells:
		for cx in w_cells:
			for dr in n:
				var sr: int = cy * 16 + map_n[dr]
				for dc in n:
					var sc: int = cx * 16 + map_n[dc]
					dst.set_pixel(cx * n + dc, cy * n + dr, src.get_pixel(sc, sr))
	return ImageTexture.create_from_image(dst)
```

- [ ] **Step 4: 改所有 `_smart_resize_atlas_16_to_12(` 调用**

Run:
```bash
cd /workspace/teilaruia
sed -i 's/_smart_resize_atlas_16_to_12(\([^)]*\))/_smart_resize_atlas(\1)/g' scripts/autoload/art_cache.gd
grep -n "_smart_resize_atlas_16_to_12" scripts/autoload/art_cache.gd && echo "还有遗留!" || echo "调用已全改 ✓"
```

> `_extract_interior_icon_12` (12px UI 图标) 也要跟着改: 把函数体里的 `12` 换成 `ChunkConstants.TILE_SIZE`。若该函数仅被 `block_icons` 用 (UI), 可保留 16px 版 `_extract_interior_icon` 不动; 确认调用点用哪个。Step: `grep -n "_extract_interior_icon" scripts/autoload/art_cache.gd`, 用到 `_12` 的把 `12` → `ChunkConstants.TILE_SIZE`。

- [ ] **Step 5: tileset_builder region/tile_size/碰撞顶点减半**

`scripts/world/tileset_builder.gd`:
- `ts.tile_size = Vector2i(12, 12)` → `Vector2i(6, 6)`
- `source.texture_region_size = Vector2i(12, 12)` → `Vector2i(6, 6)`
- 实心方块碰撞框 `±6` → `±3` (3 处: 普通实心 / 门 / 出现 `(-6,-6),(6,-6),(6,6),(-6,6)` 的地方):
  `PackedVector2Array([Vector2(-3, -3), Vector2(3, -3), Vector2(3, 3), Vector2(-3, 3)])`
- 斜坡 `GRASS_SLOPE_R`: `[Vector2(-3, 3), Vector2(3, 3), Vector2(3, -3)]`
- 斜坡 `GRASS_SLOPE_L`: `[Vector2(-3, 3), Vector2(3, 3), Vector2(-3, -3)]`
- 平台 `[(-6,-1),(6,-1),(6,1),(-6,1)]` → `[(-3,-0.5),(3,-0.5),(3,0.5),(-3,0.5)]`

- [ ] **Step 6: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_tileset_region_6.gd -gexit`
Expected: PASS

- [ ] **Step 7: Commit**

```bash
git add scripts/world/tileset_builder.gd scripts/autoload/art_cache.gd tests/unit/test_tileset_region_6.gd
git commit -m "feat(scale): 贴图缩 6px + tileset 碰撞/region 减半

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 玩家物理 ×0.5 + player.tscn 减半

**Files:**
- Modify: `scripts/player/player_controller.gd` (物理常量)
- Modify: `scenes/player/player.tscn` (碰撞+精灵 scale+位置)

- [ ] **Step 1: player_controller 物理常量 ×0.5**

`scripts/player/player_controller.gd` 按表改 (只改世界像素量; 时间/格数不动):

| 常量 | 旧 | 新 |
|---|---|---|
| SPEED | 105.0 | 52.5 |
| JUMP_VELOCITY | -240.0 | -120.0 |
| GRAVITY | 675.0 | 337.5 |
| SWIM_GRAVITY | 150.0 | 75.0 |
| SWIM_UP_SPEED | -82.0 | -41.0 |
| SWIM_MAX_SINK | 135.0 | 67.5 |
| ROPE_CLIMB_SPEED | 82.0 | 41.0 |
| KNOCKBACK_VX | 67.0 | 33.5 |
| LAND_VY_THRESHOLD | 150.0 | 75.0 |
| PLAYER_BODY_HEIGHT | 30 | 15 |
| PLAYER_AURA_TEX_SIZE | 48 | 24 |
| SUN_AURA_TEX_SIZE | 300 | 150 |
| SHAKE_MAX_OFFSET | 4.0 | 2.0 |
| HOOK_FLY_SPEED | 360.0 | 180.0 |
| HOOK_PULL_SPEED | 210.0 | 105.0 |
| HOOK_RELEASE_DIST | 7.5 | 3.75 |

> **不动**: `COYOTE_TIME / WALK_PUFF_INTERVAL / ROPE_HOLD_GRAVITY(0) / HURT_DURATION / SHAKE_DECAY / SUN_ENERGY_* / SUN_FADE_TIME / _MUSIC_INTERVAL / _SUN_INTERVAL / DROP_THROUGH_DURATION / CAVE_DEPTH_THRESHOLD(格) / HOOK_MAX_DIST_TILES(格)`。

- [ ] **Step 2: player.tscn 碰撞+精灵减半**

`scenes/player/player.tscn`:
- CollisionShape `size = Vector2(14.4, 30)` → `Vector2(7.2, 15)`
- CollisionShape `position = Vector2(0, -15)` → `Vector2(0, -7.5)`
- Sprite `position = Vector2(0, -30)` → `Vector2(0, -15)`
- Sprite `scale = Vector2(0.6, 0.625)` → `Vector2(0.3, 0.3125)`
- Sprite `offset = Vector2(-12, 0)` → `Vector2(-6, 0)`

- [ ] **Step 3: 编译检查 (无单测, 跑相关集成)**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=combat -gexit`
Expected: 加载无解析错误 (数值断言可能要等 T10 改, 先看不崩)

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player_controller.gd scenes/player/player.tscn
git commit -m "feat(scale): 玩家物理 ×0.5 + player.tscn 碰撞/精灵减半

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 玩家战斗半径 ×0.5 (敏感, 上机可能要回调)

**Files:**
- Modify: `scripts/player/player_action.gd`

- [ ] **Step 1: 战斗像素常量 ×0.5**

`scripts/player/player_action.gd` 按表改:

| 常量 | 旧 | 新 |
|---|---|---|
| SWORD_RANGE_PX | 27.0 | 13.5 |
| PICKAXE_HIT_RADIUS | 12.5 | 6.25 |
| SWORD_SWEEP_REACH_BONUS | 20.0 | 10.0 |
| SWORD_HIT_RADIUS | 17.5 | 8.75 |
| SWORD_POINT_BLANK_DIST | 22.5 | 11.25 |
| SWORD_THRUST_OFFSET | 8.0 | 4.0 |
| DAGGER_HIT_RADIUS | 13.0 | 6.5 |

> **不动**: `REACH_TILES(格) / PICKAXE_MOUSE_NEAR_RADIUS_MULT(倍率)`。
> ⚠️ 这些是用户调过的命中手感值 ("玩家 1.25x")。等比缩理论对, 但上机若"打不到怪"优先回调这几个 (见 [[reference_melee_hit_radius]])。

- [ ] **Step 2: 全文件搜剩余裸像素**

Run: `grep -nE ":?= [0-9]+\.?[0-9]* *#|OFFSET|_PX|REACH|RANGE|DIST|RADIUS" scripts/player/player_action.gd | grep -ivE "_TILES|MULT|_TIME|DURATION|ANGLE|_DEG"`
人工过一遍: 是世界像素的 ×0.5 (改), 是格/倍率/时间的跳过。

- [ ] **Step 3: 编译检查**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=combat -gexit`
Expected: 加载无错

- [ ] **Step 4: Commit**

```bash
git add scripts/player/player_action.gd
git commit -m "feat(scale): 玩家战斗命中半径 ×0.5

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 怪物物理常量 ×0.5

**Files:**
- Modify: `scripts/entities/*.gd`

- [ ] **Step 1: 各怪物像素常量 ×0.5**

按表改 (GRAVITY 675→337.5 在多个文件都一样; `* TILE_SIZE` / `_TILES` / 时间不动):

| 文件 | 常量: 旧 → 新 |
|---|---|
| animal_base.gd | GRAVITY 675→337.5; SWIM_GRAVITY 150→75 (`AUTO_STEP_LIFT := TILE_SIZE+1` 不动) |
| slime.gd | GRAVITY 675→337.5; SWIM_GRAVITY 150→75; SWIM_MAX_SINK 52→26; AGGRO_RANGE_PX 120→60 |
| king_slime.gd | GRAVITY 675→337.5; AGGRO_RANGE_PX 600→300; DESPAWN_DISTANCE_PX 960→480 |
| zombie.gd | GRAVITY 675→337.5; SWIM_GRAVITY 150→75; SWIM_MAX_SINK 52→26; SWIM_UP_SPEED -34→-17; JUMP_VY -195→-97.5 (查 WALK_SPEED 一并 ×0.5) |
| spider.gd | GRAVITY 675→337.5; WALK_SPEED 55→27.5; JUMP_VY -240→-120 |
| skeleton.gd | GRAVITY 675→337.5; WALK_SPEED 35→17.5; JUMP_VY -200→-100 |
| skeleton_king.gd | GRAVITY 675→337.5; WALK_SPEED 42→21; AGGRO_RANGE_PX 600→300; JUMP_VY -240→-120; DESPAWN_DISTANCE_PX 1100→550; DASH_SPEED 240→120; SWEEP_RANGE_PX 26→13 (BODY_SCALE 1.3 倍率不动; `RANGE_CLOSE/FAR_PX := n*TILE_SIZE` 不动) |
| mummy.gd | GRAVITY 675→337.5; WALK_SPEED 25→12.5; JUMP_VY -180→-90 |
| mimic.gd | GRAVITY 675→337.5; WALK_SPEED 40→20; JUMP_VY -340→-170 |
| friendly_skeleton.gd | GRAVITY 675→337.5; WALK_SPEED 58→29; JUMP_VY -220→-110 |
| harpy.gd | PATROL_SPEED 55→27.5; CHARGE_SPEED 120→60; AGGRO_RANGE_PX 260→130 |
| hell_wasp.gd | PATROL_SPEED 60→30; CHARGE_SPEED 130→65 |
| imp.gd | FLY_SPEED 70→35 |
| demon_eye.gd | FLY_SPEED 60→30 |
| arrow.gd | SPEED 260→130; GRAVITY 200→100 |
| fireball.gd | SPEED 180→90 |
| bone_projectile.gd | SPEED 155→77.5; GRAVITY 120→60 |
| slime_ball.gd | SPEED 240→120; GRAVITY 480→240 |

> **不动**: `remote_player.gd LERP_SPEED 8.0` (1/s 收敛率); 所有 `*_TILES` / `* TILE_SIZE` / 时间 / 数量 / `_DEG`。
> slime hop 高度是 `_TILES` 常量 + GRAVITY → 自动等比 (GRAVITY 已 ×0.5)。

- [ ] **Step 2: 兜底搜每个 entity 文件剩余裸像素速度**

Run: `grep -rnE "const [A-Z_]+ ?:?= -?[0-9]+\.?[0-9]*" scripts/entities/*.gd | grep -iE "SPEED|GRAVITY|JUMP|_VX|_VY|_PX|DASH|CHARGE|KNOCK|SINK" | grep -ivE "TILE_SIZE|_TILES|LERP_SPEED|_TIME"`
确认表里都覆盖了, 漏的补上 ×0.5。

- [ ] **Step 3: 编译检查**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=slime -gexit`
Expected: 加载无错

- [ ] **Step 4: Commit**

```bash
git add scripts/entities/animal_base.gd scripts/entities/slime.gd scripts/entities/king_slime.gd scripts/entities/zombie.gd scripts/entities/spider.gd scripts/entities/skeleton.gd scripts/entities/skeleton_king.gd scripts/entities/mummy.gd scripts/entities/mimic.gd scripts/entities/friendly_skeleton.gd scripts/entities/harpy.gd scripts/entities/hell_wasp.gd scripts/entities/imp.gd scripts/entities/demon_eye.gd scripts/entities/arrow.gd scripts/entities/fireball.gd scripts/entities/bone_projectile.gd scripts/entities/slime_ball.gd
git commit -m "feat(scale): 怪物物理/速度常量 ×0.5

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 怪物场景碰撞 + 精灵 scale 减半

> 规则: 每个 `.tscn`: CollisionShape `size`/`radius` 与所有 `position` ×0.5; AnimatedSprite2D/Sprite2D `scale` 减半 (无 scale 行 = 隐含 1.0 → 加 `scale = Vector2(0.5, 0.5)`)。
> 实现时**逐个 Read 该 .tscn** 确认精灵节点名再改 scale。碰撞数值见下表 (已算好半值)。

**Files:** `scenes/entities/*.tscn` + `scripts/entities/slime.gd` (`_SIZE_SCALE`)

- [ ] **Step 1: 碰撞框/位置 ×0.5 (按表)**

| 场景 | 改动 |
|---|---|
| arrow.tscn | radius 3.0→1.5 |
| cow.tscn | size(20,14)→(10,7); pos -26→-13, -7→-3.5 |
| demon_eye.tscn | size(16,10)→(8,5); pos -5→-2.5 (×2) |
| fireball.tscn | radius 4.0→2.0 |
| friendly_skeleton.tscn | size(10,16)→(5,8); pos -8→-4 (×2) |
| frog.tscn | size(12,10)→(6,5); pos -12→-6, -5→-2.5 |
| harpy.tscn | size(12,10)→(6,5); pos -6→-3, -5→-2.5 |
| hell_wasp.tscn | size(12,10)→(6,5); pos -6→-3, -5→-2.5 |
| imp.tscn | size(14,12)→(7,6); pos -8→-4, -7→-3.5 |
| king_slime.tscn | size(13,11)→(6.5,5.5); pos -16→-8 (×2) |
| mimic.tscn | size(12,14)→(6,7); pos -8→-4, -7→-3.5 |
| mummy.tscn | size(10,16)→(5,8); pos -8→-4 (×2) |
| penguin.tscn | size(16,14)→(8,7); pos -22→-11, -7→-3.5; sprite scale 0.85→0.425 |
| pig.tscn | size(18,10)→(9,5); pos -17→-8.5, -5→-2.5 |
| remote_player.tscn | pos -30→-15; sprite scale (1.2,1.25)→(0.6,0.625) |
| sheep.tscn | size(16,14)→(8,7); pos -23→-11.5, -7→-3.5 |
| skeleton.tscn | size(10,16)→(5,8); pos -8→-4 (×2) |
| skeleton_king.tscn | size(14,30)→(7,15); pos -16→-8, -15→-7.5; sprite pos -36→-18, scale 1.0→0.5 |
| slime.tscn | size(12,10)→(6,5); pos -12→-6, -5→-2.5 |
| slime_ball.tscn | radius 4.0→2.0 |
| spider.tscn | size(12,8)→(6,4); pos -10→-5, -4→-2 |

- [ ] **Step 2: 给隐含 scale=1.0 的怪精灵加 `scale = Vector2(0.5, 0.5)`**

逐个 Read 这些 .tscn (无 scale 行的): cow, demon_eye, friendly_skeleton, frog, harpy, hell_wasp, imp, king_slime, mimic, mummy, pig, sheep, skeleton, slime, spider。在其 AnimatedSprite2D/Sprite2D 节点属性里加 `scale = Vector2(0.5, 0.5)`。
(arrow/fireball/slime_ball 是投射物, 视觉小, 也按需加 scale=0.5 — Read 确认有无精灵节点。)

- [ ] **Step 3: slime `_SIZE_SCALE` 减半**

`scripts/entities/slime.gd`: `const _SIZE_SCALE := [0.65, 1.0, 1.5]` → `[0.325, 0.5, 0.75]`

- [ ] **Step 4: 编译/加载检查**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=slime -gexit`
Expected: 加载无错

- [ ] **Step 5: Commit**

```bash
git add scenes/entities/*.tscn scripts/entities/slime.gd
git commit -m "feat(scale): 怪物场景碰撞 + 精灵 scale 减半

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: 掉落物物理 ×0.5

**Files:** `scripts/items/item_drop.gd`

- [ ] **Step 1: 物理常量 ×0.5**

| 常量 | 旧 | 新 |
|---|---|---|
| GRAVITY | 450.0 | 225.0 |
| FRICTION | 150.0 | 75.0 |
| MAX_FALL_SPEED | 300.0 | 150.0 |

> `PICKUP_DELAY 0.4` (时间) 不动。

- [ ] **Step 2: 搜拾取/磁吸半径 (可能在别处)**

Run: `grep -rnE "pickup|magnet|PICKUP|吸|拾取" scripts/player/*.gd scripts/items/*.gd | grep -iE "range|radius|dist|= [0-9]"`
找到的世界像素半径 ×0.5。掉落物视觉尺寸 (若有 sprite scale 或 draw size) 也 ×0.5 (Read item_drop.gd 的绘制部分确认)。

- [ ] **Step 3: Commit**

```bash
git add scripts/items/item_drop.gd $(grep -rl "pickup\|magnet" scripts/player/ 2>/dev/null)
git commit -m "feat(scale): 掉落物物理/拾取半径 ×0.5

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: 光照半径 + 黑暗网格

**Files:** `scripts/fx/torch_fx.gd`, `scripts/world/world_lighting.gd`, `scripts/world/darkness_layer.gd`

- [ ] **Step 1: 火把光半径 ×0.5**

`scripts/fx/torch_fx.gd`: `const LIGHT_RADIUS := 96` → `48`。
`scripts/world/world_lighting.gd`: 搜 `grep -nE "RADIUS|= [0-9]+" scripts/world/world_lighting.gd | grep -ivE "TILE_SIZE|GRID|COLOR|ALPHA|_TIME"`, 世界像素半径 ×0.5; 以"格"为单位的不动。

- [ ] **Step 2: 黑暗网格容量加大 (关键! 否则黑暗盖不满屏)**

`scripts/world/darkness_layer.gd`: 屏幕能看到的 tile 数翻倍 (TILE_SIZE 12→6)。当前 `MAX_W := 240` / `MAX_H := 144` 按 12px 算; 6px 下可见 tile ≈ `1280/(0.8*6)=267` 宽 / `720/(0.8*6)=150` 高。改:

| 常量 | 旧 | 新 |
|---|---|---|
| MAX_W | 240 | 480 |
| MAX_H | 144 | 288 |

并把文件顶部注释里 `0.5*12` 的算式更新为 `0.8*6` (zoom 0.8, TILE_SIZE 6)。`BUFFER_TILES 8` (格) 不动。

> ⚠️ MAX_W/H 翻倍会增大黑暗贴图内存; 6px 下屏幕 tile 数确实翻倍, 必须加大否则边缘漏光。上机重点看黑暗有没有盖满。

- [ ] **Step 3: 编译检查**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=torch -gexit`
Expected: 加载无错

- [ ] **Step 4: Commit**

```bash
git add scripts/fx/torch_fx.gd scripts/world/world_lighting.gd scripts/world/darkness_layer.gd
git commit -m "feat(scale): 光照半径 ×0.5 + 黑暗网格容量翻倍 (6px 屏幕 tile 翻倍)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: FX 粒子 (可见性敏感, 保守)

**Files:** `scripts/fx/effects.gd`, `scripts/fx/*.gd`

> FX 位置多由 `* TILE_SIZE` 算 → 自动缩。但**粒子视觉尺寸 (线宽/半径/边长) 不要盲目 ×0.5** —— 会跌破可见性下限 (见 [[feedback_fx_visibility]]: 线宽 ≥2px, alpha ≥0.8)。原则: 粒子**位置/位移偏移** ×0.5, **视觉尺寸**先**不动**, 上机看比例再微调。

- [ ] **Step 1: 扫 FX 里的裸像素**

Run: `grep -rnE "= -?[0-9]+\.?[0-9]*|Vector2\(-?[0-9]" scripts/fx/*.gd | grep -ivE "TILE_SIZE|_TIME|_SEC|ALPHA|COLOR|COUNT|MAX_|CHANCE|0x|z_index|DURATION"`
人工分类:
- **位移/位置偏移 (px)**: ×0.5
- **粒子视觉尺寸 (线宽/半径/字号)**: 不动 (保可见)
- **以 TILE_SIZE 算的**: 已自动, 不动

- [ ] **Step 2: 应用 + 编译检查**

改完 Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=water_grain -gexit`
Expected: 加载无错 + grain 预算测试仍绿

- [ ] **Step 3: Commit**

```bash
git add scripts/fx/effects.gd $(git diff --name-only scripts/fx/)
git commit -m "feat(scale): FX 位置偏移 ×0.5 (粒子尺寸保可见不缩)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: 更新测试硬编码尺寸

**Files:** `tests/integration/*`

- [ ] **Step 1: 找写死尺寸的测试**

Run: `grep -rnE "\* 12|/ ?12|12\.0|\* 16|/ ?16|TILE_SIZE := 12|16, 0|Vector2\(12|Vector2\(16" tests/`
逐个判断, 上次改过的同批 + 本次新增受影响的:

| 测试 | 改动 |
|---|---|
| test_chunk_streaming | `* 12` → `* 6` (chunk 像素宽算式) |
| test_combat_phase1 | 距离常数 (如 `27*1.4`→`13.5*1.4`), `Vector2(12,0)`→`Vector2(6,0)` |
| test_mine_drop_pickup | `target*12+6` → `target*6+3` |
| test_workbench_prompt | `/12.0` → `/6.0` |
| test_animal_auto_step | 本地 `TILE_SIZE` 常量 12→6 (若有) |

> 逐个看测试意图: 是验"世界像素"的随 6 改; 是验"格/逻辑"的不改。

- [ ] **Step 2: 跑这些测试 + 改过的区域回归**

Run:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=combat -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=chunk_streaming -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=mine_drop -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=workbench -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=water -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=tile -gexit
```
Expected: 全绿。红的逐个修 (区分"测试期望要更新" vs "真 bug")。

- [ ] **Step 3: Commit**

```bash
git add tests/
git commit -m "test(scale): 更新测试硬编码尺寸 12→6

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 11: 全仓硬编码兜底 + 上机验收 (必做)

**Files:** 全仓 + 真机

- [ ] **Step 1: 全仓搜可疑裸数字尺寸**

Run:
```bash
cd /workspace/teilaruia
grep -rnE "\* 12\b|/ ?12\b|12\.0|\b\* 16\b|/ ?16\b|16\.0|\+ 6\b|- 6\b" scripts/ | grep -ivE "TILE_SIZE|_TIME|0x|ChunkConstants|//|#"
```
逐行判断: 是"世界像素 12/16 残留"的改成 6; 是巧合数字 (数组下标/颜色/无关) 的跳过。重点查 `world.gd` MINIMAP_VIEW 注释算式、`scenic_director`、`crack_overlay`、`place_bounce`、`water_grain_particle`。

- [ ] **Step 2: 跑全部受影响区域测试**

Run (分批避免超时):
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=water -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=tile -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=combat -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=slime -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=chunk -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gselect=auto_step -gexit
```
Expected: 全绿 (或仅剩已知非本次相关的红, 记录)。

- [ ] **Step 3: 真机验收 (用户做)**

`./run.sh --rebuild`, 检查清单:
- 方块明显变小 (半大小), 看到更多世界。
- 玩家走/跳/游泳/钩爪/爬绳手感不变, 不卡墙不穿墙。
- 怪物大小跟方块比例正常 (不显巨大/迷你), 能打到、会掉血。
- 掉落物能捡; 火把照亮范围合理; 夜里黑暗盖满屏 (无边缘漏光)。
- 小地图正常; 手持工具大小可接受 (嫌大再调 TOOL_SIZE)。

- [ ] **Step 4: 按反馈迭代修 (预期会有)**

常见: 战斗"打不到" → 回调 T4 命中半径; FX 太小/太大 → 调 T9; 黑暗漏光 → 加大 T8 MAX_W/H; 工具太大 → 调 held_item TOOL_SIZE。每修一处单独 commit。

- [ ] **Step 5: 推送**

```bash
git push origin main
```
GitHub Actions 自动部署。

---

## 自查 (Self-Review 记录)

- **Spec 覆盖**: ①集中 TILE_SIZE (T1) ✓; ②写死像素 ×0.5 — 玩家(T3) 战斗(T4) 怪物(T5) 掉落(T7) 光照(T8) FX(T9) ✓; ③贴图 6px+碰撞(T2) ✓; ④相机不动 (全程不碰 camera_zoom) ✓; ⑤测试(T10) ✓; ⑥硬编码兜底(T11) ✓; 生物视觉(spec 补充段)→ T6 ✓; 手持物先不动 → 全程不改 held_item (T11 上机再定) ✓。
- **Placeholder**: 数值表全部给了旧→新具体值; FX/拾取/硬编码用"grep + 分类规则"是确定性操作非占位。
- **一致性**: GRAVITY 675→337.5 全文件统一; `_smart_resize_atlas(tex, n)` 签名贯穿 T2; ×0.5 规则贯穿全程; "格/时间/倍率不缩"规则一致。
- **风险**: 最大是漏改硬编码 (T11 grep 兜底) + 战斗/FX/黑暗敏感值 (T4/T9/T8 标注 + T11 上机迭代)。
