# Teilaruia · Demo P1.5 · Atmosphere & Feel · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让玩家在 P1 静态画面基础上感受到天空飘云、跳跃落地扬灰、走路冒小尘，并为 P2 准备好挖进度裂纹 / 块破碎粒子 / 放下弹动 / 交互提示等可调 API。

**Architecture:** Godot 4.3 单进程。新 autoload `Effects` 作为粒子工厂。新增 World 子节点 `CloudLayer`、`CrackOverlay`、`EffectsRoot`，以及 Main 下的 `FloatingPrompt` CanvasLayer。所有粒子贴图程序生成（沿用 P0 PixelArt 路线）。

**Tech Stack:** Godot 4.3, GDScript, GUT 9.3.0, P1 的 ArtCache/BlocksArt。

**前置：** P1 Foundation 完成（`tag demo-p1-foundation`），23 个测试通过。

**预计 13 个任务，~55 步。**

---

## File Structure

新建：
- `scripts/fx/effects.gd` (autoload)
- `scripts/fx/particles_art.gd`
- `scripts/fx/clouds_art.gd`
- `scripts/fx/block_break_particle.gd`
- `scripts/fx/dust_particle.gd`
- `scripts/fx/place_bounce.gd`
- `scripts/world/crack_overlay.gd`
- `scripts/world/cloud_layer.gd`
- `scripts/ui/floating_prompt.gd`
- `scenes/fx/block_break_particle.tscn`
- `scenes/fx/dust_particle.tscn`
- `scenes/fx/place_bounce.tscn`
- `scenes/world/crack_overlay.tscn`
- `scenes/world/cloud_layer.tscn`
- `scenes/ui/floating_prompt.tscn`
- `tests/unit/test_effects.gd`
- `tests/unit/test_crack_overlay.gd`
- `tests/unit/test_floating_prompt.gd`
- `tests/integration/test_player_dust_emits.gd`
- `tests/integration/test_cloud_layer_loaded.gd`
- `tests/integration/test_smoke_p1_5.gd`

修改：
- `project.godot` — autoload `Effects`
- `scripts/art/blocks_art.gd` — 加 `static func get_palette(tile_id) -> Array[Color]`
- `scripts/autoload/art_cache.gd` — 预生成 cloud/particle 贴图缓存
- `scripts/player/player_controller.gd` — 在 state 转换时调 `Effects.spawn_*`
- `scripts/world/world.gd` — 加入 CloudLayer + CrackOverlay + effects_root group
- `scripts/main.gd` — 实例化 FloatingPrompt
- `scenes/world/world.tscn` — 加 CloudLayer + CrackOverlay + EffectsRoot 子节点

---

## Task 1: BlocksArt.get_palette() (TDD)

**Files:**
- Modify: `scripts/art/blocks_art.gd`
- Create: `tests/unit/test_blocks_art_palette.gd`

P2 块破碎粒子和 PlaceBounce 都要按 tile 取色。给 BlocksArt 加 `get_palette(tile_id)`，返回 `[base_color, dark_color]` (颜色数组)。

- [ ] **Step 1: 读现有 BlocksArt 了解调色板结构**

Run:
```bash
head -80 /workspace/teilaruia/scripts/art/blocks_art.gd
```

- [ ] **Step 2: 写失败测试**

Create `/workspace/teilaruia/tests/unit/test_blocks_art_palette.gd`:

```gdscript
extends GutTest

const BlocksArt = preload("res://scripts/art/blocks_art.gd")


func test_palette_for_grass_returns_two_colors():
	var palette = BlocksArt.get_palette(BlocksArt.GRASS)
	assert_eq(palette.size(), 2)
	assert_true(palette[0] is Color)
	assert_true(palette[1] is Color)


func test_palette_for_stone():
	var palette = BlocksArt.get_palette(BlocksArt.STONE)
	assert_eq(palette.size(), 2)
	# stone 偏灰，base 灰度应 >= dark 灰度
	assert_gt(palette[0].r + palette[0].g + palette[0].b,
		palette[1].r + palette[1].g + palette[1].b)


func test_palette_for_log():
	var palette = BlocksArt.get_palette(BlocksArt.LOG)
	assert_eq(palette.size(), 2)


func test_palette_for_air_returns_default():
	# AIR (0) 没调色板，返回 fallback (2 个颜色，可以是任意)
	var palette = BlocksArt.get_palette(BlocksArt.AIR)
	assert_eq(palette.size(), 2)


func test_palette_for_unknown_returns_default():
	var palette = BlocksArt.get_palette(9999)
	assert_eq(palette.size(), 2)
```

- [ ] **Step 3: 跑测试 FAIL**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `get_palette` 未定义错误。

- [ ] **Step 4: 给 BlocksArt 加 get_palette**

修改 `/workspace/teilaruia/scripts/art/blocks_art.gd`，在 const 段之后加：

```gdscript
const _PALETTES := {
	GRASS:     [Color(0.30, 0.65, 0.27), Color(0.18, 0.42, 0.18)],
	DIRT:      [Color(0.50, 0.34, 0.22), Color(0.32, 0.20, 0.12)],
	STONE:     [Color(0.60, 0.60, 0.62), Color(0.38, 0.38, 0.40)],
	SAND:      [Color(0.92, 0.84, 0.55), Color(0.70, 0.60, 0.38)],
	LOG:       [Color(0.55, 0.36, 0.20), Color(0.34, 0.20, 0.10)],
	LEAVES:    [Color(0.32, 0.60, 0.28), Color(0.18, 0.36, 0.16)],
	PLANKS:    [Color(0.78, 0.58, 0.34), Color(0.50, 0.36, 0.20)],
	WORKBENCH: [Color(0.62, 0.42, 0.22), Color(0.36, 0.24, 0.14)],
	DOOR:      [Color(0.50, 0.34, 0.20), Color(0.32, 0.20, 0.10)],
	BEDROCK:   [Color(0.25, 0.25, 0.28), Color(0.10, 0.10, 0.12)],
}
const _DEFAULT_PALETTE := [Color(0.7, 0.7, 0.7), Color(0.4, 0.4, 0.4)]


static func get_palette(tile_id: int) -> Array:
	return _PALETTES.get(tile_id, _DEFAULT_PALETTE)
```

- [ ] **Step 5: 跑测试 PASS**

Run:
```bash
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `28 passed, 0 failed` (P1 23 + 这里 5)。

- [ ] **Step 6: 提交**

```bash
git add scripts/art/blocks_art.gd tests/unit/test_blocks_art_palette.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(art): BlocksArt.get_palette(tile_id) - 10 tile 调色板 + 默认 fallback"
```

---

## Task 2: ParticlesArt + CloudsArt 程序贴图

**Files:**
- Create: `scripts/fx/particles_art.gd`
- Create: `scripts/fx/clouds_art.gd`
- Modify: `scripts/autoload/art_cache.gd`

为粒子和云生成纹理：
- 块碎片：3×3 实心方块 (base + dark 各一张)
- 灰尘 puff：5×5 半透明圆点
- 云：3 种形状 × 3 种颜色 = 9 种缓存纹理

- [ ] **Step 1: 写 particles_art.gd**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/fx
```

