# Loading Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 玩家点 "进入" / "开始" 后, 显示有暮色背景 + 像素小人跑步 + 真实进度条 + 可点击切换的小贴士的加载层, 直到 world 与 HUD 全部就绪再淡出.

**Architecture:**
- `LoadingScreen` (CanvasLayer) 是一个独立的 UI 层, 复用 main_menu 的暮色视觉风格 + `PlayerArt.build_sprite_frames()` 的 walk 动画.
- `world.gd::_ready()` 拆成 4 个 `_step_*` 方法, 加 `defer_init: bool` 标志. 默认 false 时 `_ready` 自动跑完 (兼容 `boot_to_game` 测试入口). true 时由外部一个个调 step.
- `main.gd::_start_game()` 改 async: instantiate LoadingScreen → 一步一步调 `world.run_init_step(i)` + instantiate HUD/CraftingPanel/etc, 每步 `await get_tree().process_frame` 让 UI 渲染 + 进度条更新.

**Tech Stack:** Godot 4.3, GDScript, GUT 测试框架.

**Spec:** `docs/superpowers/specs/2026-05-26-loading-screen-design.md`

---

## File Structure

**Create:**
- `scenes/ui/loading_screen.tscn` — LoadingScreen 场景 (节点骨架, 视觉细节代码生成)
- `scripts/ui/loading_screen.gd` — LoadingScreen 逻辑
- `tests/unit/test_loading_screen.gd` — LoadingScreen 单元测试
- `tests/unit/test_world_init_steps.gd` — world.gd 拆 init step 后的测试

**Modify:**
- `scripts/world/world.gd` — `_ready` 拆步 + 加 `defer_init` + `run_init_step` API
- `scripts/main.gd` — `_start_game` 改 async, 走 LoadingScreen; `boot_to_game` 保留老同步路径

---

## 测试命令速查

跑单个测试文件:
```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/<path>/<file>.gd -gexit 2>&1 | tail -30
```

跑全套测试:
```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -50
```

若新加 class_name / 资源, 先建索引一次:
```bash
cd /workspace/teilaruia && godot --headless --path . --editor --quit 2>&1 | tail -5
```

---

### Task 1: world.gd 拆 init steps + defer_init

**Files:**
- Modify: `scripts/world/world.gd:74-144` (整个 `_ready`)
- Create: `tests/unit/test_world_init_steps.gd`

---

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_world_init_steps.gd`:

```gdscript
extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")


func _make_deferred() -> Node2D:
	var w: Node2D = WorldScene.instantiate()
	w.defer_init = true
	w.world_seed = 42
	add_child_autofree(w)
	return w


func test_deferred_world_has_no_chunk_manager_before_step():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.chunk_manager, null, "defer_init=true 时 _ready 不应自动建 chunk_manager")


func test_get_init_step_count_is_4():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.get_init_step_count(), 4, "world 应公开 4 个 init step")


func test_get_init_step_label_returns_chinese():
	var w = _make_deferred()
	await get_tree().process_frame
	assert_eq(w.get_init_step_label(0), "正在构建方块...")
	assert_eq(w.get_init_step_label(1), "正在生成地形...")
	assert_eq(w.get_init_step_label(2), "正在召唤天气...")
	assert_eq(w.get_init_step_label(3), "正在召唤玩家...")


func test_run_init_step_0_builds_tileset():
	var w = _make_deferred()
	await get_tree().process_frame
	w.run_init_step(0)
	assert_ne(w.terrain_layer.tile_set, null, "step 0 后 terrain_layer 应有 tile_set")
	assert_ne(w.wall_layer.tile_set, null, "step 0 后 wall_layer 应有 tile_set")


func test_run_init_step_1_builds_chunk_manager():
	var w = _make_deferred()
	await get_tree().process_frame
	w.run_init_step(0)
	w.run_init_step(1)
	assert_ne(w.chunk_manager, null, "step 1 后 chunk_manager 应已建好")


func test_run_init_step_3_spawns_player():
	var w = _make_deferred()
	await get_tree().process_frame
	for i in 4:
		w.run_init_step(i)
	await wait_frames(2)
	assert_ne(w.get_player(), null, "step 3 后 player 应已 spawn")


func test_default_ready_runs_all_steps_backwards_compat():
	# defer_init=false (default) → _ready 跑完所有 step
	var w: Node2D = WorldScene.instantiate()
	w.world_seed = 42
	add_child_autofree(w)
	await wait_frames(2)
	assert_ne(w.chunk_manager, null, "默认路径 chunk_manager 应自动建好")
	assert_ne(w.get_player(), null, "默认路径 player 应自动 spawn")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_init_steps.gd -gexit 2>&1 | tail -30
```

Expected: 多个 fail, 因为 `defer_init`, `get_init_step_count`, `get_init_step_label`, `run_init_step` 都还不存在.

- [ ] **Step 3: 改 world.gd 增加 defer_init 与拆 step**

Edit `scripts/world/world.gd`:

把 `@export var world_seed: int = 0` 那一行下方加:

```gdscript
@export var world_seed: int = 0   # 0 表示 _ready 内随机化
@export var defer_init: bool = false   # true 时 _ready 跳过自动初始化, 由外部调 run_init_step

