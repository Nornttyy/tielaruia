# 史莱姆等级系统 实现计划（颜色 tier + 大小分裂）

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:subagent-driven-development 或 executing-plans。步骤用 `- [ ]`。

**Goal:** 普通史莱姆加 4 色等级（按深度刷, 越深越强, 用 modulate 染色）+ 3 档大小（大打死裂成同色小）。

**Architecture:** `slime.gd` 加 `color_tier`/`size` + `setup()` + 纯静态 `color_for_depth()`（可单测）+ `_die` 分裂。`world.gd` 刷怪用 `color_for_depth` 给颜色（地表 70绿/30蓝, 地下按深度红/紫）。颜色纯 `sprite.modulate` 染（不重画 pattern）。

**Tech Stack:** Godot 4.3 + GDScript, GUT。无 GUI 靠测试。

**对应 spec:** `docs/superpowers/specs/2026-06-03-slime-tiers-design.md`。在 `sky-island` 隔间分支做。**不碰** king_slime.gd / 王冠 / slime_art pattern（别的窗口的活）。

---

## 文件清单

| 文件 | 改动 |
|---|---|
| `scripts/entities/slime.gd` | 加 color/size 字段 + 常量表 + `color_for_depth()` 静态 + `setup()` + `_apply_tier()` + `contact_damage` 变量 + tier-tint 受击恢复 + `_die` 分裂 + SlimeScene preload |
| `scripts/world/world.gd` | `_spawn_surface_creature` 返回 creature; `_try_spawn_slime` 设颜色/大小; 新增地下刷史莱姆 |
| `tests/unit/test_slime_tiers.gd` | 新建 |
| `tests/integration/test_slime_split.gd` | 新建 |

**跑测试：** `godot --headless -s addons/gut/gut_cmdln.gd -gselect=<file>.gd -gexit`

---

## Task 1: 颜色/大小常量表 + `color_for_depth()` 静态 helper

**Files:** `scripts/entities/slime.gd`、`tests/unit/test_slime_tiers.gd`(新建)

- [ ] **Step 1: 失败测试** — 新建 `tests/unit/test_slime_tiers.gd`：
```gdscript
extends GutTest

const Slime = preload("res://scripts/entities/slime.gd")

func _rng(v: float) -> RandomNumberGenerator:
	# 固定 seed 让 randf 可预测; 用不同 seed 凑出 <0.7 / >=0.7
	var r := RandomNumberGenerator.new()
	r.seed = 12345
	return r

func test_color_for_depth_bands():
	var r := RandomNumberGenerator.new(); r.seed = 1
	# 地表(<8): 绿(0)或蓝(1)
	assert_true(Slime.color_for_depth(0, r) in [0, 1], "地表是绿或蓝")
	# 浅地下 8-80: 蓝(1)
	assert_eq(Slime.color_for_depth(40, r), 1, "浅地下蓝")
	# 深 80-150: 红(2)
	assert_eq(Slime.color_for_depth(120, r), 2, "深地下红")
	# 极深 >=150: 紫(3)
	assert_eq(Slime.color_for_depth(200, r), 3, "极深紫")

func test_surface_green_majority():
	# 地表大量采样: 绿应占多数 (~70%)
	var r := RandomNumberGenerator.new(); r.seed = 99
	var green := 0
	for i in 400:
		if Slime.color_for_depth(0, r) == 0:
			green += 1
	assert_gt(green, 220, "地表绿占多数 (>55%%), 实际 %d/400" % green)
	assert_lt(green, 340, "地表也有蓝 (<85%%), 实际 %d/400" % green)
```

- [ ] **Step 2: 跑测试确认失败**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_slime_tiers.gd -gexit`
Expected: FAIL（`color_for_depth` 不存在）

- [ ] **Step 3: 加常量表 + 静态 helper** — `slime.gd` 在 `const TILE_SIZE := 12` 行后加：
```gdscript

const SlimeScene = preload("res://scenes/entities/slime.tscn")  # 分裂用 (自引用 preload, Godot 允许)

