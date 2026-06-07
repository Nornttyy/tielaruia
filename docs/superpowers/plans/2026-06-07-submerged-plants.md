# 水下植物 (Submerged Plants) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** 水穿过植物而不冲掉 —— 水流进植物格时把植物记进 chunk_manager 的独立元数据层、显示水; 水退了写回植物。进存档。

**Architecture:** 照"背景墙"系统 ([[project-wall-system]]) 的独立数据层做。chunk_manager 加 `_submerged` (chunk_x → Dict[Vector2i_local → plant_tid]); 它**不是渲染图层**(那格显示水), 纯元数据。`world._set_water_tile_fast` 是所有水写入的总闸: 写水前若该格是可淹植物就记进 `_submerged`; 写空气前若该格有记录就改写回植物。water_sim 只把植物加进"可流入"判定, 不碰流动逻辑。

**Tech Stack:** Godot 4.3 + GDScript, GUT 9.x。

**对应 spec:** `docs/superpowers/specs/2026-06-07-submerged-plants-design.md`

---

## ⚠️ 并发警告(动手前必读)

别的 session 在动 `water_sim.gd`。每个 Task 动手前 `git status`; 提交**只 `git add` 本 Task 列出的精确路径**, 禁用 `-am`/`-A`/`.`。`water_sim.gd` 只改 `_water_enterable` + 1 个重力分支条件, 别的不碰。`world.gd` 大文件, 只在 `_set_water_tile_fast` 加总闸。

## 测试运行

`.gutconfig.json` 覆盖全测试目录, 所以 `-gtest=<path>` 不限单文件 —— 用 `-gselect=<裸文件名>`:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit
```
新 clone / 加 class_name 后先 `godot --headless --editor --quit` 建索引。`libfontconfig.so.1` 是无显示告警, 过滤掉。当前累计测试文件数 ~219。

---

## 文件结构

修改:
- `scripts/world/tile_data.gd` — `is_submersible_plant()` + 排除集合
- `scripts/world/chunk_manager.gd` — `_submerged` + `get/set/clear_submerged` (照 `_wall_deltas`)
- `scripts/world/water_sim.gd` — `_water_enterable` 认可淹植物 + 重力分支同改 (不碰流动逻辑)
- `scripts/world/world.gd` — `_set_water_tile_fast` 加"进水记/退水复原"总闸
- `scripts/save/save_data.gd` — `submerged_plants` 字段 + `CURRENT_VERSION` 5→6
- `scripts/save/save_manager.gd` — `_serialize_submerged` + `apply_submerged` (照 wall)
- `scripts/main.gd` — load 时 `apply_submerged` (紧跟 `apply_wall_deltas`)

新增:
- `tests/unit/test_submerged_plants.gd`
- `tests/integration/test_submerged_plants_flow.gd`

---

## Task 1: `Tiles.is_submersible_plant()`

**Files:**
- Modify: `scripts/world/tile_data.gd` (在 `is_plant` 函数后追加)
- Test: `tests/unit/test_submerged_plants.gd` (新建)

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_submerged_plants.gd`:

```gdscript
# 水下植物: 集合判定 + chunk_manager 元数据层 的纯逻辑测试。
extends GutTest


func test_submersible_set() -> void:
	assert_true(Tiles.is_submersible_plant(Tiles.PLANT_GRASS), "装饰草可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.MUSHROOM), "蘑菇可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.WHEAT_0), "小麦可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.RICE_0), "稻子可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.LOG), "树干可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.LEAVES), "树叶可淹")
	assert_true(Tiles.is_submersible_plant(Tiles.CACTUS), "仙人掌可淹")
	assert_false(Tiles.is_submersible_plant(Tiles.TORCH), "火把不淹 (功能件)")
	assert_false(Tiles.is_submersible_plant(Tiles.ROPE), "绳子不淹 (功能件)")
	assert_false(Tiles.is_submersible_plant(Tiles.STONE), "石头不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.AIR), "空气不淹")
	assert_false(Tiles.is_submersible_plant(Tiles.WATER), "水不淹")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -20
```
Expected: FAIL, `is_submersible_plant` 不存在。

