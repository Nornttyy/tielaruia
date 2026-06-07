# 活水颗粒 (Living Water Grains) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让流动/掉落的水冒出"一粒一粒"的小水珠（重力下落 + 渐隐），纯视觉叠加，不碰水模拟/存档/游泳/钓鱼/联机，网页版安全。

**Architecture:** 复用现有对象池模式（`dust_pool.gd` / `spark_pool.gd`）。新增 `WaterGrainParticle`（受重力的小 Sprite2D）+ `WaterGrainPool`（预分配复用）。`Effects` autoload 加 `spawn_water_grains()`，带全局存活上限护栏。`water_sim.gd` 在已有的三个"水在动"的点（重力下落 / 横向流前沿 / 瀑布源）调发射器；用现有 `_in_settle` 护栏保证加载找平期间不冒。颗粒颜色用 `BlocksArt.water_palette_for(tid)` 现成群系色，靠 `modulate` 染色（一张白底水珠贴图够用）。

**Tech Stack:** Godot 4.3 + GDScript，GUT 9.x 单元/集成测试。

**对应 spec:** `docs/superpowers/specs/2026-06-06-water-grains-design.md`

---

## ⚠️ 并发警告（动手前必读）

仓库有别的 session 在改 **`scripts/world/water_sim.gd`** 和 **`scripts/art/blocks_art.gd`**（细水位 + 卡水 bug）。每个 Task 动手前先 `git status`；提交时**只 `git add` 本 Task 列出的精确路径**，禁用 `-am` / `-A` / `.`。本计划**完全不改 blocks_art.gd**（颜色走现成的 `water_palette_for`，只读），把并发面降到最低。`water_sim.gd` 只在 Task 5 加 3 处发射调用，不动任何流动逻辑。

## 测试运行说明

新 clone / 加了 `class_name` 后**第一次必须先建索引**：

```bash
godot --headless --editor --quit
```

跑某个测试文件：

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

`libfontconfig.so.1: cannot open shared object file` 不是错误，是无显示环境告警，忽略。

当前累计测试文件数 218。

---

## 文件结构

新增：
- `scripts/fx/water_grain_particle.gd` — 单颗水珠：重力下落 + 渐隐 + 回池。一个职责：画一颗会落的水珠。
- `scenes/fx/water_grain_particle.tscn` — 上面脚本挂在一个 `Sprite2D` 上。
- `scripts/fx/water_grain_pool.gd` — 预分配 N 颗水珠复用（仿 `dust_pool.gd`）。
- `tests/unit/test_water_grain_budget.gd` — `Effects` 上限护栏 + 计数增减的纯逻辑测试。

修改：
- `scripts/fx/particles_art.gd` — 加 `get_water_drop()`（一张缓存的小水珠贴图）。
- `scripts/fx/effects.gd` — 加 `spawn_water_grains()` + `MAX_WATER_GRAINS` 上限 + 存活计数 + 调试计数 `grains_emitted`。
- `scripts/world/world.gd` — 在 `EffectsRoot` 下挂一个 `WaterGrainPool`（仿现有 SparkPool/DustPool）。
- `scripts/world/water_sim.gd` — 在重力下落 / 横向流前沿 / 瀑布源 3 处调 `Effects.spawn_water_grains()`。
- `tests/integration/test_liquid_flow.gd` — 断言水落进空气时调了发射器，`_in_settle` 期间不调。

---

## Task 1: 水珠贴图 `get_water_drop()`

一张 3×3 的圆润蓝白水珠，白底（靠 `modulate` 染成群系色），静态缓存只建一次。

**Files:**
- Modify: `scripts/fx/particles_art.gd`（在文件末尾加函数）
- Test: `tests/unit/test_water_grain_budget.gd`（本 Task 先建文件，写第 1 个测试）

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_water_grain_budget.gd`：

```gdscript
# 活水颗粒: 水珠贴图 + Effects 上限护栏的纯逻辑测试。
extends GutTest

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")


func test_water_drop_texture_built() -> void:
	var tex = ParticlesArt.get_water_drop()
	assert_not_null(tex, "get_water_drop 该返回贴图")
	assert_eq(tex.get_width(), 3, "水珠贴图 3px 宽")
	assert_eq(tex.get_height(), 3, "水珠贴图 3px 高")


