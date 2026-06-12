# 枪与法杖打磨 (Gun & Staff Polish) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 打磨现有 23 枪 + 20 法杖：修目标优先级/魔力折扣两个 bug、按枪配音效、枪口火光+震屏、闪电链电弧、强力枪命中特效、图标与投射物美术全面重画。

**Architecture:** 全部数据驱动 — 机制字段加在 `item_db.gd` 的 def 里（`gun_sfx`/`gun_shake`/`gun_impact`），运行时代码只在 `player_action.gd`/`bullet.gd`/`effects.gd`/`sfx_bank.gd` 各加一小段读字段的逻辑。美术 = 重画 `items_art.gd` 字符画与 `*_proj_art.gd` 像素图，渲染 PNG 给用户验收。

**Tech Stack:** Godot 4.3 / GDScript / GUT 9.x（headless）/ 程序化像素画 + 程序化合成音效

**Spec:** `docs/superpowers/specs/2026-06-12-gun-staff-polish-design.md`

---

## 仓库规矩（执行前必读）

1. 并发 session 有用户 WIP：**只 `git add <精确路径>`，禁止 `-am` / `-A` / `.`**
2. **禁止 `git commit --amend` / rebase**（并发 session 会插 commit）
3. 跑测试前若 `.godot/` 不存在：先 `godot --headless --editor --quit` 建 class_name 索引
4. `libfontconfig.so.1` 警告不是 error，过滤掉
5. 加 item 字段不用动 `_ZH_NAMES`（本计划不加新 item，只给现有 def 加字段）
6. 每完成一个 Task：给用户 3-5 行中文报告 + commit SHA + 累计测试数

测试命令模板：
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=<文件名>.gd -gexit
```

---

### Task 1: 追踪优先打敌对怪 + 魔法枪魔力折扣

**Files:**
- Modify: `scripts/entities/bullet.gd:234-246`（`_nearest_enemy`）
- Modify: `scripts/player/player_action.gd:1893-1898`（魔力路径）
- Modify: `tests/integration/test_magic_guns.gd:58`（魔力断言 96→98）
- Test: `tests/integration/test_gun_target_priority.gd`（新建）

注：spec 里 T1 的"连锁优先敌对怪"挪到本计划 Task 4 一起做（`_do_chain` 要重写成接力式，避免改两遍）。

- [ ] **Step 1: 写失败测试**

新建 `tests/integration/test_gun_target_priority.gd`：

```gdscript
# T1 验收: 追踪弹优先追敌对怪 (slimes), 没有敌对怪才追动物;
# 魔法枪魔力享受法杖同款折扣 (staff_mana_cost: 正常局半价).
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubMob:
	extends Node2D
	var hits: int = 0
	var grp: String = "slimes"
	func _init(g: String = "slimes") -> void:
		grp = g
	func _ready() -> void:
		add_to_group(grp)
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


func _stub(g: String, pos: Vector2) -> StubMob:
	var s := StubMob.new(g)
	add_child_autofree(s)
	s.global_position = pos
	return s


# 动物更近, 但有敌对怪在 → 追踪目标必须是敌对怪
func test_homing_prefers_hostile_over_closer_animal() -> void:
	var pig := _stub("animals", Vector2(40, 20))
	var zombie := _stub("slimes", Vector2(90, -30))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(120, 0), 5, null, 200.0, {"homing": 6.0})
	assert_eq(bullet._nearest_enemy(), zombie, "有敌对怪时该优先追敌对怪, 哪怕小猪更近")
	assert_eq(pig.hits, 0)


# 场上只有动物 → 退回追动物 (主动打猎仍可用)
func test_homing_falls_back_to_animal_when_no_hostile() -> void:
	var pig := _stub("animals", Vector2(40, 20))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(120, 0), 5, null, 200.0, {"homing": 6.0})
	assert_eq(bullet._nearest_enemy(), pig, "没敌对怪时退回追动物")


# 魔法枪魔力 = staff_mana_cost(base, false) (正常局半价, 至少 1)
func test_magic_gun_mana_discounted() -> void:
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(5)
	var world = main.get_node("World")
	var player = world.get_player()
	var inv = player.get_node("PlayerInventory")
	inv.pickup("lightning_gun", 1)   # mana_cost=5 → 折后 round(5*0.5)=3 (区分全价路径)
	inv.hotbar_selected = 0
	var mana = player.get_node("PlayerMana")
	mana.current_mana = 100
	var action = player.get_node("PlayerAction")
	action.mouse_world_override = player.global_position + Vector2(240, -12)
	action._try_fire_gun()
	await wait_frames(1)
	assert_eq(mana.current_mana, 97, "lightning_gun mana_cost=5, 折后该扣 3 (全价会扣 5)")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_target_priority.gd -gexit
```
预期：`test_homing_prefers_hostile_over_closer_animal` 失败（现在返回更近的猪）；`test_magic_gun_mana_discounted` 失败（现在扣全价 5，剩 95）。

- [ ] **Step 3: 改 `bullet.gd::_nearest_enemy`**

把 `scripts/entities/bullet.gd:234-246` 整个函数替换为：

```gdscript
# 找追踪目标: 敌对怪 (slimes) 优先, 一只都没有才考虑动物 — 追踪弹别丢下僵尸去追小猪.
func _nearest_enemy() -> Node2D:
	for group in ["slimes", "animals"]:
		var best: Node2D = null
		var best_d: float = INF
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
		if best != null:
			return best
	return null
```

- [ ] **Step 4: 改 `player_action.gd` 魔力路径**

`scripts/player/player_action.gd:1893-1898`，把：

```gdscript
	if mana_cost > 0:
		var mana_n: Node = get_parent().get_node_or_null("PlayerMana")
		if mana_n == null or not mana_n.has_method("try_consume"):
			return
		if not mana_n.try_consume(mana_cost):
			return   # 魔力不够 → 不发, 不进 cooldown