- [ ] **Step 3: 实现**

在 `scripts/world/tile_data.gd` 的 `func is_plant(...)` 之后追加:

```gdscript

# 可被水淹没的植物: 水流进 = 记进 _submerged 元数据、显示水; 退水复原。
# = is_plant 但排除火把/史莱姆火把/绳子 (玩家搭建的功能件, 不是植物; 火把泡水灭灯也怪)。
const _NOT_SUBMERSIBLE := {TORCH: true, SLIME_TORCH: true, ROPE: true}
func is_submersible_plant(tile_id: int) -> bool:
	return is_plant(tile_id) and not _NOT_SUBMERSIBLE.has(tile_id)
```

- [ ] **Step 4: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -12
```
Expected: 1/1 passed。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/tile_data.gd tests/unit/test_submerged_plants.gd
git commit -m "feat(submerged-plants): Tiles.is_submersible_plant (植物可淹, 排除火把/绳子)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: chunk_manager `_submerged` 元数据层

照 `_wall_deltas` 结构: chunk_x → Dict[Vector2i_local → plant_tid]。不渲染、不进 chunk tile 数组, 纯存在 chunk_manager (随 chunk 卸载/重载自动留存)。

**Files:**
- Modify: `scripts/world/chunk_manager.gd` (加成员 + 3 函数, 照 `get_wall`/`set_wall`)
- Test: `tests/unit/test_submerged_plants.gd` (加 get/set/clear 测试)

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_submerged_plants.gd` 顶部 const 区加:

```gdscript
const ChunkManager = preload("res://scripts/world/chunk_manager.gd")
```

并追加测试:

```gdscript
func test_submerged_get_set_clear() -> void:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	assert_eq(cm.get_submerged(5, 100), -1, "没记录该返 -1")
	cm.set_submerged(5, 100, Tiles.PLANT_GRASS)
	assert_eq(cm.get_submerged(5, 100), Tiles.PLANT_GRASS, "记下后该取到")
	cm.clear_submerged(5, 100)
	assert_eq(cm.get_submerged(5, 100), -1, "清掉后该返 -1")


func test_submerged_different_chunks_no_bleed() -> void:
	# 不同区块的同一 local 坐标不串 (照 _wall_deltas 按 chunk 分桶)
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.set_submerged(5, 100, Tiles.MUSHROOM)
	cm.set_submerged(5 + 1000, 100, Tiles.WHEAT_1)   # 远处另一区块
	assert_eq(cm.get_submerged(5, 100), Tiles.MUSHROOM, "本区块记录不被远处覆盖")
	assert_eq(cm.get_submerged(5 + 1000, 100), Tiles.WHEAT_1, "远处区块各记各的")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -20
```
Expected: 新 2 个 FAIL (`get_submerged` 不存在)。

- [ ] **Step 3: 实现**

在 `scripts/world/chunk_manager.gd` 顶部 `var _wall_deltas: Dictionary = {}` 那行后加:

```gdscript
var _submerged: Dictionary = {}    # chunk_x → Dict[Vector2i_local → plant_tid]; 水下植物元数据 (不渲染, 退水复原用)
```

在 `set_wall(...)` 函数之后追加 3 个函数 (照 `get_wall`/`set_wall` 用 `Chunk.chunk_x_of`/`Chunk.local_x_of`):