func test_water_drop_texture_cached() -> void:
	# 缓存: 两次调用返回同一个对象 (不重复建图)
	var a = ParticlesArt.get_water_drop()
	var b = ParticlesArt.get_water_drop()
	assert_eq(a, b, "get_water_drop 该缓存复用同一张贴图")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: FAIL，报 `get_water_drop` 方法不存在（Invalid call）。

- [ ] **Step 3: 实现**

在 `scripts/fx/particles_art.gd` 末尾追加：

```gdscript

# 3x3 圆润水珠: 白底 (中心实, 四角淡), 靠 modulate 染成群系水色。静态缓存只建一次。
static var _water_drop_cache: ImageTexture = null
static func get_water_drop() -> ImageTexture:
	if _water_drop_cache != null:
		return _water_drop_cache
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# 十字 + 中心 = 圆润点; 四角留空显得圆
	img.set_pixel(1, 0, Color(1, 1, 1, 0.85))
	img.set_pixel(0, 1, Color(1, 1, 1, 0.85))
	img.set_pixel(1, 1, Color(1, 1, 1, 1.0))
	img.set_pixel(2, 1, Color(1, 1, 1, 0.85))
	img.set_pixel(1, 2, Color(1, 1, 1, 0.85))
	_water_drop_cache = ImageTexture.create_from_image(img)
	return _water_drop_cache
```

- [ ] **Step 4: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: PASS（2 个测试通过）。

- [ ] **Step 5: 提交**

```bash
git add scripts/fx/particles_art.gd tests/unit/test_water_grain_budget.gd
git commit -m "feat(water-grains): 水珠贴图 get_water_drop (3px 白底圆点, modulate 染色)"
```

---

## Task 2: 水珠粒子 `WaterGrainParticle` + 场景

一颗受重力的小 Sprite2D，短寿命渐隐后回池（仿 `dust_particle.gd`）。

**Files:**
- Create: `scripts/fx/water_grain_particle.gd`
- Create: `scenes/fx/water_grain_particle.tscn`
- Test: `tests/unit/test_water_grain_budget.gd`（加 setup 行为测试）

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_water_grain_budget.gd` 顶部 const 区加：

```gdscript
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")
```

并加测试：

```gdscript
func test_grain_setup_resets_state() -> void:
	var g = WaterGrainScene.instantiate()
	add_child_autofree(g)
	# 先弄脏状态, 再 setup, 验证被重置 (池复用必须归零)
	g.velocity = Vector2(999, 999)
	g.setup(Vector2(10, 20), Vector2(5, -30), Color(0.4, 0.7, 1.0, 0.9))
	assert_eq(g.global_position, Vector2(10, 20), "setup 该设位置")
	assert_eq(g.velocity, Vector2(5, -30), "setup 该重置速度")
	assert_almost_eq(g.modulate.a, 0.9, 0.01, "setup 该按传入颜色定 alpha")
	assert_not_null(g.texture, "setup 该有水珠贴图")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: FAIL，报无法 preload `res://scenes/fx/water_grain_particle.tscn`（资源不存在）。

- [ ] **Step 3: 写脚本**

创建 `scripts/fx/water_grain_particle.gd`：

```gdscript
# 单颗水珠 (纯视觉)。受重力下落, 短寿命渐隐后回池。
# 由 WaterGrainPool 管理 — 寿命到调 _pool.recycle(self) 复用, 没池兜底 queue_free。
# 重力比碎块(800)轻 → 水珠飘一点, 不像石头那样砸下去。
extends Sprite2D

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const GRAVITY := 520.0
const LIFETIME := 0.6

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _alpha0: float = 1.0   # 起始 alpha (群系水色自带), 渐隐基于它
var _pool: Node = null     # WaterGrainPool 持有, 死时回池


func setup(start_pos: Vector2, vel: Vector2, color: Color) -> void:
	global_position = start_pos
	velocity = vel
	texture = ParticlesArt.get_water_drop()
	modulate = color
	_alpha0 = color.a
	_age = 0.0   # 池复用必须归零, 否则立刻"老了"消失


func _process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	modulate.a = _alpha0 * clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		if _pool != null and _pool.has_method("recycle"):
			_pool.recycle(self)
		else:
			queue_free()   # 没池兜底
```