const STEP_LABELS := [
	"正在构建方块...",
	"正在生成地形...",
	"正在召唤天气...",
	"正在召唤玩家...",
]
```

把现有 `func _ready()` (74-144 行) 整段替换为:

```gdscript
func _ready() -> void:
	# 这些 group 注册 + EffectsRoot 早期就要好 (被其他系统在 _ready 阶段 find).
	add_to_group("world")
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	# 火花对象池: 预分配 80 个 spark, 复用减 alloc
	var SparkPoolClass = preload("res://scripts/fx/spark_pool.gd")
	var sp = SparkPoolClass.new()
	sp.name = "SparkPool"
	$EffectsRoot.add_child(sp)
	if world_seed == 0:
		world_seed = randi()
	if defer_init:
		return
	# 默认: 顺序跑所有 step (兼容 boot_to_game / 直接 add_child World)
	for i in STEP_LABELS.size():
		run_init_step(i)


func get_init_step_count() -> int:
	return STEP_LABELS.size()


func get_init_step_label(idx: int) -> String:
	return STEP_LABELS[idx]


func run_init_step(idx: int) -> void:
	match idx:
		0: _step_build_tileset()
		1: _step_chunks()
		2: _step_fx_layers()
		3: _step_spawn_player()


func _step_build_tileset() -> void:
	var ts := TileSetBuilder.build()
	terrain_layer.tile_set = ts
	wall_layer.tile_set = ts  # 跟前景共享同一个 TileSet


func _step_chunks() -> void:
	chunk_manager = ChunkManagerClass.new()
	chunk_manager.name = "ChunkManager"
	add_child(chunk_manager)
	chunk_manager.setup(world_seed)
	chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
	chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
	# 初始加载中心 ±VIEW_RADIUS
	chunk_manager.ensure_loaded(0)


func _step_fx_layers() -> void:
	# 流水模拟: dirty 列表驱动, 接 chunk_manager + _set_tile
	water_sim = WaterSimClass.new()
	water_sim.name = "WaterSim"
	water_sim.world = self
	add_child(water_sim)
	minimap_data = MinimapDataClass.new()
	minimap_data.name = "MinimapData"
	add_child(minimap_data)
	# 注意顺序: rain_layer 先 add_child + 信号先 connect, 再 add_child(weather)
	# 不然 weather._ready 触发 weather_changed 时 rain_layer 还没接信号, 初始状态丢失
	rain_layer = RainLayerClass.new()
	rain_layer.name = "RainLayer"
	add_child(rain_layer)
	weather = WeatherClass.new()
	weather.name = "Weather"
	weather.weather_changed.connect(_on_weather_changed)
	weather.lightning_flash.connect(_on_lightning_flash)
	add_child(weather)
	# 夜晚气氛: 萤火虫 / 流星 / 树下飘叶子
	fireflies = FirefliesClass.new()
	fireflies.name = "Fireflies"
	add_child(fireflies)
	shooting_star = ShootingStarClass.new()
	shooting_star.name = "ShootingStar"
	add_child(shooting_star)
	falling_leaves = FallingLeavesClass.new()
	falling_leaves.name = "FallingLeaves"
	add_child(falling_leaves)
	# 图形开关: 把 GameSettings 应用到所有装饰节点
	_apply_graphics_settings.call_deferred()  # 让所有 child 先 _ready
	if not GameSettings.settings_changed.is_connected(_apply_graphics_settings):
		GameSettings.settings_changed.connect(_apply_graphics_settings)


func _step_spawn_player() -> void:
	# 找出生点 (chunk 0 内)
	spawn_point = _find_spawn_in_loaded()
	SkyLightGrid.recompute_from([])
	_spawn_player()
	# 鼠标光标管理: 默认箭头, 鼠标在敌人/方块上切换样式
	var cursor_mgr := CursorManagerClass.new()
	cursor_mgr.name = "CursorManager"
	add_child(cursor_mgr)
	# 联机: _ready 时已连上立刻接; 否则订阅 status_changed, 后续 host (游戏内) 也能触发
	if NetworkManager != null:
		if not NetworkManager.status_changed.is_connected(_on_mp_status_changed):
			NetworkManager.status_changed.connect(_on_mp_status_changed)
		if NetworkManager.connected():
			_setup_multiplayer_callbacks()
```

注意: SparkPool / 早期 group 注册依然在 `_ready` 头部 (defer_init 之前). 这些不会被多次跑, 没问题.

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_world_init_steps.gd -gexit 2>&1 | tail -30
```

Expected: 7 passed.