# 颜色 tier 0绿/1蓝/2红/3紫: modulate 染色(乘色, 蓝=原色不染) + HP/伤害乘数 + 掉 jelly 数.
const _COLOR_TINT := [Color(0.55, 1.25, 0.55), Color(1, 1, 1), Color(1.5, 0.55, 0.55), Color(1.2, 0.6, 1.5)]
const _COLOR_HP_MULT := [0.6, 1.0, 1.8, 2.8]
const _COLOR_DMG_MULT := [0.7, 1.0, 1.5, 2.2]
const _COLOR_JELLY := [1, 1, 2, 3]
# 大小 0小/1中/2大: sprite scale + HP/伤害乘数.
const _SIZE_SCALE := [0.65, 1.0, 1.5]
const _SIZE_HP_MULT := [0.5, 1.0, 1.5]
const _SIZE_DMG_MULT := [0.8, 1.0, 1.2]


# 按"地表下深度 (玩家/spawn tile_y - 地表 surf)" 选颜色. rng 让地表绿/蓝按概率.
# 地表(<8): 70% 绿 / 30% 蓝. 浅(8-80): 蓝. 深(80-150): 红. 极深(>=150): 紫.
static func color_for_depth(depth_below_surf: int, rng: RandomNumberGenerator) -> int:
	if depth_below_surf < 8:
		return 0 if rng.randf() < 0.7 else 1
	elif depth_below_surf < 80:
		return 1
	elif depth_below_surf < 150:
		return 2
	return 3
```

- [ ] **Step 4: 跑测试确认通过** — Expected: 2/2 PASS

- [ ] **Step 5: 提交**
```bash
git add scripts/entities/slime.gd tests/unit/test_slime_tiers.gd
git commit -m "feat(slime): 颜色 tier 常量表 + color_for_depth 静态 helper (史莱姆等级第1步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: `setup(color, size)` + `_apply_tier()`（属性/染色/缩放）+ contact_damage 变量

**Files:** `scripts/entities/slime.gd`、`tests/unit/test_slime_tiers.gd`

- [ ] **Step 1: 失败测试** — `test_slime_tiers.gd` 末尾加：
```gdscript
func test_setup_applies_tier_and_size():
	var s = Slime.new()
	s.setup(3, 2)   # 紫 + 大
	add_child_autofree(s)
	await wait_frames(1)
	assert_eq(s.color_tier, 3, "紫")
	assert_eq(s.size, 2, "大")
	# 紫大: HP = 25 * 2.8(紫) * 1.5(大) * 难度. 普通难度=1 → ~105. 远大于基础蓝中 25.
	assert_gt(s.max_health, 80, "紫大史莱姆血厚, 实际 %d" % s.max_health)
	assert_gt(s.contact_damage, 6, "紫大接触伤 > 基础6, 实际 %d" % s.contact_damage)
	assert_almost_eq(s.sprite.scale.x, 1.5, 0.01, "大史莱姆 scale 1.5")

func test_setup_default_is_blue_medium():
	var s = Slime.new()
	add_child_autofree(s)   # 不调 setup → 默认蓝中 (向后兼容旧 spawn)
	await wait_frames(1)
	assert_eq(s.color_tier, 1, "默认蓝")
	assert_eq(s.size, 1, "默认中")
	assert_almost_eq(s.sprite.scale.x, 1.0, 0.01, "中 scale 1.0")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: FAIL（`color_tier`/`setup` 不存在）

- [ ] **Step 3: 加字段 + setup + _apply_tier** — `slime.gd`：
  - 字段区（`var current_health` 附近）加：
    ```gdscript
	var color_tier: int = 1   # 0绿/1蓝/2红/3紫, 默认蓝 (不调 setup = 旧行为)
	var size: int = 1         # 0小/1中/2大, 默认中
	var contact_damage: int = CONTACT_DAMAGE   # _apply_tier 按 tier 缩放; 旧 CONTACT_DAMAGE 常量保留当基准
	var _base_tint: Color = Color(1, 1, 1)     # tier 染色; 受击闪光后恢复到它
    ```
  - 加 setup（spawn/分裂时 instantiate 后、add_child 前调）:
    ```gdscript
	# spawn / 分裂时设颜色+大小. 必须在 add_child(_ready) 之前调.
	func setup(p_color: int, p_size: int) -> void:
		color_tier = clampi(p_color, 0, 3)
		size = clampi(p_size, 0, 2)
    ```
  - `_ready()` 里, 把现有 `max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))` + `current_health = max_health` 两行**替换成** `_apply_tier()`（在 `sprite.sprite_frames = ...` 之前调, 因为 _apply_tier 要设 sprite.modulate/scale — 确保 sprite @onready 已就绪, 即放在 _ready 体内、sprite 已可用处）。新增方法:
    ```gdscript
	# 按 color_tier + size 算 HP/接触伤 + 染色 + 缩放. _ready 调.
	func _apply_tier() -> void:
		var hp_f: float = float(BASE_MAX_HEALTH) * _COLOR_HP_MULT[color_tier] * _SIZE_HP_MULT[size]
		max_health = max(1, int(round(hp_f * GameSettings.enemy_hp_multiplier())))
		current_health = max_health
		contact_damage = max(1, int(round(float(CONTACT_DAMAGE) * _COLOR_DMG_MULT[color_tier] * _SIZE_DMG_MULT[size])))
		_base_tint = _COLOR_TINT[color_tier]
		sprite.modulate = _base_tint
		sprite.scale = Vector2(_SIZE_SCALE[size], _SIZE_SCALE[size])
    ```
    在 `_ready()` 里调用（紧接 `sprite.play("idle")` 后）：`_apply_tier()`
  - 受击闪光恢复 tier 染色: 找 `_physics_process` 里 `sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE`，把 `Color.WHITE` 改成 `_base_tint`。
  - 接触伤用变量: `_check_player_contact` 里 `hp.take_damage(CONTACT_DAMAGE, ...)` 改成 `hp.take_damage(contact_damage, ...)`。

> 注：`_apply_tier` 用 `sprite`, 它是 `@onready`。`_ready` 体内 sprite 已就绪, 放 `sprite.play("idle")` 后 OK。`setup` 只设 int 字段, 不碰 sprite (此时可能还没 _ready), 安全。

- [ ] **Step 4: 跑测试确认通过** — Expected: 4/4 (含 Task1 的 2) PASS

- [ ] **Step 5: 提交**
```bash
git add scripts/entities/slime.gd tests/unit/test_slime_tiers.gd
git commit -m "feat(slime): setup(color,size) + 按 tier 缩放属性/染色/体型 (史莱姆等级第2步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: `_die()` 分裂（大→2中→2小, 同色）+ 按色掉 jelly

