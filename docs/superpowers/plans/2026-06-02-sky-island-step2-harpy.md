# 空岛群系 · 第 2 步实现计划（哈比鸟 + 羽毛）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development 或 executing-plans。步骤用 `- [ ]`。

**Goal:** 在空岛附近天空加一只会飞的新怪「哈比鸟」，巡逻+俯冲撞玩家，死了掉「羽毛」(feather)；羽毛为第 3 步云靴的合成材料做准备。

**Architecture:** `harpy.gd` 完全仿 `hell_wasp.gd`（飞行 CharacterBody2D + 巡逻/冲刺 AI + take_damage + `_die` 掉落 + 不跟玩家碰撞 + host 死亡同步）。生成仿 `mummy`/`spider`：worldgen 在空岛上方记 `harpy_spawn_spots` → `chunk_manager` 加载时 → `world.spawn_harpies_for_chunk`（dedup）。`feather` 物品仿 `spider_eye`（非方块 item + `items_art` 图标）。

**Tech Stack:** Godot 4.3 + GDScript，GUT。无 GUI，靠测试验收。

**对应 spec:** `docs/superpowers/specs/2026-06-02-sky-island-biome-design.md`（第 2 步）。在 `sky-island` 隔间分支做，基于第 1 步 + 最新 main。

---

## 文件清单

| 文件 | 改动 |
|---|---|
| `scripts/items/item_db.gd` | `_DEFS` 加 `"feather"` |
| `scripts/ui/crafting_panel.gd` | `_ZH_NAMES` 加 `"feather": "羽毛"` |
| `scripts/art/items_art.gd` | `_ICONS` 加 `"feather": _FEATHER` + `_FEATHER` 图案 |
| `scripts/art/harpy_art.gd` | 新建：哈比鸟 2 帧 SpriteFrames |
| `scripts/autoload/art_cache.gd` | 加 `var harpy_frames` + `_build_entities` 里 build + preload const |
| `scripts/entities/harpy.gd` | 新建：飞行怪脚本（仿 hell_wasp） |
| `scenes/entities/harpy.tscn` | 新建：CharacterBody2D + AnimatedSprite2D + CollisionShape2D |
| `scripts/world/chunk.gd` | 加 `var harpy_spawn_spots: Array = []` |
| `scripts/world/chunk_manager.gd` | 加载 chunk 时调 `spawn_harpies_for_chunk` |
| `scripts/world/world.gd` | 加 `HarpyScene` preload + `_harpy_chunks_spawned` + `spawn_harpies_for_chunk` |
| `scripts/world/world_generator.gd` | `_place_sky_island_chunk` 末尾 append `harpy_spawn_spots` |
| `tests/unit/test_harpy.gd` | 新建 |

**跑测试：** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=<file>.gd -gexit`（`-gselect` 跑单文件；gutconfig 强制 dirs，`-gtest` 不 scope）。`.godot` 已从主树复制好。

---

## Task 1: 羽毛 feather 物品 + 中文名 + 图标

**Files:** `scripts/items/item_db.gd`、`scripts/ui/crafting_panel.gd`、`scripts/art/items_art.gd`、`tests/unit/test_harpy.gd`(新建)

- [ ] **Step 1: 失败测试** — 新建 `tests/unit/test_harpy.gd`：

```gdscript
extends GutTest

const ItemsArt = preload("res://scripts/art/items_art.gd")

func test_feather_item_def():
	var def = ItemDB.get_def("feather")
	assert_not_null(def, "feather 物品存在")
	assert_eq(def["placeable_tile_id"], -1, "羽毛不是方块")

func test_feather_has_icon():
	assert_true(ItemsArt.has_icon("feather"), "羽毛有图标")
	var tex = ItemsArt.get_icon("feather")
	assert_eq(tex.get_image().get_width(), 16, "图标 16 宽")
```

- [ ] **Step 2: 跑测试确认失败**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_harpy.gd -gexit`
Expected: FAIL（feather def null / 无 icon）

- [ ] **Step 3: 加 feather 物品 + 中文名**
`item_db.gd` 在 `"spider_eye": {...}` 行后加：
```gdscript
	"feather":       {"placeable_tile_id": -1,                     "tool_kind": "",        "tool_tier": 0, "max_stack": 99},
```
`crafting_panel.gd` 的 `_ZH_NAMES` 加：
```gdscript
	"feather": "羽毛",
```

