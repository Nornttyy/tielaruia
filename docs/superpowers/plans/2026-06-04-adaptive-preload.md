# 自适应预加载 实现计划

> **For agentic workers:** TDD 逐 task。每个 task 一 commit，先写失败测试→实现→过→commit。

**Goal:** 开局加载界面测设备速度 → 按速度+平台+核数定预加载半径 → 分帧把出生点周围一大片先生成好，逛着基本不卡。

**Architecture:** 半径从写死 const 改成 `chunk_manager.view_radius` 实例变量。测速+设半径+大预载**只在异步加载界面路径(真实新游戏)**做；`boot_to_game`(测试/dev 同步路径)保持默认半径 2 → 测试照常快。

**Tech Stack:** Godot 4.3 / GDScript / GUT。设计见 `docs/superpowers/specs/2026-06-04-adaptive-preload-design.md`。

**关键约定:** 默认 view_radius=2 不变(向后兼容); 改 chunk 加载核心 → 每步全量回归 + 冒烟。commit 用精确 `git add <paths>`,禁 `-am`。[[feedback-no-am-in-subagent]]

---

### Task 1: LoadPlanner.plan_view_radius (纯函数)

**Files:**
- Create: `scripts/world/load_planner.gd`
- Test: `tests/unit/test_load_planner.gd`

- [ ] **Step 1: 写失败测试** `tests/unit/test_load_planner.gd`
```gdscript
extends GutTest
const LoadPlanner = preload("res://scripts/world/load_planner.gd")

func test_fast_machine_big_radius():
	# 2ms/chunk 很快 → 半径接近桌面上限 16
	var r := LoadPlanner.plan_view_radius(2.0, false, 4)
	assert_eq(r, LoadPlanner.MAX_RADIUS_DESKTOP, "快桌面机吃满上限")

func test_slow_machine_min_radius():
	# 400ms/chunk 很慢 → 半径到下限
	assert_eq(LoadPlanner.plan_view_radius(400.0, false, 4), LoadPlanner.MIN_RADIUS, "慢机回到最小")

func test_web_capped():
	# 网页就算快也封顶
	var r := LoadPlanner.plan_view_radius(2.0, true, 8)
	assert_lte(r, LoadPlanner.MAX_RADIUS_WEB, "网页 ≤ web 上限")
	assert_gte(r, LoadPlanner.MIN_RADIUS)

func test_bad_input_safe():
	# per=0/负不崩, 结果仍在范围
	var r := LoadPlanner.plan_view_radius(0.0, false, 1)
	assert_between(r, LoadPlanner.MIN_RADIUS, LoadPlanner.MAX_RADIUS_DESKTOP, "0 输入安全")
	var r2 := LoadPlanner.plan_view_radius(-5.0, false, 1)
	assert_between(r2, LoadPlanner.MIN_RADIUS, LoadPlanner.MAX_RADIUS_DESKTOP)
```

- [ ] **Step 2: 跑确认失败** — `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_load_planner.gd -gexit`,红(文件不存在)。

- [ ] **Step 3: 实现** `scripts/world/load_planner.gd`
```gdscript
# 按设备测速结果算"预加载半径"(出生点两边各几个 chunk). 纯函数, 不碰引擎状态.
extends RefCounted

const TARGET_PRELOAD_MS := 2000.0   # 开局愿意花在预生成的预算 (~2s)
const MIN_RADIUS := 2
const MAX_RADIUS_WEB := 5            # 网页保守 (内存 + 单线程)
const MAX_RADIUS_DESKTOP := 16

static func plan_view_radius(per_chunk_ms: float, is_web: bool, cores: int) -> int:
	var per: float = max(per_chunk_ms, 0.5)        # 防 0/负
	var budget_chunks: float = TARGET_PRELOAD_MS / per
	var radius: int = int(budget_chunks / 2.0)     # 两边分
	if cores >= 8:
		radius += 2                                # 多核略加成
	var cap: int = MAX_RADIUS_WEB if is_web else MAX_RADIUS_DESKTOP
	return clampi(radius, MIN_RADIUS, cap)
```

- [ ] **Step 4: 跑确认过** — 4/4 绿。

- [ ] **Step 5: commit**
```bash
git add scripts/world/load_planner.gd tests/unit/test_load_planner.gd
git commit -m "feat(preload): LoadPlanner.plan_view_radius 按测速/平台/核数算预载半径 (自适应预载第1步)"
```