**Files:** `scripts/entities/slime.gd`、`tests/integration/test_slime_split.gd`(新建)

- [ ] **Step 1: 失败测试** — 新建 `tests/integration/test_slime_split.gd`：
```gdscript
# 史莱姆分裂: 大/中打死裂成 2 只同色小一档; 小不裂.
extends GutTest

const Slime = preload("res://scripts/entities/slime.gd")

func _count_slimes() -> int:
	return get_tree().get_nodes_in_group("slimes").size()

func test_large_splits_into_two_medium():
	var s = Slime.new()
	s.setup(2, 2)   # 红 + 大
	add_child_autofree(s)
	await wait_frames(2)
	var before: int = _count_slimes()
	s.take_damage(99999)   # 一击毙
	await wait_frames(3)   # 等分裂 spawn + 大史莱姆 queue_free
	var after: int = _count_slimes()
	# 大死了(-1) 但裂出 2 中(+2) → 净 +1
	assert_eq(after, before + 1, "大史莱姆裂成 2 只 (净 +1). before=%d after=%d" % [before, after])
	# 裂出的是同色(红) size=1(中)
	for n in get_tree().get_nodes_in_group("slimes"):
		if n != s and is_instance_valid(n):
			assert_eq(n.color_tier, 2, "裂出的也是红")
			assert_eq(n.size, 1, "裂出的是中")

func test_small_does_not_split():
	var s = Slime.new()
	s.setup(1, 0)   # 蓝 + 小
	add_child_autofree(s)
	await wait_frames(2)
	var before: int = _count_slimes()
	s.take_damage(99999)
	await wait_frames(3)
	assert_eq(_count_slimes(), before - 1, "小史莱姆死了不裂 (净 -1)")
```

- [ ] **Step 2: 跑测试确认失败** — Expected: FAIL（无分裂, 大死了净 -1 不是 +1）