```

改成：

```gdscript
	if mana_cost > 0:
		var mana_n: Node = get_parent().get_node_or_null("PlayerMana")
		if mana_n == null or not mana_n.has_method("try_consume"):
			return
		# 魔法枪跟法杖同款折扣 (修不一致: 之前法杖半价、魔法枪全价)
		var in_combat_gun: bool = NetworkManager != null and NetworkManager.combat_enabled()
		if not mana_n.try_consume(staff_mana_cost(mana_cost, in_combat_gun)):
			return   # 魔力不够 → 不发, 不进 cooldown
```

- [ ] **Step 5: 更新受影响的旧断言**

`tests/integration/test_magic_guns.gd:58`：

```gdscript
	assert_eq(mana.current_mana, 98, "应扣 2 魔力 (arcane_gun mana_cost=4, 折后 ×0.5)")
```

- [ ] **Step 6: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_target_priority.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_magic_guns.gd -gexit
```
预期：全 PASS。

- [ ] **Step 7: Commit**

```bash
git add scripts/entities/bullet.gd scripts/player/player_action.gd tests/integration/test_gun_target_priority.gd tests/integration/test_magic_guns.gd
git commit -m "fix(gun): 追踪弹优先追敌对怪不追小猪; 魔法枪魔力享受法杖同款折扣"
```

---

### Task 2: 每把枪有自己的声音 + 法杖施法音

**Files:**
- Modify: `scripts/audio/sfx_bank.gd`（注册段 + 新增 `has_sound`）
- Modify: `scripts/items/item_db.gd:98-123`（部分枪 def 加 `gun_sfx`）
- Modify: `scripts/player/player_action.gd:1961`（开火播 def 音）、`:2041`、`:2106`（法杖 `break`→`cast`）
- Test: `tests/unit/test_gun_sfx_defs.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_gun_sfx_defs.gd`：

```gdscript
# T2 验收: 新音效已注册; 每把枪 def 里的 gun_sfx 都是真实存在的音效名 (防手滑写错).
extends GutTest


func test_new_sounds_registered() -> void:
	for name in ["gunshot_heavy", "gunshot_laser", "gunshot_ice", "gunshot_magic", "gunshot_rapid", "gunshot_flame", "cast"]:
		assert_true(SfxBank.has_sound(name), name + " 该已注册")


func test_all_gun_sfx_values_exist() -> void:
	var checked := 0
	for id in ItemDB._DEFS:
		var def: Dictionary = ItemDB._DEFS[id]
		if String(def.get("tool_kind", "")) != "gun":
			continue
		if def.has("gun_sfx"):
			assert_true(SfxBank.has_sound(String(def["gun_sfx"])), id + " 的 gun_sfx 没注册: " + String(def["gun_sfx"]))
			checked += 1
	assert_gt(checked, 5, "至少该有 6 把枪配了专属音效")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_gun_sfx_defs.gd -gexit
```
预期：FAIL（`has_sound` 方法不存在）。

- [ ] **Step 3: SfxBank 加音效 + `has_sound`**

`scripts/audio/sfx_bank.gd` 在 `_sfx["gunshot"] = ...`（第 93 行）后面追加注册（复用现成生成器 `_thunk`/`_bell`/`_moan`/`_whoosh`，不用写新合成器）：

```gdscript
	# 枪械专属音 (T2): 不同枪不同声 — 重炮"轰" / 激光"啾" / 冰"叮" / 魔法"嗖" / 连发"哒" / 火焰"呼"
	_sfx["gunshot_heavy"] = _thunk(0.3, 60.0, 0.8)        # 狙击/电磁炮/霰弹: 低频长轰
	_sfx["gunshot_laser"] = _moan(0.12, 1200.0, 300.0, 0.3)  # 激光/电: 下滑"啾"
	_sfx["gunshot_ice"] = _bell(0.12, 1500.0, 0.25)       # 冰系: 高频短叮
	_sfx["gunshot_magic"] = _moan(0.12, 500.0, 1050.0, 0.28) # 魔弹: 上扬"嗖"
	_sfx["gunshot_rapid"] = _thunk(0.06, 220.0, 0.4)      # 冲锋枪/加特林: 更轻更短"哒"
	_sfx["gunshot_flame"] = _whoosh(0.12, 0.0, 0.0, 0.4)  # 火焰喷射器: 喷气"呼"
	_sfx["cast"] = _moan(0.2, 450.0, 1150.0, 0.3)         # 法杖施法: 魔法上扬"嗖~" (替换挖土声)
```

在 `func play(...)` 前面加查询方法：

```gdscript
# 音效名是否已注册 (测试用: 防 def 里 gun_sfx 写错名)
func has_sound(sfx_name: String) -> bool:
	return _sfx.has(sfx_name)
```

注意：`_sfx` 的注册在 `_ready` 里跑；GUT 下 autoload 已就绪，直接断言即可。

- [ ] **Step 4: item_db 给枪配音**

`scripts/items/item_db.gd:98-123`，按下表往对应 def 里追加 `"gun_sfx": "..."` 字段（其余枪不加 = 默认 `gunshot`）：

| gun_sfx | 枪 |
|---|---|
| `gunshot_heavy` | shotgun, sniper, railgun, rocket_gun |
| `gunshot_laser` | laser_gun, lightning_gun, tesla_gun |
| `gunshot_ice` | freeze_ray, frost_gun, cryo_gun |
| `gunshot_magic` | arcane_gun, poison_gun, star_gun, slime_gun, leaf_gun, twin_magic_gun, venom_gun |
| `gunshot_rapid` | smg, minigun |
| `gunshot_flame` | flamethrower |
| （默认不加） | pistol, assault_rifle, ricochet_gun |