- [ ] **Step 4: 写场景**

创建 `scenes/fx/water_grain_particle.tscn`（手写文本格式；UID 随便取一个不冲突的）：

```
[gd_scene load_steps=2 format=3 uid="uid://bwgrain0water01"]

[ext_resource type="Script" path="res://scripts/fx/water_grain_particle.gd" id="1"]

[node name="WaterGrainParticle" type="Sprite2D"]
script = ExtResource("1")
```

- [ ] **Step 5: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: PASS（3 个测试通过）。

> 注：若报 `uid` 冲突，把 `uid://bwgrain0water01` 改成别的随机串再跑。

- [ ] **Step 6: 提交**

```bash
git add scripts/fx/water_grain_particle.gd scenes/fx/water_grain_particle.tscn tests/unit/test_water_grain_budget.gd
git commit -m "feat(water-grains): WaterGrainParticle (重力下落+渐隐, 仿 dust_particle)"
```

---

## Task 3: 对象池 `WaterGrainPool` + 挂进世界

预分配 N 颗水珠复用，仿 `dust_pool.gd`。在 `world.gd` 的 `EffectsRoot` 下挂一个，和 SparkPool/DustPool 并排。

**Files:**
- Create: `scripts/fx/water_grain_pool.gd`
- Modify: `scripts/world/world.gd:118-126`（在 DustPool 后面加 WaterGrainPool）
- Test: 无新测试（池由 Task 4/5 间接覆盖；纯结构代码仿现有池）

- [ ] **Step 1: 写池脚本**

创建 `scripts/fx/water_grain_pool.gd`：

```gdscript
# 水珠对象池. 预分配 N 颗 WaterGrainParticle 复用, 代替每次 instantiate / queue_free。
# 仿 dust_pool.gd / spark_pool.gd。瀑布密集处一秒几十颗, 没池就一直 alloc 卡帧。
extends Node2D

const PoolSize := 120
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")

var _pool: Array[Node] = []
var _idle: Array[Node] = []


func _ready() -> void:
	add_to_group("water_grain_pool")
	for i in PoolSize:
		var g = WaterGrainScene.instantiate()
		add_child(g)
		if "_pool" in g:
			g._pool = self   # 水珠死时调 self.recycle(g) 回池
		_deactivate(g)
		_pool.append(g)
		_idle.append(g)


# 返回 true = 取到并激活; false = 池满, 调用方放弃这一颗。
func request_grain(start_pos: Vector2, vel: Vector2, color: Color) -> bool:
	if _idle.is_empty():
		return false
	var g: Node = _idle.pop_back()
	_activate(g, start_pos, vel, color)
	return true


func recycle(g: Node) -> void:
	if g == null or not is_instance_valid(g):
		return
	_deactivate(g)
	_idle.append(g)


func _activate(g: Node, pos: Vector2, vel: Vector2, color: Color) -> void:
	g.visible = true
	g.set_process(true)
	if g.has_method("setup"):
		g.setup(pos, vel, color)


func _deactivate(g: Node) -> void:
	g.visible = false
	g.set_process(false)
```

- [ ] **Step 2: 挂进 world.gd**

读 `scripts/world/world.gd` 第 113-127 行确认现状，然后在 DustPool 那段（约 123-126 行）**后面**加：

```gdscript
	var WaterGrainPoolClass = preload("res://scripts/fx/water_grain_pool.gd")
	var wgp = WaterGrainPoolClass.new()
	wgp.name = "WaterGrainPool"
	$EffectsRoot.add_child(wgp)
```

（紧跟在现有 `$EffectsRoot.add_child(dp)` 之后，保持和 SparkPool/DustPool 同风格。）