```gdscript

# 水下植物元数据: 水盖住植物时记 plant_tid, 退水时读出来复原。纯 chunk_manager 存, 不进 chunk tile 数组。
func get_submerged(world_x: int, world_y: int) -> int:
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _submerged.has(cx):
		return -1
	var lx: int = Chunk.local_x_of(world_x)
	return _submerged[cx].get(Vector2i(lx, world_y), -1)


func set_submerged(world_x: int, world_y: int, plant_tid: int) -> void:
	var cx: int = Chunk.chunk_x_of(world_x)
	var lx: int = Chunk.local_x_of(world_x)
	if not _submerged.has(cx):
		_submerged[cx] = {}
	_submerged[cx][Vector2i(lx, world_y)] = plant_tid


func clear_submerged(world_x: int, world_y: int) -> void:
	var cx: int = Chunk.chunk_x_of(world_x)
	if not _submerged.has(cx):
		return
	var lx: int = Chunk.local_x_of(world_x)
	_submerged[cx].erase(Vector2i(lx, world_y))
```

- [ ] **Step 4: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -12
```
Expected: 3/3 passed。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/chunk_manager.gd tests/unit/test_submerged_plants.gd
git commit -m "feat(submerged-plants): chunk_manager _submerged 元数据层 (照 _wall_deltas)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: water_sim 让水能流进植物

**只改 2 处判定, 不碰任何流动/水位/找平逻辑。**

**Files:**
- Modify: `scripts/world/water_sim.gd` (`_water_enterable` + 重力下落分支条件)
- Test: `tests/integration/test_liquid_flow.gd` (加 1 个: 水流进植物格)

- [ ] **Step 1: 写失败测试**

在 `tests/integration/test_liquid_flow.gd` 末尾追加 (复用现有 `FakeWorld` / `_make_sim` / `sim._run_tick()`):

```gdscript
# 水下植物: 水该能流进植物那格 (穿过)。FakeWorld 无总闸, 这里只验"水流得进去"(_water_enterable)。
func test_water_flows_into_plant() -> void:
	var fw = FakeWorld.new()
	fw.tiles[Vector2i(0, 0)] = Tiles.WATER
	fw.tiles[Vector2i(0, 1)] = Tiles.MUSHROOM     # 下面是蘑菇 (可淹植物)
	fw.tiles[Vector2i(0, 2)] = Tiles.STONE
	fw.tiles[Vector2i(-1, 1)] = Tiles.STONE
	fw.tiles[Vector2i(1, 1)] = Tiles.STONE
	var sim = _make_sim(fw)
	sim.notify_tile_changed(0, 0)
	for i in 5:
		sim._run_tick()
	assert_eq(fw.tiles.get(Vector2i(0, 1), Tiles.AIR), Tiles.WATER, "水该往下流进蘑菇那格")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_liquid_flow.gd -gexit 2>&1 | grep -v libfontconfig | tail -20
```
Expected: `test_water_flows_into_plant` FAIL (水现在不流进蘑菇, 因 `_water_enterable` 只认 AIR/PLANT_GRASS)。

- [ ] **Step 3: 改 `_water_enterable`**

`scripts/world/water_sim.gd` 现有 (约 343-345 行):

```gdscript
# 用户要"草碰到水会被破坏": 水把 PLANT_GRASS 当空格流入, _set_water_tile_fast 覆盖即销毁.
func _water_enterable(tid: int) -> bool:
	return tid == Tiles.AIR or tid == Tiles.PLANT_GRASS
```

改成:

```gdscript
# 水下植物: 水把"可淹植物"当空格流入 (横竖都穿)。植物不被销毁 —— world._set_water_tile_fast
# 总闸会先把植物记进 _submerged, 退水时复原。岩浆不走这判定 (岩浆碰植物维持现状)。
func _water_enterable(tid: int) -> bool:
	return tid == Tiles.AIR or Tiles.is_submersible_plant(tid)
```

- [ ] **Step 4: 改重力下落分支**

`scripts/world/water_sim.gd` `_step_tile` 里现有 (约 387 行):

```gdscript
	if below_tid == Tiles.AIR or (kind == "water" and below_tid == Tiles.PLANT_GRASS):
```

改成:

```gdscript
	if below_tid == Tiles.AIR or (kind == "water" and Tiles.is_submersible_plant(below_tid)):