Create `/workspace/teilaruia/scripts/fx/particles_art.gd`:

```gdscript
# 粒子贴图程序生成。所有方法 static，返回 ImageTexture。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")


# 3x3 实心小方块，单色
static func get_block_chip(color: Color) -> ImageTexture:
	var img := Image.create(3, 3, false, Image.FORMAT_RGBA8)
	img.fill(color)
	return ImageTexture.create_from_image(img)


# 5x5 半透明圆点 puff，从中心 alpha=1 → 边缘 alpha=0
static func get_dust_puff(color: Color = Color(0.9, 0.85, 0.7, 1.0)) -> ImageTexture:
	var img := Image.create(5, 5, false, Image.FORMAT_RGBA8)
	var center := Vector2(2.0, 2.0)
	for y in 5:
		for x in 5:
			var d: float = Vector2(x, y).distance_to(center)
			var a: float = clamp(1.0 - d / 2.5, 0.0, 1.0)
			img.set_pixel(x, y, Color(color.r, color.g, color.b, color.a * a))
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 2: 写 clouds_art.gd**

Create `/workspace/teilaruia/scripts/fx/clouds_art.gd`:

```gdscript
# 云贴图程序生成。3 种形状 × 3 种颜色 = 9 种缓存纹理。
extends RefCounted

# 颜色：白 / 浅灰 / 中灰，对应近 / 中 / 远 层
const COLOR_NEAR := Color(1.0, 1.0, 1.0, 0.95)
const COLOR_MID  := Color(0.92, 0.94, 0.96, 0.75)
const COLOR_FAR  := Color(0.78, 0.82, 0.86, 0.55)

const SHAPE_FLAT := 0
const SHAPE_PUFF := 1
const SHAPE_LONG := 2


# 形状定义：每个 [(x, y, w, h)] 矩形列表组成一朵云的几个圆/块
# 简化做法：直接画几个 ellipse-like 矩形拼凑
const _SHAPES := {
	SHAPE_FLAT: {  # 水平拉长，8x4
		"size": Vector2i(8, 4),
		"rects": [
			Rect2i(1, 1, 6, 2),
			Rect2i(0, 2, 8, 1),
		],
	},
	SHAPE_PUFF: {  # 蓬松，12x6
		"size": Vector2i(12, 6),
		"rects": [
			Rect2i(2, 1, 8, 4),
			Rect2i(0, 3, 12, 2),
			Rect2i(4, 0, 4, 1),
		],
	},
	SHAPE_LONG: {  # 长条三段，16x5
		"size": Vector2i(16, 5),
		"rects": [
			Rect2i(0, 2, 6, 2),
			Rect2i(5, 1, 7, 3),
			Rect2i(11, 2, 5, 2),
		],
	},
}


static func get_texture(shape: int, color: Color) -> ImageTexture:
	var data: Dictionary = _SHAPES[shape]
	var size: Vector2i = data.size
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for rect in data.rects:
		for y in range(rect.position.y, rect.position.y + rect.size.y):
			for x in range(rect.position.x, rect.position.x + rect.size.x):
				if x >= 0 and x < size.x and y >= 0 and y < size.y:
					img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)


static func all_shapes() -> Array:
	return [SHAPE_FLAT, SHAPE_PUFF, SHAPE_LONG]


static func all_colors() -> Array:
	return [COLOR_NEAR, COLOR_MID, COLOR_FAR]
```

- [ ] **Step 3: 更新 ArtCache 预生成云贴图**

修改 `/workspace/teilaruia/scripts/autoload/art_cache.gd`，在 const 段之后加 import，在 `_ready` 末尾加新 build 方法调用：

加 import：
```gdscript
const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const CloudsArt = preload("res://scripts/fx/clouds_art.gd")
```

加成员：
```gdscript
var cloud_textures: Array = []  # Array of {shape, color, texture}
var dust_puff_texture: ImageTexture
```

`_ready` 加调用：
```gdscript
func _ready() -> void:
	_build_blocks()
	_build_items()
	_build_doors()
	_build_entities()
	_build_clouds()
	_build_particles()
```

加方法：
```gdscript
func _build_clouds() -> void:
	for shape in CloudsArt.all_shapes():
		for color in CloudsArt.all_colors():
			cloud_textures.append({
				"shape": shape,
				"color": color,
				"texture": CloudsArt.get_texture(shape, color),
			})


func _build_particles() -> void:
	dust_puff_texture = ParticlesArt.get_dust_puff()
```

- [ ] **Step 4: 冷启动确认无 error**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，28 测试仍过。

- [ ] **Step 5: 提交**

```bash
git add scripts/fx/particles_art.gd scripts/fx/clouds_art.gd scripts/autoload/art_cache.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(fx): ParticlesArt + CloudsArt 程序贴图 + ArtCache 预生成缓存"
```

---

## Task 3: Effects autoload 骨架 (TDD)

**Files:**
- Create: `scripts/fx/effects.gd`
- Modify: `project.godot` (autoload)
- Create: `tests/unit/test_effects.gd`

Effects 是粒子工厂。提供 5 个 spawn 方法（block_break, place_bounce, jump_dust, land_dust, walk_puff），每个把对应场景 instantiate 到当前场景的 `effects_root` 组（一个 group 内任意 Node2D）。本 task 先做骨架，每个 spawn 方法暂时只 instantiate 一个空 Node2D，后续 task 把真实场景填进来。

- [ ] **Step 1: 写 effects.gd 骨架**

Create `/workspace/teilaruia/scripts/fx/effects.gd`:

```gdscript
# 粒子工厂 (autoload)。spawn_* 方法实例化对应场景到 effects_root 组下的 Node。
# 找不到 effects_root 则丢到当前场景根 (兜底)。
extends Node


func _root() -> Node:
	var n: Node = get_tree().get_first_node_in_group("effects_root")
	if n != null:
		return n
	return get_tree().current_scene


func spawn_block_break(tile_coord: Vector2i, tile_id: int) -> void:
	# 占位：实际实现在 Task 4
	pass


func spawn_place_bounce(tile_coord: Vector2i) -> void:
	# 占位：Task 6
	pass


func spawn_jump_dust(world_pos: Vector2) -> void:
	# Task 5 实现
	pass


func spawn_land_dust(world_pos: Vector2) -> void:
	# Task 5 实现
	pass


func spawn_walk_puff(world_pos: Vector2) -> void:
	# Task 5 实现
	pass
```

- [ ] **Step 2: 注册 autoload**

修改 `project.godot` 的 `[autoload]` 段：

```ini
[autoload]

Tiles="*res://scripts/world/tile_data.gd"
SkyLightGrid="*res://scripts/world/sky_light_grid.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
Effects="*res://scripts/fx/effects.gd"
```

- [ ] **Step 3: 写测试**

Create `/workspace/teilaruia/tests/unit/test_effects.gd`:

```gdscript
extends GutTest


func test_effects_autoload_exists():
	assert_not_null(Effects)