- [ ] **Step 3: 跑冒烟测试确认没把世界搞崩**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_smoke.gd -gexit
```

Expected: PASS（世界能起，池挂上没报错）。

- [ ] **Step 4: 提交**

```bash
git add scripts/fx/water_grain_pool.gd scripts/world/world.gd
git commit -m "feat(water-grains): WaterGrainPool 预分配 120 颗, 挂 EffectsRoot 下"
```

---

## Task 4: `Effects.spawn_water_grains()` + 上限护栏

`Effects` autoload 加发射方法：全局存活计数 `_grain_count`，到 `MAX_WATER_GRAINS` 就 return；调试计数 `grains_emitted`（每次"被请求发射"就加，供集成测试断言）。颜色用 `BlocksArt.water_palette_for(tid)` 现成群系色（只读，不改 blocks_art）。

**Files:**
- Modify: `scripts/fx/effects.gd`（顶部加常量/计数；末尾加 `spawn_water_grains` + `_on_grain_recycled`）
- Test: `tests/unit/test_water_grain_budget.gd`（加上限护栏测试）

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_water_grain_budget.gd` 加：

```gdscript
func test_budget_blocks_when_full() -> void:
	# 存活数到顶 → 不该再发 (返回 false / grains_emitted 不增)
	Effects._grain_count = Effects.MAX_WATER_GRAINS
	var before: int = Effects.grains_emitted
	var ok: bool = Effects.spawn_water_grains(Vector2(0, 0), Vector2(0, 10), Tiles.WATER, 1)
	assert_false(ok, "存活数到上限时该拒绝发射")
	assert_eq(Effects.grains_emitted, before, "拒绝时调试计数不该增")
	Effects._grain_count = 0   # 还原, 不污染别的测试


func test_budget_counts_emit() -> void:
	# 没到上限 → 该发, 调试计数 +1
	Effects._grain_count = 0
	var before: int = Effects.grains_emitted
	var ok: bool = Effects.spawn_water_grains(Vector2(0, 0), Vector2(0, 10), Tiles.WATER, 1)
	assert_true(ok, "没到上限该允许发射")
	assert_eq(Effects.grains_emitted, before + 1, "发射该让调试计数 +1")
	Effects._grain_count = 0
```

> 注：headless GUT 里没有 `water_grain_pool` 组、`current_scene` 可能为 null。`spawn_water_grains` 必须在"没池也没 effects_root"时**安全地只计数后返回 true**（不崩、不建孤儿节点）。下面实现已处理。

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: FAIL，报 `spawn_water_grains` / `MAX_WATER_GRAINS` / `grains_emitted` / `_grain_count` 不存在。

- [ ] **Step 3: 实现**

在 `scripts/fx/effects.gd` **顶部常量区**（约第 10 行 `const CHIPS_PER_BREAK := 6` 后）加：

```gdscript
const MAX_WATER_GRAINS := 250        # 全局存活水珠硬上限 (网页安全)
var _grain_count: int = 0            # 当前存活水珠数 (发 +1, 回池 -1)
var grains_emitted: int = 0          # 调试/测试计数: 累计成功发射次数 (只增)
```

在 `effects.gd` **末尾**追加：

```gdscript

# 活水颗粒发射: 从流动的水冒小水珠 (纯视觉)。
# tid: 来源水 tile (决定群系颜色); n: 这次冒几颗。
# 返回 true = 已发射(或在 headless 下已计数); false = 到上限被拒。
# 护栏: 全局存活 >= MAX_WATER_GRAINS 直接拒 → 瀑布密集处也不会无限堆。
func spawn_water_grains(world_pos: Vector2, vel_hint: Vector2, tid: int, n: int = 1) -> bool:
	if _grain_count >= MAX_WATER_GRAINS:
		return false
	grains_emitted += 1
	# 颜色: 现成群系水色板的高光色 "c", alpha 调亮到 0.9 让水珠显眼
	var pal: Dictionary = BlocksArt.water_palette_for(tid)
	var base: Color = pal.get("c", Color(0.55, 0.8, 0.96, 1.0))
	var color := Color(base.r, base.g, base.b, 0.9)
	var pool: Node = get_tree().get_first_node_in_group("water_grain_pool")
	var has_root: bool = get_tree().get_first_node_in_group("effects_root") != null
	for i in n:
		if _grain_count >= MAX_WATER_GRAINS:
			break
		# 速度: 在 vel_hint 上加点随机扇形, 像溅开的水
		var vel := vel_hint + Vector2(randf_range(-22, 22), randf_range(-14, 4))
		var pos := world_pos + Vector2(randf_range(-2, 2), randf_range(-2, 2))
		if pool != null and pool.request_grain(pos, vel, color):
			_grain_count += 1
			continue
		# 没池但有 effects_root → 兜底 instantiate (跟其他 spawn_* 一致)
		if has_root:
			var g = WaterGrainScene.instantiate()
			_root().add_child(g)
			g._pool = self           # 让它死时调 Effects._on_grain_recycled
			g.setup(pos, vel, color)
			_grain_count += 1
		# 既没池也没 root (headless 测试): 只计数, 不建节点
	return true


# 兜底 instantiate 出来的水珠 (无池) 走 Effects 当"池": 死时回收, 维持 _grain_count 正确。
func recycle(g: Node) -> void:
	if g != null and is_instance_valid(g):
		g.queue_free()
	_grain_count = maxi(0, _grain_count - 1)
```