例（sniper 行）：

```gdscript
	"sniper":        {"placeable_tile_id": -1, "tool_kind": "gun", "tool_tier": 4, "max_stack": 1, "damage_mult": 1.0, "gun_cooldown": 0.9, "gun_damage": 32, "bullet_speed": 1000, "gun_sfx": "gunshot_heavy"},  # 狙击枪: 慢/超狠/弹速超快
```

- [ ] **Step 5: 开火/施法播对应音**

`scripts/player/player_action.gd:1961`，把 `SfxBank.play("gunshot", 0.08)` 改为：

```gdscript
	SfxBank.play(String(def.get("gun_sfx", "gunshot")) if def != null else "gunshot", 0.08)
```

`:2041`（元素法杖）与 `:2106`（机制法杖 `_cast_bullet_spell` 末尾）的 `SfxBank.play("break", 0.12)` 都改为：

```gdscript
	SfxBank.play("cast", 0.12)
```

治疗（`pickup`）/护盾（`pickup`）/召唤（`place`）的音保持不动。

- [ ] **Step 6: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_gun_sfx_defs.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_fire.gd -gexit
```
预期：全 PASS（gun_fire 回归确认播音改动没炸）。

- [ ] **Step 7: Commit**

```bash
git add scripts/audio/sfx_bank.gd scripts/items/item_db.gd scripts/player/player_action.gd tests/unit/test_gun_sfx_defs.gd
git commit -m "feat(gun): 每把枪有自己的声音 (重炮轰/激光啾/冰叮/魔法嗖/连发哒/火焰呼); 法杖施法音不再用挖土声"
```

---

### Task 3: 枪口火光 + 大威力枪震屏

**Files:**
- Modify: `scripts/fx/effects.gd`（新增 `spawn_muzzle_flash`）
- Modify: `scripts/player/player_action.gd`（`_try_fire_gun` 出弹后调用；`_spell_fx_color` 补 4 个 visual）
- Modify: `scripts/items/item_db.gd`（4 把枪加 `gun_shake`）
- Test: `tests/integration/test_gun_feel.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/integration/test_gun_feel.gd`：

```gdscript
# T3 验收: 枪口火光粒子生成; 大威力枪 def 配了合理 gun_shake.
extends GutTest


func test_muzzle_flash_spawns_particles() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_muzzle_flash(Vector2(10, 10), Vector2.RIGHT, Color8(255, 220, 140))
	assert_gt(root.get_child_count(), 0, "枪口火光该生成粒子")


func test_heavy_guns_have_shake() -> void:
	for id in ["sniper", "railgun", "rocket_gun", "shotgun"]:
		var def: Dictionary = ItemDB.get_def(id)
		var s: float = float(def.get("gun_shake", 0.0))
		assert_between(s, 0.5, 4.0, id + " 该配合理的 gun_shake (0.5~4)")


func test_normal_guns_no_shake() -> void:
	for id in ["pistol", "smg", "minigun"]:
		var def: Dictionary = ItemDB.get_def(id)
		assert_false(def.has("gun_shake"), id + " 快枪不该震屏 (会晕)")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_feel.gd -gexit
```
预期：FAIL（`spawn_muzzle_flash` 不存在；`gun_shake` 没配）。

- [ ] **Step 3: effects.gd 加 `spawn_muzzle_flash`**

`scripts/fx/effects.gd`，加在 `spawn_spell_impact`（106 行）前面：

```gdscript
# 枪口火光: 开火瞬间枪口处一撮亮火花朝射击方向喷 (0.1s 级短促). color 跟枪属性走.
# FX 可见性规矩: 亮白芯 + 高速高 alpha, 一眼能看见.
func spawn_muzzle_flash(pos: Vector2, dir: Vector2, color: Color) -> void:
	var d: Vector2 = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	var cols := [Color(1, 1, 1, 1), color, color.lightened(0.35)]
	for i in 6:
		var ang: float = d.angle() + randf_range(-0.45, 0.45)
		var sp: float = randf_range(160.0, 300.0)
		_spell_one(pos, cols[i % cols.size()], Vector2(cos(ang), sin(ang)) * sp)
```

- [ ] **Step 4: `_spell_fx_color` / `_spell_impact_fx` 补枪的 visual**

`scripts/player/player_action.gd:2110-2129`，两个映射各补 4 个分支（枪的 visual 比法杖多 laser/star/slimeblob/leaf）：

```gdscript
# 法杖弹的 visual → 命中特效的"形状" (每把法杖不同, 不再全是同一种爆炸)
func _spell_impact_fx(visual: String) -> String:
	match visual:
		"lightning": return "spark"      # 闪电: 星形快火花
		"poison":    return "gas"        # 毒: 慢散毒云
		"magic":     return "sparkle"    # 多重: 飘散魔法星
		"fire":      return "explosion"  # 爆裂: 大爆炸
		"ice":       return "splash"     # 水之: 溅水花
		"wind":      return "gust"       # 狂风: 横向风条
		"laser":     return "spark"      # 激光/电磁炮: 星形快火花
		"star":      return "sparkle"    # 星星: 魔法星
		"slimeblob": return "gas"        # 史莱姆: 黏液团散开
		"leaf":      return "sparkle"    # 绿叶: 叶屑飘散
		_:           return "sparkle"