func test_spawn_methods_do_not_crash():
	# 即使 effects_root 不存在也不应崩
	Effects.spawn_block_break(Vector2i.ZERO, 0)
	Effects.spawn_place_bounce(Vector2i.ZERO)
	Effects.spawn_jump_dust(Vector2.ZERO)
	Effects.spawn_land_dust(Vector2.ZERO)
	Effects.spawn_walk_puff(Vector2.ZERO)
	# 无 assert 失败即 PASS


func test_root_falls_back_to_current_scene_when_no_group():
	# Effects._root() 应不为 null
	var root = Effects._root()
	assert_not_null(root)
```

- [ ] **Step 4: 重建 class 索引 + 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | tail -3
timeout 60 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `31 passed, 0 failed`。

- [ ] **Step 5: 提交**

```bash
git add scripts/fx/effects.gd project.godot tests/unit/test_effects.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(fx): Effects autoload 骨架 - 5 个 spawn API + effects_root 组路由"
```

---

## Task 4: BlockBreakParticle 场景 + 接通 spawn_block_break

**Files:**
- Create: `scripts/fx/block_break_particle.gd`
- Create: `scenes/fx/block_break_particle.tscn`
- Modify: `scripts/fx/effects.gd`

挖完一格时生成 6 个 3×3 小碎片，速度随机向上扇形飞溅，受重力，30 帧后自删。

- [ ] **Step 1: 写 block_break_particle.gd**

Create `/workspace/teilaruia/scripts/fx/block_break_particle.gd`:

```gdscript
# 单个块碎片。受重力，30 帧 (0.5s @ 60fps) 后自删。
extends Sprite2D

const GRAVITY := 800.0
const LIFETIME := 0.5

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


func setup(start_pos: Vector2, color: Color, vel: Vector2) -> void:
	global_position = start_pos
	texture = _make_texture(color)
	velocity = vel


func _make_texture(color: Color) -> ImageTexture:
	# 直接走 ParticlesArt.get_block_chip
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	return ParticlesArt.get_block_chip(color)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
```

- [ ] **Step 2: 写 block_break_particle.tscn**

Run:
```bash
mkdir -p /workspace/teilaruia/scenes/fx
```

Create `/workspace/teilaruia/scenes/fx/block_break_particle.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b8teilaruiabp"]

[ext_resource type="Script" path="res://scripts/fx/block_break_particle.gd" id="1_bp"]

[node name="BlockBreakParticle" type="Sprite2D"]
script = ExtResource("1_bp")
```

- [ ] **Step 3: 接通 spawn_block_break**

修改 `/workspace/teilaruia/scripts/fx/effects.gd`，在文件顶部 const 段加：

```gdscript
const BlockBreakParticleScene = preload("res://scenes/fx/block_break_particle.tscn")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const TILE_SIZE := 16
const CHIPS_PER_BREAK := 6
```

替换 `spawn_block_break`：

```gdscript
func spawn_block_break(tile_coord: Vector2i, tile_id: int) -> void:
	var center := Vector2(
		tile_coord.x * TILE_SIZE + TILE_SIZE / 2.0,
		tile_coord.y * TILE_SIZE + TILE_SIZE / 2.0
	)
	var palette: Array = BlocksArt.get_palette(tile_id)
	var parent: Node = _root()
	for i in CHIPS_PER_BREAK:
		var chip = BlockBreakParticleScene.instantiate()
		parent.add_child(chip)
		var angle: float = randf_range(-PI, 0.0)  # 向上半圆
		var speed: float = randf_range(60.0, 140.0)
		var vel := Vector2(cos(angle), sin(angle)) * speed
		var color: Color = palette[i % palette.size()]
		chip.setup(center + Vector2(randf_range(-4, 4), randf_range(-4, 4)), color, vel)
```

- [ ] **Step 4: 加测试**

修改 `/workspace/teilaruia/tests/unit/test_effects.gd`，追加：

```gdscript
func test_spawn_block_break_creates_chips():
	# 建一个临时 root
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_block_break(Vector2i(5, 5), 1)  # GRASS
	await wait_frames(1)
	assert_eq(root.get_child_count(), 6, "应生成 6 个 chip")


func test_chips_auto_free_after_lifetime():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_block_break(Vector2i.ZERO, 1)
	await wait_frames(1)
	assert_eq(root.get_child_count(), 6)
	# 0.5s = 30 帧 @ 60fps; 等 40 帧确保过期
	await wait_frames(40)
	assert_eq(root.get_child_count(), 0, "chips 应自删")
```

- [ ] **Step 5: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `33 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/fx/block_break_particle.gd scenes/fx/block_break_particle.tscn scripts/fx/effects.gd tests/unit/test_effects.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(fx): BlockBreakParticle - 6 chip 扇形飞溅 + 0.5s 自删 + 接通 Effects"
```

---

## Task 5: DustParticle 场景 + 接通 jump/land/walk

**Files:**
- Create: `scripts/fx/dust_particle.gd`
- Create: `scenes/fx/dust_particle.tscn`
- Modify: `scripts/fx/effects.gd`

三种 dust 共用一个场景，由参数区分大小 / 生命 / 数量。

- [ ] **Step 1: 写 dust_particle.gd**

Create `/workspace/teilaruia/scripts/fx/dust_particle.gd`:

```gdscript
# 灰尘云。固定贴图，渐隐淡出 + 短上飘。
extends Sprite2D

const LIFETIME := 0.35
const RISE_SPEED := 18.0  # 缓慢上飘 (像素/秒)

var _age: float = 0.0


func setup(start_pos: Vector2, scale_factor: float = 1.0) -> void:
	global_position = start_pos
	texture = ArtCache.dust_puff_texture
	scale = Vector2(scale_factor, scale_factor)
	modulate = Color(1, 1, 1, 1.0)


func _process(delta: float) -> void:
	_age += delta
	global_position.y -= RISE_SPEED * delta
	modulate.a = clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
```

- [ ] **Step 2: 写 dust_particle.tscn**

Create `/workspace/teilaruia/scenes/fx/dust_particle.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b9teilaruiadust"]

[ext_resource type="Script" path="res://scripts/fx/dust_particle.gd" id="1_dust"]

[node name="DustParticle" type="Sprite2D"]
script = ExtResource("1_dust")
```

- [ ] **Step 3: 接通三个 spawn 方法**

修改 `/workspace/teilaruia/scripts/fx/effects.gd`，加 preload：

```gdscript
const DustParticleScene = preload("res://scenes/fx/dust_particle.tscn")
```

替换三个方法：

```gdscript
func spawn_jump_dust(world_pos: Vector2) -> void:
	var parent: Node = _root()
	for i in 4:
		var d = DustParticleScene.instantiate()
		parent.add_child(d)
		d.setup(world_pos + Vector2(randf_range(-5, 5), randf_range(-2, 2)),
			randf_range(0.7, 1.0))


func spawn_land_dust(world_pos: Vector2) -> void:
	var parent: Node = _root()
	for i in 6:
		var d = DustParticleScene.instantiate()
		parent.add_child(d)
		d.setup(world_pos + Vector2(randf_range(-8, 8), randf_range(-1, 1)),
			randf_range(1.0, 1.4))


