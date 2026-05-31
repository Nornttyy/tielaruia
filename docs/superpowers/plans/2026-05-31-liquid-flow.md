# 流体流动（岩浆流动 + 水/岩浆=石头）实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让岩浆像水一样流动（慢吞吞、有深浅），并实现"水碰岩浆→岩浆变普通石头+冒烟"。

**Architecture:** 把现有 `water_sim.gd`（dirty-list 驱动的流水引擎）泛化成"流体引擎"，水和岩浆共用重力下流+横向铺平+体积守恒逻辑；差异只有流速（岩浆每 3 tick 流一步）和异种相遇反应（变石头）。新增 3 个岩浆深浅方块。

**Tech Stack:** Godot 4.3 + GDScript，GUT 测试。`.tscn`/美术全由文本/程序生成。

参考设计：`docs/superpowers/specs/2026-05-31-liquid-flow-design.md`

---

## 运行测试

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gselect=test_liquid_flow.gd -gexit 2>&1 | grep -v libfontconfig
```
GUT 加载慢(可达 60-200s)，耐心等。若超时无输出，用 `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|Parse Error"`（无输出=编译健康）做兜底，并在报告中说明。

## 并发警告（重要）
本仓库有并发 session 在同一 main 上活动，会改 `tile_data.gd` / `art_cache.gd` 等公共文件并偶发合并冲突。每个 task：
- 提交**只用指定文件名**：`git commit <exact paths> -m "..."`，**严禁** `-am`/`-A`/`.`（否则会卷入别人 staged 的改动）。
- 提交后 `git show HEAD --stat` 确认只含本 task 的文件。
- 不碰 `CLAUDE.md`、`minimap_view.gd`、`save_manager.gd` 等非本计划文件。

## 文件结构
- `scripts/world/tile_data.gd` — 加 LAVA_L1/L2/L3 常量 + _DATA 条目（非实心、不可挖）
- `scripts/art/blocks_art.gd` — 加 `get_lava_level_atlas(level)`（镜像 `get_water_level_atlas`）
- `scripts/autoload/art_cache.gd` — 注册 3 个岩浆深浅贴图
- `scripts/world/tileset_builder.gd` — tile_ids 加 3 个（静态，无动画）
- `scripts/world/water_sim.gd` — 液种泛化 + 岩浆慢速 + 水/岩浆反应
- `scripts/fx/effects.gd` — `spawn_steam_puff`
- `scripts/player/player_health.gd` — 岩浆伤害判定含 LAVA_L1..L3
- `tests/integration/test_liquid_flow.gd` — 新建

---

## Task 1: 新增岩浆深浅方块 + 烫伤识别

**Files:**
- Modify: `scripts/world/tile_data.gd`
- Modify: `scripts/player/player_health.gd`
- Test: `tests/integration/test_liquid_flow.gd`（新建）

- [ ] **Step 1: 写失败测试** — 新建 `tests/integration/test_liquid_flow.gd`：

```gdscript
# 流体流动验收: 岩浆流动 + 水/岩浆=石头
extends GutTest


func test_lava_level_tiles_defined() -> void:
	assert_eq(Tiles.LAVA_L1, 71, "LAVA_L1 = 71")
	assert_eq(Tiles.LAVA_L2, 72, "LAVA_L2 = 72")
	assert_eq(Tiles.LAVA_L3, 73, "LAVA_L3 = 73")
	# 岩浆深浅都是非实心 (玩家能穿过, 像满格 LAVA)
	assert_false(Tiles.is_solid(Tiles.LAVA_L1), "LAVA_L1 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L2), "LAVA_L2 非实心")
	assert_false(Tiles.is_solid(Tiles.LAVA_L3), "LAVA_L3 非实心")
```

- [ ] **Step 2: 跑测试看它失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gselect=test_liquid_flow.gd -gexit 2>&1 | grep -v libfontconfig`
Expected: FAIL（`LAVA_L1` 等常量不存在）

- [ ] **Step 3: 加常量**

在 `scripts/world/tile_data.gd`，紧挨 `const LAVA := 56` 那组常量后面（确认 71/72/73 当前未被占用——文件里现最大 id 是 70）加：
```gdscript
const LAVA_L1 := 71         # 1/4 岩浆 (流动浅位)
const LAVA_L2 := 72         # 2/4 岩浆
const LAVA_L3 := 73         # 3/4 岩浆 (满格仍是 LAVA = 56)
```

- [ ] **Step 4: 加 _DATA 条目**

先读现有 `LAVA: { ... }` 的 _DATA 条目（在同文件的大字典里），照它的字段加三条（非实心、不可挖、无掉落、无 tool_tiers）。例如紧跟 LAVA 条目后：
```gdscript
	LAVA_L1: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	LAVA_L2: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	LAVA_L3: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