```

(只把 `below_tid == Tiles.PLANT_GRASS` 换成 `Tiles.is_submersible_plant(below_tid)`; 其余不动。岩浆 `kind != "water"` 不受影响。)

- [ ] **Step 5: 跑测试确认通过 + 回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_liquid_flow.gd -gexit 2>&1 | grep -v libfontconfig | tail -20
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_water_settles.gd -gexit 2>&1 | grep -v libfontconfig | tail -8
```
Expected: test_liquid_flow 全过 (含新的); test_water_settles 维持原状态 (水行为没变 —— 你没碰流动逻辑)。

- [ ] **Step 6: 提交**

```bash
git add scripts/world/water_sim.gd tests/integration/test_liquid_flow.gd
git commit -m "feat(submerged-plants): water_sim 让水能流进可淹植物 (穿过, 不碰流动逻辑)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: world.gd 总闸 — 进水记植物 / 退水复原

**Files:**
- Modify: `scripts/world/world.gd` (`_set_water_tile_fast` 开头加总闸)
- Test: `tests/integration/test_submerged_plants_flow.gd` (新建, boot 真 world)

- [ ] **Step 1: 写失败测试**

新建 `tests/integration/test_submerged_plants_flow.gd`:

```gdscript
# 水下植物总闸: 进水记植物、退水复原 (走 world._set_water_tile_fast 真路径)。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_water_submerges_then_restores_plant() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	# 在一个已加载的地下格放一株草 (出生点 0 号区块已加载)
	var x: int = 3
	var y: int = 120
	cm.set_tile(x, y, Tiles.PLANT_GRASS)
	# 进水: 该格变水, 草被记进 _submerged
	world._set_water_tile_fast(x, y, Tiles.WATER)
	assert_eq(cm.get_tile(x, y), Tiles.WATER, "进水后该格显示水")
	assert_eq(cm.get_submerged(x, y), Tiles.PLANT_GRASS, "草被记进水下植物层")
	# 退水: 写空气 → 应复原成草, 记录清掉
	world._set_water_tile_fast(x, y, Tiles.AIR)
	assert_eq(cm.get_tile(x, y), Tiles.PLANT_GRASS, "退水后草复原 (不是空气)")
	assert_eq(cm.get_submerged(x, y), -1, "复原后水下植物记录清掉")


func test_water_over_air_no_phantom_plant() -> void:
	# 对照: 本来是空气的格进水再退水 → 还是空气 (不该凭空冒植物)
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(42)
	await wait_frames(2)
	var world = main.get_node("World")
	var cm = world.chunk_manager
	var x: int = 4
	var y: int = 121
	cm.set_tile(x, y, Tiles.AIR)
	world._set_water_tile_fast(x, y, Tiles.WATER)
	assert_eq(cm.get_submerged(x, y), -1, "空气进水不该记植物")
	world._set_water_tile_fast(x, y, Tiles.AIR)
	assert_eq(cm.get_tile(x, y), Tiles.AIR, "退水还是空气")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants_flow.gd -gexit 2>&1 | grep -v libfontconfig | tail -25
```
Expected: `test_water_submerges_then_restores_plant` FAIL (没总闸: 进水后 get_submerged 返 -1, 退水后是 AIR 不是草)。

- [ ] **Step 3: 加总闸**

`scripts/world/world.gd` 现有 `_set_water_tile_fast` 开头:

```gdscript
func _set_water_tile_fast(x: int, y: int, tile_id: int, from_remote: bool = false) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	chunk_manager.set_tile(x, y, tile_id)
```

改成 (在 `chunk_manager.set_tile` 之前插入总闸, 总闸可能把 tile_id 从 AIR 改成植物):

```gdscript
func _set_water_tile_fast(x: int, y: int, tile_id: int, from_remote: bool = false) -> void:
	if y < 0 or y >= ChunkConstants.WORLD_HEIGHT:
		return
	# 水下植物总闸: 写水前若该格是可淹植物 → 记进 _submerged; 写空气前若底下记着植物 → 改写回植物。
	# 只认 is_water (岩浆不记 → 岩浆碰植物维持现状)。覆盖所有水写入/退水路径 (都过这一个闸)。
	if Tiles.is_water(tile_id):
		var existing: int = chunk_manager.get_tile(x, y)
		if Tiles.is_submersible_plant(existing):
			chunk_manager.set_submerged(x, y, existing)
	elif tile_id == Tiles.AIR:
		var plant: int = chunk_manager.get_submerged(x, y)
		if plant != -1:
			tile_id = plant
			chunk_manager.clear_submerged(x, y)
	chunk_manager.set_tile(x, y, tile_id)