# 法杖弹的 visual → 施法/命中火花的颜色 (跟弹色一致, 一眼能认是哪把法杖)
func _spell_fx_color(visual: String) -> Color:
	match visual:
		"lightning": return Color8(255, 235, 90)   # 黄电
		"poison":    return Color8(120, 200, 60)    # 绿毒
		"fire":      return Color8(255, 150, 40)    # 橙火
		"ice":       return Color8(90, 180, 240)    # 冰蓝
		"wind":      return Color8(210, 240, 255)   # 白青
		"laser":     return Color8(255, 90, 80)     # 激光红
		"star":      return Color8(255, 215, 90)    # 星金
		"slimeblob": return Color8(110, 220, 90)    # 黏液绿
		"leaf":      return Color8(120, 200, 80)    # 叶绿
		_:           return Color8(180, 100, 235)   # 紫 (多重/魔法弹默认)
```

- [ ] **Step 5: `_try_fire_gun` 出弹后放火光 + 震屏**

`scripts/player/player_action.gd:1961`（pellets 循环结束后、播音那行前面）插入：

```gdscript
	# 枪口火光: 多弹丸也只闪一次; 颜色跟 gun_visual 走 (普通子弹枪 = 暖黄白)
	if Effects != null and Effects.has_method("spawn_muzzle_flash"):
		var mf_color: Color = Color8(255, 220, 140)
		if def != null and def.has("gun_visual"):
			mf_color = _spell_fx_color(String(def.get("gun_visual")))
		Effects.spawn_muzzle_flash(start + base_dir * 10.0, base_dir, mf_color)
	# 大威力枪开火震屏 (gun_shake 字段; 快枪不配 = 不震, 防晕)
	var shake_amt: float = float(def.get("gun_shake", 0.0)) if def != null else 0.0
	if shake_amt > 0.0 and parent.has_method("shake"):
		parent.shake(shake_amt)
```

- [ ] **Step 6: item_db 配 `gun_shake`**

`scripts/items/item_db.gd` 给 4 把枪 def 追加字段：
- `sniper`: `"gun_shake": 2.5`
- `railgun`: `"gun_shake": 3.0`
- `rocket_gun`: `"gun_shake": 2.0`
- `shotgun`: `"gun_shake": 1.5`

- [ ] **Step 7: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_feel.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_staff_fx.gd -gexit
```
预期：全 PASS（staff_fx 回归确认映射函数改动兼容）。

- [ ] **Step 8: Commit**

```bash
git add scripts/fx/effects.gd scripts/player/player_action.gd scripts/items/item_db.gd tests/integration/test_gun_feel.gd
git commit -m "feat(gun): 枪口火光 (颜色跟属性走) + 狙击/电磁炮/火箭/霰弹开火震屏"
```

---

### Task 4: 闪电链电弧 + 接力式跳怪（含敌对优先）

**Files:**
- Modify: `scripts/fx/effects.gd`（新增 `spawn_lightning_arc`）
- Modify: `scripts/entities/bullet.gd:288-308`（`_do_chain` 重写成接力式 + 新增 `_chain_next`）
- Test: `tests/integration/test_lightning_arc.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/integration/test_lightning_arc.gd`：

```gdscript
# T4 验收: 电弧 Line2D 生成 + 自动释放; 闪电链接力式跳怪 (每跳从上一只出发) + 敌对优先.
extends GutTest

const BulletScene = preload("res://scenes/entities/bullet.tscn")


class StubMob:
	extends Node2D
	var hits: int = 0
	var grp: String = "slimes"
	func _init(g: String = "slimes") -> void:
		grp = g
	func _ready() -> void:
		add_to_group(grp)
	func take_damage(_d: int, _src: Vector2, _kb: float = 0.0) -> void:
		hits += 1


func _stub(g: String, pos: Vector2) -> StubMob:
	var s := StubMob.new(g)
	add_child_autofree(s)
	s.global_position = pos
	return s


func test_arc_spawns_and_frees() -> void:
	var root := Node2D.new()
	root.add_to_group("effects_root")
	add_child_autofree(root)
	Effects.spawn_lightning_arc(Vector2.ZERO, Vector2(60, 0))
	assert_gt(root.get_child_count(), 0, "电弧该生成 Line2D")
	await wait_seconds(0.6)
	assert_eq(root.get_child_count(), 0, "淡出后该自动释放")


# 接力式: A(30,0) B(80,0) C(130,0), 链 2 跳半径 64.
# 旧"发散式"从 A 量距离够不着 C (100>64); 接力式 B→C 只有 50 → C 必须被电到.
func test_chain_relays_beyond_first_radius() -> void:
	var a := _stub("slimes", Vector2(30, 0))
	var b := _stub("slimes", Vector2(80, 0))
	var c := _stub("slimes", Vector2(130, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {"chain": 2, "chain_radius": 64.0})
	await wait_frames(20)
	assert_gt(a.hits, 0, "直击 A")
	assert_gt(b.hits, 0, "第 1 跳电到 B")
	assert_gt(c.hits, 0, "接力第 2 跳从 B 出发电到 C")


# 敌对优先: 第一跳该跳敌对怪, 哪怕动物更近
func test_chain_prefers_hostile_over_closer_animal() -> void:
	var first := _stub("slimes", Vector2(30, 0))
	var pig := _stub("animals", Vector2(45, 0))
	var skel := _stub("slimes", Vector2(70, 0))
	var bullet = BulletScene.instantiate()
	add_child_autofree(bullet)
	bullet.setup(Vector2.ZERO, Vector2(200, 0), 5, null, 300.0, {"chain": 1, "chain_radius": 64.0})
	await wait_frames(20)
	assert_gt(first.hits, 0)
	assert_gt(skel.hits, 0, "链 1 跳该电敌对怪")
	assert_eq(pig.hits, 0, "动物更近也不该被电 (还有敌对怪在)")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_lightning_arc.gd -gexit
```
预期：FAIL（`spawn_lightning_arc` 不存在；C 没被电到；猪被电）。

- [ ] **Step 3: effects.gd 加 `spawn_lightning_arc`**

`scripts/fx/effects.gd`，加在 `spawn_muzzle_flash` 后面：