```
（若 LAVA 的真实条目字段与此不同，以 LAVA 的为准照抄，只把名字换成 LAVA_L1/L2/L3。`is_solid()` 读的就是 `"solid"` 字段，所以 solid=false 即满足测试。）

- [ ] **Step 5: 岩浆烫伤识别深浅位**

在 `scripts/player/player_health.gd` 的 `_check_lava_damage`，当前判定是 `cm.get_tile(...) == Tiles.LAVA`。改成一个 helper，让浅岩浆也烫人。在文件里加：
```gdscript
func _is_lava(tid: int) -> bool:
	return tid == Tiles.LAVA or tid == Tiles.LAVA_L1 or tid == Tiles.LAVA_L2 or tid == Tiles.LAVA_L3
```
把 `_check_lava_damage` 里的两处 `cm.get_tile(tile_x, foot_y) == Tiles.LAVA` / `cm.get_tile(tile_x, head_y) == Tiles.LAVA` 改成 `_is_lava(cm.get_tile(tile_x, foot_y))` / `_is_lava(cm.get_tile(tile_x, head_y))`。

- [ ] **Step 6: 跑测试看它通过**

Run: 同 Step 2。Expected: `test_lava_level_tiles_defined` PASS。

- [ ] **Step 7: 提交**

```bash
git commit scripts/world/tile_data.gd scripts/player/player_health.gd tests/integration/test_liquid_flow.gd -m "feat(liquid): 岩浆深浅方块 LAVA_L1..L3 + 烫伤识别"
git show HEAD --stat   # 确认只含这 3 个文件
```

---

## Task 2: 岩浆深浅美术 + 注册

**Files:**
- Modify: `scripts/art/blocks_art.gd`
- Modify: `scripts/autoload/art_cache.gd`
- Test: `tests/integration/test_liquid_flow.gd`

- [ ] **Step 1: 写失败测试** — 追加：

```gdscript
func test_lava_level_textures_built() -> void:
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L1), "LAVA_L1 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L2), "LAVA_L2 该有世界贴图")
	assert_not_null(ArtCache.block_textures.get(Tiles.LAVA_L3), "LAVA_L3 该有世界贴图")
```

- [ ] **Step 2: 跑测试看它失败** — 同上命令，Expected: FAIL（block_textures 没有这些 key）。

- [ ] **Step 3: 加 get_lava_level_atlas**

先读 `scripts/art/blocks_art.gd` 里的 `get_water_level_atlas(level)` 和它用的 `_clip_water_top(pattern, clip_rows)`（通用，按行清顶部），以及 `_LAVA` pattern + `_P_LAVA` palette（都已存在）。在 `get_water_level_atlas` 附近加镜像版（岩浆不做动画，用 4 个相同帧填满 64×16，跟水同结构好让 art_cache 同样处理）：
```gdscript
# 岩浆深浅 atlas: 跟 get_water_level_atlas 同结构 (64×16), 但 4 帧相同 (岩浆不动画).
# level 1=1/4 (顶 12 行透明), 2=1/2 (顶 8 行), 3=3/4 (顶 4 行).
static func get_lava_level_atlas(level: int) -> ImageTexture:
	assert(level >= 1 and level <= 3, "level 必须 1-3")
	var clip_rows: int = (4 - level) * 4
	var clipped: Array = _clip_water_top(_LAVA, clip_rows)
	var dst := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for i in range(4):
		var frame_img: Image = PixelArt.grid_to_image(clipped, _P_LAVA)
		dst.blit_rect(frame_img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	return ImageTexture.create_from_image(dst)
```
（确认 `_clip_water_top` / `PixelArt.grid_to_image` 的真实签名与 `get_water_level_atlas` 中用法一致；若 `grid_to_image` 不是这个名字，用 `get_water_level_atlas` 里实际调用的那个。）

- [ ] **Step 4: art_cache 注册**

在 `scripts/autoload/art_cache.gd`：
(a) 把 `BlocksArt.LAVA_L1, BlocksArt.LAVA_L2, BlocksArt.LAVA_L3` 加进构建 `block_textures` 的那个 tile 列表（紧跟 `BlocksArt.LAVA` 那行；注意 BlocksArt 里也要有这三个常量——BlocksArt 与 Tiles 常量镜像，若 BlocksArt 缺则在 `scripts/art/blocks_art.gd` 顶部加 `const LAVA_L1 := 71` 等，跟它现有 `const WATER_L1 := 34` 风格一致）。
(b) 在贴图构建的 `elif` 链里（紧跟 `WATER_L3` 分支）加三段，镜像水位写法：
```gdscript
		elif tile_id == BlocksArt.LAVA_L1:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(1))
			block_icons[tile_id] = block_textures[tile_id]
		elif tile_id == BlocksArt.LAVA_L2:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(2))
			block_icons[tile_id] = block_textures[tile_id]
		elif tile_id == BlocksArt.LAVA_L3:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(3))
			block_icons[tile_id] = block_textures[tile_id]