- [ ] **Step 4: 加 feather 图标**
`items_art.gd` 在 `_ICONS := {` 前加图案（用现有 PALETTE 的 j=骨白/w=羊毛阴影/k=深褐/n=黑）：
```gdscript
const _FEATHER := [
	"................",
	".......jn.......",
	"......jwwn......",
	"......jwwn......",
	".....jjwwn......",
	".....jwwkn......",
	"....jjwwkn......",
	"....jwwwkn......",
	"...jjwwwkn......",
	"...jwwwwkn......",
	"...jwwwkn.......",
	"....jwwkn.......",
	".....jwkn.......",
	"......jkn.......",
	".......kn.......",
	"......n.........",
]
```
`_ICONS` 字典里（`"spider_eye": _SPIDER_EYE,` 附近）加：
```gdscript
	"feather": _FEATHER,
```

- [ ] **Step 5: 跑测试确认通过** — Expected: PASS（2/2）

- [ ] **Step 6: 提交**
```bash
git add scripts/items/item_db.gd scripts/ui/crafting_panel.gd scripts/art/items_art.gd tests/unit/test_harpy.gd
git commit -m "feat(item): 羽毛 feather 物品+中文名+图标 (空岛第2步, 哈比鸟掉落物)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: 哈比鸟美术（2 帧 SpriteFrames）

**Files:** `scripts/art/harpy_art.gd`(新建)、`scripts/autoload/art_cache.gd`、`tests/unit/test_harpy.gd`

- [ ] **Step 1: 失败测试** — `test_harpy.gd` 末尾加：
```gdscript
func test_harpy_frames_built():
	assert_not_null(ArtCache.harpy_frames, "哈比鸟 SpriteFrames 已建")
	assert_true(ArtCache.harpy_frames.has_animation("move"), "有 move 动画")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: `harpy_frames` null

- [ ] **Step 3: 建 harpy_art.gd**（仿 hell_wasp_art：暖色白棕鸟，2 帧拍翅）新建 `scripts/art/harpy_art.gd`：
```gdscript
# 哈比鸟 (Harpy): 天空浮岛附近飞行怪. 白羽身 + 棕翼 + 黄喙. 2 帧拍翅 (上/下).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(45, 33, 26),     # 黑褐描边
	"w": Color8(245, 240, 230),  # 白羽主
	"W": Color8(208, 196, 178),  # 白羽阴影
	"t": Color8(184, 140, 92),   # 棕翼
	"T": Color8(140, 100, 62),   # 棕翼深
	"y": Color8(245, 198, 70),   # 黄喙/爪
	"e": Color8(40, 30, 25),     # 眼
}

# 帧 0: 翅膀上扬
const _F0 := [
	"......nwwn......",
	".....nwwwwn.....",
	"..t..nwewen..t..",
	".tTn.nwyywn.nTt.",
	"tTTnnwwwwwwnnTTt",
	".tTnwwwWWwwwnTt.",
	"..nwwwWWWWwwwn..",
	"..nwwWWWWWWwwn..",
	"...nwwWWWWwwn...",
	"...nwwwwwwwwn...",
	"....nwwwwwwn....",
	".....nwwwwn.....",
	"......nyynn.....",
	".....ny..yn.....",
	"....ny....yn....",
	"................",
]

# 帧 1: 翅膀下压
const _F1 := [
	"......nwwn......",
	".....nwwwwn.....",
	".....nwewen.....",
	".....nwyywn.....",
	"..nnnwwwwwwnnn..",
	".tTnwwwWWwwwnTt.",
	"tTTwwwWWWWwwwTTt",
	".tTnwWWWWWWwnTt.",
	"..tnwwWWWWwwnt..",
	"...nwwwwwwwwn...",
	"....nwwwwwwn....",
	".....nwwwwn.....",
	"......nyynn.....",
	".....ny..yn.....",
	"....ny....yn....",
	"................",
]

static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0: ImageTexture = PixelArt.grid_to_texture(_F0, PALETTE)
	var t1: ImageTexture = PixelArt.grid_to_texture(_F1, PALETTE)
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 10.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, t0)
		sf.add_frame(anim, t1)
	return sf
```