- [ ] **Step 5: 跑现有 main / save 测试确认不回归**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_main_state_machine.gd -gexit 2>&1 | tail -20
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_save_manager.gd -gexit 2>&1 | tail -20
```

Expected: 全部通过 (defer_init=false 默认路径行为不变).

- [ ] **Step 6: Commit**

```bash
cd /workspace/teilaruia && git add scripts/world/world.gd tests/unit/test_world_init_steps.gd && git commit -m "$(cat <<'EOF'
refactor(world): 拆 _ready 成 4 个 init step + defer_init 模式

为加载画面准备: 加载流程逐步调 run_init_step 推进进度条.
默认路径 (defer_init=false) 行为不变, 兼容 boot_to_game.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 2: LoadingScreen 骨架 + 场景文件

**Files:**
- Create: `scenes/ui/loading_screen.tscn`
- Create: `scripts/ui/loading_screen.gd`
- Create: `tests/unit/test_loading_screen.gd`

---

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_loading_screen.gd`:

```gdscript
extends GutTest

const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")


func _make() -> CanvasLayer:
	var ls: CanvasLayer = LoadingScreenScene.instantiate()
	add_child_autofree(ls)
	return ls


func test_instantiate_does_not_crash():
	var ls = _make()
	await get_tree().process_frame
	assert_not_null(ls)
	assert_true(ls.visible)


func test_layer_is_50():
	var ls = _make()
	await get_tree().process_frame
	assert_eq(ls.layer, 50, "LoadingScreen layer 应为 50 (在 world 与 HUD 之上)")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -15
```

Expected: 报错找不到 `res://scenes/ui/loading_screen.tscn`.

- [ ] **Step 3: 创建 scripts/ui/loading_screen.gd 骨架**

Create `scripts/ui/loading_screen.gd`:

```gdscript
# 加载层: 暮色背景 + 玩家像素小人跑步 + 真实进度条 + 可点击切换小贴士.
# 由 main.gd 在 _start_game 中 instantiate, 加载过程一步一步调 set_progress 推进.
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它


func _ready() -> void:
	pass
```

- [ ] **Step 4: 创建 scenes/ui/loading_screen.tscn**

Create `scenes/ui/loading_screen.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/ui/loading_screen.gd" id="1"]

[node name="LoadingScreen" type="CanvasLayer"]
layer = 50
script = ExtResource("1")
```

- [ ] **Step 5: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -15
```

Expected: 2 passed.

- [ ] **Step 6: Commit**

```bash
cd /workspace/teilaruia && git add scenes/ui/loading_screen.tscn scripts/ui/loading_screen.gd tests/unit/test_loading_screen.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): 骨架场景 + 脚本 + 测试

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 3: LoadingScreen 视觉 (sky / stars / player runner)

**Files:**
- Modify: `scripts/ui/loading_screen.gd`
- Modify: `tests/unit/test_loading_screen.gd` (追加测试)

---

- [ ] **Step 1: 追加测试**

Append to `tests/unit/test_loading_screen.gd`:

```gdscript
func test_setup_creates_sky_gradient():
	var ls = _make()
	await get_tree().process_frame
	var sky: ColorRect = ls.get_node_or_null("Sky")
	assert_not_null(sky, "Sky ColorRect 应存在")
	var grad: TextureRect = sky.get_node_or_null("SkyGradient")
	assert_not_null(grad, "SkyGradient TextureRect 应存在")
	assert_not_null(grad.texture, "SkyGradient 应有 GradientTexture2D")


func test_setup_creates_14_stars():
	var ls = _make()
	await get_tree().process_frame
	var stars_root: Control = ls.get_node_or_null("Stars")
	assert_not_null(stars_root, "Stars 容器应存在")
	assert_eq(stars_root.get_child_count(), 14, "应有 14 颗星")


func test_setup_creates_player_runner_playing_walk():
	var ls = _make()
	await get_tree().process_frame
	var runner: AnimatedSprite2D = ls.get_node_or_null("PlayerRunner")
	assert_not_null(runner, "PlayerRunner AnimatedSprite2D 应存在")
	assert_eq(runner.animation, "walk", "应播 walk 动画")
	assert_true(runner.is_playing(), "动画应在播")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -20
```

Expected: 3 个新测试 fail (Sky / Stars / PlayerRunner 不存在).

- [ ] **Step 3: 实现视觉**

Replace `scripts/ui/loading_screen.gd` with:

```gdscript
# 加载层: 暮色背景 + 玩家像素小人跑步 + 真实进度条 + 可点击切换小贴士.
# 由 main.gd 在 _start_game 中 instantiate, 加载过程一步一步调 set_progress 推进.
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它

const PlayerArt = preload("res://scripts/art/player_art.gd")
const VIEWPORT_SIZE := Vector2(1280, 720)


func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()


# 暮色渐变, 复用 main_menu 的色板
func _setup_sky() -> void:
	var sky := ColorRect.new()
	sky.name = "Sky"
	sky.anchor_right = 1.0
	sky.anchor_bottom = 1.0
	sky.color = Color8(80, 50, 90)   # 兜底色
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(80, 50, 90))           # 顶: 深紫红
	gradient.add_point(0.35, Color8(220, 110, 90))      # 暮色橙红
	gradient.add_point(0.65, Color8(255, 180, 110))     # 金橙
	gradient.set_color(gradient.get_point_count() - 1, Color8(255, 210, 150))  # 底: 暖肉粉
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.width = 64
	grad_tex.height = 256
	var tex_rect := TextureRect.new()
	tex_rect.name = "SkyGradient"
	tex_rect.texture = grad_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(tex_rect)


func _setup_stars() -> void:
	var stars := Control.new()
	stars.name = "Stars"
	stars.anchor_right = 1.0
	stars.anchor_bottom = 1.0
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stars)
	for i in 14:
		var s := ColorRect.new()
		s.color = Color(1, 1, 0.88, 0.7)
		s.size = Vector2(2, 2)
		var x: float = randf() * VIEWPORT_SIZE.x
		var y: float = randf_range(20.0, VIEWPORT_SIZE.y * 0.28)
		s.position = Vector2(x, y)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stars.add_child(s)
		var period: float = randf_range(1.2, 2.6)
		var min_a: float = randf_range(0.15, 0.45)
		var t := create_tween().set_loops()
		t.tween_property(s, "modulate:a", min_a, period).set_trans(Tween.TRANS_SINE)
		t.tween_property(s, "modulate:a", 1.0, period).set_trans(Tween.TRANS_SINE)


func _setup_player_runner() -> void:
	var runner := AnimatedSprite2D.new()
	runner.name = "PlayerRunner"
	runner.sprite_frames = PlayerArt.build_sprite_frames()
	runner.animation = "walk"
	runner.scale = Vector2(4.0, 4.0)
	runner.position = Vector2(VIEWPORT_SIZE.x / 2.0, VIEWPORT_SIZE.y * 0.45)
	runner.play()
	add_child(runner)
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -20
```

Expected: 5 passed (原 2 + 新 3).

- [ ] **Step 5: Commit**

```bash
cd /workspace/teilaruia && git add scripts/ui/loading_screen.gd tests/unit/test_loading_screen.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): 暮色天空 + 星星 + 玩家小人 walk 动画

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 4: LoadingScreen 进度条 + set_progress

**Files:**
- Modify: `scripts/ui/loading_screen.gd`
- Modify: `tests/unit/test_loading_screen.gd`

---

- [ ] **Step 1: 追加测试**

Append to `tests/unit/test_loading_screen.gd`:

```gdscript
func test_progress_nodes_exist():
	var ls = _make()
	await get_tree().process_frame
	assert_not_null(ls.get_node_or_null("ProgressBg"), "ProgressBg 应存在")
	assert_not_null(ls.get_node_or_null("ProgressBg/ProgressFill"), "ProgressFill 应存在")
	assert_not_null(ls.get_node_or_null("StageLabel"), "StageLabel 应存在")
	assert_not_null(ls.get_node_or_null("PercentLabel"), "PercentLabel 应存在")


func test_set_progress_updates_text():
	var ls = _make()
	await get_tree().process_frame
	ls.set_progress(0.37, "正在生成地形...")
	# 等 tween 完成
	await get_tree().create_timer(0.3).timeout
	var stage_label: Label = ls.get_node("StageLabel")
	var percent_label: Label = ls.get_node("PercentLabel")
	assert_eq(stage_label.text, "正在生成地形...")
	assert_eq(percent_label.text, "37%")


func test_set_progress_fill_width_proportional():
	var ls = _make()
	await get_tree().process_frame
	ls.set_progress(0.5, "x")
	await get_tree().create_timer(0.3).timeout
	var bg: Panel = ls.get_node("ProgressBg")
	var fill: ColorRect = ls.get_node("ProgressBg/ProgressFill")
	# fill.size.x ≈ bg.size.x * 0.5 (允许 1px 误差)
	assert_almost_eq(fill.size.x, bg.size.x * 0.5, 1.0)
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -20
```

Expected: 新 3 fail.

- [ ] **Step 3: 实现进度条与 set_progress**

Edit `scripts/ui/loading_screen.gd`. 在 const 区下方加成员:

```gdscript
const BAR_SIZE := Vector2(480, 28)
const BAR_BG_COLOR := Color8(58, 42, 26)
const BAR_BORDER := Color8(212, 181, 138)
const BAR_FILL_COLOR := Color8(255, 180, 110)
const TEXT_WARM := Color8(242, 194, 101)

var _progress_bg: Panel
var _progress_fill: ColorRect
var _stage_label: Label
var _percent_label: Label
var _progress_tween: Tween
```

把 `_ready` 改为:

```gdscript
func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()
	_setup_progress_bar()
	_setup_labels()