```
（岩浆深浅不是物品，icon 用同一张贴图占位即可，避免缺 key。`_smart_resize_atlas_16_to_12` 是水位用的同一函数。）

- [ ] **Step 5: 跑测试看它通过** — `test_lava_level_textures_built` PASS。

- [ ] **Step 6: 整体导入确认** — `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|blocks_art|art_cache"`（无输出）。

- [ ] **Step 7: 提交**

```bash
git commit scripts/art/blocks_art.gd scripts/autoload/art_cache.gd tests/integration/test_liquid_flow.gd -m "feat(liquid): 岩浆深浅美术 + 注册"
git show HEAD --stat
```

---

## Task 3: TileSet 注册岩浆深浅（静态、可穿过）

**Files:**
- Modify: `scripts/world/tileset_builder.gd`
- Test: 用整体导入 + 既有 world 测试间接验证（TileSet 难直接单测）

- [ ] **Step 1: 加进 tile_ids**

在 `scripts/world/tileset_builder.gd` 的 `tile_ids` 数组里，紧跟 `Tiles.LAVA` 加 `Tiles.LAVA_L1, Tiles.LAVA_L2, Tiles.LAVA_L3`。碰撞由 `Tiles.is_solid()` 门控，岩浆深浅 solid=false → 自动无碰撞、可穿过（同满格 LAVA）。**不要**把它们加进水的 4 帧动画分支（岩浆静态）。

- [ ] **Step 2: 整体导入确认无报错**

Run: `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|physics.size|tileset"`
Expected: 无输出。（漏加 tile_ids 会导致放置/渲染时找不到 source；这步确保 TileSet 正确构建。）

- [ ] **Step 3: 提交**

```bash
git commit scripts/world/tileset_builder.gd -m "feat(liquid): TileSet 注册岩浆深浅 (静态可穿过)"
git show HEAD --stat
```

---

## Task 4: 流体引擎泛化（岩浆会流，跟水同逻辑）

**Files:**
- Modify: `scripts/world/water_sim.gd`
- Test: `tests/integration/test_liquid_flow.gd`

读 `scripts/world/water_sim.gd` 全文（已有 `_level_of`/`_tile_for_level`/`_step_tile`/`add_water`/`mark_dirty`/`notify_tile_changed`/`_run_tick`，用 `world._set_water_tile_fast` 设 tile）。本 task 把它泛化成同时认水和岩浆，岩浆流动规律与水**完全一致**（慢速放到 Task 5，反应放到 Task 6）。

- [ ] **Step 1: 写失败测试** — 追加：

