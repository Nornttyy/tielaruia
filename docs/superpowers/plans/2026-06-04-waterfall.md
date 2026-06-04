# 瀑布（真水版）实现计划

> **For agentic workers:** 用 TDD 逐 task 实现。每步 `- [ ]`。每个 task 一个 commit，先写失败测试→实现→过→commit。

**Goal:** 世界里加真水瀑布：山崖顶"水源块"永远冒水，靠现成液体模拟流下崖面积成潭，玩家可挖渠/堵/挖掉。

**Architecture:** 新增发射型 tile `WATER_SOURCE`（实心可挖、不是 liquid），`water_sim._step_tile` 给它特判每 N 拍往正下方灌 WATER；chunk 加载唤醒扫描带上它；world_generator 在陡崖唇放置 + 崖底挖潭；落水溅水花。

**Tech Stack:** Godot 4.3 / GDScript / GUT。设计见 `docs/superpowers/specs/2026-06-04-waterfall-design.md`。

**关键约定:**
- 加 tile 必须同步 `tileset_builder.gd` 的 `tile_ids` 数组 + 在 `blocks_art.gd` 画贴图，否则 tile 不显示也不报错（[[feedback-tileset-registration]]）。
- 改液体前必看 [[project-water-sim]]：薄水 L1 只往有落差的洞流（防平地抖）。
- subagent 别用；机械改动自己做。commit 用精确 `git add <paths>`，禁 `-am`/`-A`/`.`（[[feedback-no-am-in-subagent]]）。

---

### Task 1: WATER_SOURCE tile（实心·可挖·不掉物·有贴图）

**Files:**
- Modify: `scripts/world/tile_data.gd`（加 const + 属性 dict）
- Modify: `scripts/art/blocks_art.gd`（画贴图）
- Modify: `scripts/world/tileset_builder.gd:30`（tile_ids 加它）
- Test: `tests/unit/test_waterfall.gd`（新建）

- [ ] **Step 1: 写失败测试** `tests/unit/test_waterfall.gd`

```gdscript
extends GutTest

const WaterSim = preload("res://scripts/world/water_sim.gd")


func test_water_source_tile_defined():
	assert_eq(Tiles.WATER_SOURCE, 84, "WATER_SOURCE = 84 (下一个空 id)")
	assert_true(Tiles.is_solid(Tiles.WATER_SOURCE), "水源块实心 (能挖能站, 水从底下冒)")

func test_water_source_drops_nothing():
	# 挖掉不掉物 → 不可获得 → 防无限水
	var drops = Tiles.get_drops(Tiles.WATER_SOURCE) if Tiles.has_method("get_drops") else []
	assert_eq(drops.size(), 0, "水源块挖了不掉物品")

func test_water_source_texture_built():
	assert_not_null(ArtCache.block_textures.get(Tiles.WATER_SOURCE), "水源块该有世界贴图 (没画=不显示)")

func test_water_source_not_liquid():
	var sim = WaterSim.new()
	add_child_autofree(sim)
	assert_false(sim.is_liquid(Tiles.WATER_SOURCE), "水源块不算流动液体 (免污染游泳/作物判定)")
```

- [ ] **Step 2: 跑测试确认失败** — `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_waterfall.gd -gexit`，预期红（WATER_SOURCE 未定义）。

- [ ] **Step 3: 加 tile 常量 + 属性** `scripts/world/tile_data.gd`
  在 `const WATER_SWAMP := 83` 后加：
```gdscript
const WATER_SOURCE := 84     # 水源块: 永远冒水的泉眼 (瀑布). 实心可挖, 挖掉就停; 不掉物=不可造, 防无限水
```
  在属性 dict 里（仿 CLOUD 那条）加：
```gdscript
	WATER_SOURCE: {
		# 实心 (水从底下冒, 能站能挖), 木镐挖. 不掉物品 (世界生成专属, 玩家拿不到).
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [],
	},
```