- [ ] **Step 3: 改 `_die()` + 加 `_split()`** — `slime.gd` 的 `_die()` 改成（按色掉 jelly + 分裂）:
```gdscript
func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 按颜色 tier 掉 slime_jelly
	for i in _COLOR_JELLY[color_tier]:
		_spawn_drop("slime_jelly")
	# 大/中: 裂成 2 只同色小一档 (小不裂)
	if size > 0:
		_split()
	queue_free()


# 在死亡点附近 spawn 2 只同色 size-1 的史莱姆, 给点散开横速 (像泰拉瑞亚炸开).
func _split() -> void:
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	if entities == null:
		return
	for i in 2:
		var child = SlimeScene.instantiate()
		child.setup(color_tier, size - 1)
		entities.add_child(child)
		child.global_position = global_position + Vector2(randf_range(-6.0, 6.0), -4.0)
		if "velocity" in child:
			child.velocity = Vector2(randf_range(-50.0, 50.0), -130.0)   # 弹开
```

> 联机：分裂只在 host/单机跑（`_die` 已在 host 权威路径；client 端 slime `has_meta("is_remote")` 不跑 AI/死亡逻辑, 由 host 同步）。沿用现有约定, 不额外处理。

- [ ] **Step 4: 跑测试确认通过**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_slime_split.gd -gexit`
Expected: 2/2 PASS

- [ ] **Step 5: 提交**
```bash
git add scripts/entities/slime.gd tests/integration/test_slime_split.gd
git commit -m "feat(slime): 大史莱姆打死分裂成 2 只同色小一档 + 按色掉 jelly (史莱姆等级第3步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: 地表刷怪给颜色(70绿/30蓝) + 随机大小

**Files:** `scripts/world/world.gd`、`tests/unit/test_slime_tiers.gd`

- [ ] **Step 1: 失败测试** — `test_slime_tiers.gd` 末尾加（测刷怪用的"地表颜色/大小"纯逻辑——把它做成 slime.gd 的静态 helper 才好测）:
```gdscript
func test_random_size_in_range():
	var r := RandomNumberGenerator.new(); r.seed = 7
	for i in 50:
		var sz := Slime.random_spawn_size(r)
		assert_true(sz in [0, 1, 2], "大小 0/1/2, 实际 %d" % sz)
```

- [ ] **Step 2: 跑测试确认失败** — Expected: `random_spawn_size` 不存在

- [ ] **Step 3a: slime.gd 加 random_spawn_size 静态** — `color_for_depth` 后加：
```gdscript
# 刷怪随机大小: 40% 大 / 40% 中 / 20% 小 (偏大给分裂乐趣).
static func random_spawn_size(rng: RandomNumberGenerator) -> int:
	var r: float = rng.randf()
	if r < 0.40:
		return 2
	elif r < 0.80:
		return 1
	return 0
```

- [ ] **Step 3b: world.gd `_spawn_surface_creature` 返回 creature** — 把签名 `-> void` 改 `-> Node`，函数末尾 `entities_root.add_child(creature)\n\t\treturn` 改成 `entities_root.add_child(creature)\n\t\treturn creature`，并在函数最后（10 次都没找到位置）`return null`。即：
```gdscript
		entities_root.add_child(creature)
		return creature
	return null
```
（其他调用者如 `_try_spawn_zombie` 忽略返回值, 不受影响。）

- [ ] **Step 3c: world.gd `_try_spawn_slime` 设颜色/大小**：
```gdscript
func _try_spawn_slime() -> void:
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES:
		return
	var s = _spawn_surface_creature(SlimeScene)
	if s != null and s.has_method("setup"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		# 地表深度≈0 → color_for_depth 给 70绿/30蓝
		s.setup(SlimeScene_color_helper(rng), s.random_spawn_size(rng))
```
> 注：上面 `SlimeScene_color_helper` 是占位——实际直接用 slime 的静态: 加一行 `const SlimeClass = preload("res://scripts/entities/slime.gd")` 到 world.gd 顶部 const 区，然后 `s.setup(SlimeClass.color_for_depth(0, rng), SlimeClass.random_spawn_size(rng))`。改成：
```gdscript
func _try_spawn_slime() -> void:
	var slimes := get_tree().get_nodes_in_group("slimes")
	if slimes.size() >= MAX_SLIMES:
		return
	var s = _spawn_surface_creature(SlimeScene)
	if s != null and s.has_method("setup"):
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		s.setup(SlimeClass.color_for_depth(0, rng), SlimeClass.random_spawn_size(rng))
```
world.gd 顶部 const 区（`const SlimeScene = preload(...)` 附近）加：
```gdscript
const SlimeClass = preload("res://scripts/entities/slime.gd")
```