- [ ] **Step 4: 接 art_cache** — `art_cache.gd`：
  - preload const 区（`const HellWaspArt = ...` 附近）加：`const HarpyArt = preload("res://scripts/art/harpy_art.gd")`
  - var 区（`var hell_wasp_frames: SpriteFrames` 附近）加：`var harpy_frames: SpriteFrames`
  - `_build_entities()` 里（`hell_wasp_frames = HellWaspArt.build_sprite_frames()` 后）加：
    ```gdscript
	# 哈比鸟: 天空浮岛飞行怪
	harpy_frames = HarpyArt.build_sprite_frames()
    ```

- [ ] **Step 5: 跑测试确认通过** — Expected: PASS

- [ ] **Step 6: 提交**
```bash
git add scripts/art/harpy_art.gd scripts/autoload/art_cache.gd tests/unit/test_harpy.gd
git commit -m "feat(art): 哈比鸟 2 帧贴图 + 接 ArtCache (空岛第2步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: 哈比鸟实体（harpy.gd + harpy.tscn）

**Files:** `scripts/entities/harpy.gd`(新建)、`scenes/entities/harpy.tscn`(新建)、`tests/unit/test_harpy.gd`

哈比鸟设定（仿 hell_wasp，调成天空版）：HP 24、接触伤 8、巡逻 55 / 冲刺 120、aggro 260px。死掉 1-2 feather。天空 despawn：飞到 spawn 下方 >100 tile（掉到地面附近）就消失；玩家 >600px 时 idle。

- [ ] **Step 1: 失败测试** — `test_harpy.gd` 末尾加：
```gdscript
const HarpyScene = preload("res://scenes/entities/harpy.tscn")

func test_harpy_instantiates_and_no_player_collision():
	var h = HarpyScene.instantiate()
	add_child_autofree(h)
	await wait_frames(2)
	assert_eq(h.collision_layer, 0, "哈比鸟 collision_layer=0 (玩家不被它挡)")
	assert_true(h.is_in_group("slimes"), "在通用敌人组 slimes (武器能打)")
	assert_true(h.is_in_group("harpies"), "在 harpies 组")

func test_harpy_drops_feather_on_death():
	var h = HarpyScene.instantiate()
	add_child_autofree(h)
	await wait_frames(2)
	h.take_damage(9999, Vector2.ZERO, 0.0)   # 一击毙
	await wait_frames(2)
	var drops = get_tree().get_nodes_in_group("item_drops")
	var has_feather := false
	for d in drops:
		if d.get("item_id") == "feather":
			has_feather = true
	assert_true(has_feather, "哈比鸟死了掉羽毛")