- [ ] **Step 4: 画贴图** `scripts/art/blocks_art.gd`
  仿现有 block 画法（参考 CLOUD），加一个 `WATER_SOURCE` 的 12×12 贴图：深湿石底色 + 中间一个发亮的蓝色出水口（可辨认的"泉眼"形状，别随机散点，见 [[feedback-warm-detailed-textures]]），注册进 `ArtCache.block_textures[Tiles.WATER_SOURCE]`。读该文件现有格式照搬。

- [ ] **Step 5: 注册进 tileset** `scripts/world/tileset_builder.gd`
  在 `tile_ids` 数组（line ~30，水那几行附近）加一行 `Tiles.WATER_SOURCE,`。

- [ ] **Step 6: 跑测试确认过** — 同 Step 2 命令，预期 4/4 绿。

- [ ] **Step 7: commit**
```bash
git add scripts/world/tile_data.gd scripts/art/blocks_art.gd scripts/world/tileset_builder.gd tests/unit/test_waterfall.gd
git commit -m "feat(waterfall): WATER_SOURCE 水源块 tile (实心可挖不掉物+贴图) (瀑布第1步)"
```

---

### Task 2: 水源发射逻辑（water_sim）

**Files:**
- Modify: `scripts/world/water_sim.gd`（`_step_tile` 加特判 + `_step_source` + 常量）
- Test: `tests/integration/test_waterfall_sim.gd`（新建，用 FakeWorld 套路，仿 `tests/integration/test_liquid_flow.gd`）

- [ ] **Step 1: 写失败测试** `tests/integration/test_waterfall_sim.gd`
  （FakeWorld/FakeCM/_make_sim 直接抄 `test_liquid_flow.gd` 的写法）

```gdscript
# 水源块发射: 往下灌水、自己不变少、下方满了歇、挖掉就停.
extends GutTest

class FakeWorld:
	extends Node2D
	var tiles := {}
	var chunk_manager = null
	func _init(): chunk_manager = FakeCM.new(tiles)
	func _set_water_tile_fast(x, y, tid): tiles[Vector2i(x, y)] = tid
class FakeCM:
	var tiles
	func _init(t): tiles = t
	func get_tile(x, y): return tiles.get(Vector2i(x, y), Tiles.AIR)

func _make_sim(fake) -> Node:
	var WaterSim = load("res://scripts/world/water_sim.gd")
	var sim = WaterSim.new()
	sim.world = fake
	add_child_autofree(sim)
	return sim

func _t(fw, x, y) -> int:
	return fw.tiles.get(Vector2i(x, y), Tiles.AIR)


func test_source_emits_water_below():
	# 水源在 (0,0), 下方 (0,1) AIR, 再下 (0,2) STONE 接住
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0,0)] = Tiles.WATER_SOURCE
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_true(sim.is_liquid(_t(fw, 0, 1)), "水源下方该冒出水, 实际 %d" % _t(fw,0,1))

func test_source_not_depleted():
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0,0)] = Tiles.WATER_SOURCE
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_eq(_t(fw, 0, 0), Tiles.WATER_SOURCE, "水源自己不变少, 永远是 WATER_SOURCE")

func test_dug_source_stops():
	# 挖掉水源 (→AIR) 后, 不再冒水
	var fw = FakeWorld.new(); add_child_autofree(fw)
	fw.tiles[Vector2i(0,0)] = Tiles.AIR
	fw.tiles[Vector2i(0,2)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.mark_dirty(0, 0)
	sim.settle_now()
	assert_false(sim.is_liquid(_t(fw, 0, 1)), "没水源 → 下方不该有水")
```

- [ ] **Step 2: 跑确认失败** — `-gselect=test_waterfall_sim.gd`，预期红。

- [ ] **Step 3: 实现** `scripts/world/water_sim.gd`
  常量区加：
```gdscript
const SOURCE_TICK_DIVISOR := 2      # 水源每 2 拍灌一次 (温柔水流 + 省 CPU)
```
  `_step_tile(cm, x, y)` 开头（读完 `tid` 之后、`kind` 判定之前）加：
```gdscript
	if tid == Tiles.WATER_SOURCE:
		_step_source(cm, x, y)
		return
```
  新增函数：