并在 `effects.gd` 顶部 const 区加场景预载（约第 7 行 PlaceBounceScene 旁）：

```gdscript
const WaterGrainScene = preload("res://scenes/fx/water_grain_particle.tscn")
```

> 池里的水珠回收走 `WaterGrainPool.recycle`（已减不到 Effects._grain_count）。问题：池回收时谁减 `_grain_count`？池的水珠 `_pool` 指向**池**，不是 Effects。所以**池回收也要通知 Effects 减计数**。改 `WaterGrainPool.recycle` 末尾加一行：

修改 `scripts/fx/water_grain_pool.gd` 的 `recycle`：

```gdscript
func recycle(g: Node) -> void:
	if g == null or not is_instance_valid(g):
		return
	_deactivate(g)
	_idle.append(g)
	Effects._grain_count = maxi(0, Effects._grain_count - 1)   # 通知全局护栏: 又空出一颗
```

- [ ] **Step 4: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/unit/test_water_grain_budget.gd -gexit
```

Expected: PASS（5 个测试通过）。

- [ ] **Step 5: 提交**

```bash
git add scripts/fx/effects.gd scripts/fx/water_grain_pool.gd tests/unit/test_water_grain_budget.gd
git commit -m "feat(water-grains): Effects.spawn_water_grains + MAX_WATER_GRAINS=250 全局护栏"
```

---

## Task 5: water_sim 三处发射钩子 + 集成测试

在 `water_sim.gd` 已有的"水在动"的点调发射器。**只加调用，不动任何流动逻辑**。复用现有 `_in_settle` 护栏（加载找平不冒）。和现有 `spawn_splash` 并存（splash 是落地大溅花、桌面限频；grains 是飞溅水珠、含网页）。

**Files:**
- Modify: `scripts/world/water_sim.gd`（重力下落分支 ~388 行内、横向流 ~438 行内、瀑布源 ~351 行内）
- Test: `tests/integration/test_liquid_flow.gd`（加发射器调用断言）

- [ ] **Step 1: 写失败测试**

在 `tests/integration/test_liquid_flow.gd` 末尾加（复用文件里已有的 `FakeWorld` / `_make_sim`）：

```gdscript
# 活水颗粒: 水落进空气时该调发射器; settle 期间不该调。
func test_grains_emit_on_fall() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE     # 下落 1 格后下方是石头 → 砸到底
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim._in_settle = false
	var before: int = Effects.grains_emitted
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._physics_process(0.016)
	assert_gt(Effects.grains_emitted, before, "水落进空气该冒水珠 (发射器被调)")


func test_grains_silent_during_settle() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim._in_settle = true                       # 加载找平期间
	var before: int = Effects.grains_emitted
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._physics_process(0.016)
	assert_eq(Effects.grains_emitted, before, "settle 期间不该冒水珠")
```

> 若 `_physics_process` 在测试里不驱动 dirty 处理，改成调文件里其他测试用的同款步进调用（看 `test_lava_falls_down` 的循环体里实际调的是哪个方法，照抄）。

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_liquid_flow.gd -gexit
```

Expected: FAIL，`test_grains_emit_on_fall` 失败（`grains_emitted` 没增，因为还没接钩子）。