- [ ] **Step 4: 跑测试确认通过** — Expected: test_slime_tiers 全过（含 random_size）

- [ ] **Step 5: 提交**
```bash
git add scripts/entities/slime.gd scripts/world/world.gd tests/unit/test_slime_tiers.gd
git commit -m "feat(slime): 地表刷怪 70绿/30蓝 + 随机大小 (史莱姆等级第4步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: 地下按深度刷史莱姆（红/紫深处）

**Files:** `scripts/world/world.gd`、`tests/integration/test_slime_underground.gd`(新建)

地下刷史莱姆: 玩家在地下时（深度 ≥ 8 且没在地狱 y<220），timer 周期在玩家附近找一个 AIR + 下方实心地板的坑, 按该坑深度 `color_for_depth` 给颜色。

- [ ] **Step 1: 失败测试** — 新建 `tests/integration/test_slime_underground.gd`：
```gdscript
# 地下刷史莱姆: 玩家挖到深处, 周围能刷出对应颜色(红/紫)的史莱姆.
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const TILE_SIZE := 12

func test_underground_slime_spawns_colored_by_depth():
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game(2024)
	await wait_frames(15)
	var world = main.get_node("World")
	var player = world.get_player()
	assert_not_null(player)
	# 把玩家瞬移到深地下 (surf~115 下方 100 格 ≈ 红区), 清个站脚坑
	var deep_tile_y := 215   # 深 (>surf+80 红, <220 非地狱)
	player.global_position = Vector2(0 * TILE_SIZE + 6, deep_tile_y * TILE_SIZE)
	world._ensure_air_pocket(0, deep_tile_y)
	await wait_frames(2)
	# 直接调地下刷怪函数 (绕过 timer), 多试几次提高命中
	var spawned_colored := false
	for i in 20:
		world._try_spawn_underground_slime()
		await wait_frames(1)
	for n in get_tree().get_nodes_in_group("slimes"):
		if is_instance_valid(n) and "color_tier" in n and n.color_tier >= 2:
			spawned_colored = true
	assert_true(spawned_colored, "深地下应刷出红/紫(tier>=2)史莱姆")
```
> 若该测试因找坑随机性偶发不稳, 放宽: 断言"地下刷出了任意史莱姆"或增大重试次数。重点验证 `_try_spawn_underground_slime` 能在地下刷出按深度上色的史莱姆。

- [ ] **Step 2: 跑测试确认失败** — Expected: `_try_spawn_underground_slime` 不存在

- [ ] **Step 3: world.gd 加地下刷怪** — 加函数（放 `_try_spawn_slime` 附近）：
```gdscript
const UNDERGROUND_SLIME_MAX := 6   # 地下史莱姆上限 (跟地表 MAX_SLIMES 分开)

# 地下刷史莱姆: 玩家在地下(深度>=8, 非地狱)时, 附近找 AIR+地板坑, 按深度上色刷.
func _try_spawn_underground_slime() -> void:
	var player := get_player()
	if player == null:
		return
	if get_tree().get_nodes_in_group("slimes").size() >= UNDERGROUND_SLIME_MAX + MAX_SLIMES:
		return
	var px: int = int(floor(player.global_position.x / TILE_SIZE))
	var py: int = int(floor(player.global_position.y / TILE_SIZE))
	if py >= 220:
		return   # 地狱不刷史莱姆
	# 玩家附近找坑: AIR 格, 下面实心地板, 在玩家深度附近
	for _i in 12:
		var sign_x: int = 1 if randf() < 0.5 else -1
		var cand_x: int = px + sign_x * randi_range(SPAWN_RANGE_MIN, SPAWN_RANGE_MAX)
		var cand_y: int = py + randi_range(-3, 3)
		if cand_y < 4 or cand_y >= 218:
			continue
		if chunk_manager.get_tile(cand_x, cand_y) != Tiles.AIR:
			continue
		if chunk_manager.get_tile(cand_x, cand_y - 1) != Tiles.AIR:
			continue
		var floor_tile: int = chunk_manager.get_tile(cand_x, cand_y + 1)
		if floor_tile == Tiles.AIR or floor_tile == Tiles.BEDROCK:
			continue
		# 算深度: cand_y - 该列地表 surf
		var surf_y: int = _surf_at_x(cand_x)
		var depth: int = cand_y - surf_y
		if depth < 8:
			continue   # 太浅算地表, 交给地表刷
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		var s = SlimeScene.instantiate()
		s.setup(SlimeClass.color_for_depth(depth, rng), SlimeClass.random_spawn_size(rng))
		s.global_position = Vector2(cand_x * TILE_SIZE + TILE_SIZE / 2.0, cand_y * TILE_SIZE + TILE_SIZE)
		entities_root.add_child(s)
		return