---

### Task 2: chunk_manager 半径实例化 + load_one + preload_around + loaded_count

**Files:**
- Modify: `scripts/world/chunk_manager.gd`
- Test: `tests/integration/test_chunk_preload.gd`

- [ ] **Step 1: 写失败测试** `tests/integration/test_chunk_preload.gd`
```gdscript
# chunk_manager: view_radius 实例变量 + preload_around 一次生成一大片 + loaded_count.
extends GutTest

const ChunkManager = preload("res://scripts/world/chunk_manager.gd")

func _make_cm() -> Node:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.setup(12345)   # 跟现有 setup(seed) 一致; 若签名不同, 读 chunk_manager 调整
	return cm

func test_default_radius_loads_5():
	var cm = _make_cm()
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_count(), 5, "默认 view_radius=2 → ±2 = 5 个 chunk")

func test_bigger_radius_loads_more():
	var cm = _make_cm()
	cm.view_radius = 4
	cm.ensure_loaded(0)
	assert_eq(cm.loaded_count(), 9, "view_radius=4 → ±4 = 9 个")

func test_preload_around_generates_span():
	var cm = _make_cm()
	cm.preload_around(0, 6)
	assert_eq(cm.loaded_count(), 13, "preload_around(0,6) → ±6 = 13 个")
	assert_true(cm.is_loaded(0), "出生点 chunk 在")
```

- [ ] **Step 2: 跑确认失败** — 红(loaded_count / preload_around / view_radius 不存在)。

- [ ] **Step 3: 实现** `scripts/world/chunk_manager.gd`
  在成员区加: `var view_radius: int = ChunkConstants.VIEW_RADIUS`
  `ensure_loaded` 把 `var radius: int = ChunkConstants.VIEW_RADIUS` 改成 `var radius: int = view_radius`。
  加方法(用现有 `_load_chunk` / `_loaded` 字典):
```gdscript
func loaded_count() -> int:
	return _loaded.size()

func is_loaded(cx: int) -> bool:
	return _loaded.has(cx)

# 生成单个 chunk (没载过才生成). 加载界面分帧预载用.
func load_one(cx: int) -> void:
	if not _loaded.has(cx):
		_load_chunk(cx)

# 一次生成 center ± radius 的全部 chunk (同步, 测试 + 同步预载用; 分帧版在加载界面循环 load_one).
func preload_around(center_cx: int, radius: int) -> void:
	for cx in range(center_cx - radius, center_cx + radius + 1):
		load_one(cx)
```
  注: 若 `setup` 签名/`_loaded` 名不同, 读 chunk_manager 现有代码对齐(别假设)。

- [ ] **Step 4: 跑确认过** — 3/3 绿。

- [ ] **Step 5: 回归** — `-gselect=test_chunk` 跑所有 chunk 相关 + `-gselect=test_smoke`, 确认没改坏现有加载。

- [ ] **Step 6: commit**
```bash
git add scripts/world/chunk_manager.gd tests/integration/test_chunk_preload.gd
git commit -m "feat(preload): chunk_manager view_radius 实例化 + load_one/preload_around/loaded_count (自适应预载第2步)"
```

---

### Task 3: 加载界面测速 → 设半径 → 分帧大预载 (异步路径 only)

**Files:**
- Modify: `scripts/main.gd`（`_run_async_load` 加测速+预载阶段）
- Modify: `scripts/world/world.gd`（`_check_chunk_load` 的 unload 用 `chunk_manager.view_radius`）
- Test: `tests/integration/test_adaptive_preload_boot.gd`（验同步路径不受影响 + 默认半径）

- [ ] **Step 1: 写失败测试** `tests/integration/test_adaptive_preload_boot.gd`
```gdscript
# 同步路径 (boot_to_game/测试) 不测速、保持默认半径 2 → 不会拖慢/多载.
extends GutTest
const MainScene = preload("res://scenes/main.tscn")

func test_sync_boot_keeps_default_radius():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(10)
	var world = main.get_node("World")
	assert_eq(world.chunk_manager.view_radius, 2, "同步路径不动半径, 保持默认 2 (测试快)")
```