```gdscript
# 直接造一个最小 water_sim + 假 chunk_manager 太重; 用真 world 太慢.
# 这里用一个轻量假 cm: 记录 tile, 暴露 get_tile/_set_water_tile_fast.
class FakeWorld:
	var tiles := {}
	var chunk_manager = null
	func _init():
		chunk_manager = FakeCM.new(tiles)
	func _set_water_tile_fast(x, y, tid):
		tiles[Vector2i(x, y)] = tid
class FakeCM:
	var tiles
	func _init(t): tiles = t
	func get_tile(x, y):
		return tiles.get(Vector2i(x, y), Tiles.AIR)

func _make_sim(fake) -> Node:
	var WaterSim = load("res://scripts/world/water_sim.gd")
	var sim = WaterSim.new()
	sim.world = fake
	add_child_autofree(sim)
	return sim

func test_lava_falls_down() -> void:
	var fw = FakeWorld.new()
	# 一格满岩浆在 (0,0), 下面 (0,1) 是空气, 再下 (0,2) 是石头地板
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	# 岩浆应已下落到 (0,1) (石头上方), (0,0) 变空
	assert_eq(fw.tiles.get(Vector2i(0,1), Tiles.AIR), Tiles.LAVA, "岩浆该落到石头上方")
	assert_eq(fw.tiles.get(Vector2i(0,0), Tiles.AIR), Tiles.AIR, "原位该空")
```

- [ ] **Step 2: 跑测试看它失败** — Expected: FAIL（岩浆不被识别为流体，不流动；(0,1) 仍是 AIR）。

- [ ] **Step 3: 泛化液种识别**

在 `water_sim.gd` 加：
```gdscript
# 液种: "water" / "lava" / "" (非流体)
func _liquid_kind(tid: int) -> String:
	if tid == Tiles.WATER or tid == Tiles.WATER_L1 or tid == Tiles.WATER_L2 or tid == Tiles.WATER_L3:
		return "water"
	if tid == Tiles.LAVA or tid == Tiles.LAVA_L1 or tid == Tiles.LAVA_L2 or tid == Tiles.LAVA_L3:
		return "lava"
	return ""
```
把现有 `_level_of(tid)` 扩展为也认岩浆（满=4，L3=3，L2=2，L1=1）：
```gdscript
func _level_of(tid: int) -> int:
	if tid == Tiles.WATER or tid == Tiles.LAVA: return 4
	if tid == Tiles.WATER_L3 or tid == Tiles.LAVA_L3: return 3
	if tid == Tiles.WATER_L2 or tid == Tiles.LAVA_L2: return 2
	if tid == Tiles.WATER_L1 or tid == Tiles.LAVA_L1: return 1
	return 0
```
把 `_tile_for_level(L)` 改成带液种：
```gdscript
func _tile_for_level(kind: String, L: int) -> int:
	if kind == "lava":
		if L >= 4: return Tiles.LAVA
		if L == 3: return Tiles.LAVA_L3
		if L == 2: return Tiles.LAVA_L2
		if L == 1: return Tiles.LAVA_L1
		return Tiles.AIR
	# 默认水
	if L >= 4: return Tiles.WATER
	if L == 3: return Tiles.WATER_L3
	if L == 2: return Tiles.WATER_L2
	if L == 1: return Tiles.WATER_L1
	return Tiles.AIR
```
**注意:** `add_water()` 里原来调 `_tile_for_level(L+1)` / `_tile_for_level(1)`，要改成 `_tile_for_level("water", ...)`（下雨只加水）。同步更新 `add_water` 内所有调用。

- [ ] **Step 4: 泛化 _step_tile 的流动**