func spawn_walk_puff(world_pos: Vector2) -> void:
	var parent: Node = _root()
	var d = DustParticleScene.instantiate()
	parent.add_child(d)
	d.setup(world_pos + Vector2(randf_range(-2, 2), 0), 0.6)
```

- [ ] **Step 4: 加测试**

修改 `tests/unit/test_effects.gd` 追加：

```gdscript
func test_spawn_jump_dust_creates_4():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_jump_dust(Vector2(100, 100))
	await wait_frames(1)
	assert_eq(root.get_child_count(), 4)


func test_spawn_walk_puff_creates_1():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_walk_puff(Vector2(0, 0))
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)


func test_dust_auto_frees():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_walk_puff(Vector2.ZERO)
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)
	await wait_frames(30)  # 0.5s
	assert_eq(root.get_child_count(), 0)
```

- [ ] **Step 5: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `36 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/fx/dust_particle.gd scenes/fx/dust_particle.tscn scripts/fx/effects.gd tests/unit/test_effects.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(fx): DustParticle - 渐隐上飘 + jump(4)/land(6)/walk(1) spawn"
```

---

## Task 6: PlaceBounce 节点 + 接通 spawn_place_bounce

**Files:**
- Create: `scripts/fx/place_bounce.gd`
- Create: `scenes/fx/place_bounce.tscn`
- Modify: `scripts/fx/effects.gd`

放下块时叠一个 Sprite2D，纹理从 TileMapLayer 当前 tile 取，scale 用 Tween 从 (1.2, 1.2) → (1.0, 1.0) 100ms 收回，结束自删。

- [ ] **Step 1: 写 place_bounce.gd**

Create `/workspace/teilaruia/scripts/fx/place_bounce.gd`:

```gdscript
# 放下块时的 scale bounce 动画。给目标 tile 上叠一个 Sprite2D，
# scale 从 (1.2, 1.2) → (1.0, 1.0) 用 Tween 100ms，完成自删。
# texture 取该 tile 的 block_texture (来自 ArtCache.block_textures)。
extends Sprite2D

const TILE_SIZE := 16
const BOUNCE_DURATION := 0.1
const START_SCALE := 1.2
const END_SCALE := 1.0


func setup(tile_coord: Vector2i, tile_id: int) -> void:
	if ArtCache.block_textures.has(tile_id):
		texture = ArtCache.block_textures[tile_id]
	centered = false  # 让 origin 在左上对齐 tile
	global_position = Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
	# 缩放是相对 sprite origin。Sprite 是 16x16，centered=false → origin 在左上
	# 但 scale 是从 origin 开始的，所以缩放过头会偏。统一做法：tween 时调整 position 让中心稳定
	var center := global_position + Vector2(TILE_SIZE / 2.0, TILE_SIZE / 2.0)
	scale = Vector2(START_SCALE, START_SCALE)
	_align_to_center(center)
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(_set_scale_around_center.bind(center),
		START_SCALE, END_SCALE, BOUNCE_DURATION)
	tween.tween_callback(queue_free)


func _set_scale_around_center(s: float, center: Vector2) -> void:
	scale = Vector2(s, s)
	_align_to_center(center)


func _align_to_center(center: Vector2) -> void:
	# 让 scaled 后的中心仍在 center 上
	global_position = center - Vector2(TILE_SIZE / 2.0 * scale.x, TILE_SIZE / 2.0 * scale.y)
```

- [ ] **Step 2: 写 place_bounce.tscn**

Create `/workspace/teilaruia/scenes/fx/place_bounce.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b10teilaruipb"]

[ext_resource type="Script" path="res://scripts/fx/place_bounce.gd" id="1_pb"]

[node name="PlaceBounce" type="Sprite2D"]
script = ExtResource("1_pb")
```

- [ ] **Step 3: 接通 Effects.spawn_place_bounce**

修改 `/workspace/teilaruia/scripts/fx/effects.gd`：

加 preload：
```gdscript
const PlaceBounceScene = preload("res://scenes/fx/place_bounce.tscn")
```

`spawn_place_bounce` 需要 tile_id 才能取贴图。改签名为 `(tile_coord, tile_id)`：

```gdscript
func spawn_place_bounce(tile_coord: Vector2i, tile_id: int = -1) -> void:
	if tile_id == -1:
		return
	var pb = PlaceBounceScene.instantiate()
	_root().add_child(pb)
	pb.setup(tile_coord, tile_id)
```

> Spec §3 写的是 `spawn_place_bounce(tile_coord)`。这里改成 `(tile_coord, tile_id)` 必要，因为没 tile_id 无法决定贴图。同步更新 spec §3。

修改 `/workspace/teilaruia/docs/superpowers/specs/2026-05-18-teilaruia-demo-p1-5-atmosphere-feel-design.md`，把：
```
Effects.spawn_place_bounce(tile_coord: Vector2i)
```
改成：
```
Effects.spawn_place_bounce(tile_coord: Vector2i, tile_id: int)
```

- [ ] **Step 4: 加测试**

修改 `tests/unit/test_effects.gd` 追加：

```gdscript
func test_spawn_place_bounce_creates_node():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_place_bounce(Vector2i(5, 5), 1)  # GRASS
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)


func test_spawn_place_bounce_auto_frees():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_place_bounce(Vector2i.ZERO, 1)
	await wait_frames(1)
	assert_eq(root.get_child_count(), 1)
	# 100ms = 6 帧；等 12 帧
	await wait_frames(12)
	assert_eq(root.get_child_count(), 0)


func test_spawn_place_bounce_with_invalid_id_does_nothing():
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_place_bounce(Vector2i.ZERO)  # 不传 tile_id → -1 → noop
	await wait_frames(1)
	assert_eq(root.get_child_count(), 0)
```

- [ ] **Step 5: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `39 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/fx/place_bounce.gd scenes/fx/place_bounce.tscn scripts/fx/effects.gd tests/unit/test_effects.gd docs/superpowers/specs/2026-05-18-teilaruia-demo-p1-5-atmosphere-feel-design.md
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(fx): PlaceBounce scale tween 100ms + spec API 签名更正"
```

---

## Task 7: CrackOverlay 节点

**Files:**
- Create: `scripts/world/crack_overlay.gd`
- Create: `scenes/world/crack_overlay.tscn`
- Create: `tests/unit/test_crack_overlay.gd`

挖进度裂纹覆盖层。`set_progress(tile, ratio)` 在 tile 上叠一个 Sprite2D；ratio 决定显示哪个阶段（0..0.25, 0.25..0.5, 0.5..0.75, 0.75..1.0）。`clear(tile)` 移除。同 tile 重复调更新，不堆叠。

裂纹贴图：4 张 16×16 RGBA8，黑色线条 + 透明背景。用代码生成（在 ParticlesArt 里加）。

- [ ] **Step 1: 给 ParticlesArt 加 get_crack_stage(stage: int)**

修改 `/workspace/teilaruia/scripts/fx/particles_art.gd` 末尾追加：

```gdscript
# stage 0..3：裂纹由少到多
const _CRACK_PATTERNS := [
	# Stage 0: 一条短裂纹
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7)],
	# Stage 1: 加一根分叉
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7)],
	# Stage 2: 再加一条
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11)],
	# Stage 3: 大面积裂
	[Vector2i(7, 4), Vector2i(8, 5), Vector2i(8, 6), Vector2i(7, 7),
	 Vector2i(9, 6), Vector2i(10, 7), Vector2i(5, 9), Vector2i(6, 10), Vector2i(7, 11),
	 Vector2i(3, 6), Vector2i(4, 7), Vector2i(11, 11), Vector2i(12, 12), Vector2i(2, 11)],
]


