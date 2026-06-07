# 侧面分层渲染 + 默认小人 Implementation Plan (Plan 2)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把玩家美术改成泰拉瑞亚式 **24×48 侧面单眼**、由 `CharacterData.appearance_dict()` 驱动的**分层拼装** (披风/身体/裤子/衬衫/头发), 支持性别/胸围/发型/皮肤·头发·衬衫·裤子·眼珠换色; 玩家在世界里渲染当前角色的样子, 占的格子/碰撞不变。

**Architecture:** 重构 `scripts/art/player_art.gd`: `build_sprite_frames(appearance := DEFAULT)` 对每个动画帧从 5 层 ascii 网格叠出合并网格 (后画盖前画), 用 appearance 的颜色生成 per-character 调色板, 再喂现有 `PixelArt.build_sprite_frames`。画布 24×48; 玩家场景 `AnimatedSprite2D` scale 减半、offset 调整保持世界尺寸/脚底锚点。`ArtCache` 加 `player_frames_for(appearance)`; `player_controller` / `remote_player` 用当前角色外观出图 (无角色 fallback 默认)。

**本计划范围**: 框架 + **默认服装** (T恤/长裤/无披风/短发) + 男女身体 + 胸围 + 4 发型 + 全部换色。**不含**主题套装/泳衣/其它衣裤款 (= shirt_style/pants_style 仅 0 与 cape 0 真正画出; 其余款式号先 fallback 到默认款, 留 Plan 4 逐批补)。捏人/选角色 UI = Plan 3。

**Tech Stack:** Godot 4.3 + GDScript; `PixelArt.grid_to_texture` / `build_sprite_frames`; GUT 像素断言。

**⚠️ 并发**: `player_art.gd` / `art_cache.gd` 近期有别的 session 动过。每步前 `git status`, `git add <精确路径>`, **禁** `-am`/`-A`/`.`。

**⚠️ 测试**: 改 class_name/autoload 后先 `godot --headless --editor --quit`。单文件测试:
```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=<file>.gd -gexit
```
(`libfontconfig` 警告过滤。)

---

## 画布与对齐约定 (所有 Task 共享)

- **画布 24 宽 × 48 高**。每帧是 48 个长度 48 的字符串 (宽 24)。**所有层网格必须 24×48**, 不足补 `.` (透明)。
- **锚点行 (男女/所有款共用, 保证层对齐)**:
  - 头部: row 2..15 (脸/眼/发都在这区)
  - 眼睛: row 7 附近 (朝右那侧, col 14..17 区)
  - 躯干 (衬衫覆盖): row 16..30
  - 腿 (裤子覆盖): row 31..45
  - 脚底 (靴): row 46..47 (贴底)
- **朝右**: 脸/眼朝画布右侧。运行时 `flip_h` 朝左 (player_controller 已有, 不改)。
- **调色板字符 (固定含义, 全层统一)**:
  - `.` 透明 / `s` 皮肤 / `k` 皮肤阴影 / `W` 眼白(固定白) / `i` 眼珠(=eye_color) / `e` 眼/睫毛深色(固定 Color8(20,20,20)) / `m` 嘴(固定 Color8(150,70,70))
  - `h` 头发 / `H` 头发阴影 / `w` 衬衫 / `D` 衬衫阴影 / `b` 裤子 / `B` 裤子阴影 / `o` 靴(固定棕) / `O` 靴阴影(固定)
  - `c` 披风 / `C` 披风阴影
- **颜色来源**: skin=`skin_color`, skin阴影=`skin_color.darkened(0.18)`; 头发/衬衫/裤子/披风同理主色 + `.darkened(0.28)` 阴影; 眼珠=`eye_color`; 眼白固定白; 靴/眼深/嘴固定色。

---

## Task 1: 24×48 分层框架 + 默认男侧面小人

**Files:**
- Modify: `scripts/art/player_art.gd` (整体重构)
- Test: `tests/unit/test_player_art_appearance.gd` (新建)