- [ ] **Step 2: 跑确认** — 先跑, 现在应该已经过(默认 2)。这步是"护栏测试"防 Task 3 改动误把同步路径也调大。**若它红了说明实现把同步路径也改了, 必须修。**

- [ ] **Step 3: 实现 world.gd unload 用实例半径** — 把 `_check_chunk_load` 里
  `chunk_manager.unload_far_from(pcx, ChunkConstants.VIEW_RADIUS + 1)` 改成
  `chunk_manager.unload_far_from(pcx, chunk_manager.view_radius + 1)`。

- [ ] **Step 4: 实现 main.gd 测速+预载阶段** — `_run_async_load` 里, init steps 之后、淡出之前, 加:
```gdscript
	# 自适应预载: 测设备速度 → 定半径 → 分帧把出生点一大片先生成好
	loading.set_progress(0.80, "正在测速...")
	var cm = w.chunk_manager
	var t0: int = Time.get_ticks_msec()
	# 基准: 生成出生点两侧 8 个新 chunk (这些也是真要预载的, 不浪费)
	for bcx in [3, 4, 5, 6, -3, -4, -5, -6]:
		cm.load_one(bcx)
	var per: float = float(Time.get_ticks_msec() - t0) / 8.0
	cm.view_radius = LoadPlanner.plan_view_radius(per, OS.has_feature("web"), OS.get_processor_count())
	# 分帧预载 ±view_radius (跳过已载的)
	var r: int = cm.view_radius
	var total: int = 2 * r + 1
	var done: int = 0
	for cx in range(-r, r + 1):
		cm.load_one(cx)
		done += 1
		if done % 3 == 0:
			loading.set_progress(0.80 + 0.15 * float(done) / float(total), "正在预生成世界 (%d/%d)..." % [done, total])
			await get_tree().process_frame
```
  在 main.gd 顶部加 `const LoadPlanner = preload("res://scripts/world/load_planner.gd")`。
  注: 读 `_run_async_load` 现有结构(我之前见过: Step F 90% 之后), 把这段插在 HUD 之后、`loading.finish_and_fade()` 之前, 进度数对齐现有 0.80→0.90 段。

- [ ] **Step 5: 跑护栏测试 + 冒烟** — `test_adaptive_preload_boot`(同步仍 2) + `test_smoke`(异步? 不, smoke 用 boot_to_game 同步; 异步预载 smoke 测不到, 靠不崩 + 手动)。两者绿。

- [ ] **Step 6: commit**
```bash
git add scripts/main.gd scripts/world/world.gd tests/integration/test_adaptive_preload_boot.gd
git commit -m "feat(preload): 加载界面测速→定半径→分帧大预载 (异步路径); unload 用实例半径 (自适应预载第3步)"
```

---

### Task 4: 验收 + 上线

- [ ] **Step 1: 全量 x2** — `godot --headless -s addons/gut/gut_cmdln.gd -gexit`, 0 failing, 跑两遍防 flaky(尤其 chunk/save/世界相关)。
- [ ] **Step 2: 冒烟** — `test_smoke` 3/3。
- [ ] **Step 3: 报告** — 大白话 1-3 行 + 累计测试数 ([[feedback-simple-language]])。
- [ ] **Step 4: 合并 origin/main + 推送** — fetch; merge-tree 查冲突; merge; 合并后再全量; `git push origin sky-island:main` ([[reference-github-push]])。
- [ ] **Step 5: 报告上线** — 3-5 分钟网页生效。提醒用户: 网页版半径会自动保守, 桌面会大很多。

---

## Self-Review
- **Spec 覆盖**: LoadPlanner(T1) / view_radius+preload(T2) / 测速+大预载 wiring(T3) / 验收(T4) 对齐 spec 四组件 ✓
- **类型一致**: `view_radius`、`plan_view_radius`、`load_one`、`preload_around`、`loaded_count`、`is_loaded` 全程同名 ✓
- **测试快**: 测速+大预载只在异步路径; 同步路径(所有 boot_to_game 测试)保持半径 2 → 不拖慢测试。T3 Step1 护栏测试守这条 ✓
- **风险**: 默认半径不变(回退安全); 改核心配全量 x2 + 冒烟; 不碰世界内容(联机安全) ✓
- **占位符**: 无 TBD; "读现有 setup/_loaded 名对齐"是合理的防假设指引(实现时核对), 非占位 ✓