```gdscript
# 闪电电弧: from→to 锯齿折线, 双层 (宽辉光 + 亮芯), 0.18s 淡出自毁.
# 闪电链每跳一只怪画一道, 一眼看清电到了谁. 线宽 ≥2px (FX 可见性规矩).
func spawn_lightning_arc(from: Vector2, to: Vector2) -> void:
	var root: Node = _root()
	var seg: Vector2 = to - from
	var n: int = clampi(int(seg.length() / 14.0) + 2, 3, 8)
	var normal: Vector2 = seg.normalized().orthogonal() if seg.length() > 0.01 else Vector2.UP
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	for i in range(1, n):
		pts.append(seg * (float(i) / float(n)) + normal * randf_range(-5.0, 5.0))
	pts.append(seg)
	var glow := Line2D.new()
	glow.points = pts
	glow.width = 5.0
	glow.default_color = Color(1.0, 0.95, 0.55, 0.5)
	glow.position = from
	glow.z_index = 60
	var core := Line2D.new()
	core.points = pts
	core.width = 2.5
	core.default_color = Color8(255, 248, 190)
	core.position = from
	core.z_index = 61
	root.add_child(glow)
	root.add_child(core)
	var tw := core.create_tween()
	tw.set_parallel(true)
	tw.tween_property(core, "modulate:a", 0.0, 0.18)
	tw.tween_property(glow, "modulate:a", 0.0, 0.18)
	tw.chain().tween_callback(func() -> void:
		if is_instance_valid(glow):
			glow.queue_free()
		if is_instance_valid(core):
			core.queue_free())
```

- [ ] **Step 4: `_do_chain` 重写成接力式**

`scripts/entities/bullet.gd:288-308`，整段替换为：

```gdscript
# 闪电连锁 (接力式): 第一只 → 最近 → 次近 依次跳, 每跳从上一只出发量半径 + 画一道电弧.
# 敌对怪 (slimes) 优先, 动物只在没敌对怪时垫底 (跟 _nearest_enemy 同规矩).
func _do_chain(from_enemy: Node2D, src: Vector2) -> void:
	if from_enemy == null:
		return
	var hit: Dictionary = {from_enemy.get_instance_id(): true}
	var current: Node2D = from_enemy
	for _i in chain:
		var next: Node2D = _chain_next(current, hit)
		if next == null:
			break
		hit[next.get_instance_id()] = true
		if Effects != null and Effects.has_method("spawn_lightning_arc"):
			Effects.spawn_lightning_arc(current.global_position, next.global_position)
		if next.has_method("take_damage"):
			next.take_damage(damage, src, 80.0)
		current = next


# 接力下一跳: current 周围 chain_radius 内没电过的怪, 敌对优先取最近. 没有 → null (链断).
func _chain_next(current: Node2D, hit: Dictionary) -> Node2D:
	for group in ["slimes", "animals"]:
		var best: Node2D = null
		var best_d: float = INF
		for e in get_tree().get_nodes_in_group(group):
			if e == _shooter or not is_instance_valid(e) or not e is Node2D:
				continue
			if e.has_meta("is_remote") or hit.has(e.get_instance_id()):
				continue
			var d: float = current.global_position.distance_to((e as Node2D).global_position)
			if d <= chain_radius and d < best_d:
				best_d = d
				best = e
		if best != null:
			return best
	return null
```

- [ ] **Step 5: 跑测试确认通过**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_lightning_arc.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_magic_guns_3b.gd -gexit
```
预期：全 PASS（3b 回归覆盖旧闪电链行为——若 3b 里有"发散式距离"假设的断言，按接力式语义更新并在 commit message 说明）。

- [ ] **Step 6: Commit**

```bash
git add scripts/fx/effects.gd scripts/entities/bullet.gd tests/integration/test_lightning_arc.gd
git commit -m "feat(gun): 闪电链改接力式跳怪 + 每跳画锯齿电弧 (敌对优先, 一眼看清电到谁)"
```

---

### Task 5: 强力枪命中特效 + opts 构建去重

**Files:**
- Modify: `scripts/player/player_action.gd:1913-1937`（手搓 opts 换成 `_proj_opts_from_def`）
- Modify: `scripts/items/item_db.gd`（sniper / railgun 加 `gun_impact: true`）
- Test: `tests/unit/test_proj_opts.gd`（新建）

- [ ] **Step 1: 写失败测试**

新建 `tests/unit/test_proj_opts.gd`：

```gdscript
# T5 验收: _proj_opts_from_def 字段映射正确; gun_impact 枪带命中特效 opts.
extends GutTest

const PlayerAction = preload("res://scripts/player/player_action.gd")


func _pa() -> Node:
	var pa = PlayerAction.new()
	autofree(pa)
	return pa


func test_opts_basic_mapping() -> void:
	var def := {"gun_pierce": true, "gun_slow_factor": 0.4, "gun_slow_dur": 2.5, "gun_visual": "ice", "bullet_lifetime": 0.9}
	var opts: Dictionary = _pa()._proj_opts_from_def(def)
	assert_true(bool(opts.get("pierce", false)))
	assert_eq(float(opts.get("slow_factor", 0.0)), 0.4)
	assert_eq(String(opts.get("visual", "")), "ice")
	assert_eq(float(opts.get("lifetime", 0.0)), 0.9)


func test_gun_impact_defs_marked() -> void:
	for id in ["sniper", "railgun"]:
		assert_true(bool(ItemDB.get_def(id).get("gun_impact", false)), id + " 该配 gun_impact")
	assert_false(bool(ItemDB.get_def("minigun").get("gun_impact", false)), "快枪不配 (防刷屏)")