把 `_step_tile` 改成液种感知（重力下流 + 同种部分填充 + 横向往同种低位均衡；异种相邻**不**互相填充——留给 Task 6 反应）。完整替换 `_step_tile`：
```gdscript
func _step_tile(cm, x: int, y: int) -> void:
	var tid: int = cm.get_tile(x, y)
	var kind: String = _liquid_kind(tid)
	if kind == "":
		return
	var L: int = _level_of(tid)
	# 重力: 看下方
	var below_tid: int = cm.get_tile(x, y + 1)
	if below_tid == Tiles.AIR:
		world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, L))
		world._set_water_tile_fast(x, y, Tiles.AIR)
		notify_tile_changed(x, y + 1)
		return
	# 下方同种且没满 → 往下转
	if _liquid_kind(below_tid) == kind:
		var below_L: int = _level_of(below_tid)
		if below_L < 4:
			var xfer: int = mini(L, 4 - below_L)
			world._set_water_tile_fast(x, y + 1, _tile_for_level(kind, below_L + xfer))
			var new_L: int = L - xfer
			if new_L > 0:
				world._set_water_tile_fast(x, y, _tile_for_level(kind, new_L))
				mark_dirty(x, y)
			else:
				world._set_water_tile_fast(x, y, Tiles.AIR)
			notify_tile_changed(x, y + 1)
			return
	# 下方堵 (实心/异种/同种已满) → 横向均衡 (L>=2 才溢)
	if L < 2:
		return
	var lx_tid: int = cm.get_tile(x - 1, y)
	var rx_tid: int = cm.get_tile(x + 1, y)
	var candidates: Array = []
	# 只往 AIR 或同种且更低的邻居流
	for nx_tid in [[x - 1, lx_tid], [x + 1, rx_tid]]:
		var nx: int = nx_tid[0]
		var nt: int = nx_tid[1]
		if nt == Tiles.AIR:
			candidates.append([nx, 0])
		elif _liquid_kind(nt) == kind and _level_of(nt) < L:
			candidates.append([nx, _level_of(nt)])
	if candidates.is_empty():
		return
	candidates.sort_custom(func(a, b): return a[1] < b[1])
	var target: Array = candidates[0]
	var tx: int = int(target[0])
	var tL: int = int(target[1])
	world._set_water_tile_fast(tx, y, _tile_for_level(kind, tL + 1))
	var nl: int = L - 1
	if nl > 0:
		world._set_water_tile_fast(x, y, _tile_for_level(kind, nl))
		mark_dirty(x, y)
	else:
		world._set_water_tile_fast(x, y, Tiles.AIR)
	notify_tile_changed(tx, y)
```

- [ ] **Step 5: 跑测试看它通过** — `test_lava_falls_down` + 既有水测试（若有）PASS。再加一条横向铺平测试确认岩浆会摊开：
```gdscript
func test_lava_spreads_sideways() -> void:
	var fw = FakeWorld.new()
	# 满岩浆在 (0,0), 下面石头 (0,1), 两侧 (±1,0) 空气, 两侧下方石头
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(0,1)] = Tiles.STONE
	fw.tiles[Vector2i(-1,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 10:
		sim._run_tick()
	# 岩浆该向某一侧溢出 (至少一侧出现岩浆深浅)
	var left = _liquid_kind_of(fw, -1, 0)
	var right = _liquid_kind_of(fw, 1, 0)
	assert_true(left == "lava" or right == "lava", "岩浆该横向摊开")

func _liquid_kind_of(fw, x, y) -> String:
	var t = fw.tiles.get(Vector2i(x,y), Tiles.AIR)
	if t == Tiles.LAVA or t == Tiles.LAVA_L1 or t == Tiles.LAVA_L2 or t == Tiles.LAVA_L3:
		return "lava"
	return ""
```

- [ ] **Step 6: 提交**

```bash
git commit scripts/world/water_sim.gd tests/integration/test_liquid_flow.gd -m "feat(liquid): water_sim 泛化, 岩浆会流 (重力+铺平+体积守恒)"
git show HEAD --stat
```

---

## Task 5: 岩浆慢速（每 3 tick 流一步）

**Files:**
- Modify: `scripts/world/water_sim.gd`
- Test: `tests/integration/test_liquid_flow.gd`

- [ ] **Step 1: 写失败测试** — 追加：

```gdscript
func test_lava_slower_than_water() -> void:
	var fw = FakeWorld.new()
	# 水在 (0,0), 岩浆在 (5,0), 各自下方空气
	fw.tiles[Vector2i(0,0)] = Tiles.WATER
	fw.tiles[Vector2i(5,0)] = Tiles.LAVA
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	sim.notify_tile_changed(5, 0)
	# 只跑 1 个 tick: 水该已下落, 岩浆还没 (cadence)
	sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0,1), Tiles.AIR), Tiles.WATER, "水 1 tick 就下落")
	assert_eq(fw.tiles.get(Vector2i(5,1), Tiles.AIR), Tiles.AIR, "岩浆 1 tick 还没动 (慢)")
	assert_eq(fw.tiles.get(Vector2i(5,0), Tiles.AIR), Tiles.LAVA, "岩浆还在原位")
```

- [ ] **Step 2: 跑测试看它失败** — Expected: FAIL（岩浆和水一样快，第 1 tick 就落了）。

- [ ] **Step 3: 加 cadence**