**说明**: 这是核心。`build_sprite_frames(appearance)` 流程: 对每个动画 (idle/walk/jump/fall/hurt) 的每帧, 取 5 层网格 → `_composite(layers)` 合并 → 收集到 animations dict → 用 `_palette_from(appearance)` 生成调色板 → `PixelArt.build_sprite_frames`。本 Task 只画 **男身体 + 默认款** (短发 hair 0 / T恤 shirt 0 / 长裤 pants 0 / 无披风); 其它款式号本 Task 一律回退到默认款 (Plan 4 补)。

- [ ] **Step 1: 写失败测试** (锁框架契约 + 默认基准 + 眼睛)

Create `tests/unit/test_player_art_appearance.gd`:

```gdscript
extends GutTest

const PlayerArt = preload("res://scripts/art/player_art.gd")

func _default_appearance() -> Dictionary:
	return {
		"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
		"cape_style": 0, "chest_size": 1,
		"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
		"shirt_color": Color8(229, 57, 53), "pants_color": Color8(38, 70, 130),
		"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
	}

func test_build_returns_sprite_frames_with_all_anims():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	assert_true(sf is SpriteFrames, "返回 SpriteFrames")
	for anim in ["idle", "walk", "jump", "fall", "hurt"]:
		assert_true(sf.has_animation(anim), "有动画 %s" % anim)

func test_canvas_is_24x48():
	var sf = PlayerArt.build_sprite_frames(_default_appearance())
	var tex = sf.get_frame_texture("idle", 0)
	assert_eq(tex.get_width(), 24, "宽 24")
	assert_eq(tex.get_height(), 48, "高 48")

func test_no_arg_uses_default_and_matches_appearance_default():
	# 无参 = 默认 appearance, 两者首帧逐像素一致 (锁"默认基准")。
	var a = PlayerArt.build_sprite_frames()
	var b = PlayerArt.build_sprite_frames(_default_appearance())
	var ia = a.get_frame_texture("idle", 0).get_image()
	var ib = b.get_frame_texture("idle", 0).get_image()
	for y in range(48):
		for x in range(24):
			assert_eq(ia.get_pixel(x, y), ib.get_pixel(x, y), "默认基准像素 (%d,%d) 一致" % [x, y])

func test_shirt_color_pixel_follows_appearance():
	var ap = _default_appearance()
	ap["shirt_color"] = Color8(10, 200, 30)
	var sf = PlayerArt.build_sprite_frames(ap)
	var img = sf.get_frame_texture("idle", 0).get_image()
	# 躯干中心 (row 20, 朝右身体列 12 附近) 应是衬衫主色
	assert_true(_has_color_near(img, Color8(10, 200, 30), 16..30, 8..18), "躯干有所选衬衫色")

func test_eye_has_white_and_iris():
	var ap = _default_appearance()
	ap["eye_color"] = Color8(200, 30, 30)
	var sf = PlayerArt.build_sprite_frames(ap)
	var img = sf.get_frame_texture("idle", 0).get_image()
	# 头部眼区 (row 5..12) 同时有近白 (眼白) 和所选眼珠色
	assert_true(_has_color_near(img, Color(1, 1, 1, 1), 4..13, 10..20, 0.18), "眼区有眼白")
	assert_true(_has_color_near(img, Color8(200, 30, 30), 4..13, 10..20, 0.12), "眼区有所选眼珠色")

func test_unknown_shirt_style_falls_back_no_crash():
	var ap = _default_appearance()
	ap["shirt_style"] = 99   # 未画的款 → 回退默认, 不崩
	var sf = PlayerArt.build_sprite_frames(ap)
	assert_true(sf.has_animation("idle"), "未知款回退不崩")

# helper: 在 row/col 范围内是否有接近 target 的像素 (容差比较)
func _has_color_near(img: Image, target: Color, rows, cols, tol := 0.06) -> bool:
	for y in rows:
		for x in cols:
			var c = img.get_pixel(x, y)
			if c.a > 0.5 and abs(c.r - target.r) < tol and abs(c.g - target.g) < tol and abs(c.b - target.b) < tol:
				return true
	return false
```