- [ ] **Step 3: 接重力下落钩子**

`scripts/world/water_sim.gd` 重力下落分支，现有第 385-387 行：

```gdscript
			if kind == "water" and not _in_settle and _tick_n % 4 == 0 and not OS.has_feature("web"):
				if cm.get_tile(x, y + 2) != Tiles.AIR:
					Effects.spawn_splash(Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE))
```

在这段**之后**（仍在 `return` 之前，即 388 行 `return` 上面）加：

```gdscript
			# 活水颗粒: 下落的水冒水珠 (含网页, 靠 Effects 全局上限控量)。settle 不冒。
			if kind == "water" and not _in_settle:
				Effects.spawn_water_grains(
					Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE),
					Vector2(0, 60), tid, 1)
```

- [ ] **Step 4: 接横向流前沿钩子**

`scripts/world/water_sim.gd` `_step_water_lateral` 末尾，现有第 433-439 行（写入 best_nx + notify）。在 `notify_tile_changed(x, y)`（约 439 行）**之后**加：

```gdscript
	# 活水颗粒: 横向漫流前沿冒 1 颗 (流进空气那一步)。settle 不冒。
	if not _in_settle and best_nl == 0:   # best_nl==0 表示流进的是空气/草须 (真前沿)
		var dir: float = 40.0 if best_nx > x else -40.0
		Effects.spawn_water_grains(
			Vector2((best_nx + 0.5) * TILE_SIZE, (y + 0.5) * TILE_SIZE),
			Vector2(dir, 10), Tiles.WATER, 1)
```

- [ ] **Step 5: 接瀑布源钩子**

`scripts/world/water_sim.gd` `_step_source`，现有第 349-352 行往下灌水那段。在 `mark_dirty(x, y)`（约 352 行）**之后**加：

```gdscript
		# 活水颗粒: 瀑布源往下灌时冒水珠。源不受 settle 影响也照 _in_settle 护栏统一。
		if not _in_settle:
			Effects.spawn_water_grains(
				Vector2((x + 0.5) * TILE_SIZE, (y + 1.5) * TILE_SIZE),
				Vector2(0, 70), Tiles.WATER, 1)
```

- [ ] **Step 6: 跑集成测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_liquid_flow.gd -gexit
```

Expected: PASS（含新加的 2 个发射断言）。

- [ ] **Step 7: 跑水回归测试确认行为没变**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_water_settles.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_smoke.gd -gexit
```

Expected: 两个都 PASS（颗粒纯视觉，不该改 tile 结果）。

> ⚠️ `test_water_settles.gd` 据 `stuck-water-handoff` 交接文档**可能本来就是红的**（卡水 bug，别的 session 负责）。跑之前先 `git stash` 看一眼基线 / 或 `git log` 确认该 bug 是否已修。**只要它的红/绿状态在你改之前之后一致**（你只加了发射调用，没碰流动逻辑），就算通过本步。若它从绿变红，说明你误改了流动逻辑，回退重看 Step 3-5。

- [ ] **Step 8: 提交**

```bash
git add scripts/world/water_sim.gd tests/integration/test_liquid_flow.gd
git commit -m "feat(water-grains): water_sim 重力/横向/瀑布源 3 处接发射器 (settle 不冒)"
```

---

## Task 6（可选 polish，收尾再做）: 落地溅花 + 顺坡滑

让水珠**撞到实心/水面时**喷 1~2 颗极小溅花、落斜坡时顺坡滑一点。需要给水珠 `chunk_manager` 引用做碰撞查询。**核心效果（Task 1-5）上线、用户看过觉得不够"撞地感"再做这步。**

**Files:**
- Modify: `scripts/fx/water_grain_pool.gd`（`_ready` 里存 `world` / `chunk_manager` 引用，传给水珠）
- Modify: `scripts/world/world.gd`（建池后 `wgp.chunk_manager = chunk_manager`）
- Modify: `scripts/fx/water_grain_particle.gd`（`_process` 查下一步是否实心/水 → 落地回收 + 触发小溅花）

- [ ] **Step 1: 池持有 chunk_manager 并下发**

`water_grain_pool.gd` 加成员 + 在 `_activate` 把引用塞给水珠：