在 `water_sim.gd` 加常量 + tick 计数：
```gdscript
const LAVA_TICK_DIVISOR := 3   # 岩浆每 3 个 tick 才流一步 (≈ 0.36s, 慢吞吞)
var _tick_n: int = 0
```
在 `_run_tick()` 开头加 `_tick_n += 1`（在取 `working` 之前）。
在 `_step_tile` 开头（取得 `kind` 之后、流动之前）加：
```gdscript
	# 岩浆慢: 非其 tick → 推迟 (重新标 dirty 保活), 本 tick 不流
	if kind == "lava" and _tick_n % LAVA_TICK_DIVISOR != 0:
		mark_dirty(x, y)
		return
```
（注意: `mark_dirty` 会把它放回下个 tick 的 working; `_run_tick` 里 `_dirty.clear()` 在取 working 之后, 所以本 tick 标的 dirty 会留到下个 tick。确认顺序无误。）

- [ ] **Step 4: 跑测试看它通过** — `test_lava_slower_than_water` PASS（注意 `_run_tick` 第一次调用 `_tick_n` 变 1，`1 % 3 != 0` → 岩浆跳过；水正常流）。其余测试里岩浆相关的若依赖步数，确认仍在所给循环次数内能完成（Task 4 的岩浆测试用了 5-10 tick，足够跨过 cadence）。

- [ ] **Step 5: 提交**

```bash
git commit scripts/world/water_sim.gd tests/integration/test_liquid_flow.gd -m "feat(liquid): 岩浆慢速 (每 3 tick 流一步)"
git show HEAD --stat
```

---

## Task 6: 水 + 岩浆 = 石头（+ 冒烟）

**Files:**
- Modify: `scripts/world/water_sim.gd`
- Modify: `scripts/fx/effects.gd`
- Test: `tests/integration/test_liquid_flow.gd`

- [ ] **Step 1: 写失败测试** — 追加：

```gdscript
func test_water_lava_makes_stone() -> void:
	var fw = FakeWorld.new()
	# 岩浆 (0,0) 紧挨水 (1,0)
	fw.tiles[Vector2i(0,0)] = Tiles.LAVA
	fw.tiles[Vector2i(1,0)] = Tiles.WATER
	# 下方都堵住 (防下落, 专测反应)
	fw.tiles[Vector2i(0,1)] = Tiles.STONE
	fw.tiles[Vector2i(1,1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	sim.notify_tile_changed(1, 0)
	for i in 6:
		sim._run_tick()
	# 岩浆格应变成石头
	assert_eq(fw.tiles.get(Vector2i(0,0)), Tiles.STONE, "岩浆碰水变石头")
	# 水被消耗 (降级或变空)
	var w = fw.tiles.get(Vector2i(1,0), Tiles.AIR)
	assert_true(w != Tiles.WATER, "水该被消耗一级")
```

- [ ] **Step 2: 跑测试看它失败** — Expected: FAIL（无反应，岩浆仍是 LAVA）。

- [ ] **Step 3: effects 加冒烟**

在 `scripts/fx/effects.gd` 加（仿 `spawn_jump_dust`，复用 dust 池，几颗向上的小烟）：
```gdscript
func spawn_steam_puff(world_pos: Vector2) -> void:
	var pool: Node = get_tree().get_first_node_in_group("dust_pool")
	for i in 5:
		var pos: Vector2 = world_pos + Vector2(randf_range(-4, 4), randf_range(-3, 1))
		var scl: float = randf_range(0.8, 1.2)
		if pool != null and pool.request_dust(pos, scl):
			continue
		var d = DustParticleScene.instantiate()
		_root().add_child(d)
		d.setup(pos, scl)
```
（注: 复用现有 dust 粒子, 是灰扑扑的小烟; 颜色染白是可选润色, 不在本 task 范围。`DustParticleScene` / `_root()` 文件里已有。）

- [ ] **Step 4: water_sim 加反应**