- [ ] **Step 2: 跑测试确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_player_art_appearance.gd -gexit`
Expected: FAIL — `build_sprite_frames` 现在无参签名/旧 12×24, 多数断言挂。

- [ ] **Step 3: 重写 `player_art.gd` 框架**

整体替换 `scripts/art/player_art.gd`。结构:

```gdscript
# 玩家像素画: 泰拉瑞亚式 24×48 侧面单眼。按 CharacterData.appearance_dict() 分层拼装:
# 披风(后) → 身体(皮肤+靴) → 裤子 → 衬衫 → 头发。每层 24×48 ascii, 后画盖前画。
# 朝右版; 运行时 flip_h 朝左。本文件(Plan 2)只画默认款 (短发/T恤/长裤/无披风) + 男女身体;
# 其它款式号回退默认 (Plan 4 逐批补)。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")
const W := 24
const H := 48

const DEFAULT_APPEARANCE := {
	"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
	"cape_style": 0, "chest_size": 1,
	"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
	"shirt_color": Color8(229, 57, 53), "pants_color": Color8(38, 70, 130),
	"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
}

# 固定色 (不随 appearance 变)
const _BOOT := Color8(74, 47, 26)
const _BOOT_SH := Color8(48, 30, 15)
const _EYE_DARK := Color8(20, 20, 20)
const _MOUTH := Color8(150, 70, 70)
const _WHITE := Color(1, 1, 1, 1)


# 主入口: appearance → SpriteFrames。无参用默认。
static func build_sprite_frames(appearance: Dictionary = DEFAULT_APPEARANCE) -> SpriteFrames:
	var pal := _palette_from(appearance)
	var anims := {
		"idle": {"frames": [_frame(appearance, "idle_a"), _frame(appearance, "idle_b")], "fps": 2.0, "loop": true},
		"walk": {"frames": [_frame(appearance, "walk_a"), _frame(appearance, "idle_a"), _frame(appearance, "walk_c"), _frame(appearance, "idle_a")], "fps": 10.0, "loop": true},
		"jump": {"frames": [_frame(appearance, "jump")], "fps": 1.0, "loop": false},
		"fall": {"frames": [_frame(appearance, "fall")], "fps": 1.0, "loop": false},
		"hurt": {"frames": [_frame(appearance, "hurt")], "fps": 1.0, "loop": false},
	}
	return PixelArt.build_sprite_frames(anims, pal)


# 一帧 = 5 层合并。pose 名选每层对应姿态网格。
static func _frame(ap: Dictionary, pose: String) -> Array:
	var layers := [
		_cape_layer(ap, pose),
		_body_layer(ap, pose),
		_pants_layer(ap, pose),
		_shirt_layer(ap, pose),
		_hair_layer(ap, pose),
	]
	return _composite(layers)


# 合并: 从空白 24×48 起, 逐层把非 '.' 字符覆盖上去 (后层盖前层)。
static func _composite(layers: Array) -> Array:
	var out: Array = []
	for y in H:
		out.append(".".repeat(W))
	for layer in layers:
		if layer == null:
			continue
		for y in H:
			var row: String = out[y]
			var lrow: String = layer[y]
			var chars := row.split("")  # 注意: GDScript split("") 行为, 用下面逐字符法替代
			var merged := ""
			for x in W:
				var lc := lrow.substr(x, 1)
				merged += lc if lc != "." else row.substr(x, 1)
			out[y] = merged
	return out


static func _palette_from(ap: Dictionary) -> Dictionary:
	var skin: Color = ap.get("skin_color", DEFAULT_APPEARANCE["skin_color"])
	var hair: Color = ap.get("hair_color", DEFAULT_APPEARANCE["hair_color"])
	var shirt: Color = ap.get("shirt_color", DEFAULT_APPEARANCE["shirt_color"])
	var pants: Color = ap.get("pants_color", DEFAULT_APPEARANCE["pants_color"])
	var cape: Color = ap.get("cape_color", DEFAULT_APPEARANCE["cape_color"])
	var eye: Color = ap.get("eye_color", DEFAULT_APPEARANCE["eye_color"])
	return {
		".": Color(0, 0, 0, 0),
		"s": skin, "k": skin.darkened(0.18),
		"h": hair, "H": hair.darkened(0.28),
		"w": shirt, "D": shirt.darkened(0.28),
		"b": pants, "B": pants.darkened(0.28),
		"c": cape, "C": cape.darkened(0.28),
		"i": eye, "W": _WHITE, "e": _EYE_DARK, "m": _MOUTH,
		"o": _BOOT, "O": _BOOT_SH,
	}