static func get_crack_stage(stage: int) -> ImageTexture:
	stage = clampi(stage, 0, 3)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var crack_color := Color(0.05, 0.05, 0.05, 0.85)
	for p in _CRACK_PATTERNS[stage]:
		if p.x >= 0 and p.x < 16 and p.y >= 0 and p.y < 16:
			img.set_pixel(p.x, p.y, crack_color)
	return ImageTexture.create_from_image(img)
```

- [ ] **Step 2: 给 ArtCache 缓存裂纹贴图**

修改 `scripts/autoload/art_cache.gd`：

加成员：
```gdscript
var crack_textures: Array = []  # 4 个阶段
```

加 build：
```gdscript
func _build_particles() -> void:
	dust_puff_texture = ParticlesArt.get_dust_puff()
	for stage in 4:
		crack_textures.append(ParticlesArt.get_crack_stage(stage))
```

- [ ] **Step 3: 写 crack_overlay.gd**

Create `/workspace/teilaruia/scripts/world/crack_overlay.gd`:

```gdscript
# 挖进度裂纹覆盖层。每个 tile 最多一个 Sprite2D 子节点显示裂纹。
# 用 dict 索引避免重复 instantiate。
extends Node2D

const TILE_SIZE := 16

var _active: Dictionary = {}  # Vector2i → Sprite2D


# ratio 0..1。0 或 >=1 视作清除。<= 0.25 stage 0；<= 0.5 stage 1；<= 0.75 stage 2；< 1.0 stage 3
func set_progress(tile_coord: Vector2i, ratio: float) -> void:
	if ratio <= 0.0 or ratio >= 1.0:
		clear(tile_coord)
		return
	var stage: int = 3
	if ratio <= 0.25:
		stage = 0
	elif ratio <= 0.5:
		stage = 1
	elif ratio <= 0.75:
		stage = 2
	var sprite: Sprite2D = _active.get(tile_coord, null)
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.centered = false
		sprite.global_position = Vector2(tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE)
		add_child(sprite)
		_active[tile_coord] = sprite
	sprite.texture = ArtCache.crack_textures[stage]


func clear(tile_coord: Vector2i) -> void:
	if _active.has(tile_coord):
		_active[tile_coord].queue_free()
		_active.erase(tile_coord)


func active_count() -> int:
	return _active.size()
```

- [ ] **Step 4: 写 crack_overlay.tscn**

Create `/workspace/teilaruia/scenes/world/crack_overlay.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b11teilaruicrack"]

[ext_resource type="Script" path="res://scripts/world/crack_overlay.gd" id="1_crack"]

[node name="CrackOverlay" type="Node2D"]
script = ExtResource("1_crack")
```

- [ ] **Step 5: 写测试**

Create `/workspace/teilaruia/tests/unit/test_crack_overlay.gd`:

```gdscript
extends GutTest

const CrackOverlayScene = preload("res://scenes/world/crack_overlay.tscn")


func _make_overlay() -> Node2D:
	var co = CrackOverlayScene.instantiate()
	add_child_autofree(co)
	return co


func test_set_progress_creates_sprite():
	var co = _make_overlay()
	co.set_progress(Vector2i(3, 3), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 1)


func test_set_progress_same_tile_updates_not_duplicates():
	var co = _make_overlay()
	co.set_progress(Vector2i(1, 1), 0.2)
	co.set_progress(Vector2i(1, 1), 0.7)
	await wait_frames(1)
	assert_eq(co.active_count(), 1, "同 tile 重调应只 1 个 sprite")


func test_set_progress_zero_clears():
	var co = _make_overlay()
	co.set_progress(Vector2i(2, 2), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 1)
	co.set_progress(Vector2i(2, 2), 0.0)
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_set_progress_one_clears():
	var co = _make_overlay()
	co.set_progress(Vector2i(2, 2), 0.5)
	co.set_progress(Vector2i(2, 2), 1.0)
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_clear_removes():
	var co = _make_overlay()
	co.set_progress(Vector2i(4, 4), 0.5)
	co.clear(Vector2i(4, 4))
	await wait_frames(1)
	assert_eq(co.active_count(), 0)


func test_multiple_tiles_independent():
	var co = _make_overlay()
	co.set_progress(Vector2i(0, 0), 0.3)
	co.set_progress(Vector2i(1, 0), 0.8)
	co.set_progress(Vector2i(2, 0), 0.5)
	await wait_frames(1)
	assert_eq(co.active_count(), 3)
	co.clear(Vector2i(1, 0))
	await wait_frames(1)
	assert_eq(co.active_count(), 2)
```

- [ ] **Step 6: 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | tail -3
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `45 passed, 0 failed`。

- [ ] **Step 7: 提交**

```bash
git add scripts/fx/particles_art.gd scripts/autoload/art_cache.gd scripts/world/crack_overlay.gd scenes/world/crack_overlay.tscn tests/unit/test_crack_overlay.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(world): CrackOverlay - 4 阶段裂纹 + set_progress/clear API + 7 测试"
```

---

## Task 8: FloatingPrompt 场景

**Files:**
- Create: `scripts/ui/floating_prompt.gd`
- Create: `scenes/ui/floating_prompt.tscn`
- Create: `tests/unit/test_floating_prompt.gd`

CanvasLayer 下的 Label，跟随给定的世界坐标。`show(world_pos, text)` 显示，`hide()` 隐藏。世界坐标→屏幕坐标用 Camera2D 的 transform。

- [ ] **Step 1: 写 floating_prompt.gd**

Run:
```bash
mkdir -p /workspace/teilaruia/scripts/ui
```

Create `/workspace/teilaruia/scripts/ui/floating_prompt.gd`:

```gdscript
# 跟随世界坐标的文字提示。CanvasLayer 下的 Label。
# show(world_pos, text) 后每帧重新计算屏幕位置（玩家移动时跟随）。
extends CanvasLayer

@onready var label: Label = $Label

var _target_world_pos: Vector2 = Vector2.ZERO
var _visible: bool = false


func _ready() -> void:
	visible = false
	label.visible = false


func show(world_pos: Vector2, text: String) -> void:
	_target_world_pos = world_pos
	label.text = text
	visible = true
	label.visible = true
	_visible = true
	_update_position()


func hide() -> void:
	visible = false
	label.visible = false
	_visible = false


func is_showing() -> bool:
	return _visible


func _process(_delta: float) -> void:
	if _visible:
		_update_position()


func _update_position() -> void:
	# 世界坐标 → 屏幕坐标。CanvasLayer 默认 follow_viewport_enabled=false → 直接用 viewport transform。
	var viewport := get_viewport()
	var canvas_transform := viewport.get_canvas_transform()
	var screen_pos: Vector2 = canvas_transform * _target_world_pos
	# 中心对齐 (label 宽度居中)
	label.position = screen_pos - Vector2(label.size.x / 2.0, label.size.y + 4)