```

在文件末尾加:

```gdscript
func _setup_progress_bar() -> void:
	_progress_bg = Panel.new()
	_progress_bg.name = "ProgressBg"
	_progress_bg.custom_minimum_size = BAR_SIZE
	_progress_bg.size = BAR_SIZE
	_progress_bg.position = Vector2(
		(VIEWPORT_SIZE.x - BAR_SIZE.x) / 2.0,
		VIEWPORT_SIZE.y * 0.65,
	)
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = BAR_BG_COLOR
	bg_style.border_color = BAR_BORDER
	bg_style.border_width_left = 2
	bg_style.border_width_right = 2
	bg_style.border_width_top = 2
	bg_style.border_width_bottom = 2
	_progress_bg.add_theme_stylebox_override("panel", bg_style)
	add_child(_progress_bg)

	_progress_fill = ColorRect.new()
	_progress_fill.name = "ProgressFill"
	_progress_fill.color = BAR_FILL_COLOR
	_progress_fill.position = Vector2(2, 2)
	_progress_fill.size = Vector2(0, BAR_SIZE.y - 4)
	_progress_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_progress_bg.add_child(_progress_fill)


func _setup_labels() -> void:
	_stage_label = Label.new()
	_stage_label.name = "StageLabel"
	_stage_label.text = ""
	_stage_label.add_theme_color_override("font_color", TEXT_WARM)
	_stage_label.add_theme_font_size_override("font_size", 22)
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_label.size = Vector2(VIEWPORT_SIZE.x, 28)
	_stage_label.position = Vector2(0, VIEWPORT_SIZE.y * 0.58)
	add_child(_stage_label)

	_percent_label = Label.new()
	_percent_label.name = "PercentLabel"
	_percent_label.text = "0%"
	_percent_label.add_theme_color_override("font_color", TEXT_WARM)
	_percent_label.add_theme_font_size_override("font_size", 18)
	_percent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_percent_label.size = Vector2(80, 22)
	_percent_label.position = Vector2(
		_progress_bg.position.x + BAR_SIZE.x + 12,
		_progress_bg.position.y + 3,
	)
	add_child(_percent_label)


func set_progress(percent: float, stage_text: String) -> void:
	percent = clamp(percent, 0.0, 1.0)
	_stage_label.text = stage_text
	_percent_label.text = "%d%%" % int(round(percent * 100.0))
	var target_w: float = (BAR_SIZE.x - 4.0) * percent
	if _progress_tween != null and _progress_tween.is_running():
		_progress_tween.kill()
	_progress_tween = create_tween()
	_progress_tween.tween_property(
		_progress_fill, "size:x", target_w, 0.2
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -25
```

Expected: 8 passed.

- [ ] **Step 5: Commit**

```bash
cd /workspace/teilaruia && git add scripts/ui/loading_screen.gd tests/unit/test_loading_screen.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): 进度条 + set_progress(percent, stage)

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 5: LoadingScreen 小贴士 + 点击切换

**Files:**
- Modify: `scripts/ui/loading_screen.gd`
- Modify: `tests/unit/test_loading_screen.gd`

---

- [ ] **Step 1: 追加测试**

Append to `tests/unit/test_loading_screen.gd`:

```gdscript
func test_tip_button_exists_with_label():
	var ls = _make()
	await get_tree().process_frame
	var btn: Button = ls.get_node_or_null("TipButton")
	assert_not_null(btn, "TipButton 应存在")
	var tip_label: Label = btn.get_node_or_null("TipLabel")
	assert_not_null(tip_label, "TipLabel 应存在")
	assert_true(tip_label.text.length() > 0, "初始就应有一条贴士")


func test_clicking_tip_button_advances_to_next_tip():
	var ls = _make()
	await get_tree().process_frame
	var tip_label: Label = ls.get_node("TipButton/TipLabel")
	var first: String = tip_label.text
	# 模拟点击
	ls._on_tip_pressed()
	await get_tree().process_frame
	var second: String = tip_label.text
	assert_ne(first, second, "点击后应换贴士")


func test_tips_pool_has_20_entries():
	assert_eq(LoadingScreenScene.instantiate().TIPS.size(), 20, "贴士池应 20 条")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -20
```

Expected: 新 3 fail.

- [ ] **Step 3: 实现 TIPS + TipButton + 自动 / 点击切换**

Edit `scripts/ui/loading_screen.gd`. 在 const 区追加:

```gdscript
const TIPS: PackedStringArray = [
	"小贴士: 按 A / D 左右移动",
	"小贴士: 按 空格 跳跃",
	"小贴士: 按住 鼠标左键 挖方块",
	"小贴士: 鼠标右键 (或 F) 放方块 / 吃食物",
	"小贴士: 按 E 和村民聊天",
	"小贴士: 按 数字 1-9 切换热键栏",
	"小贴士: 走到工作台前点一下打开合成",
	"小贴士: 砍树就能拿到木头",
	"小贴士: 挖矿要用更好的镐子",
	"小贴士: 火把可以照亮山洞",
	"小贴士: 晚上小心僵尸出没!",
	"小贴士: slime 弱, 适合新手练习",
	"小贴士: 牛 / 羊 / 猪 可以打掉拿肉",
	"小贴士: 肚子饿了记得吃东西",
	"小贴士: 按 Esc 暂停游戏",
	"小贴士: 下雨天会让水变多",
	"小贴士: 闪电过后空气会更清新",
	"小贴士: 萤火虫只在晚上出来",
	"小贴士: 死了会在出生点复活, 掉的东西在原地",
	"小贴士: 看到流星记得许愿",
]
const TIP_AUTO_INTERVAL := 4.0
const TIP_HINT_SUFFIX := "    (点击换一条)"
```