```

各层函数返回 24×48 网格。本 Task 实现:
- `_cape_layer`: 本 Task 一律返回全透明 (cape_style 0)。其它 cape 号回退透明 (Plan 4)。
- `_body_layer`: 按 `gender`。本 Task 只做**男** (gender 0); gender 1 本 Task 也先用男身体 (Task 3 补女)。男身体 = 侧面、皮肤+靴+侧脸(含眼白`W`/眼珠`i`/睫毛`e`/嘴`m`), 躯干/腿留 `.`。给出 7 个 pose (idle_a/idle_b/walk_a/walk_c/jump/fall/hurt)。
- `_pants_layer`: pants_style 0 (长裤) → 腿部 `b/B` 填充, 跟随 pose 腿姿。其它号回退长裤。
- `_shirt_layer`: shirt_style 0 (T恤) → 躯干 `w/D` 填充。其它号回退 T恤。
- `_hair_layer`: hair_style 0 (短发) → 头顶 `h/H`。其它号本 Task 回退短发 (Task 4 补)。

**默认男 idle_a 完整示例** (24×48, 朝右; 执行者照此风格画其余 pose + 各层; 这是"默认基准", 像素测试锁它):

```
# 仅作锚点/风格参考 — 执行时把"身体层"与"裤子/衬衫/头发层"拆开 (此处是合并后效果示意)。
# row0-1 透明; 头 row2-15; 躯干(衬衫) row16-30; 腿(裤子) row31-45; 靴 row46-47。
# (此处省略逐行 ascii: 执行者按上面锚点+调色板字符绘制, 满足 Step1 像素断言即可;
#  关键: 朝右侧脸 row7 有 'W'(眼白)+'i'(眼珠); 躯干 row20 有 'w'; 腿 row38 有 'b'; row47 有 'o'。)
```

> **执行注意**: ascii 绘制是视觉迭代活。先画出能过 Step 1 全部断言的版本 (尺寸/动画齐全/默认基准自洽/衬衫色·眼睛·回退正确), 跑通后用 `tests/unit/test_export_animal_preview.gd` 同款手法导出 PNG 自查 + 让用户眼验, 再回调细节 (明暗/侧脸/靴)。`_composite` 里 `split("")` 那行按注释改成逐字符 substr 安全写法。

- [ ] **Step 4: 跑测试确认通过**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_player_art_appearance.gd -gexit`
Expected: PASS (6 passing)。

- [ ] **Step 5: 导出 PNG 自查 (可选但建议)**

加一个临时导出 (照 `tests/unit/test_export_animal_preview.gd`): 把 idle/walk 各帧存 `/tmp/preview_player_*.png`, 自己 Read 看侧面/眼睛/比例对不对; 不对就调 ascii 回 Step 4。

- [ ] **Step 6: Commit**

```bash
git add scripts/art/player_art.gd tests/unit/test_player_art_appearance.gd
git commit -m "feat(character-art): 24×48 侧面单眼分层框架 + 默认男小人 + 像素测试"
```

---

## Task 2: 玩家场景缩放 + 按角色外观出图接线

**Files:**
- Modify: `scenes/player/player.tscn` (AnimatedSprite2D offset/scale)
- Modify: `scripts/autoload/art_cache.gd` (加 `player_frames_for`)
- Modify: `scripts/player/player_controller.gd:82` (用当前角色外观)
- Modify: `scripts/entities/remote_player.gd:18` (同款, fallback 默认)
- Test: `tests/unit/test_player_art_scale_wiring.gd` (新建)

- [ ] **Step 1: 写失败测试**

Create `tests/unit/test_player_art_scale_wiring.gd`:

```gdscript
extends GutTest

func test_artcache_player_frames_for_returns_frames():
	var ap = {
		"gender": 0, "hair_style": 0, "shirt_style": 0, "pants_style": 0,
		"cape_style": 0, "chest_size": 1,
		"skin_color": Color8(255, 218, 185), "hair_color": Color8(121, 85, 72),
		"shirt_color": Color8(10, 200, 30), "pants_color": Color8(38, 70, 130),
		"cape_color": Color8(150, 40, 50), "eye_color": Color8(60, 110, 70),
	}
	var sf = ArtCache.player_frames_for(ap)
	assert_true(sf is SpriteFrames, "返回 SpriteFrames")
	assert_eq(sf.get_frame_texture("idle", 0).get_width(), 24, "24 宽")

func test_player_scene_sprite_scaled_for_48px_art():
	# 24×48 art × scale 应 ≈ 旧 12×24 × (1.2,1.25) = 屏幕 (14.4, 30)
	var p = preload("res://scenes/player/player.tscn").instantiate()
	add_child_autofree(p)
	var spr: AnimatedSprite2D = p.get_node("AnimatedSprite2D")
	assert_almost_eq(spr.scale.x, 0.6, 0.01, "scale.x 减半")
	assert_almost_eq(spr.scale.y, 0.625, 0.01, "scale.y 减半")
	assert_eq(spr.offset, Vector2(-12, 0), "offset 水平居中 24 宽")
```

- [ ] **Step 2: 跑确认失败**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_player_art_scale_wiring.gd -gexit`
Expected: FAIL — `player_frames_for` 不存在 + scale 还是 (1.2,1.25)。

- [ ] **Step 3: 改 player.tscn**

`scenes/player/player.tscn` 的 AnimatedSprite2D 节点 (第 20-24 行):
```
offset = Vector2(-6, 0)
scale = Vector2(1.2, 1.25)
```
改成:
```
offset = Vector2(-12, 0)
scale = Vector2(0.6, 0.625)
```
(`position = Vector2(0, -30)` / `centered = false` 不变: 48×0.625=30 高, 脚底仍在原点; 碰撞体不动。)

- [ ] **Step 4: 改 art_cache.gd**

`scripts/autoload/art_cache.gd` 加方法 (放 `_build_entities` 后或文件末尾):
```gdscript
# 按角色外观出玩家 SpriteFrames (捏人/换装用)。player_frames (默认) 仍由 _build_entities 缓存。
func player_frames_for(appearance: Dictionary) -> SpriteFrames:
	return PlayerArt.build_sprite_frames(appearance)
```
(`_build_entities` 里 `player_frames = PlayerArt.build_sprite_frames()` 无参不变 = 默认款, 留作 loading_screen / fallback。)

- [ ] **Step 5: 改 player_controller.gd:82**

把 `sprite.sprite_frames = ArtCache.player_frames` 改成:
```gdscript
	# 用当前角色外观出图; 没选角色 (测试/老流程) fallback 默认 player_frames。
	if typeof(CharacterManager) != TYPE_NIL and CharacterManager.current != null:
		sprite.sprite_frames = ArtCache.player_frames_for(CharacterManager.current.appearance_dict())
	else:
		sprite.sprite_frames = ArtCache.player_frames
```

- [ ] **Step 6: 改 remote_player.gd:18**

`_sprite.sprite_frames = ArtCache.player_frames` 暂保持默认 (联机外观同步 = spec 非目标)。仅加注释:
```gdscript
	# 远程玩家暂用默认外观 (联机外观同步是后续, 见 spec 非目标)。
	_sprite.sprite_frames = ArtCache.player_frames
```

- [ ] **Step 7: 跑测试 + 全回归**

```bash
godot --headless --editor --quit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gselect=test_player_art_scale_wiring.gd -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 新测试 PASS; 全套无新增失败 (既有牛爬台阶 1 个失败属无关, 不计)。
`./run.sh --rebuild` 让用户眼验: 玩家变侧面小人、大小/落点跟以前一样。

- [ ] **Step 8: Commit**

```bash
git add scenes/player/player.tscn scripts/autoload/art_cache.gd scripts/player/player_controller.gd scripts/entities/remote_player.gd tests/unit/test_player_art_scale_wiring.gd
git commit -m "feat(character-art): 玩家场景缩放适配 24×48 + 按角色外观出图接线"
```