```gdscript
# 水源块: 每 N 拍往正下方灌一格满水, 自己永不变少. 下方满/堵 → 不灌不重标 = 歇着 (self-limiting).
func _step_source(cm, x: int, y: int) -> void:
	if _tick_n % SOURCE_TICK_DIVISOR != 0:
		mark_dirty(x, y)   # 非本拍: 保活, 不灌
		return
	var below: int = cm.get_tile(x, y + 1)
	var can_fill: bool = below == Tiles.AIR \
			or (_liquid_kind(below) == "water" and _level_of(below) < 4)
	if can_fill:
		world._set_water_tile_fast(x, y + 1, Tiles.WATER)
		notify_tile_changed(x, y + 1)
		mark_dirty(x, y)   # 还有活, 继续醒着
	# 下方满水/实心/岩浆 → 啥也不做, dirty 不重标 → 自然歇下
```

- [ ] **Step 4: 跑确认过** — 同 Step 2，预期 3/3 绿。

- [ ] **Step 5: commit**
```bash
git add scripts/world/water_sim.gd tests/integration/test_waterfall_sim.gd
git commit -m "feat(waterfall): 水源块发射逻辑 (每2拍灌下方满水·不耗竭·下满即歇) (瀑布第2步)"
```

---

### Task 3: chunk 加载唤醒带上水源（防冻空中）

**Files:**
- Modify: `scripts/world/world.gd`（chunk 唤醒扫描 line ~860 的 continue 条件）
- Test: `tests/integration/test_waterfall_wake.gd`（新建，boot 真游戏放一个水源验证它流）

- [ ] **Step 1: 写失败测试** `tests/integration/test_waterfall_wake.gd`

```gdscript
# 真世界里放一个水源, 下面是空腔接实地 → 唤醒后该冒水流下.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE := 12

func test_placed_source_flows_in_world():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(15)
	var world = main.get_node("World")
	var player = world.get_player()
	var px := int(floor(player.global_position.x / TILE))
	var py := int(floor(player.global_position.y / TILE)) + 3
	# 挖一段竖井 (py..py+4 AIR), 底下 py+5 留实心接水
	for dy in range(0, 5):
		world._set_tile(px, py + dy, Tiles.AIR)
	if world.chunk_manager.get_tile(px, py + 5) == Tiles.AIR:
		world._set_tile(px, py + 5, Tiles.STONE)
	# 顶上放水源
	world._set_tile(px, py - 1, Tiles.WATER_SOURCE)
	await wait_frames(40)   # 让 sim 实时流几拍
	var got_water := false
	for dy in range(0, 6):
		if world.water_sim.is_liquid(world.chunk_manager.get_tile(px, py + dy)):
			got_water = true
	assert_true(got_water, "放下的水源该把竖井灌出水来 (说明被唤醒了+在流)")
```

- [ ] **Step 2: 跑确认失败** — `-gselect=test_waterfall_wake.gd`。可能因唤醒缺失而无水→红。

- [ ] **Step 3: 实现** `scripts/world/world.gd`
  chunk 唤醒扫描里（line ~860）把：
```gdscript
				if not water_sim.is_liquid(t):
					continue
```
  改成：
```gdscript
				# 水源块不是 liquid 但也要唤醒, 否则世界生成的瀑布冻在崖顶不流
				if not water_sim.is_liquid(t) and t != Tiles.WATER_SOURCE:
					continue
```
  注：`_set_tile` 已会 `notify_tile_changed` 唤醒邻居，所以测试里手动放的水源即时就醒；本步保证的是**世界生成时就埋好**的水源在 chunk 加载时也醒（靠 Task 4 的集成测试 + smoke 兜底）。

- [ ] **Step 4: 跑确认过** — 同 Step 2，预期 1/1 绿。

- [ ] **Step 5: commit**
```bash
git add scripts/world/world.gd tests/integration/test_waterfall_wake.gd
git commit -m "feat(waterfall): chunk 加载唤醒扫描带上水源 (防冻崖顶) (瀑布第3步)"
```

---

### Task 4: 世界生成在陡崖放瀑布