func test_gun_fire_opts_include_impact_for_marked_gun() -> void:
	var pa = _pa()
	# 模拟 _try_fire_gun 的 opts 组装路径: gun_impact → impact_fx/impact_color 进 opts
	var def: Dictionary = ItemDB.get_def("railgun")
	var opts: Dictionary = pa._proj_opts_from_def(def)
	if bool(def.get("gun_impact", false)):
		var vis: String = String(def.get("gun_visual", ""))
		opts["impact_fx"] = pa._spell_impact_fx(vis) if vis != "" else "spark"
		opts["impact_color"] = pa._spell_fx_color(vis) if vis != "" else Color8(255, 230, 150)
	assert_eq(String(opts.get("impact_fx", "")), "spark", "railgun (laser visual) 命中该放 spark")
```

- [ ] **Step 2: 跑测试确认失败**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_proj_opts.gd -gexit
```
预期：`test_gun_impact_defs_marked` FAIL（字段没配）。

- [ ] **Step 3: item_db 配 `gun_impact`**

`scripts/items/item_db.gd`：`sniper` 与 `railgun` def 各追加 `"gun_impact": true`。

- [ ] **Step 4: `_try_fire_gun` 换用 `_proj_opts_from_def`**

`scripts/player/player_action.gd:1913-1937`，把"手搓 opts 的 25 行"（`var opts: Dictionary = {}` 到 `opts["gravity"] = ...` 整块）替换为：

```gdscript
	# opts 统一走 _proj_opts_from_def (跟机制法杖共用, 一处维护)
	var opts: Dictionary = _proj_opts_from_def(def)
	# 强力枪命中特效: 慢而狠的枪 (gun_impact) 命中也放招牌特效; 快枪不配 → 不喷 (防刷屏)
	if def != null and bool(def.get("gun_impact", false)):
		var iv: String = String(def.get("gun_visual", ""))
		opts["impact_fx"] = _spell_impact_fx(iv) if iv != "" else "spark"
		opts["impact_color"] = _spell_fx_color(iv) if iv != "" else Color8(255, 230, 150)
```

注意：`_proj_opts_from_def` 比手搓版多映射 `gun_explode_radius`/`gun_knockback`/`gun_launch` —— 现有枪 def 没这些字段，行为不变；这正是去重的意义。

- [ ] **Step 5: 跑全量回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_guns_variety.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_guns_batch2.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_magic_guns.gd -gexit
```
预期：全 PASS（重构不改行为）。

- [ ] **Step 6: Commit**

```bash
git add scripts/player/player_action.gd scripts/items/item_db.gd tests/unit/test_proj_opts.gd
git commit -m "feat(gun): 狙击/电磁炮命中爆特效 (gun_impact); _try_fire_gun 的 opts 改走 _proj_opts_from_def 去重"
```

---

### Task 6: 枪 + 法杖图标重画（两批，渲染图给用户验收）

**Files:**
- Modify: `scripts/art/items_art.gd`（23 把枪 + 20 根法杖的 16×16 字符画）
- Create: `scripts/tools/render_weapons_sheet.gd`（武器总表渲染器）
- 已有回归: ArtCache 图标测试（跑 unit 全量确认没漏）

画法约束（按既有美术规矩）：
- 16×16 字符画，字母 = `items_art.gd` 顶部 `PALETTE` 的颜色键；缺色可往 PALETTE 加键（加注释），别复用已有键改色
- 每把武器轮廓必须互相区分：长度 / 枪管数 / 配件 / 杖头形状
- 暖色基调；金属可冷灰但点缀色跟属性元素走；要可识别形状，不要随机散点
- 手持外观 = 同一张图标，重画一次两处生效

每把武器一句话设计稿（执行时照这个画，画完对照检查）：

**枪（23）：**
| id | 轮廓要点 |
|---|---|
| pistol | 短管 + 下垂握把，经典 L 形 |
| smg | 矮胖方身 + 下插弹匣 + 短管 |
| assault_rifle | 中长管 + 弯弹匣 + 枪托 |
| shotgun | 粗双管 + 木质护木前段 |
| sniper | 全宽细长管 + 顶部瞄准镜圆筒 + 枪托 |
| laser_gun | 流线壳体 + 管口发光红环 |
| flamethrower | 粗短喷口 + 机身下挂橙色燃料罐 |
| freeze_ray | 圆润壳体 + 冰蓝晶体管口 + 霜白纹 |
| arcane_gun | 紫水晶镶嵌枪身 + 弯曲魔纹 |
| poison_gun | 绿色药囊鼓包 + 滴液管口 |
| lightning_gun | 锯齿状黄色线圈绕管 |
| star_gun | 星形管口 + 金黄星徽 |
| slime_gun | 果冻绿半透明圆壶身 |
| frost_gun | 三叉雪花喷口 + 冰蓝 |
| leaf_gun | 木藤缠绕枪身 + 叶片管口 |
| minigun | 三层多管转轮 + 粗机匣 |
| twin_magic_gun | 上下双管 + 双紫宝石 |
| rocket_gun | 大口径粗筒 + 露出弹头红尖 |
| ricochet_gun | 弹簧纹枪身 + 圆弧弹道标记 |
| tesla_gun | 双天线叉 + 蓝白电球管口 |
| cryo_gun | 大冰晶背包 + 宽喇叭口 |
| venom_gun | 深紫毒腺 + 双滴液獠牙管口 |
| railgun | 方正双轨道夹弹芯 + 蓝光条 |

**法杖（20）：** 统一竖持长杆 + 不同杖头：
| id | 杖头 |
|---|---|
| wood_staff | 绿叶簇球 |
| iron_staff | 蓝冰菱晶 |
| hell_staff | 橙红火焰球 |
| skull_staff | 白骷髅头 |
| lightning_staff | 锯齿黄电晶 |
| poison_staff | 绿色滴液囊 |
| multi_staff | 三叉分枝各嵌小紫晶 |
| explosive_staff | 红色炸弹球 + 引线 |
| water_staff | 蓝水滴宝石 |
| wind_staff | 白青螺旋纹环 |
| heal_staff | 绿十字宝石 |
| bird_staff | 蓝色小鸟雕像 |
| crack_staff | 棕色岩石拳 |
| homing_staff | 紫眼球晶体 |
| beam_staff | 红色长条棱镜 |
| frost_staff | 六角雪花晶 |
| bounce_star_staff | 金星 + 弹簧圈 |
| meteor_staff | 带尾焰的陨石球 |
| greater_heal_staff | 大绿十字 + 光环 |
| shield_staff | 蓝盾牌徽 |

样板（sniper 重画示例，执行时按此质量要求画其余）：

```gdscript
# 狙击枪: 全宽细长管 + 顶部瞄准镜 + 枪托 — 一眼"又长又专业"
const _SNIPER := [
	"................",
	"................",
	"................",
	".....nnnn.......",
	"....nbBBn.......",
	"....nnnnn.......",
	"nnnnnnnnnnnnnnnn",
	"nBBBBBBBBBBBBbbn",
	"nKhhKBBBBBBnnnnn",
	".nhhhKKBBn......",
	".nhHhn.nKn......",
	".nhhn..nKn......",
	".nhn...nn.......",
	".nn.............",
	"................",
	"................",
]
```

- [ ] **Step 1: 写渲染器（先有验收工具再画）**

新建 `scripts/tools/render_weapons_sheet.gd`：

```gdscript
# 一次性武器美术预览 (headless). 把所有枪 + 法杖图标放大拼成 PNG, 发给用户过目.
# 跑法: godot --headless --script res://scripts/tools/render_weapons_sheet.gd
# 产出: /tmp/art_preview/guns.png  /tmp/art_preview/staves.png
extends SceneTree