---

## Task 3: 女身体 + 胸围 0..5

**Files:**
- Modify: `scripts/art/player_art.gd` (`_body_layer` 加 gender 1 + chest_size)
- Test: `tests/unit/test_player_art_appearance.gd` (加断言)

- [ ] **Step 1: 加失败测试** (追加到 test_player_art_appearance.gd)

```gdscript
func test_female_body_differs_from_male():
	var m = _default_appearance(); m["gender"] = 0
	var f = _default_appearance(); f["gender"] = 1
	var im = PlayerArt.build_sprite_frames(m).get_frame_texture("idle", 0).get_image()
	var iff = PlayerArt.build_sprite_frames(f).get_frame_texture("idle", 0).get_image()
	var diff := 0
	for y in range(48):
		for x in range(24):
			if im.get_pixel(x, y) != iff.get_pixel(x, y):
				diff += 1
	assert_gt(diff, 10, "女身体与男身体有明显差异 (重画比例)")

func test_chest_size_changes_female_torso():
	var f0 = _default_appearance(); f0["gender"] = 1; f0["chest_size"] = 0
	var f5 = _default_appearance(); f5["gender"] = 1; f5["chest_size"] = 5
	var i0 = PlayerArt.build_sprite_frames(f0).get_frame_texture("idle", 0).get_image()
	var i5 = PlayerArt.build_sprite_frames(f5).get_frame_texture("idle", 0).get_image()
	var diff := 0
	for y in range(16, 26):   # 胸口区
		for x in range(24):
			if i0.get_pixel(x, y) != i5.get_pixel(x, y):
				diff += 1
	assert_gt(diff, 0, "胸围 0 与 5 在胸口区像素不同")

func test_male_ignores_chest_size():
	var m0 = _default_appearance(); m0["gender"] = 0; m0["chest_size"] = 0
	var m5 = _default_appearance(); m5["gender"] = 0; m5["chest_size"] = 5
	var i0 = PlayerArt.build_sprite_frames(m0).get_frame_texture("idle", 0).get_image()
	var i5 = PlayerArt.build_sprite_frames(m5).get_frame_texture("idle", 0).get_image()
	for y in range(48):
		for x in range(24):
			assert_eq(i0.get_pixel(x, y), i5.get_pixel(x, y), "男版不受 chest_size 影响 (%d,%d)" % [x, y])
```

- [ ] **Step 2: 跑确认失败** (女==男, chest 不变)

Run: `... -gselect=test_player_art_appearance.gd ...` → 新 3 断言 FAIL。

- [ ] **Step 3: 实现女身体 + 胸围**

`_body_layer(ap, pose)`: `gender==1` 时返回女版网格组 (肩窄/腰收/侧脸睫毛); 女版躯干 row16..26 按 `chest_size` (0..5) 取胸口前凸变体 (每档前缘多 1 列 `s`/`k`)。`gender==0` 时男版, 忽略 chest_size。给出男女各 7 pose。

> 执行: 女身体共用锚点行 (头/臂/腿一致), 只躯干宽窄 + 胸口弧 + 脸睫毛不同。chest 变体可用一个 helper 把基础女躯干网格在胸口行右移/补 `chest_size` 个像素。

- [ ] **Step 4: 跑通** → PASS。
- [ ] **Step 5: Commit**
```bash
git add scripts/art/player_art.gd tests/unit/test_player_art_appearance.gd
git commit -m "feat(character-art): 女身体(重画比例) + 胸围 0..5 + 测试"
```

---

## Task 4: 4 发型 + 头发换色

**Files:**
- Modify: `scripts/art/player_art.gd` (`_hair_layer` 4 款)
- Test: `tests/unit/test_player_art_appearance.gd` (加断言)

- [ ] **Step 1: 加失败测试**