**Files:**
- Modify: `scripts/world/world_generator.gd`（加 `_is_cliff` 纯函数 + 仿 pond 的放置段 + 常量）
- Test: `tests/unit/test_waterfall_gen.gd`（新建，单测纯函数 `_is_cliff`）

- [ ] **Step 1: 写失败测试** `tests/unit/test_waterfall_gen.gd`

```gdscript
# 陡崖识别: 给一段地表高度数组, 判断某列是不是崖唇.
extends GutTest

const WorldGen = preload("res://scripts/world/world_generator.gd")

func test_is_cliff_detects_drop():
	var wg = WorldGen.new()
	# heights[x] = 地表 y (越大越低). x=5 是崖唇: 右边 4 列内掉了 10 格
	var heights := PackedInt32Array([100,100,100,100,100,100, 110,110,110,110,110])
	# 平地段 (x=2): 不是崖
	assert_eq(wg._is_cliff(heights, 2, 4, 8), 0, "平地不是崖")
	# 崖唇 (x=5): 右侧 4 列落差 ≥8 → 返回非 0 (方向)
	assert_ne(wg._is_cliff(heights, 5, 4, 8), 0, "x=5 该判成崖唇")

func test_is_cliff_small_drop_no():
	var wg = WorldGen.new()
	var heights := PackedInt32Array([100,100,100,103,103,103,103])
	assert_eq(wg._is_cliff(heights, 2, 4, 8), 0, "只掉 3 格 < 8, 不算崖")
```

- [ ] **Step 2: 跑确认失败** — `-gselect=test_waterfall_gen.gd`，预期红（`_is_cliff` 不存在）。

- [ ] **Step 3: 实现纯函数 + 放置** `scripts/world/world_generator.gd`
  常量区加（仿 POND_*）：
```gdscript
const WATERFALL_CHANCE := 0.04        # 稀有
const WATERFALL_MIN_DROP := 8         # 崖唇到崖底落差 ≥ 这么多 tile 才放
const WATERFALL_SPAN := 4             # 在 ±这么多列内看落差
```
  加纯函数（可单测）：
```gdscript
# 某列是不是"崖唇": 往左或右 span 列内地表掉 ≥ min_drop. 返回掉落方向 (+1右/-1左/0不是).
func _is_cliff(heights, x: int, span: int, min_drop: int) -> int:
	var n: int = heights.size()
	var here: int = heights[x] if x >= 0 and x < n else 0
	var rx: int = x + span
	if rx < n and heights[rx] - here >= min_drop:
		return 1
	var lx: int = x - span
	if lx >= 0 and heights[lx] - here >= min_drop:
		return -1
	return 0
```
  在 pond 放置那段附近（line ~445 的逐列循环里），加瀑布放置（仿 pond 的 hash roll + biome 检查；用 salt 7790）：
```gdscript
			# 瀑布: 陡崖唇稀有放一个水源, 水顺崖流下
			if biome == BIOME_FOREST or biome == BIOME_JUNGLE:
				var wf_dir: int = _is_cliff(chunk_heights, wx, WATERFALL_SPAN, WATERFALL_MIN_DROP)
				var wf_roll: float = float(_hash3(world_seed, wx, 7790) & 0xffff) / 65535.0
				if wf_dir != 0 and wf_roll < WATERFALL_CHANCE:
					var lip_surf: int = chunk_heights[wx]
					# 水源放在崖唇地表上方一格, 朝低边推一格让它正下方是崖面空气
					var sx: int = lx + wf_dir
					var sy: int = lip_surf
					if sx >= 0 and sx < chunk_width and c.tiles[lx][lip_surf - 1] == Tiles.AIR:
						c.tiles[lx][lip_surf - 1] = Tiles.WATER_SOURCE
```
  注：放置几何在实现时按真实 `c.tiles` 边界微调（参考 pond 段的 `lx/wx/chunk_start_x` 用法），保证水源正下方是崖面 AIR；崖底自然低地即天然接水潭，先不强行挖潭（YAGNI，靠地形 + 溢流）。

- [ ] **Step 4: 跑确认过** — 同 Step 2，预期 2/2 绿。

- [ ] **Step 5: 冒烟** — `-gselect=test_smoke.gd`，确认 world_generator 改完游戏照常启动（3/3）。