const ItemsArt = preload("res://scripts/art/items_art.gd")

const ZOOM := 8
const CELL := 16
const PAD := 6
const COLS := 6
const BG := Color8(48, 52, 60)

const GUNS := [
	"pistol", "smg", "assault_rifle", "shotgun", "sniper", "laser_gun",
	"flamethrower", "freeze_ray", "arcane_gun", "poison_gun", "lightning_gun",
	"star_gun", "slime_gun", "frost_gun", "leaf_gun", "minigun", "twin_magic_gun",
	"rocket_gun", "ricochet_gun", "tesla_gun", "cryo_gun", "venom_gun", "railgun",
]
const STAVES := [
	"wood_staff", "iron_staff", "hell_staff", "skull_staff", "lightning_staff",
	"poison_staff", "multi_staff", "explosive_staff", "water_staff", "wind_staff",
	"heal_staff", "bird_staff", "crack_staff", "homing_staff", "beam_staff",
	"frost_staff", "bounce_star_staff", "meteor_staff", "penta_staff",
	"greater_heal_staff", "shield_staff",
]


func _init() -> void:
	var dir := DirAccess.open("/tmp")
	if dir and not dir.dir_exists("art_preview"):
		dir.make_dir("art_preview")
	_render(GUNS, "/tmp/art_preview/guns.png")
	_render(STAVES, "/tmp/art_preview/staves.png")
	quit()