```gdscript
func test_hairstyles_differ():
	var imgs := []
	for hs in range(4):
		var ap = _default_appearance(); ap["hair_style"] = hs
		imgs.append(PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image())
	# 任意两款头顶区 (row 2..8) 应有差异
	for a in range(4):
		for c in range(a + 1, 4):
			var diff := 0
			for y in range(2, 9):
				for x in range(24):
					if imgs[a].get_pixel(x, y) != imgs[c].get_pixel(x, y):
						diff += 1
			assert_gt(diff, 0, "发型 %d 与 %d 不同" % [a, c])

func test_hair_color_follows_appearance():
	var ap = _default_appearance(); ap["hair_color"] = Color8(20, 180, 220)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(20, 180, 220), 2..10, 6..20), "头发是所选色")
```

- [ ] **Step 2: 跑确认失败** (4 款现都回退短发 → 相同)。
- [ ] **Step 3: 实现 `_hair_layer` 4 款** (0 短发 / 1 长发 / 2 马尾 / 3 呆毛), 头发用 `h/H`, 跟随 idle_b 头部下沉 1px。
- [ ] **Step 4: 跑通** → PASS。
- [ ] **Step 5: Commit**
```bash
git add scripts/art/player_art.gd tests/unit/test_player_art_appearance.gd
git commit -m "feat(character-art): 4 发型 + 头发换色 + 测试"
```

---

## Task 5: 换色全覆盖回归 (皮肤/裤子/眼珠) + Plan 2 收尾

**Files:**
- Test: `tests/unit/test_player_art_appearance.gd` (加断言)
- (必要时微调 `player_art.gd`)

- [ ] **Step 1: 加失败/验证测试**

```gdscript
func test_skin_color_follows_appearance():
	var ap = _default_appearance(); ap["skin_color"] = Color8(90, 60, 40)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(90, 60, 40), 3..12, 10..20), "脸是所选肤色")

func test_pants_color_follows_appearance():
	var ap = _default_appearance(); ap["pants_color"] = Color8(20, 160, 60)
	var img = PlayerArt.build_sprite_frames(ap).get_frame_texture("idle", 0).get_image()
	assert_true(_has_color_near(img, Color8(20, 160, 60), 31..45, 8..18), "裤子是所选色")
```

- [ ] **Step 2: 跑** — 若 Task 1 调色板正确, 应直接 PASS (验证用)。不过则调 `_palette_from` / 对应层。
- [ ] **Step 3: 全套回归**

```bash
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/unit -gexit
godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://tests/integration -gexit
```
Expected: 全 PASS (除既有牛 1 失败)。

- [ ] **Step 4: Commit**
```bash
git add tests/unit/test_player_art_appearance.gd scripts/art/player_art.gd
git commit -m "feat(character-art): 皮肤/裤子/眼珠换色回归测试 — Plan 2 默认小人收尾"
```

---

## Self-Review

**Spec 覆盖 (Plan 2 = spec C 框架 + C1/C2)**:
- 侧面单眼 24×48 + 所有层侧面 → Task 1 ✅
- 男女身材不同 + 胸围 0..5 → Task 3 ✅
- 4 发型 → Task 4 ✅
- 皮肤/头发/衬衫/裤子/眼珠换色 + 眼白+眼珠 → Task 1/4/5 ✅
- 画布加大显示缩放减半保尺寸/碰撞 → Task 2 ✅
- 默认 = 新侧面基准 (不再 = 老正面) + 像素锁基准 → Task 1 `test_no_arg_uses_default...` ✅
- 按 current.appearance_dict() 出图 + 无角色 fallback → Task 2 ✅

**不在本计划 (留后续, 非遗漏)**:
- 衣裤主题款/泳衣/披风实绘 (shirt/pants/cape 非 0 号) → Plan 4
- 捏人 + 选角色 UI → Plan 3
- 美术"很多细节"(明暗/纹理) → 框架就位后在各 Task 画 ascii 时落实, 用户眼验回调

**占位/一致性**: `build_sprite_frames(appearance)` / `appearance_dict` keys / 调色板字符 / 锚点行 全计划一致。`_composite` 的 `split("")` 已标注改逐字符 substr。

**执行注意**: ascii 美术是视觉迭代 — 每 Task 先满足像素断言, 再导 PNG + 用户眼验回调细节。改 .tscn (Task 2) 手写文本, 注意 UID 不动。