成员追加:

```gdscript
var _tip_button: Button
var _tip_label: Label
var _tips_shuffled: Array[String] = []
var _tip_idx: int = 0
var _tip_timer: Timer
```

`_ready` 改:

```gdscript
func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()
	_setup_progress_bar()
	_setup_labels()
	_setup_tip()
```

文件末尾加:

```gdscript
func _setup_tip() -> void:
	_tips_shuffled.clear()
	for t in TIPS:
		_tips_shuffled.append(t)
	_tips_shuffled.shuffle()

	_tip_button = Button.new()
	_tip_button.name = "TipButton"
	_tip_button.flat = true
	_tip_button.focus_mode = Control.FOCUS_NONE
	_tip_button.size = Vector2(VIEWPORT_SIZE.x, 40)
	_tip_button.position = Vector2(0, VIEWPORT_SIZE.y * 0.85)
	add_child(_tip_button)

	_tip_label = Label.new()
	_tip_label.name = "TipLabel"
	_tip_label.add_theme_color_override("font_color", TEXT_WARM)
	_tip_label.add_theme_font_size_override("font_size", 18)
	_tip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tip_label.size = _tip_button.size
	_tip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_button.add_child(_tip_label)
	_show_current_tip()

	_tip_button.pressed.connect(_on_tip_pressed)

	_tip_timer = Timer.new()
	_tip_timer.wait_time = TIP_AUTO_INTERVAL
	_tip_timer.one_shot = false
	_tip_timer.autostart = true
	add_child(_tip_timer)
	_tip_timer.timeout.connect(_on_tip_pressed)


func _show_current_tip() -> void:
	_tip_label.text = _tips_shuffled[_tip_idx] + TIP_HINT_SUFFIX


func _on_tip_pressed() -> void:
	_tip_idx = (_tip_idx + 1) % _tips_shuffled.size()
	_show_current_tip()
	if _tip_timer != null:
		_tip_timer.start()  # 重置 4 秒自动计时
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -25
```

Expected: 11 passed.

- [ ] **Step 5: Commit**

```bash
cd /workspace/teilaruia && git add scripts/ui/loading_screen.gd tests/unit/test_loading_screen.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): 20 条小贴士 + 4s 自动 / 点击切换

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 6: LoadingScreen finish_and_fade

**Files:**
- Modify: `scripts/ui/loading_screen.gd`
- Modify: `tests/unit/test_loading_screen.gd`

---

- [ ] **Step 1: 追加测试**

Append to `tests/unit/test_loading_screen.gd`:

```gdscript
func test_finish_and_fade_emits_finished_signal():
	var ls = _make()
	await get_tree().process_frame
	ls.set_progress(1.0, "进入世界!")
	ls.finish_and_fade()
	await ls.finished
	# 到这里若没 timeout 就算通过
	assert_true(true)


func test_fade_overlay_alpha_animates_to_1():
	var ls = _make()
	await get_tree().process_frame
	var fade: ColorRect = ls.get_node("FadeOverlay")
	assert_almost_eq(fade.color.a, 0.0, 0.01, "初始 alpha 应为 0")
	ls.finish_and_fade()
	await ls.finished
	assert_almost_eq(fade.color.a, 1.0, 0.01, "fade 完成后 alpha 应为 1")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -20
```

Expected: 2 个新测试 fail (FadeOverlay 不存在 / finish_and_fade 不存在).

- [ ] **Step 3: 实现 FadeOverlay + finish_and_fade**

Edit `scripts/ui/loading_screen.gd`. 加常量:

```gdscript
const FADE_DURATION := 0.5
```

加成员:

```gdscript
var _fade_overlay: ColorRect
```

`_ready` 改:

```gdscript
func _ready() -> void:
	_setup_sky()
	_setup_stars()
	_setup_player_runner()
	_setup_progress_bar()
	_setup_labels()
	_setup_tip()
	_setup_fade_overlay()
```

文件末尾加:

```gdscript
func _setup_fade_overlay() -> void:
	_fade_overlay = ColorRect.new()
	_fade_overlay.name = "FadeOverlay"
	_fade_overlay.color = Color(0, 0, 0, 0)   # 初始透明
	_fade_overlay.anchor_right = 1.0
	_fade_overlay.anchor_bottom = 1.0
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade_overlay)


func finish_and_fade() -> void:
	var t := create_tween()
	t.tween_property(_fade_overlay, "color:a", 1.0, FADE_DURATION).set_trans(Tween.TRANS_SINE)
	t.tween_callback(func(): finished.emit())
```

- [ ] **Step 4: 跑测试确认通过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_loading_screen.gd -gexit 2>&1 | tail -25
```