```

- [ ] **Step 2: 写 floating_prompt.tscn**

Run:
```bash
mkdir -p /workspace/teilaruia/scenes/ui
```

Create `/workspace/teilaruia/scenes/ui/floating_prompt.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b12teilaruifp"]

[ext_resource type="Script" path="res://scripts/ui/floating_prompt.gd" id="1_fp"]

[node name="FloatingPrompt" type="CanvasLayer"]
script = ExtResource("1_fp")

[node name="Label" type="Label"]
text = "按 E"
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(1, 0.95, 0.7, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 2
```

- [ ] **Step 3: 写测试**

Create `/workspace/teilaruia/tests/unit/test_floating_prompt.gd`:

```gdscript
extends GutTest

const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")


func _make() -> CanvasLayer:
	var fp = FloatingPromptScene.instantiate()
	add_child_autofree(fp)
	return fp


func test_initially_hidden():
	var fp = _make()
	assert_false(fp.is_showing())
	assert_false(fp.visible)


func test_show_makes_visible():
	var fp = _make()
	fp.show(Vector2(100, 100), "按 E")
	assert_true(fp.is_showing())
	assert_true(fp.visible)


func test_show_updates_text():
	var fp = _make()
	fp.show(Vector2.ZERO, "拿起")
	assert_eq(fp.label.text, "拿起")


func test_hide():
	var fp = _make()
	fp.show(Vector2.ZERO, "x")
	fp.hide()
	assert_false(fp.is_showing())
	assert_false(fp.visible)
```

- [ ] **Step 4: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `49 passed, 0 failed`。

- [ ] **Step 5: 提交**

```bash
git add scripts/ui/floating_prompt.gd scenes/ui/floating_prompt.tscn tests/unit/test_floating_prompt.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(ui): FloatingPrompt 跟随世界坐标的文字浮标 + 4 测试"
```

---

## Task 9: CloudLayer 场景

**Files:**
- Create: `scripts/world/cloud_layer.gd`
- Create: `scenes/world/cloud_layer.tscn`
- Create: `tests/integration/test_cloud_layer_loaded.gd`

ParallaxBackground 子层 3 个，每层 motion_scale 不同 + 5-8 朵云自滚动。云出屏 wrap 到对侧。

- [ ] **Step 1: 写 cloud_layer.gd**

Create `/workspace/teilaruia/scripts/world/cloud_layer.gd`:

```gdscript
# 视差云层。挂在 World 下，3 个 ParallaxLayer (远/中/近)。
# 每个 layer 内 5-8 朵云，自滚动；出屏 wrap。
extends ParallaxBackground

const CloudsArt = preload("res://scripts/fx/clouds_art.gd")

# 每层 [motion_scale, scroll_speed, cloud_count, color_index]
const _LAYERS := [
	{"motion_scale": 0.2, "speed": 6.0,  "count": 6, "color_idx": 2},  # 远，COLOR_FAR
	{"motion_scale": 0.5, "speed": 14.0, "count": 5, "color_idx": 1},  # 中
	{"motion_scale": 0.8, "speed": 26.0, "count": 4, "color_idx": 0},  # 近
]
const WORLD_WIDTH_PX := 1024 * 16  # 16384
const SKY_Y_TOP := -200          # 云出现的 y 范围（玩家头顶之上）
const SKY_Y_BOTTOM := 200


var _cloud_data: Array = []  # 每朵 {sprite, speed, wrap_width}


func _ready() -> void:
	for layer_def in _LAYERS:
		var pl := ParallaxLayer.new()
		pl.motion_scale = Vector2(layer_def.motion_scale, layer_def.motion_scale * 0.2)
		# 极大 mirroring 让云在任何相机位置都能见
		pl.motion_mirroring = Vector2(2000, 0)
		add_child(pl)
		for i in layer_def.count:
			var shape_options: Array = CloudsArt.all_shapes()
			var color_options: Array = CloudsArt.all_colors()
			var shape: int = shape_options[randi() % shape_options.size()]
			var color: Color = color_options[layer_def.color_idx]
			var sprite := Sprite2D.new()
			sprite.texture = CloudsArt.get_texture(shape, color)
			sprite.centered = false
			sprite.position = Vector2(
				randf_range(0, 2000),
				randf_range(SKY_Y_TOP, SKY_Y_BOTTOM)
			)
			pl.add_child(sprite)
			_cloud_data.append({
				"sprite": sprite,
				"speed": layer_def.speed,
				"wrap_width": 2000.0,
			})


func _process(delta: float) -> void:
	for c in _cloud_data:
		c.sprite.position.x += c.speed * delta
		if c.sprite.position.x > c.wrap_width:
			c.sprite.position.x -= c.wrap_width + c.sprite.texture.get_width()


func layer_count() -> int:
	# 仅算 ParallaxLayer 子节点
	var n := 0
	for child in get_children():
		if child is ParallaxLayer:
			n += 1
	return n
```

- [ ] **Step 2: 写 cloud_layer.tscn**

Create `/workspace/teilaruia/scenes/world/cloud_layer.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b13teilaruiclouds"]

[ext_resource type="Script" path="res://scripts/world/cloud_layer.gd" id="1_cl"]

[node name="CloudLayer" type="ParallaxBackground"]
script = ExtResource("1_cl")
```

- [ ] **Step 3: 写集成测试**

Create `/workspace/teilaruia/tests/integration/test_cloud_layer_loaded.gd`:

```gdscript
extends GutTest

const CloudLayerScene = preload("res://scenes/world/cloud_layer.tscn")


func test_cloud_layer_creates_three_parallax_layers():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	assert_eq(cl.layer_count(), 3, "应有 3 个 ParallaxLayer")


func test_cloud_layer_has_clouds():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	# 总云数 = 6 + 5 + 4 = 15
	var total := 0
	for layer in cl.get_children():
		total += layer.get_child_count()
	assert_eq(total, 15)


func test_clouds_move_over_time():
	var cl = CloudLayerScene.instantiate()
	add_child_autofree(cl)
	await wait_frames(1)
	# 取第一朵云的 x
	var first_layer = cl.get_child(0)
	var sprite: Sprite2D = first_layer.get_child(0)
	var x0: float = sprite.position.x
	await wait_frames(30)  # 0.5s
	var x1: float = sprite.position.x
	assert_ne(x0, x1, "云应随时间移动")
```

- [ ] **Step 4: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `52 passed, 0 failed`。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/cloud_layer.gd scenes/world/cloud_layer.tscn tests/integration/test_cloud_layer_loaded.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(world): CloudLayer 3 层视差 + 15 朵云自滚动 + wrap"
```

---

## Task 10: 接入 World - effects_root + CloudLayer + CrackOverlay

**Files:**
- Modify: `scripts/world/world.gd`
- Modify: `scenes/world/world.tscn`

把 CloudLayer + CrackOverlay 加到 World 场景；加 EffectsRoot 节点并加入 `effects_root` 组。CloudLayer 必须挂在 Camera2D 前的渲染层（z_index 负，云在 tile 后面）。

- [ ] **Step 1: 修改 world.tscn**

替换 `/workspace/teilaruia/scenes/world/world.tscn`：

```
[gd_scene load_steps=4 format=3 uid="uid://b2teilaruiaworld"]

[ext_resource type="Script" path="res://scripts/world/world.gd" id="1_world"]
[ext_resource type="PackedScene" path="res://scenes/world/cloud_layer.tscn" id="2_clouds"]
[ext_resource type="PackedScene" path="res://scenes/world/crack_overlay.tscn" id="3_crack"]

[node name="World" type="Node2D"]
script = ExtResource("1_world")

[node name="CloudLayer" parent="." instance=ExtResource("2_clouds")]

[node name="TerrainLayer" type="TileMapLayer" parent="."]

[node name="CrackOverlay" parent="." instance=ExtResource("3_crack")]

[node name="EffectsRoot" type="Node2D" parent="."]

[node name="Entities" type="Node2D" parent="."]

[node name="Camera2D" type="Camera2D" parent="."]
zoom = Vector2(2, 2)
position_smoothing_enabled = true
position_smoothing_speed = 8.0
```

- [ ] **Step 2: 修改 world.gd 加 group**

修改 `/workspace/teilaruia/scripts/world/world.gd`，在 `_ready` 中追加：

```gdscript
func _ready() -> void:
	terrain_layer.tile_set = TileSetBuilder.build()
	terrain_layer.add_to_group("terrain_layer")
	$EffectsRoot.add_to_group("effects_root")
	_generate_and_apply()
	_spawn_player()
	SkyLightGrid.recompute_from(_tiles)
```

- [ ] **Step 3: 加 World 暴露 CrackOverlay 引用的便利方法（让 P2 PlayerAction 能拿到）**

修改 `scripts/world/world.gd` 末尾追加：

```gdscript
func get_crack_overlay() -> Node:
	return $CrackOverlay
```

- [ ] **Step 4: 冷启动 + 测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，52 仍过。

- [ ] **Step 5: 提交**

```bash
git add scripts/world/world.gd scenes/world/world.tscn
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(world): World 场景加 CloudLayer + CrackOverlay + EffectsRoot 组"
```

---

## Task 11: 接入 PlayerController - jump/land/walk dust

**Files:**
- Modify: `scripts/player/player_controller.gd`
- Create: `tests/integration/test_player_dust_emits.gd`

在 PlayerController 状态切换时调 Effects.spawn_*。

- [ ] **Step 1: 修改 player_controller.gd**

读现有 player_controller.gd 后，完整替换为：

```gdscript
# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const COYOTE_TIME := 0.10
const LAND_VY_THRESHOLD := 200.0    # 落地时 vy 超此值才扬大灰
const WALK_PUFF_INTERVAL := 0.3     # 走路每 0.3s 一次 puff

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote_timer: float = 0.0
var _facing_right: bool = true
var _was_on_floor: bool = true
var _previous_vy: float = 0.0
var _walk_step_timer: float = 0.0


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED

	# 落地检测（用本帧前的 vy 判断"落得多狠"）
	var on_floor_now := is_on_floor()

	# 重力
	if not on_floor_now:
		velocity.y += GRAVITY * delta
		_coyote_timer = max(0.0, _coyote_timer - delta)
	else:
		_coyote_timer = COYOTE_TIME

	# 跳跃
	var did_jump := false
	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0
		did_jump = true

	# 记录跳前 vy 给落地用
	var pre_move_vy := velocity.y

	move_and_slide()

	var on_floor_after := is_on_floor()

	# 跳起瞬间扬灰
	if did_jump:
		Effects.spawn_jump_dust(global_position)

	# 落地瞬间扬灰：本帧由空中变地面 + 之前的 vy 够大
	if not _was_on_floor and on_floor_after and _previous_vy > LAND_VY_THRESHOLD:
		Effects.spawn_land_dust(global_position)

	# 走路 puff：在地 + 有移动
	if on_floor_after and abs(dir) > 0.01:
		_walk_step_timer -= delta
		if _walk_step_timer <= 0:
			var facing_sign := 1.0 if _facing_right else -1.0
			Effects.spawn_walk_puff(global_position + Vector2(-facing_sign * 4, 0))
			_walk_step_timer = WALK_PUFF_INTERVAL
	else:
		_walk_step_timer = 0.0

	_was_on_floor = on_floor_after
	_previous_vy = pre_move_vy

	# 朝向
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right

	# 动画状态机
	_update_animation(dir, on_floor_after)


func _update_animation(dir: float, on_floor: bool) -> void:
	var next_anim: String
	if not on_floor:
		next_anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(dir) > 0.01:
		next_anim = "walk"
	else:
		next_anim = "idle"
	if sprite.animation != next_anim:
		sprite.play(next_anim)
```

- [ ] **Step 2: 写集成测试**

Create `/workspace/teilaruia/tests/integration/test_player_dust_emits.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _effects_count() -> int:
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	return 0 if root == null else root.get_child_count()


func test_player_walking_emits_puffs():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var count_before := _effects_count()
	# 模拟按 D 走 0.5s
	Input.action_press("move_right")
	await wait_frames(40)
	Input.action_release("move_right")
	# 至少有一个 puff（很可能多个）
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	# walk_puff 每 0.3s = 18 帧一次；40 帧 → 至少 1 次
	# 但 puff 0.35s 自删，所以可能立即被销毁；这里测累计 spawn ≥ 1 而不是当前 count
	# 简化：检查 _walk_step_timer 推进 = 至少触发过一次
	# 用 root.get_child_count 在 spawn 后立刻 > 0 的瞬间难以稳定捕获
	# 改用 sentinel：之前 0 → 走了若干帧 → 之后立刻有 ≥ 1 或刚好掉到 0 但要求中途有过
	# 简化为：再走一短段，紧跟 frame 内 count ≥ 1
	Input.action_press("move_right")
	await wait_frames(20)
	# 在 walk_step_timer 刚 reset 后的几帧内大概率有粒子
	var observed_any := false
	for _i in 30:
		if _effects_count() > 0:
			observed_any = true
			break
		await wait_frames(1)
	Input.action_release("move_right")
	assert_true(observed_any, "走路期间应至少观察到 1 个粒子")
```

- [ ] **Step 3: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `53 passed, 0 failed`。

- [ ] **Step 4: 提交**

```bash
git add scripts/player/player_controller.gd tests/integration/test_player_dust_emits.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(player): jump/land/walk dust 触发 + 走路 puff 集成测试"
```

---

## Task 12: 接入 Main + FloatingPrompt workbench 提示

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scripts/player/player_controller.gd`

Main 实例化 FloatingPrompt。PlayerController 每帧检查 chebyshev ≤ 2 内是否有 WORKBENCH tile，是 → 调 FloatingPrompt.show；否 → hide。

- [ ] **Step 1: 修改 main.gd**

替换 `/workspace/teilaruia/scripts/main.gd`：

```gdscript
# 游戏根：实例化 World + DebugHUD + FloatingPrompt。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")

var world: Node2D
var debug_hud: CanvasLayer
var floating_prompt: CanvasLayer


func _ready() -> void:
	world = WorldScene.instantiate()
	add_child(world)

	floating_prompt = FloatingPromptScene.instantiate()
	floating_prompt.add_to_group("floating_prompt")
	add_child(floating_prompt)

	debug_hud = DebugHudScene.instantiate()
	add_child(debug_hud)

	debug_hud.call_deferred("set_player", world.get_player())
```

- [ ] **Step 2: 修改 player_controller.gd 加 workbench 检测**

在 `_physics_process` 末尾追加（在 `_update_animation(...)` 之后）：

```gdscript
	_update_workbench_prompt()


func _update_workbench_prompt() -> void:
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	if fp == null:
		return
	var terrain := get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return
	var foot := global_position
	var pt := Vector2i(int(floor(foot.x / 16.0)), int(floor(foot.y / 16.0)))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var coord := pt + Vector2i(dx, dy)
			if terrain.get_cell_source_id(coord) == Tiles.WORKBENCH:
				fp.show_prompt(Vector2(coord.x * 16 + 8, coord.y * 16 - 4), "按 E")
				return
	# 没找到
	if fp.is_showing():
		fp.hide_prompt()
```

- [ ] **Step 3: 冷启动 + 跑测试**

Run:
```bash
rm -rf .godot && timeout 30 godot --headless --editor --quit 2>&1 | grep -iE "error" | grep -v libfontconfig || echo "clean"
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: `clean`，53 仍过。

- [ ] **Step 4: 写 workbench prompt 集成测试**

Create `/workspace/teilaruia/tests/integration/test_workbench_prompt.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_prompt_shows_near_workbench():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	var world = main.get_node("World")
	var player = world.get_player()
	var terrain: TileMapLayer = world.get_node("TerrainLayer")
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	# 在玩家旁边放 1 个 workbench
	var foot := player.global_position
	var pt := Vector2i(int(floor(foot.x / 16.0)), int(floor(foot.y / 16.0)))
	terrain.set_cell(pt + Vector2i(1, 0), Tiles.WORKBENCH, Vector2i.ZERO)
	await wait_frames(2)
	assert_true(fp.is_showing(), "靠近工作台应显示提示")


func test_prompt_hides_when_no_workbench():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	# 默认没有工作台 → 不显示
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	await wait_frames(2)
	assert_false(fp.is_showing())
```

- [ ] **Step 5: 跑测试**

Run:
```bash
timeout 120 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -10
```

Expected: 累计 `55 passed, 0 failed`。

- [ ] **Step 6: 提交**

```bash
git add scripts/main.gd scripts/player/player_controller.gd tests/integration/test_workbench_prompt.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "feat(ui): 玩家附近 workbench 时显示「按 E」提示 + 2 集成测试"
```

---

## Task 13: 60 秒长跑 smoke + tag P1.5

**Files:**
- Create: `tests/integration/test_smoke_p1_5.gd`
- Modify: `docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md`

跑 600 帧（10s）验证：场景活着、effects_root 子节点数有界（粒子能自删）、没异常。

- [ ] **Step 1: 写测试**

Create `/workspace/teilaruia/tests/integration/test_smoke_p1_5.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func test_runs_600_frames_no_crash_and_effects_bounded():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(600)
	assert_not_null(main.get_node_or_null("World"))
	var root: Node = get_tree().get_first_node_in_group("effects_root")
	assert_not_null(root, "effects_root 组节点应存在")
	# 期望粒子数 ≤ 200（理论瞬时上限：6 chip + 6 dust + 几 walk puff，但都很快自删）
	assert_lt(root.get_child_count(), 200, "粒子数不应失控")


func test_player_moving_60_frames():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	await wait_frames(2)
	Input.action_press("move_right")
	await wait_frames(60)
	Input.action_release("move_right")
	# 没崩就行
	assert_not_null(main.get_node_or_null("World"))
```

- [ ] **Step 2: 跑测试**

Run:
```bash
timeout 180 godot --headless -d -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json 2>&1 | tail -15
```

Expected: 累计 `57 passed, 0 failed`。

- [ ] **Step 3: 提交**

```bash
git add tests/integration/test_smoke_p1_5.gd
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "test(integration): P1.5 长跑 smoke - 600 帧无 crash + 粒子数有界"
```

- [ ] **Step 4: 更新顶层 spec §18**

修改 `/workspace/teilaruia/docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md`，§18 段把 P1 行下方加 P1.5：

把：
```
- ✅ P1 Foundation — `tag demo-p1-foundation` — 2026-05-17
  - GUT 9.3.0 接入 + 23 个自动化测试通过
  ...
- ⏳ P2 Items & Interaction — 待开始
```

改成：
```
- ✅ P1 Foundation — `tag demo-p1-foundation` — 2026-05-17
  - GUT 9.3.0 接入 + 23 个自动化测试通过
  ...
- ✅ P1.5 Atmosphere & Feel — `tag demo-p1.5-feel` — 2026-05-18
  - 视差云 3 层 + 玩家 jump/land/walk 尘埃
  - Effects autoload（block_break/place_bounce/jump_dust/land_dust/walk_puff）
  - CrackOverlay 挖进度裂纹 4 阶段框架
  - FloatingPrompt 「按 E」提示框架
  - 57 个测试全过
  - P2 接 5 个 hook 即可接通 mining/place 的视觉反馈
- ⏳ P2 Items + Interaction + Crafting — 待开始
```

- [ ] **Step 5: 提交 spec 更新 + 打 tag**

```bash
git add docs/superpowers/specs/2026-05-17-teilaruia-demo-design.md
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" commit -m "docs: 标记 P1.5 Atmosphere & Feel 完成"
git -c user.name="Duke Aguirre" -c user.email="Duke_Aguirredlz@greenmail.net" tag -a demo-p1.5-feel -m "Demo P1.5 完成: 视差云 + 玩家尘埃 + Effects/CrackOverlay/FloatingPrompt 框架"
git log --oneline | head -20
```

---

## Spec Coverage Check

对 spec `2026-05-18-teilaruia-demo-p1-5-atmosphere-feel-design.md`：
- §2.1 视差云 → Task 9, 10 ✅
- §2.1 玩家尘埃 → Task 11 ✅
- §2.1 块破碎粒子 → Task 4 ✅
- §2.1 挖进度裂纹 → Task 7 ✅
- §2.1 块放下弹动 → Task 6 ✅
- §2.1 交互提示浮标 → Task 8, 12 ✅
- §2.3 P2 API 承诺 → Task 3, 4, 5, 6, 7, 8 ✅
- §3 文件结构 → Task 1-9 涵盖 ✅
- §4 数据流 → Task 4, 5, 7, 9, 11, 12 ✅
- §5 测试矩阵 → Task 3, 7, 8, 9, 11, 12, 13 ✅
- §6 验收 → Task 13 ✅
- §8 P2 衔接 → 5 hook 已留接口 ✅

---

## 验收门禁

每 task：
1. GUT 全测试通过
2. `godot --headless` 无 error
3. git 干净

P1.5 整体：tag `demo-p1.5-feel` + 累计 57 个测试通过 + spec §18 更新。