```
> 注：`add_child_autofree` / `wait_frames` 是 GUT 提供。`item_drops` 组名以 item_drop.tscn 实际为准——若 ItemDrop 不在该组，改测试为扫 entities_root 子节点 item_id。先 grep `add_to_group` in item_drop.gd 确认。

- [ ] **Step 2: 跑测试确认失败** — Expected: HarpyScene 加载失败 / 文件不存在

- [ ] **Step 3: 建 harpy.gd**（仿 hell_wasp.gd，复制后改：常量、掉落 feather、despawn 逻辑、组名）新建 `scripts/entities/harpy.gd`：
```gdscript
# 哈比鸟 (Harpy): 天空浮岛附近飞行怪. 看见玩家 260px 内俯冲撞过来, 撞 8 伤 + 击退.
# HP 24. 死了掉 1-2 feather. 仿 hell_wasp 但调成天空版 (despawn 看离 spawn 远近).
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 12
const BASE_MAX_HEALTH := 24
const CONTACT_DAMAGE := 8
const PATROL_SPEED := 55.0
const CHARGE_SPEED := 120.0
const AGGRO_RANGE_PX := 260.0
const ENEMY_IFRAME_SEC := 0.15
const DESPAWN_BELOW_TILES := 100   # 掉到 spawn 下方 100 tile (到地面了) → despawn

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _charge_target: Vector2 = Vector2.ZERO
var _charge_t: float = 0.0
var _charge_cooldown: float = 0.0
var _spawn_y_tile: int = -1

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	sprite.sprite_frames = ArtCache.harpy_frames
	sprite.play("move")
	add_to_group("harpies")
	add_to_group("slimes")
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		_check_player_contact()
		return
	if _is_dying:
		return
	if _spawn_y_tile < 0:
		_spawn_y_tile = int(floor(global_position.y / TILE_SIZE))
	# 天空 despawn: 掉到 spawn 下方太远 (到地面了)
	var y_tile: int = int(floor(global_position.y / TILE_SIZE))
	if y_tile > _spawn_y_tile + DESPAWN_BELOW_TILES:
		queue_free()
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	_charge_t = max(0.0, _charge_t - delta)
	_charge_cooldown = max(0.0, _charge_cooldown - delta)
	var player := _find_player()
	if player == null:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var dx0: float = player.global_position.x - global_position.x
	var dy0: float = player.global_position.y - global_position.y
	if dx0 * dx0 + dy0 * dy0 > 360000.0:   # 玩家 >600px → idle
		velocity = Vector2.ZERO
		return
	var dist: float = global_position.distance_to(player.global_position)
	if _charge_t > 0.0:
		var dir: Vector2 = (_charge_target - global_position).normalized()
		velocity = dir * CHARGE_SPEED
	elif dist <= AGGRO_RANGE_PX:
		if _charge_cooldown <= 0.0:
			_charge_target = player.global_position
			_charge_t = 0.6
			_charge_cooldown = 1.4
		else:
			var to_player: Vector2 = player.global_position - global_position
			var dir: Vector2 = to_player.normalized()
			velocity = Vector2(-dir.y, dir.x) * PATROL_SPEED
	else:
		velocity = Vector2.ZERO
	sprite.flip_h = velocity.x < 0
	move_and_slide()
	_check_player_contact()


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 10.0 or dy < -22.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 200.0)
	_charge_t = 0.0


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_cached_player = null
		return null
	_cached_player = players[0]
	return _cached_player


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0:
		return false
	if _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -8), actual_loss)
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var dir: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity = dir * knockback
		_charge_t = 0.0
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	for _i in randi_range(1, 2):
		_spawn_drop("feather")
	queue_free()


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-3.0, 3.0), -4.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)
```

- [ ] **Step 4: 建 harpy.tscn**（仿 hell_wasp.tscn；UID 用唯一串避免冲突）新建 `scenes/entities/harpy.tscn`：
```
[gd_scene load_steps=3 format=3 uid="uid://b_harpy_sky_2026"]

[ext_resource type="Script" path="res://scripts/entities/harpy.gd" id="1_harpy"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_harpy"]
size = Vector2(12, 10)

[node name="Harpy" type="CharacterBody2D"]
script = ExtResource("1_harpy")
collision_layer = 0
collision_mask = 3

[node name="AnimatedSprite2D" type="AnimatedSprite2D" parent="."]
position = Vector2(0, -6)
centered = true

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, -5)
shape = SubResource("RectangleShape2D_harpy")
```

- [ ] **Step 5: 跑测试确认通过** — Expected: PASS（实体生成、组、掉羽毛）

- [ ] **Step 6: 提交**
```bash
git add scripts/entities/harpy.gd scenes/entities/harpy.tscn tests/unit/test_harpy.gd
git commit -m "feat(entity): 哈比鸟实体 (飞行+俯冲, 掉羽毛, 不撞玩家) (空岛第2步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 生成接线（空岛上方刷哈比鸟）

**Files:** `scripts/world/chunk.gd`、`scripts/world/chunk_manager.gd`、`scripts/world/world.gd`、`scripts/world/world_generator.gd`、`tests/unit/test_harpy.gd`

- [ ] **Step 1: 失败测试** — `test_harpy.gd` 末尾加：
```gdscript
const WG = preload("res://scripts/world/world_generator.gd")

func test_sky_island_records_harpy_spots():
	var chunks = WG._sky_island_chunks(777)
	var c = WG.generate_chunk(777, chunks[0], 256)
	assert_gt(c.harpy_spawn_spots.size(), 0, "空岛 chunk 记了哈比鸟出生点")
	# 出生点在天空层 (y<60)
	for spot in c.harpy_spawn_spots:
		assert_lt(spot.y, 60, "哈比鸟出生点在天空层")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: `harpy_spawn_spots` 不存在（chunk.gd 没此字段）

- [ ] **Step 3: chunk.gd 加字段** — 在 `var mummy_spawn_spots: Array = []` 行后加：
```gdscript
var harpy_spawn_spots: Array = []    # 空岛上方哈比鸟出生点 (world tile 坐标)
```

- [ ] **Step 4: world_generator 记录出生点** — `_place_sky_island_chunk` 里，第 4 步「树」之后加（岛中心上方天空 1-2 只）：
```gdscript
	# 5) 哈比鸟出生点: 岛顶上方天空 (1-2 只), 记进 chunk 供 chunk_manager 召
	var harpy_count: int = rng.randi_range(1, 2)
	for hi in range(harpy_count):
		var hdx: int = rng.randi_range(-half + 3, half - 3)
		var hy: int = top_y - 6 - (hi * 2)   # 草顶上方 6+ 格的开阔天空
		if hy < 2:
			hy = 2
		c.harpy_spawn_spots.append(Vector2i(chunk_start + x_center_local + hdx, hy))