Expected: 13 passed.

- [ ] **Step 5: Commit**

```bash
cd /workspace/teilaruia && git add scripts/ui/loading_screen.gd tests/unit/test_loading_screen.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): finish_and_fade 0.5s 淡出 + finished signal

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

### Task 7: main.gd 集成 — _start_game 走 LoadingScreen

**Files:**
- Modify: `scripts/main.gd`
- Modify: `tests/integration/test_main_state_machine.gd` (追加一个测试)

---

- [ ] **Step 1: 追加测试**

Append to `tests/integration/test_main_state_machine.gd`:

```gdscript
const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")


func test_start_game_signal_creates_loading_screen():
	var m = _make()
	await get_tree().process_frame
	# 走 menu start_game 信号 (跟用户按 "新游戏" 一样)
	m._main_menu.start_game.emit({"world_seed": 42, "world_name": "t", "difficulty": 1})
	await get_tree().process_frame
	# LoadingScreen 应已 add 到 m
	var ls: CanvasLayer = null
	for c in m.get_children():
		if c is CanvasLayer and c.name == "LoadingScreen":
			ls = c
			break
	assert_not_null(ls, "_start_game 应创建 LoadingScreen")


func test_loading_screen_removed_after_load_completes():
	var m = _make()
	await get_tree().process_frame
	m._main_menu.start_game.emit({"world_seed": 42, "world_name": "t", "difficulty": 1})
	# 等加载流程完 (约 1s + 0.5s 淡出)
	await get_tree().create_timer(2.0).timeout
	for c in m.get_children():
		assert_ne(c.name, "LoadingScreen", "加载完成后 LoadingScreen 应被 queue_free")
	assert_eq(m._state, "game")
	assert_ne(m.world, null)
	assert_ne(m.world.get_player(), null)


func test_boot_to_game_skips_loading_screen():
	# boot_to_game (测试入口) 走老路径, 不创建 LoadingScreen
	var m = _make()
	await get_tree().process_frame
	m.boot_to_game(42)
	await wait_frames(2)
	for c in m.get_children():
		assert_ne(c.name, "LoadingScreen", "boot_to_game 不应创建 LoadingScreen")
	assert_eq(m._state, "game")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_main_state_machine.gd -gexit 2>&1 | tail -25
```

Expected: 新 2 个 fail (test_start_game_signal_creates_loading_screen, test_loading_screen_removed_after_load_completes). `test_boot_to_game_skips_loading_screen` 当前应通过 (现在根本没 LoadingScreen).

- [ ] **Step 3: 改 main.gd — `_start_game` 走 LoadingScreen, `boot_to_game` 保留同步路径**

Edit `scripts/main.gd`. 顶部加 preload:

```gdscript
const LoadingScreenScene = preload("res://scenes/ui/loading_screen.tscn")
```

替换整个 `_start_game` (原 47-101 行):

```gdscript
func _start_game(seed_or_opts = 0) -> void:
	# 兼容 2 种调用 (同 spec):
	# - 老接口 (int seed): boot_to_game / 测试用; 走默认难度/名字
	# - 新接口 (Dictionary opts): 主菜单 "新游戏" 配置面板传 {world_seed, world_name, difficulty}
	var world_seed: int = 0
	var world_name: String = ""
	var difficulty: int = 1
	if seed_or_opts is Dictionary:
		var opts: Dictionary = seed_or_opts
		world_seed = int(opts.get("world_seed", 0))
		world_name = String(opts.get("world_name", ""))
		difficulty = int(opts.get("difficulty", 1))
	else:
		world_seed = int(seed_or_opts)
	if "current_difficulty" in GameSettings:
		GameSettings.current_difficulty = difficulty
	if "current_world_name" in GameSettings:
		GameSettings.current_world_name = world_name
	_state = "game"
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.visible = false
	_run_async_load(world_seed)


# 异步加载流程: instantiate LoadingScreen → 一步步推进进度 → 淡出.
func _run_async_load(world_seed: int) -> void:
	var loading: CanvasLayer = LoadingScreenScene.instantiate()
	loading.name = "LoadingScreen"
	add_child(loading)
	await get_tree().process_frame   # 让 LoadingScreen 渲染一帧

	# Step A (5%): World instantiate (defer_init)
	loading.set_progress(0.05, "正在准备世界...")
	var w = WorldScene.instantiate()
	w.name = "World"
	w.defer_init = true
	if world_seed != 0:
		w.world_seed = world_seed
	add_child(w)
	_game_nodes.append(w)
	await get_tree().process_frame

	# Step B-E (20% / 40% / 60% / 75%): world.run_init_step(0..3)
	var step_count: int = w.get_init_step_count()
	var step_pcts: PackedFloat32Array = [0.20, 0.40, 0.60, 0.75]
	for i in step_count:
		loading.set_progress(step_pcts[i], w.get_init_step_label(i))
		w.run_init_step(i)
		await get_tree().process_frame

	# Step F (90%): HUD + 其他 UI 面板
	loading.set_progress(0.90, "正在准备界面...")
	var hud = HudScene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	_game_nodes.append(hud)
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	add_child(floating)
	_game_nodes.append(floating)
	var debug = DebugHudScene.instantiate()
	add_child(debug)
	_game_nodes.append(debug)
	var dialogue = DialogueBoxScene.instantiate()
	add_child(dialogue)
	_game_nodes.append(dialogue)
	_wire_player.call_deferred()
	_start_autosave()
	await get_tree().process_frame

	# 100%: 完成 + 淡出
	loading.set_progress(1.0, "进入世界!")
	loading.finish_and_fade()
	await loading.finished
	loading.queue_free()