```

(下面原有的渲染 `terrain_layer.set_cell` 用的是 `tile_id` —— 因为总闸可能已把它从 AIR 改成植物, 渲染会正确画出复原的植物。`if tile_id == Tiles.AIR` 渲染分支也照常: 复原成植物时走 else 画植物。无需改下面。)

- [ ] **Step 4: 跑测试确认通过 + 回归冒烟**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants_flow.gd -gexit 2>&1 | grep -v libfontconfig | tail -15
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_smoke.gd -gexit 2>&1 | grep -v libfontconfig | tail -8
```
Expected: 2/2 passed; smoke 通过。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/world.gd tests/integration/test_submerged_plants_flow.gd
git commit -m "feat(submerged-plants): _set_water_tile_fast 总闸 — 进水记植物/退水复原

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 存档 — 水下植物进存档 + 旧档兼容

照 `wall_deltas` 平行加一份。

**Files:**
- Modify: `scripts/save/save_data.gd` (`submerged_plants` 字段 + `CURRENT_VERSION` 5→6)
- Modify: `scripts/save/save_manager.gd` (`_serialize_submerged` + `apply_submerged` + save 时写)
- Modify: `scripts/main.gd` (load 时 `apply_submerged`, 紧跟 `apply_wall_deltas`)
- Test: `tests/unit/test_submerged_plants.gd` (加序列化往返 + 旧档兼容)

- [ ] **Step 1: 写失败测试**

在 `tests/unit/test_submerged_plants.gd` 追加:

```gdscript
func test_submerged_save_roundtrip() -> void:
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	cm.set_submerged(5, 100, Tiles.MUSHROOM)
	cm.set_submerged(-3, 50, Tiles.WHEAT_1)
	var serialized: Dictionary = SaveManager._serialize_submerged(cm)
	# 还原到新 cm
	var cm2 = ChunkManager.new()
	add_child_autofree(cm2)
	SaveManager.apply_submerged(cm2, serialized)
	assert_eq(cm2.get_submerged(5, 100), Tiles.MUSHROOM, "序列化往返: 蘑菇还在")
	assert_eq(cm2.get_submerged(-3, 50), Tiles.WHEAT_1, "序列化往返: 小麦还在")


func test_old_save_without_submerged_field() -> void:
	# 旧档无 submerged_plants → SaveData 默认空 dict; apply 空 dict 不崩
	var data = SaveData.new()
	assert_eq(data.submerged_plants, {}, "新建 SaveData 该默认空 submerged_plants")
	var cm = ChunkManager.new()
	add_child_autofree(cm)
	SaveManager.apply_submerged(cm, {})   # 不该崩
	assert_eq(cm.get_submerged(0, 0), -1, "空档应用后无记录")
```

在文件顶部 const 区加 (若尚无):

```gdscript
const SaveData = preload("res://scripts/save/save_data.gd")
```

(`SaveManager` 是 autoload, 直接用名字; `ChunkManager` const 已在 Task 2 加。)

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -20
```
Expected: 新 2 个 FAIL (`submerged_plants` 字段 / `_serialize_submerged` / `apply_submerged` 不存在)。

- [ ] **Step 3: save_data 加字段 + 升版本**

`scripts/save/save_data.gd`: 把 `const CURRENT_VERSION := 5` 改成 `:= 6`。
在 `@export var wall_deltas: Dictionary = {}` 那行后加:

```gdscript
# 水下植物: 被水盖住的植物 (退水复原)。结构同 wall_deltas。旧档无此字段 → 默认空, 兼容。
@export var submerged_plants: Dictionary = {}
```

- [ ] **Step 4: save_manager 加序列化/还原 + save 时写**

`scripts/save/save_manager.gd`: 在 `_serialize_wall_deltas` / `apply_wall_deltas` 之后追加 (结构完全照搬, 只把 `_wall_deltas` 换成 `_submerged`):

```gdscript