```

- [ ] **Step 5: world.gd 加 spawn 函数** — `HarpyScene` preload（`const HellWaspScene = ...` 附近）：
```gdscript
const HarpyScene = preload("res://scenes/entities/harpy.tscn")
```
dedup 字典 + 函数（仿 `spawn_mineshaft_spiders_for_chunk`，放它附近）：
```gdscript
# 空岛哈比鸟: 同款 spot→spawn 机制 (dedup, chunk 重载不重生)
var _harpy_chunks_spawned: Dictionary = {}   # chunk_x int → true
func spawn_harpies_for_chunk(chunk_x: int, spots: Array) -> void:
	if spots.is_empty():
		return
	if _harpy_chunks_spawned.has(chunk_x):
		return
	_harpy_chunks_spawned[chunk_x] = true
	for spot in spots:
		var creature := HarpyScene.instantiate()
		creature.global_position = Vector2(
			spot.x * TILE_SIZE + TILE_SIZE / 2.0,
			spot.y * TILE_SIZE + TILE_SIZE
		)
		entities_root.add_child(creature)
```

- [ ] **Step 6: chunk_manager 调用** — 在调 `spawn_mineshaft_spiders_for_chunk` 那段后面加同款：
```gdscript
	# 空岛哈比鸟: 同款机制
	if not c.harpy_spawn_spots.is_empty():
		var world_node4: Node = get_tree().get_first_node_in_group("world")
		if world_node4 != null and world_node4.has_method("spawn_harpies_for_chunk"):
			world_node4.spawn_harpies_for_chunk(cx, c.harpy_spawn_spots)
```

- [ ] **Step 7: 跑测试确认通过** — Expected: PASS

- [ ] **Step 8: 全套 unit 回归 + 提交**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -ginclude_subdirs=false -gexit`
Expected: 只有 3 个已知预存失败（iron_ingot/chunk delta/列200），无新增。
```bash
git add scripts/world/chunk.gd scripts/world/chunk_manager.gd scripts/world/world.gd scripts/world/world_generator.gd tests/unit/test_harpy.gd
git commit -m "feat(world): 空岛上方刷哈比鸟 (spot→spawn 接线, dedup) (空岛第2步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 收尾验收

- [ ] **Step 1: 全套 unit 测试** — 确认 test_harpy 全过 + 无新失败，记累计测试数。
- [ ] **Step 2: 集成冒烟** — `-gselect=test_smoke.gd`：游戏起、世界加载不崩。
- [ ] **Step 3: 报告** — 3-5 行（哈比鸟+羽毛做了啥 + commit SHA + 累计测试数）。

---

## Self-Review（已核对）

- **Spec 覆盖**：第 2 步「哈比鸟飞行 AI（仿 demon_eye/hell_wasp）」「掉 feather」「不跟玩家碰撞」「空岛生成记 harpy_spawn_spots，chunk_manager 召」「host 权威死亡同步」全有 Task。✅
- **占位符**：无 TBD；art 图案给了完整 16×16；harpy.gd 给全。
- **命名一致**：`harpy_frames` / `HarpyArt` / `HarpyScene` / `harpy_spawn_spots` / `spawn_harpies_for_chunk` / `_harpy_chunks_spawned` / `"harpies"`+`"slimes"` 组 / `"feather"` 全程一致。
- **风险点**：① `item_drops` 组名 / take_damage 一击毙的掉落落点——测试 Step 1 注里提示先 grep item_drop.gd 的 `add_to_group` 确认组名，不对就改测试扫 entities_root。② harpy.tscn 的 UID 必须唯一（`uid://b_harpy_sky_2026`），手写 .tscn 易踩 UID 冲突。③ 美术是占位暖色鸟，用户看到后可再调（feedback_warm_detailed_textures）。