在 `_step_tile` 里，取得 `kind` 之后、cadence 判定**之前**（反应不受慢速限制，要灵敏），插入反应检查：
```gdscript
	# 水 / 岩浆相邻 → 岩浆变石头, 水消耗一级 (经典 Terraria 风)
	if _react_water_lava(cm, x, y, kind):
		return
```
加方法：
```gdscript
# 返回 true 表示本格已因反应被处理 (不再流动)
func _react_water_lava(cm, x: int, y: int, kind: String) -> bool:
	var neighbors := [Vector2i(x-1,y), Vector2i(x+1,y), Vector2i(x,y-1), Vector2i(x,y+1)]
	if kind == "lava":
		for n in neighbors:
			if _liquid_kind(cm.get_tile(n.x, n.y)) == "water":
				# 本格岩浆 → 石头; 那格水降一级
				world._set_water_tile_fast(x, y, Tiles.STONE)
				_reduce_liquid(cm, n.x, n.y)
				Effects.spawn_steam_puff(Vector2((x + 0.5) * 12.0, (y + 0.5) * 12.0))
				notify_tile_changed(x, y)
				notify_tile_changed(n.x, n.y)
				return true
	elif kind == "water":
		for n in neighbors:
			if _liquid_kind(cm.get_tile(n.x, n.y)) == "lava":
				# 那格岩浆 → 石头; 本格水降一级
				world._set_water_tile_fast(n.x, n.y, Tiles.STONE)
				_reduce_liquid(cm, x, y)
				Effects.spawn_steam_puff(Vector2((n.x + 0.5) * 12.0, (n.y + 0.5) * 12.0))
				notify_tile_changed(n.x, n.y)
				notify_tile_changed(x, y)
				return true
	return false

# 把 (x,y) 的水降一级 (L1 → AIR)
func _reduce_liquid(cm, x: int, y: int) -> void:
	var L: int = _level_of(cm.get_tile(x, y))
	var nl: int = L - 1
	world._set_water_tile_fast(x, y, _tile_for_level("water", nl))
```
（TILE_SIZE=12; 世界坐标 = (tile+0.5)*12 取格中心。若 water_sim 已有 TILE_SIZE 常量则用它。`Effects` 是 autoload。）

- [ ] **Step 5: 跑测试看它通过** — `test_water_lava_makes_stone` + 所有早先测试 PASS。

- [ ] **Step 6: 整体导入确认** — `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|water_sim|effects"`（无输出）。

- [ ] **Step 7: 提交**

```bash
git commit scripts/world/water_sim.gd scripts/fx/effects.gd tests/integration/test_liquid_flow.gd -m "feat(liquid): 水+岩浆=石头 + 冒烟"
git show HEAD --stat
```

---

## Task 7: 全量验收

- [ ] **Step 1: 跑整个流体测试文件** — 全部 PASS（约 6 个测试）：
`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gselect=test_liquid_flow.gd -gexit 2>&1 | grep -v libfontconfig`

- [ ] **Step 2: 整体导入无回归** — `godot --headless --editor --quit 2>&1 | grep -v libfontconfig | grep -iE "SCRIPT ERROR|Parse Error"`（无输出）。

- [ ] **Step 3: 跑既有 world / 存档测试确认体积守恒类逻辑没碰坏**（water_sim 被改）：
`godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gprefix=test_ -gexit 2>&1 | grep -v libfontconfig | grep -iE "Totals|Failing"` — 失败数不应比基线（环境性 save/combat/eat 等）更多。

- [ ] **Step 4: 给用户的手动验收清单（网页版重导出后）**
  - 挖开岩浆池旁边 → 岩浆慢慢流出、越流越薄
  - 往岩浆倒水（或水流到岩浆边）→ 岩浆"哧"地变石头 + 冒烟
  - 站在流动的浅岩浆上 → 照样烫掉血

---

## Self-Review 记录
- **Spec 覆盖**: 慢岩浆(T5)、水+岩浆=石头(T6)、岩浆深浅(T1美术T2注册T3)、烫伤含深浅(T1)、冒烟(T6)、性能(沿用 MAX_TILES_PER_TICK/batch, 未改)、体积守恒(T4 同水逻辑)。全覆盖。
- **类型一致**: `_tile_for_level(kind, L)` 全程带 kind；`_liquid_kind` 返回 "water"/"lava"/""；`_level_of` 统一认两种。`add_water` 调用已更新带 "water"。
- **Placeholder**: 每步给完整代码；"读 X 照抄"处都附了并行示例(get_water_level_atlas / LAVA _DATA 条目)与字段说明，非空泛。
- **风险**: 美术管线(T2)最不确定——已要求实现者先读 get_water_level_atlas 真实实现再镜像, 并用 block_textures 非空断言兜底验证。