# 水下植物 delta 序列化 (结构同 wall delta, 读 _submerged). str(cx) key 防 .tres 丢 0 号区块.
func _serialize_submerged(cm) -> Dictionary:
	var out: Dictionary = {}
	for cx in cm._submerged.keys():
		var inner: Dictionary = cm._submerged[cx]
		var arr := PackedInt32Array()
		for pos_v2i in inner.keys():
			arr.append(pos_v2i.x)
			arr.append(pos_v2i.y)
			arr.append(inner[pos_v2i])
		out[str(cx)] = arr
	return out


# 还原水下植物 delta 到 chunk_manager._submerged (供 load 后调用). 跟 apply_wall_deltas 平行.
static func apply_submerged(cm, serialized: Dictionary) -> void:
	for cx_key in serialized.keys():
		var cx: int = int(cx_key)
		var arr: PackedInt32Array = serialized[cx_key]
		var inner: Dictionary = {}
		var i: int = 0
		while i + 2 < arr.size():
			inner[Vector2i(arr[i], arr[i + 1])] = arr[i + 2]
			i += 3
		cm._submerged[cx] = inner
```

并在 save 收集处 (约 59 行 `data.wall_deltas = _serialize_wall_deltas(world.chunk_manager)` 之后) 加:

```gdscript
	data.submerged_plants = _serialize_submerged(world.chunk_manager)
```

- [ ] **Step 5: main.gd load 时还原**

`scripts/main.gd` 现有 (约 321 行):

```gdscript
		SaveManager.apply_wall_deltas(w.chunk_manager, data.wall_deltas)
```

在它后面紧跟一行 (匹配前面同样的缩进/守卫):

```gdscript
		SaveManager.apply_submerged(w.chunk_manager, data.submerged_plants)
```

(若 `apply_wall_deltas` 那行外包着 `if data.wall_deltas:` 之类的守卫, 把这行放进同一守卫块内, 与之并列。)

- [ ] **Step 6: 跑测试确认通过 + 存档回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_submerged_plants.gd -gexit 2>&1 | grep -v libfontconfig | tail -12
godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_save_load.gd -gexit 2>&1 | grep -v libfontconfig | tail -10
```
Expected: test_submerged_plants 5/5 (or all) passed; 存档相关测试维持通过。
> 注: 若没有 `test_save_load.gd`, 找 `tests/` 里实际的存档测试文件名 (`ls tests/**/ | grep -i save`) 用 `-gselect` 跑它确认没回归。

- [ ] **Step 7: 提交**

```bash
git add scripts/save/save_data.gd scripts/save/save_manager.gd scripts/main.gd tests/unit/test_submerged_plants.gd
git commit -m "feat(submerged-plants): 进存档 (submerged_plants 字段, 照 wall_deltas) + 旧档兼容

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review 结论

- **Spec 覆盖**: A 集合(T1) / B 水流入(T3) / C chunk_manager 层(T2)+总闸(T4) / D 存档(T5) 全覆盖。
- **无 placeholder**: 每步完整代码 + 确切命令 + 期望。
- **类型一致**: `is_submersible_plant(tid)->bool` / `get_submerged->int(-1)` / `set_submerged` / `clear_submerged` / `_serialize_submerged` / `apply_submerged` 全程一致。
- **并发**: water_sim 只改 2 处判定; world.gd 只在 _set_water_tile_fast 加总闸; 每 Task 精确 git add。
- **已知限制**: 细水流穿植物会闪 (spec 已记, 不在本计划修)。