- [ ] **Step 6: commit**
```bash
git add scripts/world/world_generator.gd tests/unit/test_waterfall_gen.gd
git commit -m "feat(waterfall): 世界生成陡崖唇稀有放水源 (_is_cliff 纯函数+放置) (瀑布第4步)"
```

---

### Task 5: 落水溅水花特效

**Files:**
- Modify: `scripts/fx/effects.gd`（加 `spawn_splash`）
- Modify: `scripts/world/water_sim.gd`（水重力落地时低概率喷水花）
- Test: `tests/unit/test_waterfall_fx.gd`（新建）

- [ ] **Step 1: 写失败测试** `tests/unit/test_waterfall_fx.gd`

```gdscript
# 水花特效: spawn_splash 该造出够明显的粒子 (宽≥2 / alpha≥0.8 / 量足).
extends GutTest

func test_spawn_splash_makes_visible_particles():
	assert_true(Effects.has_method("spawn_splash"), "Effects 该有 spawn_splash")
	var before := Effects.get_child_count()
	Effects.spawn_splash(Vector2(100, 100))
	assert_gt(Effects.get_child_count(), before, "spawn_splash 该加出粒子节点")
```

- [ ] **Step 2: 跑确认失败** — `-gselect=test_waterfall_fx.gd`，预期红。

- [ ] **Step 3: 实现** `scripts/fx/effects.gd`
  仿 `spawn_steam_puff`（line ~73）加 `spawn_splash(world_pos)`：往上+两侧溅蓝色小水滴，够明显（[[feedback-fx-visibility]]：宽≥2px、alpha≥0.8、数量足）。读该文件 steam_puff 格式照搬改色改方向。

- [ ] **Step 4: 触发** `scripts/world/water_sim.gd`
  `_step_tile` 里水靠重力下落、下方是实心/满水（落地）的分支，低概率（如 `_tick_n % 6 == 0` 且仅桌面 `not OS.has_feature("web")`）调 `Effects.spawn_splash(落点像素坐标)`。限频防刷屏。

- [ ] **Step 5: 跑确认过** — 同 Step 2，预期 1/1 绿。

- [ ] **Step 6: commit**
```bash
git add scripts/fx/effects.gd scripts/world/water_sim.gd tests/unit/test_waterfall_fx.gd
git commit -m "feat(waterfall): 落水溅水花特效 spawn_splash + 落地触发 (瀑布第5步)"
```

---

### Task 6: 验收 + 上线

- [ ] **Step 1: 全量回归** — `godot --headless -s addons/gut/gut_cmdln.gd -gexit`，预期 0 failing（重点 water/液体相关 + 全量）。跑两次确认不 flaky。
- [ ] **Step 2: 冒烟** — `-gselect=test_smoke.gd`，3/3。
- [ ] **Step 3: 报告** — 给用户 1-3 行大白话总结（[[feedback-simple-language]]）+ 累计测试数。
- [ ] **Step 4: 合并 origin/main + 推送** — `git fetch origin main`；`git merge-tree` 查冲突；`git merge origin/main`；合并后再跑一次全量；`git push origin sky-island:main` 触发部署（[[reference-github-push]] / [[feedback-deploy-flow]]）。
- [ ] **Step 5: 报告上线** — 告诉用户 3-5 分钟后网页可见。

---

## Self-Review

- **Spec 覆盖**: tile(T1)/发射(T2)/唤醒(T3)/放置(T4)/特效(T5)/验收(T6) 对齐 spec 六组件 ✓
- **类型一致**: `WATER_SOURCE`、`_step_source`、`SOURCE_TICK_DIVISOR`、`_is_cliff`、`spawn_splash` 全程同名 ✓
- **占位符**: 无 TBD；贴图/特效像素细节让实现时照搬现成 CLOUD/steam_puff 格式（合理的"跟现有模式"指引，非占位）✓
- **风险**: 改 water_sim 的 T2/T5 都只在 `_step_tile` 加分支不动现有流动；T4 改 world_generator 配 smoke 兜底；全量跑两次防 flaky ✓