func _render(ids: Array, path: String) -> void:
	var rows: int = int(ceil(float(ids.size()) / float(COLS)))
	var cw: int = (CELL + PAD) * ZOOM
	var img := Image.create(COLS * cw + PAD * ZOOM, rows * cw + PAD * ZOOM, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	for i in ids.size():
		var id: String = ids[i]
		if not ItemsArt.has_icon(id):
			print("缺图标: ", id)
			continue
		var src: Image = ItemsArt.get_icon(id).get_image()
		var big := src.duplicate()
		big.resize(CELL * ZOOM, CELL * ZOOM, Image.INTERPOLATE_NEAREST)
		var x: int = (i % COLS) * cw + PAD * ZOOM
		var y: int = (i / COLS) * cw + PAD * ZOOM
		img.blend_rect(big, Rect2i(0, 0, CELL * ZOOM, CELL * ZOOM), Vector2i(x, y))
		print("[%d] %s" % [i, id])
	img.save_png(path)
	print("saved: ", path)
```

注意 `penta_staff` 在 STAVES 里 — 一共 21 根（spec 写 20 是漏数了 penta_staff，以代码为准）。

- [ ] **Step 2: 渲染"改前"基线图**

```bash
godot --headless --script res://scripts/tools/render_weapons_sheet.gd
```
预期：`/tmp/art_preview/guns.png` + `staves.png` 出图。把两张图发给用户（SendUserMessage 附件）作为"改前"对照。

- [ ] **Step 3: 重画第一批 — 23 把枪**

按上面设计稿逐把重画 `items_art.gd` 里的枪 const。自查清单：
- 任意两把枪缩略图能区分（轮廓/配件不同）
- 描边连续（n 包边不断），不浮空噪点
- 属性枪有元素徽记色（电黄/冰蓝/毒绿/火橙/星金）

- [ ] **Step 4: 渲染 + 单元回归 + 发图**

```bash
godot --headless --script res://scripts/tools/render_weapons_sheet.gd
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
```
预期：unit 全 PASS（图标注册测试没破）。把新 `guns.png` 发给用户过目，**等用户反馈**；不满意的单独返工再渲染。

- [ ] **Step 5: Commit 第一批**

```bash
git add scripts/art/items_art.gd scripts/tools/render_weapons_sheet.gd
git commit -m "art(gun): 23 把枪图标重画 — 每把轮廓差异化 (狙击长管瞄准镜/加特林转轮/火焰背罐...)"
```

- [ ] **Step 6: 重画第二批 — 21 根法杖**

按设计稿重画法杖 const（统一竖杆 + 差异化杖头）。同样自查。

- [ ] **Step 7: 渲染 + 回归 + 发图 + Commit 第二批**

```bash
godot --headless --script res://scripts/tools/render_weapons_sheet.gd
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
git add scripts/art/items_art.gd
git commit -m "art(staff): 21 根法杖图标重画 — 杖头按属性差异化 (电晶/雪花/绿十字/骷髅...)"
```

---

### Task 7: 投射物贴图重画

**Files:**
- Modify: `scripts/art/bullet_proj_art.gd` / `laser_proj_art.gd` / `magic_proj_art.gd` / `lightning_proj_art.gd` / `star_proj_art.gd` / `slime_blob_proj_art.gd` / `leaf_proj_art.gd` / `wind_proj_art.gd` / `fireball_art.gd`（fire/ice/nature 三色）
- Modify: `scripts/tools/render_weapons_sheet.gd`（追加投射物页）
- 回归: 跑 integration 的 gun/staff 测试确认 build_sprite_frames API 没破

画法约束：
- **保持 `build_sprite_frames()` 签名与动画名不变**（`bullet.gd::_apply_visual` 按 `names[0]` 播，帧数可加）
- 每种弹"亮芯 + 半透辉光边"两层层次，别只是色块
- 飞行感：拖尾/速度线方向统一朝右（运行时按飞行方向旋转）
- 可加 2 帧闪烁动画（`set_animation_loop(true)` + `set_animation_speed(8.0)`），单帧的保持单帧也行

每种弹一句话设计稿：
| 文件 | 要点 |
|---|---|
| bullet_proj_art | 铜壳弹头更立体 + 3 条速度线拖尾 |
| laser_proj_art | 红色长条光束 + 白热亮芯 + 外辉光 |
| magic_proj_art | 紫色菱形晶 + 环绕小星 2 帧闪 |
| lightning_proj_art | 黄电球 + 锯齿短弧伸出 2 帧抖 |
| star_proj_art | 五角金星 + 金粉拖尾 |
| slime_blob_proj_art | 果冻团压扁/回弹 2 帧 + 高光点 |
| leaf_proj_art | 旋转叶片 2 帧 + 叶脉 |
| wind_proj_art | 白青螺旋气流条 |
| fireball_art | 火球纹理层次加强（暗焰皮 + 亮芯），三色（fire/ice/nature）同构 |

- [ ] **Step 1: 渲染器追加投射物页**

`scripts/tools/render_weapons_sheet.gd` 的 `_init` 里追加渲染各 `*_proj_art` 的首帧到 `/tmp/art_preview/projectiles.png`：

```gdscript
	# 投射物首帧预览 (T7)
	var projs := {
		"bullet": preload("res://scripts/art/bullet_proj_art.gd").build_sprite_frames(),
		"laser": preload("res://scripts/art/laser_proj_art.gd").build_sprite_frames(),
		"magic": preload("res://scripts/art/magic_proj_art.gd").build_sprite_frames(),
		"lightning": preload("res://scripts/art/lightning_proj_art.gd").build_sprite_frames(),
		"star": preload("res://scripts/art/star_proj_art.gd").build_sprite_frames(),
		"slimeblob": preload("res://scripts/art/slime_blob_proj_art.gd").build_sprite_frames(),
		"leaf": preload("res://scripts/art/leaf_proj_art.gd").build_sprite_frames(),
		"wind": preload("res://scripts/art/wind_proj_art.gd").build_sprite_frames(),
		"fire": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("fire"),
		"ice": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("ice"),
		"nature": preload("res://scripts/art/fireball_art.gd").build_sprite_frames("nature"),
	}
	var imgs: Array = []
	for key in projs:
		var sf: SpriteFrames = projs[key]
		var anim: String = sf.get_animation_names()[0]
		imgs.append([key, sf.get_frame_texture(anim, 0).get_image()])
		print("proj: ", key)
	_render_images(imgs, "/tmp/art_preview/projectiles.png")
```

并把 `_render` 拆出可复用的 `_render_images(pairs: Array, path: String)`（入参 `[名字, Image]` 对，渲染逻辑同 `_render`，开头把 `ids` 换成 pairs 即可——执行时做这个小重构）。

- [ ] **Step 2: 渲染"改前"基线 + 重画**

```bash
godot --headless --script res://scripts/tools/render_weapons_sheet.gd
```
逐文件重画（按设计稿），保持 API/动画名。

- [ ] **Step 3: 回归 + 渲染 + 发图**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_gun_fire.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_guns_variety.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gselect=test_staff_spells.gd -gexit
godot --headless --script res://scripts/tools/render_weapons_sheet.gd
```
预期：全 PASS + `projectiles.png` 出图发用户过目。

- [ ] **Step 4: Commit**

```bash
git add scripts/art/bullet_proj_art.gd scripts/art/laser_proj_art.gd scripts/art/magic_proj_art.gd scripts/art/lightning_proj_art.gd scripts/art/star_proj_art.gd scripts/art/slime_blob_proj_art.gd scripts/art/leaf_proj_art.gd scripts/art/wind_proj_art.gd scripts/art/fireball_art.gd scripts/tools/render_weapons_sheet.gd
git commit -m "art(proj): 11 种投射物贴图重画 — 亮芯+辉光两层, 部分加 2 帧动画"
```

---

## 收尾

- [ ] 全量测试：unit + integration 两个目录都跑一遍，全绿
- [ ] `git log --oneline -10` 检查没有混入无关 commit
- [ ] push（用户偏好：能看见就 push）：`git push origin main`
- [ ] 给用户中文总结（每个 T 的效果 + 累计测试数 + 网页版 3-5 分钟后生效）