# 取某列地表 y (扫第一个非 AIR). 给地下深度算用.
func _surf_at_x(tx: int) -> int:
	for y in ChunkConstants.WORLD_HEIGHT:
		if chunk_manager.get_tile(tx, y) != Tiles.AIR:
			return y
	return ChunkConstants.WORLD_HEIGHT / 2
```

- [ ] **Step 4: 接到 timer** — `_process` 里现有刷怪段（`if TimeOfDay.is_night(): _try_spawn_zombie() else: _try_spawn_slime()`）改成: 玩家在地下也刷地下史莱姆。改成：
```gdscript
			var _player := get_player()
			var _py: int = int(floor(_player.global_position.y / TILE_SIZE)) if _player != null else 0
			var _surf: int = _surf_at_x(int(floor(_player.global_position.x / TILE_SIZE))) if _player != null else 0
			if _player != null and (_py - _surf) >= 8 and _py < 220:
				_try_spawn_underground_slime()   # 地下: 不分昼夜, 刷按深度上色的史莱姆
			elif TimeOfDay.is_night():
				_try_spawn_zombie()
			else:
				_try_spawn_slime()
```

- [ ] **Step 5: 跑测试确认通过** — Expected: PASS（地下刷出 tier≥2）

- [ ] **Step 6: 全套 unit 回归 + 提交**
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit/ -ginclude_subdirs=false -gexit`
Expected: 只有已知预存失败（iron_ingot 等），无新增。
```bash
git add scripts/world/world.gd tests/integration/test_slime_underground.gd
git commit -m "feat(slime): 地下按深度刷红/紫史莱姆 (史莱姆等级第5步)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: 收尾验收

- [ ] **Step 1: 全套 unit + 相关集成** — test_slime_tiers / test_slime_split / test_slime_underground 全过；test_smoke 不崩。
- [ ] **Step 2: 报告** — 3-5 行（颜色 tier + 分裂 + 刷怪做了啥 + commit + 累计测试数）。
- [ ] **Step 3: 合并 + push**（merge-tree 干跑 → 主树合并/branch:main → 验证 → push 部署）。

---

## Self-Review（已核对）

- **Spec 覆盖**：4 色按深度（color_for_depth, Task1/4/5）✅；染色 modulate（_apply_tier, Task2）✅；HP/伤害按 tier（_apply_tier）✅；大小 3 档 + scale（Task2）✅；大→分裂（_die/_split, Task3）✅；按色掉 jelly（Task3）✅；地表 70/30（Task4）✅；地下按深度刷（Task5）✅；不碰 king/王冠/pattern（全程只动 slime.gd 实例染色 + world 刷怪）✅。
- **占位符**：Task4 Step3c 把占位 `SlimeScene_color_helper` 明确改成 `SlimeClass.color_for_depth`，已无占位。
- **命名一致**：`color_tier`/`size`/`setup`/`_apply_tier`/`color_for_depth`/`random_spawn_size`/`contact_damage`/`_base_tint`/`_split`/`SlimeClass`/`_try_spawn_underground_slime`/`_surf_at_x` 全程一致。
- **风险点**：① modulate 从蓝底乘绿/紫可能偏闷 → 实现时看 build_atlas 出图调 tint 值（spec 已留"太丑退 palette"后路, 但优先 modulate）。② 地下刷怪找坑随机 → 测试用重试 + 放宽断言。③ world.gd / slime.gd 若跟改剑/王的窗口撞, merge 前 `git merge-tree` 干跑, branch:main 推。④ `_apply_tier` 替换 `_ready` 原 max_health 两行——确认只替换那两行, 别动难度缩放语义 (已包进 _COLOR/_SIZE 乘数 × enemy_hp_multiplier)。