```

替换 `boot_to_game` (原 182-188 行) — 老路径不走 LoadingScreen, 直接同步:

```gdscript
# 测试用 helper: 同步切到 game 状态, 不走 LoadingScreen.
# 等价于按 "新游戏" 但跳过加载动画. 固定 seed=42 让测试可重复.
func boot_to_game(world_seed: int = 42) -> void:
	if _state == "game":
		return
	if _main_menu != null and is_instance_valid(_main_menu):
		_main_menu.queue_free()
		_main_menu = null
	_state = "game"
	# 同步路径: World 默认 defer_init=false, _ready 自动跑完所有 step
	var w = WorldScene.instantiate()
	w.name = "World"
	if world_seed != 0:
		w.world_seed = world_seed
	add_child(w)
	_game_nodes.append(w)
	var hud = HudScene.instantiate()
	hud.name = "HUD"
	add_child(hud)
	_game_nodes.append(hud)
	var crafting = CraftingPanelScene.instantiate()
	crafting.name = "CraftingPanel"
	crafting.add_to_group("crafting_panel")
	add_child(crafting)
	_game_nodes.append(crafting)
	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	add_child(floating)
	_game_nodes.append(floating)
	var debug = DebugHudScene.instantiate()
	add_child(debug)
	_game_nodes.append(debug)
	var dialogue = DialogueBoxScene.instantiate()
	add_child(dialogue)
	_game_nodes.append(dialogue)
	_wire_player.call_deferred()
	_start_autosave()
```

- [ ] **Step 4: 跑 main 测试确认全过**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_main_state_machine.gd -gexit 2>&1 | tail -30
```

Expected: 6 passed (原 3 + 新 3).

- [ ] **Step 5: 跑全套 tests 确认无回归**

```bash
cd /workspace/teilaruia && godot --headless --path . -s addons/gut/gut_cmdln.gd -gdir=res://tests -gexit 2>&1 | tail -40
```

Expected: 所有原有测试 (save / chunk / hunger / craft / mine / etc) 继续通过. 加上 LoadingScreen + world_init_steps 总数应增加.

- [ ] **Step 6: 手动验证 (用户在 Mac 上跑)**

```bash
cd ~/Dev/teilaruia && ./run.sh
```

期望: 点 "新世界" → 创建 → "开始" → 看到暮色背景, 玩家小人跑步动画, 进度条平滑 0%→100% 推进, 阶段文字依次切换 ("准备世界..." → "构建方块..." → "生成地形..." → "召唤天气..." → "召唤玩家..." → "准备界面..." → "进入世界!"), 小贴士底部显示 + 自动每 4s 切, 点击立即切下一条, 最后 0.5s 淡黑进入游戏.

- [ ] **Step 7: Commit**

```bash
cd /workspace/teilaruia && git add scripts/main.gd tests/integration/test_main_state_machine.gd && git commit -m "$(cat <<'EOF'
feat(loading-screen): main._start_game 异步驱动 + boot_to_game 保留同步路径

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## 自检清单

- **Spec coverage**:
  - 暮色背景 ✓ Task 3
  - 像素小人 walk 动画 ✓ Task 3
  - 7 个加载阶段 + 真实进度 ✓ Task 7 (5% + 4 个 world step + 90% + 100%, 共 7 个 set_progress 点位)
  - 进度条 (暖色 + tween 平滑) ✓ Task 4
  - 阶段文字 ✓ Task 4
  - 百分比文字 ✓ Task 4
  - 20 条小贴士 ✓ Task 5
  - 每 4s 自动切 ✓ Task 5
  - 点击立即切 + 重置 timer ✓ Task 5
  - (点击换一条) 灰色提示 ✓ Task 5 (TIP_HINT_SUFFIX)
  - 0.5s 淡出 ✓ Task 6
  - boot_to_game 兼容 ✓ Task 1 + Task 7
  - world.gd 拆 step (4 个) ✓ Task 1

- **No placeholders**: 每个 step 都有完整代码块 / 完整测试.

- **Type consistency**: `LoadingScreen.set_progress(percent: float, stage_text: String)`、`World.run_init_step(idx: int)`、`World.get_init_step_count() -> int`、`World.get_init_step_label(idx) -> String`、`LoadingScreen.finish_and_fade()`、`signal finished` — 整套贯穿 Task 1 / 4 / 6 / 7 一致.