```gdscript
var chunk_manager = null   # world.gd 建池后赋值; 给水珠做落地碰撞查询
```

在 `_ready` 的 `if "_pool" in g:` 块里加：

```gdscript
		if "_cm" in g:
			g._cm = chunk_manager
```

- [ ] **Step 2: world.gd 赋 chunk_manager**

`scripts/world/world.gd` 建 `wgp` 那段（Task 3 加的）后，注意 `chunk_manager` 在 world.gd 约 188 行才创建。WaterGrainPool 在 113-126 行的早期块创建，那时 `chunk_manager` 还没建。所以**改为在 `chunk_manager` 创建后**（约 191 行 `chunk_manager.setup(...)` 之后）补：

```gdscript
	var _wgp: Node = $EffectsRoot.get_node_or_null("WaterGrainPool")
	if _wgp != null:
		_wgp.chunk_manager = chunk_manager
```

- [ ] **Step 3: 水珠落地检测**

`water_grain_particle.gd` 加成员 `var _cm = null`，在 `_process` 移动后、寿命判断前插入：

```gdscript
	# 落地检测: 下一格是实心或水 → 落地, 喷极小溅花后回收
	if _cm != null:
		var tx: int = int(floor(global_position.x / 12.0))   # TILE_SIZE=12
		var ty: int = int(floor(global_position.y / 12.0))
		var t: int = _cm.get_tile(tx, ty)
		if Tiles.is_solid(t) or Tiles.is_water(t):
			# 落地: 极小溅花 (1 颗向上), 不递归冒 (n=1, vel 向上)
			Effects.spawn_water_grains(global_position, Vector2(0, -30), Tiles.WATER, 1)
			if _pool != null and _pool.has_method("recycle"):
				_pool.recycle(self)
			else:
				queue_free()
			return
```

> 注意递归风险：落地溅花又会落地再溅 → 靠 `MAX_WATER_GRAINS` 上限和 LIFETIME 兜住，但为稳妥，落地溅出的水珠 vel 向上且只 1 颗，且 Effects 上限会很快截断。可接受。

- [ ] **Step 4: 跑全套水测试 + 冒烟**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_liquid_flow.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://tests/integration/test_smoke.gd -gexit
```

Expected: PASS。

- [ ] **Step 5: 提交**

```bash
git add scripts/fx/water_grain_pool.gd scripts/fx/water_grain_particle.gd scripts/world/world.gd
git commit -m "feat(water-grains): 水珠落地溅花 (池下发 chunk_manager 做碰撞)"
```

---

## 验收（用户亲眼看，无 GUI 自动验收）

核心（Task 1-5）跑完后让用户用 `./run.sh` 看：
- 挖开一个水池底部 → 水往下掉的地方**冒一串小水珠**。
- 世界里的瀑布（`WATER_SOURCE`）往下灌处**持续冒水珠**。
- 静止的水**不冒**（颗粒只挂流动事件，零开销）。
- 网页版（push 到 main 自动部署，3-5 分钟）瀑布密集处**帧率不崩**（靠 250 上限）。

调试若"看不见水珠" → 按 CLAUDE.md：第一假设是**太弱/太小**，先把 `get_water_drop` 调大到 4-5px、`spawn_water_grains` 的 `n` 调到 2-3、颜色 alpha 调到 1.0 夸张化，确认能看见再回调。

---

## Self-Review 结论

- **Spec 覆盖**：A 颗粒(Task 1-2) / B 发射器(Task 5) / C 护栏(Task 4) / D 水面美术 → **D 故意没做**（spec 说 D 可独立后做 + blocks_art 并发风险高，本计划为降并发面整段不碰 blocks_art；落地溅花/顺坡滑收进可选 Task 6）。撞地溅花+顺坡滑 = Task 6。
- **无 placeholder**：每步有完整代码 + 确切命令 + 期望输出。
- **类型一致**：`spawn_water_grains(world_pos, vel_hint, tid, n)` / `request_grain(pos, vel, color)` / `recycle(g)` / `_grain_count` / `grains_emitted` 全程一致。
- **并发**：water_sim 只加调用不改逻辑；完全不碰 blocks_art；每 Task 精确 `git add`。
