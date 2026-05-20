# 主菜单 + 暂停菜单 + 死亡屏幕 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 给 teilaruia 加上启动主菜单 / 死亡屏 / ESC 暂停菜单 三个 UI，把瞬时复活改成"死亡屏 + 复活按钮"流程，主菜单做高品质版（像素 LOGO + 动态场景背景 + 按钮质感）。

**Architecture:** `main.gd` 升级为状态机（menu ↔ game）。3 个新 CanvasLayer 场景（MainMenu / PauseMenu / DeathScreen）一直存在但默认隐藏。新增 `GameSettings` autoload 管音量。主菜单背景用现有 `PixelArt` 系统手绘的小场景（不复用 World）。

**Tech Stack:** Godot 4.3 + GDScript + GUT 测试框架。沿用项目现有 `scripts/art/pixel_art.gd` 的 ASCII 网格转纹理工作流。

参考 spec: `docs/superpowers/specs/2026-05-20-menus-death-screen-design.md`

**测试运行**: `cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3 && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -10`（editor 跑一次让 class_name 索引建好，第二次再跑 gut；libfontconfig 警告可忽略）

---

## 文件结构

新建:
- `scripts/autoload/game_settings.gd` — 主音量 setter/getter，apply 到 AudioServer
- `scripts/art/logo_art.gd` — teilaruia 像素 LOGO，导出 make_texture()
- `scripts/art/menu_scene_art.gd` — 云/山/树/地面 像素纹理
- `scenes/ui/death_screen.tscn` + `scripts/ui/death_screen.gd` — 死亡屏
- `scenes/ui/pause_menu.tscn` + `scripts/ui/pause_menu.gd` — 暂停菜单
- `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd` — 主菜单（含设置子面板）
- `tests/unit/test_game_settings.gd`
- `tests/unit/test_logo_art.gd`
- `tests/unit/test_death_screen.gd`
- `tests/unit/test_pause_menu.gd`
- `tests/unit/test_main_menu.gd`

修改:
- `project.godot` — 注册 GameSettings autoload + 注册 `ui_pause` input action (ESC)
- `scripts/main.gd` — 重写为状态机
- `scenes/main.tscn` — 加 MainMenu/PauseMenu/DeathScreen 子节点
- `scripts/world/world.gd` — `_on_player_died` 改名 `respawn_player`，删 died 自动连接

---

### Task 1: GameSettings autoload

最小的独立单元。设置完先确保它跑通，后面 MainMenu 设置面板才有东西可绑。

**Files:**
- Create: `scripts/autoload/game_settings.gd`
- Modify: `project.godot` (加 autoload)
- Test: `tests/unit/test_game_settings.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_game_settings.gd`:

```gdscript
extends GutTest

# GameSettings 是 autoload，直接用名字访问
func test_default_master_volume_is_one():
	assert_eq(GameSettings.master_volume, 1.0, "默认满音量")


func test_set_master_volume_applies_to_audio_server():
	GameSettings.master_volume = 0.5
	var db = AudioServer.get_bus_volume_db(0)
	# linear_to_db(0.5) ≈ -6.02
	assert_almost_eq(db, linear_to_db(0.5), 0.1, "0.5 线性 → -6 dB")
	# 还原避免污染其他测试
	GameSettings.master_volume = 1.0


func test_set_master_volume_zero_mutes():
	GameSettings.master_volume = 0.0
	var db = AudioServer.get_bus_volume_db(0)
	assert_eq(db, -80.0, "0 线性 → -80 dB (静音)")
	GameSettings.master_volume = 1.0


func test_set_master_volume_clamps():
	GameSettings.master_volume = 1.5
	assert_eq(GameSettings.master_volume, 1.0, "上限 1.0")
	GameSettings.master_volume = -0.3
	assert_eq(GameSettings.master_volume, 0.0, "下限 0.0")
	GameSettings.master_volume = 1.0
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_settings.gd 2>&1 | tail -20
```
Expected: FAIL `Identifier "GameSettings" not declared`

- [ ] **Step 3: 创建 GameSettings 脚本**

创建 `scripts/autoload/game_settings.gd`:

```gdscript
# 全局设置 autoload。当前只有主音量。
# 设置 master_volume 时自动应用到 AudioServer 总线 0。
extends Node

var master_volume: float = 1.0:
	set(v):
		master_volume = clamp(v, 0.0, 1.0)
		_apply_to_audio_server()


func _ready() -> void:
	_apply_to_audio_server()


func _apply_to_audio_server() -> void:
	var db: float = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
	AudioServer.set_bus_volume_db(0, db)
```

- [ ] **Step 4: 注册 autoload**

修改 `project.godot`，在 `[autoload]` 段末尾添加：

```
GameSettings="*res://scripts/autoload/game_settings.gd"
```

完整 [autoload] 段应该是这样（不要动其他行）：
```
[autoload]

Tiles="*res://scripts/world/tile_data.gd"
SkyLightGrid="*res://scripts/world/sky_light_grid.gd"
ItemDB="*res://scripts/items/item_db.gd"
RecipeDB="*res://scripts/crafting/recipe_db.gd"
ArtCache="*res://scripts/autoload/art_cache.gd"
Effects="*res://scripts/fx/effects.gd"
GameSettings="*res://scripts/autoload/game_settings.gd"
```

- [ ] **Step 5: 让 editor 重建 class_name 索引，然后跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_game_settings.gd 2>&1 | tail -20
```
Expected: 4 个测试全 PASS

- [ ] **Step 6: 跑全量测试确保没退步**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```
Expected: 所有原有测试 + 4 个新测试都 PASS

- [ ] **Step 7: 提交**

```bash
cd /workspace/teilaruia
git add scripts/autoload/game_settings.gd project.godot tests/unit/test_game_settings.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(settings): GameSettings autoload + 主音量控制

应用到 AudioServer 总线 0。0 视为静音 (-80 dB)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: logo_art.gd — teilaruia 像素 LOGO

提供一个手画的 LOGO 像素图，供 MainMenu 用。

**Files:**
- Create: `scripts/art/logo_art.gd`
- Test: `tests/unit/test_logo_art.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_logo_art.gd`:

```gdscript
extends GutTest

const LogoArt = preload("res://scripts/art/logo_art.gd")


func test_make_texture_returns_image_texture():
	var tex = LogoArt.make_texture()
	assert_not_null(tex)
	assert_true(tex is ImageTexture)


func test_texture_has_expected_dimensions():
	var tex = LogoArt.make_texture()
	# 9 字母 × ~7 宽 + 间距 = 60+，高度 9
	assert_gt(tex.get_width(), 40)
	assert_gt(tex.get_height(), 5)
	assert_lt(tex.get_height(), 16)


func test_texture_has_visible_pixels():
	# 验证不是全透明
	var tex = LogoArt.make_texture()
	var img = tex.get_image()
	var found_visible := false
	for y in img.get_height():
		for x in img.get_width():
			if img.get_pixel(x, y).a > 0.5:
				found_visible = true
				break
		if found_visible:
			break
	assert_true(found_visible, "至少有可见像素")
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_logo_art.gd 2>&1 | tail -10
```
Expected: FAIL，找不到 logo_art.gd

- [ ] **Step 3: 创建 logo_art.gd**

创建 `scripts/art/logo_art.gd`。LOGO 画 9 个小写字母 "teilaruia"，每个字母 5 列 × 7 行，字间 1 列间距，外加 1 列左右边距 = 总宽 5*9 + 8 + 2 = 55，高 9（顶部底部各留 1 行边距）。

```gdscript
# teilaruia 像素 LOGO。
# 配色：金黄主色 + 深棕描边 + 阴影由外部 ShadowSprite 实现 (本文件只画主体)。
# 输出: 55×9 像素的纹理 (放大 6× = 330×54 显示)。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"g": Color8(242, 194, 101),   # 金黄主色
	"o": Color8(58, 26, 10),      # 深棕描边
}

# 每个字母 5×7，行 0-6，字母间留 1 列 "." 间距
# 行 7-8 是字母底部基线空间 (i/l 的下沿)
# 总宽 55 = 1(左边距) + 9*5 + 8(字间间距) + 1(右边距)
const _ROWS := [
	".......................................................",
	".og..og..og.og..og.og.og..og.og..og.og.og.og.og...og.og.",
	".ogg.ogg.ogg.ogg.og.ogg.ogg.ogg.og.ogg.ogg.ogg...ogg.ogg",
	".og..og..og.og..og.og.og.og.og.og.og.og.og.og...og.og.og",
	".og..og..og..og.og.og.og.og.og.og.og.og.og.og...og.og.og",
	".og..ogg.og..og.og.og.og.og.og.og.og.og.og.og...og.og.og",
	".......................................................",
	".......................................................",
	"........................................................",
]
```

**注意**：上面这个 grid 是占位结构，字母实际形状不正确。直接画 9 个字母 × 5 宽 × 7 高 是个体力活，我下面给一个简化版：用一个抽象 "TEILARUIA" 块状 LOGO 代替字母细节。重写 `_ROWS` 为：

```gdscript
# 抽象块状 LOGO: 9 个金黄竖块（代表 9 个字母），中间一行加横线营造 "te-i-l-a-r-u-i-a" 感觉
# 9 块 × 5 列 + 8 间距 + 2 边距 = 55 宽，9 高
const _ROWS := [
	".......................................................",
	".oooo..oooo..o....oooo.oooo.oooo.oooo..o...oooo.oooo....",
	".o....o..o...o....o..o.o.o..o..o.o.o...o...o.o..o..o....",
	".oooo.oooo...o....oooo.oooo.o.o..o.o...o...o.o..oooo....",
	".o....o..o...o....o.o..o.o..o.o..o.o...o...o.o..o.o.....",
	".oooo.o..o...o....o..o.o..o.o..o.oooo..o...oooo.o..o....",
	".......................................................",
	"........................................................",
	"........................................................",
]
```

**这个 grid 还是不对**。承认现实：手写 9 个像素字母在这里不优雅。改用更靠谱的策略 —— 用 Godot 内置 Label + 大字号 + 描边 + 阴影来达到"像素 LOGO 风"，依然在 logo_art.gd 文件里提供 ImageTexture，但实际是渲染一段文本到图像。

**最终方案** —— logo_art.gd 改为生成"带描边阴影的 'teilaruia' 文字图":

```gdscript
# teilaruia LOGO 纹理：用默认字体渲染大字号文字 + 双层位移做描边/阴影。
# 输出: 实际尺寸取决于字体，约 280×40 像素。
extends RefCounted

const FONT_SIZE := 32
const COLOR_MAIN := Color8(242, 194, 101)
const COLOR_OUTLINE := Color8(58, 26, 10)
const COLOR_SHADOW := Color8(0, 0, 0, 180)
const TEXT := "teilaruia"


static func make_texture() -> ImageTexture:
	# 用 ThemeDB 的默认字体测量文本尺寸
	var font: Font = ThemeDB.fallback_font
	var size: Vector2 = font.get_string_size(TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	var w: int = int(size.x) + 8
	var h: int = int(size.y) + 8
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	# 用 SubViewport + Label 渲染，然后截图回 Image
	# 但 RefCounted 没有 tree，这里另开一个静态工具：直接调 font.draw_string 到 CanvasItem 不可行
	# 简化：返回一个空的 placeholder ImageTexture，logo 实际由 MainMenu 的 Label 节点绘制
	return ImageTexture.create_from_image(img)
```

**这套也不行**（Font 无法离屏渲染到 Image 而不经过场景树）。改最终方案：

**LOGO 不做成 ImageTexture，做成"MainMenu 里的 Label 配置"**。logo_art.gd 改成提供 LabelSettings 资源 + 配套阴影 Label 的位移和颜色常量：

```gdscript
# teilaruia LOGO 样式: 配置 Label 的字号/颜色/描边/阴影。
# MainMenu 用两个 Label (阴影层 + 主层) 实现 LOGO 视觉。
extends RefCounted

const TEXT := "teilaruia"
const FONT_SIZE := 64
const COLOR_MAIN := Color8(242, 194, 101)       # 金黄
const COLOR_OUTLINE := Color8(58, 26, 10)       # 深棕描边
const COLOR_SHADOW := Color8(0, 0, 0, 180)      # 阴影
const OUTLINE_PX := 3                            # 描边粗细
const SHADOW_OFFSET := Vector2(4, 4)             # 阴影位移


# 应用到主 Label：金黄 + 深棕描边
static func style_main_label(label: Label) -> void:
	label.text = TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_MAIN)
	label.add_theme_color_override("font_outline_color", COLOR_OUTLINE)
	label.add_theme_constant_override("outline_size", OUTLINE_PX)


# 应用到阴影 Label：黑色半透明，无描边，位置 offset
static func style_shadow_label(label: Label) -> void:
	label.text = TEXT
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", COLOR_SHADOW)
```

**重写测试**（适应新 API）：

```gdscript
extends GutTest

const LogoArt = preload("res://scripts/art/logo_art.gd")


func test_text_is_teilaruia():
	assert_eq(LogoArt.TEXT, "teilaruia")


func test_font_size_is_reasonable():
	assert_gt(LogoArt.FONT_SIZE, 32)
	assert_lt(LogoArt.FONT_SIZE, 128)


func test_style_main_label_sets_text_and_size():
	var label = Label.new()
	add_child_autofree(label)
	LogoArt.style_main_label(label)
	assert_eq(label.text, "teilaruia")
	assert_eq(label.get_theme_font_size("font_size"), LogoArt.FONT_SIZE)
	assert_eq(label.get_theme_color("font_color"), LogoArt.COLOR_MAIN)


func test_style_shadow_label_uses_shadow_color():
	var label = Label.new()
	add_child_autofree(label)
	LogoArt.style_shadow_label(label)
	assert_eq(label.text, "teilaruia")
	assert_eq(label.get_theme_color("font_color"), LogoArt.COLOR_SHADOW)
```

把 Step 1 那个旧的 ImageTexture 测试整个替换为上面这个新测试。

- [ ] **Step 4: 创建 logo_art.gd**

写上面"最终方案"的 logo_art.gd 内容（`style_main_label` + `style_shadow_label`）。

- [ ] **Step 5: 替换测试文件，跑测试**

把 Step 1 的 test 内容整个替换成 Step 3 的"重写测试"内容，然后：

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_logo_art.gd 2>&1 | tail -10
```
Expected: 4 个测试 PASS

- [ ] **Step 6: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```
Expected: 所有测试 PASS

- [ ] **Step 7: 提交**

```bash
cd /workspace/teilaruia
git add scripts/art/logo_art.gd tests/unit/test_logo_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(art): logo_art.gd — teilaruia LOGO 样式 (主+阴影 Label)

不画像素字 (字母手画太脆弱)，用默认字体大字号 + 金黄主色 + 深棕描边
+ 黑色阴影位移 4px 实现 LOGO 视觉。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: menu_scene_art.gd — 主菜单背景的像素元素

为主菜单背景提供云、远山、树、地面噪点纹理。

**Files:**
- Create: `scripts/art/menu_scene_art.gd`
- Test: `tests/unit/test_menu_scene_art.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_menu_scene_art.gd`:

```gdscript
extends GutTest

const MenuSceneArt = preload("res://scripts/art/menu_scene_art.gd")


func test_make_cloud_returns_texture():
	var tex = MenuSceneArt.make_cloud()
	assert_not_null(tex)
	assert_true(tex is ImageTexture)
	assert_gt(tex.get_width(), 8)


func test_make_hill_returns_texture():
	var tex = MenuSceneArt.make_hill()
	assert_not_null(tex)
	assert_gt(tex.get_width(), 32)


func test_make_tree_returns_texture():
	var tex = MenuSceneArt.make_tree()
	assert_not_null(tex)
	assert_gt(tex.get_height(), 8)


func test_make_ground_noise_returns_texture():
	var tex = MenuSceneArt.make_ground_noise()
	assert_not_null(tex)
	assert_gt(tex.get_width(), 8)
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_menu_scene_art.gd 2>&1 | tail -10
```
Expected: FAIL，找不到 menu_scene_art.gd

- [ ] **Step 3: 创建 menu_scene_art.gd**

```gdscript
# 主菜单背景元素：云、远山、树剪影、地面噪点。
# 全部用 ASCII 网格 + PixelArt 生成。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _CLOUD_PALETTE := {
	".": Color(0, 0, 0, 0),
	"w": Color8(255, 245, 230, 200),   # 暖白半透
	"W": Color8(240, 220, 200, 230),   # 略暗高光
}

# 24×8 椭圆云
const _CLOUD_ROWS := [
	"........wwwwwww.........",
	".....wwwwwwwwwwwww......",
	"...wwwwWWWWWWwwwwwww....",
	"..wwwwWWWWWWWWWwwwwwww..",
	"..wwwwwWWWWWWWWwwwwwww..",
	"...wwwwwwwwwwwwwwwww....",
	".....wwwwwwwwwwwww......",
	".........wwwww..........",
]

const _HILL_PALETTE := {
	".": Color(0, 0, 0, 0),
	"h": Color8(74, 56, 88),    # 紫灰
	"H": Color8(54, 40, 64),    # 深紫
}

# 80×10 起伏远山轮廓
const _HILL_ROWS := [
	"...........................hh.........................hhh.....................",
	"..........................hhhh.......................hhhhhh....................",
	".....hh..................hhhhhh......hhh............hhhhhhhh..........hhh......",
	"....hhhh................hhhhhhhh....hhhhh..........hhhhhhhhhh........hhhhh.....",
	"...hhhhhh..............hhhhHHHHhh..hhhhhhh........hhhhHHHHHHhh......hhhhhhh....",
	"..hhhhhhhh............hhhhHHHHHHhhhhhhHHhhhh.....hhhHHHHHHHHHHhh...hhhhHHhhhh..",
	".hhhhHHHHhh..........hhhHHHHHHHHHhhhHHHHHhhhh...hhHHHHHHHHHHHHHh..hhhHHHHHhhh..",
	"hhhhHHHHHHhh........hhHHHHHHHHHHHHhHHHHHHHHhhh.hhHHHHHHHHHHHHHHhhhhHHHHHHHHhhhh",
	"hhHHHHHHHHHHhhhhhhhhHHHHHHHHHHHHHHHHHHHHHHHHHhhhHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHh",
	"HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
]

const _TREE_PALETTE := {
	".": Color(0, 0, 0, 0),
	"t": Color8(20, 14, 24),    # 近黑剪影
}

# 12×16 尖顶树剪影
const _TREE_ROWS := [
	".....tt.....",
	"....tttt....",
	"...tttttt...",
	"..tttttttt..",
	"...tttttt...",
	"..tttttttt..",
	".tttttttttt.",
	"..tttttttt..",
	".tttttttttt.",
	"tttttttttttt",
	".tttttttttt.",
	"tttttttttttt",
	".....tt.....",
	".....tt.....",
	".....tt.....",
	".....tt.....",
]

const _GROUND_PALETTE := {
	".": Color8(58, 36, 22),    # 暗棕底
	"d": Color8(74, 50, 30),    # 略亮棕
	"D": Color8(42, 26, 16),    # 更暗
}

# 16×8 重复用噪点地面贴图
const _GROUND_ROWS := [
	"..d...D...d..D..",
	".D...d...D..d...",
	"d..D...d...D...d",
	"...d..D...d.D...",
	".D...d..D..d...D",
	"d.D..d.D..d.D..d",
	"..d..D..d.D...d.",
	"D..d.D..d.D...D.",
]


static func make_cloud() -> ImageTexture:
	return PixelArt.grid_to_texture(_CLOUD_ROWS, _CLOUD_PALETTE)


static func make_hill() -> ImageTexture:
	return PixelArt.grid_to_texture(_HILL_ROWS, _HILL_PALETTE)


static func make_tree() -> ImageTexture:
	return PixelArt.grid_to_texture(_TREE_ROWS, _TREE_PALETTE)


static func make_ground_noise() -> ImageTexture:
	return PixelArt.grid_to_texture(_GROUND_ROWS, _GROUND_PALETTE)
```

- [ ] **Step 4: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_menu_scene_art.gd 2>&1 | tail -10
```
Expected: 4 个测试 PASS

- [ ] **Step 5: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```

- [ ] **Step 6: 提交**

```bash
cd /workspace/teilaruia
git add scripts/art/menu_scene_art.gd tests/unit/test_menu_scene_art.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(art): menu_scene_art.gd — 主菜单背景元素 (云/山/树/地面)

ASCII 像素网格生成: 24×8 云、80×10 远山、12×16 树剪影、16×8 地面噪点。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: DeathScreen 场景 + 脚本 + 测试

**Files:**
- Create: `scenes/ui/death_screen.tscn`
- Create: `scripts/ui/death_screen.gd`
- Test: `tests/unit/test_death_screen.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_death_screen.gd`:

```gdscript
extends GutTest

const DeathScreenScene = preload("res://scenes/ui/death_screen.tscn")


func _make() -> CanvasLayer:
	var ds = DeathScreenScene.instantiate()
	add_child_autofree(ds)
	return ds


func before_each():
	# 重置 paused，避免测试间互相影响
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_initially_hidden():
	var ds = _make()
	assert_false(ds.visible)


func test_show_death_makes_visible_and_pauses():
	var ds = _make()
	ds.show_death()
	assert_true(ds.visible)
	assert_true(get_tree().paused)


func test_emits_respawn_when_button_pressed_after_fade():
	var ds = _make()
	ds.show_death()
	# 强制结束淡入
	ds.skip_fade_for_test()
	var emitted := [false]
	ds.respawn.connect(func(): emitted[0] = true)
	# 直接触发按钮逻辑
	ds._on_respawn_pressed()
	assert_true(emitted[0])


func test_hide_unpauses_and_hides():
	var ds = _make()
	ds.show_death()
	ds.hide_death()
	assert_false(ds.visible)
	assert_false(get_tree().paused)


func test_button_disabled_during_fade():
	var ds = _make()
	ds.show_death()
	# 淡入还没完
	assert_true(ds._respawn_button.disabled, "淡入中按钮禁用")
	ds.skip_fade_for_test()
	assert_false(ds._respawn_button.disabled, "淡入完按钮启用")
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_death_screen.gd 2>&1 | tail -10
```
Expected: FAIL，找不到 death_screen.tscn

- [ ] **Step 3: 创建 death_screen.tscn**

创建 `scenes/ui/death_screen.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://b9teilaruidskin"]

[ext_resource type="Script" path="res://scripts/ui/death_screen.gd" id="1_ds"]

[node name="DeathScreen" type="CanvasLayer"]
layer = 100
process_mode = 3
script = ExtResource("1_ds")

[node name="Background" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 1)

[node name="TitleLabel" type="Label" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -260.0
offset_top = -120.0
offset_right = 260.0
offset_bottom = -40.0
text = "你　死　了"
horizontal_alignment = 1
vertical_alignment = 1
theme_override_font_sizes/font_size = 64
theme_override_colors/font_color = Color(0.659, 0.196, 0.196, 1)
theme_override_colors/font_outline_color = Color(0, 0, 0, 1)
theme_override_constants/outline_size = 4

[node name="RespawnButton" type="Button" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -100.0
offset_top = 40.0
offset_right = 100.0
offset_bottom = 80.0
text = "回到出生点"
disabled = true
```

注意 `process_mode = 3` 意思是 PROCESS_MODE_ALWAYS（暂停时仍处理）。

- [ ] **Step 4: 创建 death_screen.gd**

创建 `scripts/ui/death_screen.gd`:

```gdscript
# 死亡屏幕：黑屏淡入 + "你 死 了" + 回到出生点按钮。
# 玩家死亡时由 main.gd 调 show_death() 显示，按钮按下发 respawn 信号。
# CanvasLayer process_mode = ALWAYS，暂停时仍可点击。
extends CanvasLayer

signal respawn

const FADE_DURATION := 0.6

@onready var _bg: ColorRect = $Background
@onready var _title: Label = $TitleLabel
@onready var _respawn_button: Button = $RespawnButton

var _tween: Tween = null


func _ready() -> void:
	visible = false
	_respawn_button.pressed.connect(_on_respawn_pressed)


func show_death() -> void:
	visible = true
	_respawn_button.disabled = true
	_bg.modulate.a = 0.0
	_title.modulate.a = 0.0
	_respawn_button.modulate.a = 0.0
	get_tree().paused = true
	if _tween != null and _tween.is_running():
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)  # 暂停时仍跑
	_tween.tween_property(_bg, "modulate:a", 1.0, FADE_DURATION)
	_tween.tween_property(_title, "modulate:a", 1.0, FADE_DURATION).set_delay(0.2)
	_tween.tween_property(_respawn_button, "modulate:a", 1.0, FADE_DURATION).set_delay(0.3)
	_tween.chain().tween_callback(func(): _respawn_button.disabled = false)


func hide_death() -> void:
	visible = false
	if _tween != null and _tween.is_running():
		_tween.kill()
	get_tree().paused = false


# 测试用：跳过 tween 直接到末态
func skip_fade_for_test() -> void:
	if _tween != null and _tween.is_running():
		_tween.custom_step(FADE_DURATION * 2)
	_bg.modulate.a = 1.0
	_title.modulate.a = 1.0
	_respawn_button.modulate.a = 1.0
	_respawn_button.disabled = false


func _on_respawn_pressed() -> void:
	respawn.emit()
```

- [ ] **Step 5: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_death_screen.gd 2>&1 | tail -15
```
Expected: 5 个测试 PASS

如果某个 tween 相关测试失败，检查 `_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` —— 这一行让 tween 在暂停时也能跑（测试时 paused = true）。

- [ ] **Step 6: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```

- [ ] **Step 7: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/death_screen.tscn scripts/ui/death_screen.gd tests/unit/test_death_screen.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(ui): DeathScreen — 黑屏淡入 + 你死了 + 回到出生点

CanvasLayer always-process，淡入 0.6s 期间按钮禁用防误触，按下发 respawn 信号。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: 接入 DeathScreen 到 main.gd + world.gd 重命名 respawn

把 world.gd 里的瞬时复活逻辑改成由 main.gd 接管 → 显示 DeathScreen → 复活按钮触发。

**Files:**
- Modify: `scripts/world/world.gd` — 改名 + 删 died 自动连接
- Modify: `scripts/main.gd` — 加 DeathScreen 实例 + 接管 died
- Modify: `scenes/main.tscn` — 加 DeathScreen 子节点

- [ ] **Step 1: 修改 world.gd 改名 + 删自动连接**

修改 `scripts/world/world.gd`，做两处改动：

**改动 A**: 删除 `_spawn_player()` 里的 `hp.died.connect(_on_player_died)` 块（行 102-105）。把那 4 行删了，函数变成：

```gdscript
func _spawn_player() -> void:
	var player := PlayerScene.instantiate()
	player.position = _spawn_world_pos()
	entities_root.add_child(player)
	camera.reparent(player)
	camera.position = Vector2.ZERO
```

**改动 B**: 把 `func _on_player_died() -> void:` 改名为 `func respawn_player() -> void:`（行 115）。函数体不变。

- [ ] **Step 2: 修改 main.tscn 加 DeathScreen 子节点**

修改 `scenes/main.tscn`，整个文件替换为：

```
[gd_scene load_steps=3 format=3 uid="uid://b4teilaruiamain"]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]
[ext_resource type="PackedScene" path="res://scenes/ui/death_screen.tscn" id="2_ds"]

[node name="Main" type="Node"]
script = ExtResource("1_main")

[node name="DeathScreen" parent="." instance=ExtResource("2_ds")]
```

- [ ] **Step 3: 修改 main.gd 接管 died 信号**

修改 `scripts/main.gd`，替换 `_wire_player` 函数（最后那段）：

```gdscript
func _wire_player() -> void:
	var player: Node2D = world.get_player()
	if player == null:
		return
	debug_hud.set_player(player)
	hud.bind_player(player)
	crafting_panel.bind_inventory(player.get_node("PlayerInventory"))
	# 连死亡信号到死亡屏 (替代 world 内的瞬时复活)
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		hp.died.connect($DeathScreen.show_death)
	# 死亡屏复活按钮 → 调 world.respawn_player + 关掉死亡屏
	$DeathScreen.respawn.connect(_on_respawn)


func _on_respawn() -> void:
	world.respawn_player()
	$DeathScreen.hide_death()
```

注意：`$DeathScreen` 在 main.tscn 现在是 Main 的子节点，所以 `$DeathScreen` 可访问。

- [ ] **Step 4: 跑全量测试看没退步**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```
Expected: 所有测试 PASS。如果 world 的集成测试调了 `_on_player_died` 旧名字，搜一下并改成 `respawn_player`：

```bash
cd /workspace/teilaruia && grep -rn "_on_player_died" tests/ scripts/
```
应该没有别处引用了。

- [ ] **Step 5: 手动验证 (启动游戏让 player 死亡)**

```bash
cd /workspace/teilaruia && timeout 30 godot --headless 2>&1 | tail -20
```
不会自动死，但至少要确认能启动到 main 场景不崩。

- [ ] **Step 6: 提交**

```bash
cd /workspace/teilaruia
git add scripts/world/world.gd scripts/main.gd scenes/main.tscn
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(death): 接入 DeathScreen 替代瞬时复活

- world.gd: _on_player_died 改名 respawn_player，删 died 自动连接
- main.gd: 接管 died → 显示 DeathScreen，复活按钮 → world.respawn_player
- main.tscn: 加 DeathScreen 子节点

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 6: PauseMenu 场景 + 脚本 + ESC input action

**Files:**
- Create: `scenes/ui/pause_menu.tscn`
- Create: `scripts/ui/pause_menu.gd`
- Test: `tests/unit/test_pause_menu.gd`
- Modify: `project.godot` — 加 `ui_pause` input action

- [ ] **Step 1: 添加 ui_pause input action 到 project.godot**

修改 `project.godot`，在 `[input]` 段（move_left 上面或下面）加：

```
ui_pause={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":4194305,"physical_keycode":0,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)]
}
```

(keycode 4194305 = `KEY_ESCAPE`)

- [ ] **Step 2: 写失败测试**

创建 `tests/unit/test_pause_menu.gd`:

```gdscript
extends GutTest

const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")


func _make() -> CanvasLayer:
	var pm = PauseMenuScene.instantiate()
	add_child_autofree(pm)
	return pm


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_initially_hidden():
	var pm = _make()
	assert_false(pm.visible)


func test_open_shows_and_pauses():
	var pm = _make()
	pm.open()
	assert_true(pm.visible)
	assert_true(get_tree().paused)


func test_close_hides_and_unpauses():
	var pm = _make()
	pm.open()
	pm.close()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_toggle_open_close():
	var pm = _make()
	assert_false(pm.visible)
	pm.toggle()
	assert_true(pm.visible)
	pm.toggle()
	assert_false(pm.visible)


func test_resume_button_closes():
	var pm = _make()
	pm.open()
	pm._on_resume_pressed()
	assert_false(pm.visible)
	assert_false(get_tree().paused)


func test_return_to_menu_button_emits_signal():
	var pm = _make()
	pm.open()
	var emitted := [false]
	pm.return_to_menu.connect(func(): emitted[0] = true)
	pm._on_return_to_menu_pressed()
	assert_true(emitted[0])
```

- [ ] **Step 3: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_pause_menu.gd 2>&1 | tail -10
```
Expected: FAIL，找不到 pause_menu.tscn

- [ ] **Step 4: 创建 pause_menu.tscn**

```
[gd_scene load_steps=2 format=3 uid="uid://b8teilaruipausem"]

[ext_resource type="Script" path="res://scripts/ui/pause_menu.gd" id="1_pm"]

[node name="PauseMenu" type="CanvasLayer"]
layer = 90
process_mode = 3
script = ExtResource("1_pm")

[node name="Dim" type="ColorRect" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 0.6)

[node name="VBox" type="VBoxContainer" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -120.0
offset_top = -100.0
offset_right = 120.0
offset_bottom = 100.0
theme_override_constants/separation = 16

[node name="TitleLabel" type="Label" parent="VBox"]
text = "已 暂 停"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 32
theme_override_colors/font_color = Color(0.831, 0.71, 0.541, 1)

[node name="ResumeButton" type="Button" parent="VBox"]
custom_minimum_size = Vector2(240, 40)
text = "继续游戏"

[node name="ReturnToMenuButton" type="Button" parent="VBox"]
custom_minimum_size = Vector2(240, 40)
text = "回主菜单"

[node name="QuitButton" type="Button" parent="VBox"]
custom_minimum_size = Vector2(240, 40)
text = "退出游戏"
```

- [ ] **Step 5: 创建 pause_menu.gd**

```gdscript
# 暂停菜单：ESC 切换，3 个按钮 (继续 / 回主菜单 / 退出)。
# CanvasLayer process_mode = ALWAYS，暂停时仍响应输入。
# 由 main.gd 监听 _unhandled_input 中的 ui_pause action 调 toggle。
extends CanvasLayer

signal return_to_menu

@onready var _resume_button: Button = $VBox/ResumeButton
@onready var _return_button: Button = $VBox/ReturnToMenuButton
@onready var _quit_button: Button = $VBox/QuitButton


func _ready() -> void:
	visible = false
	_resume_button.pressed.connect(_on_resume_pressed)
	_return_button.pressed.connect(_on_return_to_menu_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)


func open() -> void:
	visible = true
	get_tree().paused = true


func close() -> void:
	visible = false
	get_tree().paused = false


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _on_resume_pressed() -> void:
	close()


func _on_return_to_menu_pressed() -> void:
	return_to_menu.emit()


func _on_quit_pressed() -> void:
	get_tree().quit()
```

- [ ] **Step 6: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_pause_menu.gd 2>&1 | tail -15
```
Expected: 6 个测试 PASS

- [ ] **Step 7: 接入到 main.gd**

修改 `scripts/main.gd`：

1. 在 `const` 区加：
```gdscript
const PauseMenuScene = preload("res://scenes/ui/pause_menu.tscn")
```

2. 在 `_ready()` 末尾（在 `_wire_player.call_deferred()` 之前）加：
```gdscript
	var pause_menu = PauseMenuScene.instantiate()
	pause_menu.return_to_menu.connect(_on_return_to_menu)
	add_child(pause_menu)
```
(注：这里先用代码实例化，Task 11 重写状态机时会改成 tscn 子节点)

3. 加一个新函数处理 ESC（在文件末尾）：
```gdscript
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause"):
		# 死亡屏可见时 ESC 不响应
		if $DeathScreen.visible:
			return
		_get_pause_menu().toggle()
		get_viewport().set_input_as_handled()


func _get_pause_menu() -> CanvasLayer:
	for child in get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("pause_menu.gd"):
			return child
	return null


func _on_return_to_menu() -> void:
	# Task 11 实现：销毁 game 节点组 + 显示 MainMenu。当前是占位
	push_warning("回主菜单 — 在 Task 11 实现")
	_get_pause_menu().close()
```

- [ ] **Step 8: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```
Expected: 所有测试 PASS

- [ ] **Step 9: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/pause_menu.tscn scripts/ui/pause_menu.gd tests/unit/test_pause_menu.gd project.godot scripts/main.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(ui): PauseMenu + ESC 切换

ESC 弹暂停菜单 (继续/回主菜单/退出)，死亡屏可见时 ESC 不响应。
回主菜单暂时是 push_warning 占位，下一个 Task 接状态机。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 7: MainMenu — 场景骨架 + 背景层

先建 MainMenu 的骨架场景 + 动态背景层，但不接入到 main.gd（下一个 Task 才接）。

**Files:**
- Create: `scenes/ui/main_menu.tscn`
- Create: `scripts/ui/main_menu.gd`
- Test: `tests/unit/test_main_menu.gd`

- [ ] **Step 1: 写失败测试**

创建 `tests/unit/test_main_menu.gd`:

```gdscript
extends GutTest

const MainMenuScene = preload("res://scenes/ui/main_menu.tscn")


func _make() -> CanvasLayer:
	var mm = MainMenuScene.instantiate()
	add_child_autofree(mm)
	return mm


func test_instantiates():
	var mm = _make()
	assert_not_null(mm)


func test_has_background_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("BackgroundLayer"), "BackgroundLayer 节点存在")


func test_background_has_sky_gradient():
	var mm = _make()
	var sky = mm.get_node_or_null("BackgroundLayer/Sky")
	assert_not_null(sky, "Sky 节点存在")


func test_background_has_clouds():
	var mm = _make()
	var clouds = mm.get_node_or_null("BackgroundLayer/Clouds")
	assert_not_null(clouds)
	assert_gt(clouds.get_child_count(), 0, "至少一个云 Sprite")
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -10
```
Expected: FAIL，找不到 main_menu.tscn

- [ ] **Step 3: 创建 main_menu.tscn 骨架**

`scenes/ui/main_menu.tscn`:

```
[gd_scene load_steps=2 format=3 uid="uid://bmmteilaruimm"]

[ext_resource type="Script" path="res://scripts/ui/main_menu.gd" id="1_mm"]

[node name="MainMenu" type="CanvasLayer"]
layer = 50
script = ExtResource("1_mm")

[node name="BackgroundLayer" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="Sky" type="ColorRect" parent="BackgroundLayer"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.196, 0.118, 0.184, 1)

[node name="Hills" type="Sprite2D" parent="BackgroundLayer"]
position = Vector2(640, 480)
scale = Vector2(8, 8)
centered = false

[node name="Trees" type="Node2D" parent="BackgroundLayer"]

[node name="Ground" type="ColorRect" parent="BackgroundLayer"]
anchor_top = 0.75
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0.227, 0.141, 0.086, 1)

[node name="Clouds" type="Node2D" parent="BackgroundLayer"]

[node name="Slimes" type="Node2D" parent="BackgroundLayer"]
```

- [ ] **Step 4: 创建 main_menu.gd 骨架 + 背景层动画**

`scripts/ui/main_menu.gd`:

```gdscript
# 主菜单：背景层 (天空渐变 + 云 + 山 + 树 + 地面 + slime) + 标题层 + 按钮层。
# 由 main.gd 实例化并监听 start_game 信号。
extends CanvasLayer

signal start_game

const MenuSceneArt = preload("res://scripts/art/menu_scene_art.gd")
const LogoArt = preload("res://scripts/art/logo_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")

const VIEWPORT_SIZE := Vector2(1280, 720)
const CLOUD_COUNT := 4
const TREE_COUNT := 5
const SLIME_COUNT := 2
const CLOUD_SPEED_RANGE := Vector2(6.0, 14.0)
const SLIME_HOP_INTERVAL := 2.5

@onready var _bg_layer: Control = $BackgroundLayer
@onready var _hills: Sprite2D = $BackgroundLayer/Hills
@onready var _trees_root: Node2D = $BackgroundLayer/Trees
@onready var _clouds_root: Node2D = $BackgroundLayer/Clouds
@onready var _slimes_root: Node2D = $BackgroundLayer/Slimes

var _cloud_speeds: Array[float] = []
var _slime_hop_timers: Array[float] = []


func _ready() -> void:
	_setup_sky_gradient()
	_setup_hills()
	_setup_trees()
	_setup_clouds()
	_setup_slimes()


func _process(delta: float) -> void:
	_animate_clouds(delta)
	_animate_slimes(delta)


func _setup_sky_gradient() -> void:
	# Sky 是 ColorRect，用 GradientTexture2D 做渐变
	var gradient := Gradient.new()
	gradient.set_color(0, Color8(42, 26, 58))      # 上方深紫
	gradient.add_point(0.5, Color8(196, 110, 60))  # 中部橙红
	gradient.set_color(1, Color8(242, 194, 101))   # 地平线金黄
	gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	var grad_tex := GradientTexture2D.new()
	grad_tex.gradient = gradient
	grad_tex.fill_from = Vector2(0, 0)
	grad_tex.fill_to = Vector2(0, 1)
	grad_tex.width = 64
	grad_tex.height = 256
	# 把 Sky 从 ColorRect 改成 TextureRect 行不通(已经在 tscn 里是 ColorRect)，
	# 这里改用 ColorRect 替代为加一个 TextureRect 在前面覆盖
	var sky: ColorRect = $BackgroundLayer/Sky
	var tex_rect := TextureRect.new()
	tex_rect.name = "SkyGradient"
	tex_rect.texture = grad_tex
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	tex_rect.anchor_right = 1.0
	tex_rect.anchor_bottom = 1.0
	tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.add_child(tex_rect)


func _setup_hills() -> void:
	_hills.texture = MenuSceneArt.make_hill()
	# 80×10 像素，放大到屏宽。位置在中部偏下
	_hills.scale = Vector2(VIEWPORT_SIZE.x / 80.0, 6.0)
	_hills.position = Vector2(0, VIEWPORT_SIZE.y * 0.55)
	_hills.centered = false


func _setup_trees() -> void:
	var tree_tex = MenuSceneArt.make_tree()
	# 错落分布在地面以上
	var x_positions := [80.0, 280.0, 540.0, 820.0, 1100.0]
	var scales := [3.0, 4.0, 3.5, 4.5, 3.0]
	for i in TREE_COUNT:
		var s := Sprite2D.new()
		s.texture = tree_tex
		s.centered = false
		s.scale = Vector2(scales[i], scales[i])
		# 12×16 像素 × scale → 树底贴到地面 (y = 0.75 * 720 = 540)
		s.position = Vector2(x_positions[i], VIEWPORT_SIZE.y * 0.75 - 16.0 * scales[i])
		_trees_root.add_child(s)


func _setup_clouds() -> void:
	var cloud_tex = MenuSceneArt.make_cloud()
	for i in CLOUD_COUNT:
		var s := Sprite2D.new()
		s.texture = cloud_tex
		s.centered = false
		s.scale = Vector2(4.0, 4.0)
		# 随机分布在屏幕上方 1/3 区域
		var x: float = randf() * VIEWPORT_SIZE.x
		var y: float = randf_range(40.0, VIEWPORT_SIZE.y * 0.3)
		s.position = Vector2(x, y)
		_clouds_root.add_child(s)
		_cloud_speeds.append(randf_range(CLOUD_SPEED_RANGE.x, CLOUD_SPEED_RANGE.y))


func _setup_slimes() -> void:
	var sf = SlimeArt.build_sprite_frames()
	var slime_x := [400.0, 880.0]
	for i in SLIME_COUNT:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = sf
		anim.animation = "idle"
		anim.play()
		anim.scale = Vector2(3.0, 3.0)
		# 16×12 sprite，底部贴地面
		anim.position = Vector2(slime_x[i], VIEWPORT_SIZE.y * 0.75 - 12.0 * 3.0)
		_slimes_root.add_child(anim)
		_slime_hop_timers.append(randf_range(0.0, SLIME_HOP_INTERVAL))


func _animate_clouds(delta: float) -> void:
	for i in _clouds_root.get_child_count():
		var c = _clouds_root.get_child(i)
		c.position.x += _cloud_speeds[i] * delta
		# 屏幕右出 → 左入
		var cloud_w := 24.0 * c.scale.x
		if c.position.x > VIEWPORT_SIZE.x:
			c.position.x = -cloud_w


func _animate_slimes(delta: float) -> void:
	for i in _slimes_root.get_child_count():
		_slime_hop_timers[i] -= delta
		if _slime_hop_timers[i] <= 0.0:
			_slime_hop_timers[i] = SLIME_HOP_INTERVAL + randf_range(-0.5, 0.5)
			var slime: AnimatedSprite2D = _slimes_root.get_child(i)
			# 简单 hop: 用 tween 跳 30px 右然后弹回
			var t := create_tween()
			t.tween_property(slime, "position:y", slime.position.y - 24, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			t.tween_property(slime, "position:y", slime.position.y, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			slime.animation = "hop"
			slime.play()
			await get_tree().create_timer(0.5).timeout
			slime.animation = "idle"
			slime.play()
```

- [ ] **Step 5: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 4 个测试 PASS

- [ ] **Step 6: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/main_menu.tscn scripts/ui/main_menu.gd tests/unit/test_main_menu.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(menu): MainMenu 骨架 + 动态背景层

天空渐变 (紫→橙→金) + 漂浮云 + 远山剪影 + 5 棵树 + 2 只跳跃 slime。
按钮和标题层下个 Task 加。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 8: MainMenu — 标题层 (像素 LOGO + 副标题 + 呼吸动画)

**Files:**
- Modify: `scenes/ui/main_menu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `tests/unit/test_main_menu.gd`

- [ ] **Step 1: 加测试**

往 `tests/unit/test_main_menu.gd` 末尾追加：

```gdscript
func test_has_title_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("TitleLayer"))


func test_title_has_logo_label():
	var mm = _make()
	var logo = mm.get_node_or_null("TitleLayer/LogoLabel")
	assert_not_null(logo)
	assert_eq(logo.text, "teilaruia")


func test_title_has_shadow_label():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("TitleLayer/LogoShadow"))


func test_title_has_subtitle():
	var mm = _make()
	var sub = mm.get_node_or_null("TitleLayer/Subtitle")
	assert_not_null(sub)
```

- [ ] **Step 2: 跑测试看新加的失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 4 个新测试 FAIL，老 4 个 PASS

- [ ] **Step 3: 修改 main_menu.tscn 加 TitleLayer**

在 `scenes/ui/main_menu.tscn` 文件末尾（Slimes 节点后）追加：

```
[node name="TitleLayer" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2

[node name="LogoShadow" type="Label" parent="TitleLayer"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -300.0
offset_top = 90.0
offset_right = 300.0
offset_bottom = 170.0
horizontal_alignment = 1

[node name="LogoLabel" type="Label" parent="TitleLayer"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -300.0
offset_top = 86.0
offset_right = 300.0
offset_bottom = 166.0
horizontal_alignment = 1

[node name="Subtitle" type="Label" parent="TitleLayer"]
anchors_preset = 5
anchor_left = 0.5
anchor_right = 0.5
offset_left = -200.0
offset_top = 168.0
offset_right = 200.0
offset_bottom = 188.0
text = "2D 沙盒 · Terraria 风"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 14
theme_override_colors/font_color = Color(0.831, 0.71, 0.541, 0.8)
```

- [ ] **Step 4: 修改 main_menu.gd 应用 LOGO 样式 + 呼吸动画**

在 `main_menu.gd` 末尾追加：

```gdscript
func _setup_title() -> void:
	var logo: Label = $TitleLayer/LogoLabel
	var shadow: Label = $TitleLayer/LogoShadow
	LogoArt.style_main_label(logo)
	LogoArt.style_shadow_label(shadow)


func _start_title_breathing() -> void:
	var logo: Label = $TitleLayer/LogoLabel
	var shadow: Label = $TitleLayer/LogoShadow
	var base_y := logo.offset_top
	var t := create_tween().set_loops()
	t.tween_property(logo, "offset_top", base_y - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t.tween_property(logo, "offset_top", base_y, 1.5).set_trans(Tween.TRANS_SINE)
	var t2 := create_tween().set_loops()
	var sh_base := shadow.offset_top
	t2.tween_property(shadow, "offset_top", sh_base - 4.0, 1.5).set_trans(Tween.TRANS_SINE)
	t2.tween_property(shadow, "offset_top", sh_base, 1.5).set_trans(Tween.TRANS_SINE)
```

修改 `_ready()` 添加调用：

```gdscript
func _ready() -> void:
	_setup_sky_gradient()
	_setup_hills()
	_setup_trees()
	_setup_clouds()
	_setup_slimes()
	_setup_title()
	_start_title_breathing()
```

- [ ] **Step 5: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 全部 8 个测试 PASS

- [ ] **Step 6: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/main_menu.tscn scripts/ui/main_menu.gd tests/unit/test_main_menu.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(menu): MainMenu 标题层 — LOGO + 副标题 + 呼吸动画

LogoLabel + LogoShadow 双层 (金黄 + 黑色阴影 4px offset)，
呼吸浮动 ±4px 周期 3s。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 9: MainMenu — 按钮层 (4 按钮 + StyleBox + hover 箭头)

**Files:**
- Modify: `scenes/ui/main_menu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `tests/unit/test_main_menu.gd`

- [ ] **Step 1: 加测试**

往 `tests/unit/test_main_menu.gd` 末尾追加：

```gdscript
func test_has_button_layer():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("ButtonLayer"))


func test_has_four_buttons():
	var mm = _make()
	var vb = mm.get_node_or_null("ButtonLayer/VBox")
	assert_not_null(vb)
	assert_eq(vb.get_child_count(), 4, "4 个按钮容器")


func test_continue_button_disabled():
	var mm = _make()
	var cont_btn = mm.get_node_or_null("ButtonLayer/VBox/ContinueRow/Button")
	assert_not_null(cont_btn)
	assert_true(cont_btn.disabled)


func test_new_game_button_emits_start_game():
	var mm = _make()
	var emitted := [false]
	mm.start_game.connect(func(): emitted[0] = true)
	mm._on_new_game_pressed()
	# 过渡淡出后才 emit
	await get_tree().create_timer(0.5).timeout
	assert_true(emitted[0])


func test_hover_arrow_initially_invisible():
	var mm = _make()
	var arrow = mm.get_node_or_null("ButtonLayer/VBox/NewGameRow/Arrow")
	assert_not_null(arrow)
	assert_false(arrow.visible)
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 5 个新测试 FAIL

- [ ] **Step 3: 修改 main_menu.tscn 加按钮层**

在文件末尾追加（TitleLayer 之后）：

```
[node name="ButtonLayer" type="Control" parent="."]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0

[node name="VBox" type="VBoxContainer" parent="ButtonLayer"]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -140.0
offset_top = 40.0
offset_right = 140.0
offset_bottom = 260.0
theme_override_constants/separation = 10

[node name="NewGameRow" type="HBoxContainer" parent="ButtonLayer/VBox"]
theme_override_constants/separation = 6

[node name="Arrow" type="Label" parent="ButtonLayer/VBox/NewGameRow"]
custom_minimum_size = Vector2(20, 40)
text = "▶"
vertical_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.949, 0.761, 0.396, 1)
visible = false

[node name="Button" type="Button" parent="ButtonLayer/VBox/NewGameRow"]
custom_minimum_size = Vector2(240, 44)
text = "新游戏"

[node name="ContinueRow" type="HBoxContainer" parent="ButtonLayer/VBox"]
theme_override_constants/separation = 6

[node name="Arrow" type="Label" parent="ButtonLayer/VBox/ContinueRow"]
custom_minimum_size = Vector2(20, 40)
text = "▶"
vertical_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.949, 0.761, 0.396, 1)
visible = false

[node name="Button" type="Button" parent="ButtonLayer/VBox/ContinueRow"]
custom_minimum_size = Vector2(240, 44)
text = "继续 (暂未开放)"
disabled = true

[node name="SettingsRow" type="HBoxContainer" parent="ButtonLayer/VBox"]
theme_override_constants/separation = 6

[node name="Arrow" type="Label" parent="ButtonLayer/VBox/SettingsRow"]
custom_minimum_size = Vector2(20, 40)
text = "▶"
vertical_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.949, 0.761, 0.396, 1)
visible = false

[node name="Button" type="Button" parent="ButtonLayer/VBox/SettingsRow"]
custom_minimum_size = Vector2(240, 44)
text = "设置"

[node name="QuitRow" type="HBoxContainer" parent="ButtonLayer/VBox"]
theme_override_constants/separation = 6

[node name="Arrow" type="Label" parent="ButtonLayer/VBox/QuitRow"]
custom_minimum_size = Vector2(20, 40)
text = "▶"
vertical_alignment = 1
theme_override_font_sizes/font_size = 18
theme_override_colors/font_color = Color(0.949, 0.761, 0.396, 1)
visible = false

[node name="Button" type="Button" parent="ButtonLayer/VBox/QuitRow"]
custom_minimum_size = Vector2(240, 44)
text = "退出"

[node name="FadeOverlay" type="ColorRect" parent="ButtonLayer"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
color = Color(0, 0, 0, 1)
modulate = Color(1, 1, 1, 0)
mouse_filter = 2
```

- [ ] **Step 4: 修改 main_menu.gd 加按钮逻辑 + 样式**

在 `main_menu.gd` 末尾追加：

```gdscript
const BTN_NORMAL_BG := Color8(58, 42, 26)
const BTN_NORMAL_BORDER := Color8(212, 181, 138)
const BTN_NORMAL_TEXT := Color8(242, 194, 101)
const BTN_HOVER_BG := Color8(90, 58, 42)
const BTN_HOVER_BORDER := Color8(242, 194, 101)
const BTN_HOVER_TEXT := Color8(255, 245, 220)
const BTN_PRESSED_BG := Color8(42, 26, 10)


func _setup_buttons() -> void:
	var rows := [
		{"row": "NewGameRow", "callback": _on_new_game_pressed},
		{"row": "ContinueRow", "callback": Callable()},
		{"row": "SettingsRow", "callback": _on_settings_pressed},
		{"row": "QuitRow", "callback": _on_quit_pressed},
	]
	for entry in rows:
		var row_name: String = entry["row"]
		var btn: Button = $ButtonLayer/VBox.get_node(row_name + "/Button")
		var arrow: Label = $ButtonLayer/VBox.get_node(row_name + "/Arrow")
		_apply_button_style(btn)
		btn.mouse_entered.connect(func(): arrow.visible = true)
		btn.mouse_exited.connect(func(): arrow.visible = false)
		var cb: Callable = entry["callback"]
		if cb.is_valid():
			btn.pressed.connect(cb)


func _apply_button_style(btn: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = BTN_NORMAL_BG
	normal.border_color = BTN_NORMAL_BORDER
	normal.border_width_left = 1
	normal.border_width_top = 1
	normal.border_width_right = 1
	normal.border_width_bottom = 1
	normal.content_margin_left = 16
	normal.content_margin_right = 16
	normal.content_margin_top = 8
	normal.content_margin_bottom = 8
	btn.add_theme_stylebox_override("normal", normal)

	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = BTN_HOVER_BG
	hover.border_color = BTN_HOVER_BORDER
	btn.add_theme_stylebox_override("hover", hover)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = BTN_PRESSED_BG
	pressed.content_margin_top = 10
	pressed.content_margin_bottom = 6
	btn.add_theme_stylebox_override("pressed", pressed)

	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color8(40, 30, 20)
	disabled.border_color = Color8(100, 80, 60)
	btn.add_theme_stylebox_override("disabled", disabled)

	btn.add_theme_color_override("font_color", BTN_NORMAL_TEXT)
	btn.add_theme_color_override("font_hover_color", BTN_HOVER_TEXT)
	btn.add_theme_color_override("font_pressed_color", BTN_NORMAL_TEXT)
	btn.add_theme_color_override("font_disabled_color", Color8(120, 100, 80))
	btn.add_theme_font_size_override("font_size", 18)


func _on_new_game_pressed() -> void:
	# 淡出 0.3s 黑场 0.4s → emit start_game
	var fade: ColorRect = $ButtonLayer/FadeOverlay
	var vbox: VBoxContainer = $ButtonLayer/VBox
	var t := create_tween()
	t.tween_property(vbox, "modulate:a", 0.0, 0.3)
	t.parallel().tween_property(fade, "modulate:a", 1.0, 0.4)
	t.tween_callback(func(): start_game.emit())


func _on_settings_pressed() -> void:
	# Task 10 实装
	push_warning("设置 — Task 10 实现")


func _on_quit_pressed() -> void:
	get_tree().quit()
```

修改 `_ready()`：

```gdscript
func _ready() -> void:
	_setup_sky_gradient()
	_setup_hills()
	_setup_trees()
	_setup_clouds()
	_setup_slimes()
	_setup_title()
	_start_title_breathing()
	_setup_buttons()
```

- [ ] **Step 5: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 全部 13 个测试 PASS

- [ ] **Step 6: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/main_menu.tscn scripts/ui/main_menu.gd tests/unit/test_main_menu.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(menu): MainMenu 按钮层 — 4 按钮 + hover ▶ + pressed 下压

StyleBoxFlat 暖色: 棕底 + 金黄描边 + 文字。hover 加亮 + 左侧 ▶ 出现，
pressed 内边距上 10 下 6 模拟下压 2px。新游戏点击触发淡出 0.3s + 黑场
0.4s → emit start_game。设置按钮下个 Task 实装。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 10: MainMenu — 设置子面板 (主音量滑条)

**Files:**
- Modify: `scenes/ui/main_menu.tscn`
- Modify: `scripts/ui/main_menu.gd`
- Modify: `tests/unit/test_main_menu.gd`

- [ ] **Step 1: 加测试**

往 `tests/unit/test_main_menu.gd` 末尾追加：

```gdscript
func test_has_settings_panel():
	var mm = _make()
	assert_not_null(mm.get_node_or_null("SettingsPanel"))


func test_settings_panel_initially_hidden():
	var mm = _make()
	var panel = mm.get_node("SettingsPanel")
	assert_false(panel.visible)


func test_volume_slider_reflects_game_settings():
	GameSettings.master_volume = 0.7
	var mm = _make()
	var slider: HSlider = mm.get_node("SettingsPanel/VBox/VolumeRow/Slider")
	# slider 范围 0-100，整数
	assert_almost_eq(slider.value, 70.0, 0.5)
	GameSettings.master_volume = 1.0


func test_slider_change_updates_game_settings():
	var mm = _make()
	var slider: HSlider = mm.get_node("SettingsPanel/VBox/VolumeRow/Slider")
	slider.value = 50.0
	slider.value_changed.emit(50.0)
	assert_almost_eq(GameSettings.master_volume, 0.5, 0.01)
	GameSettings.master_volume = 1.0


func test_settings_button_opens_panel():
	var mm = _make()
	mm._on_settings_pressed()
	assert_true(mm.get_node("SettingsPanel").visible)
	assert_false(mm.get_node("ButtonLayer/VBox").visible)


func test_back_button_closes_panel():
	var mm = _make()
	mm._on_settings_pressed()
	mm._on_settings_back_pressed()
	assert_false(mm.get_node("SettingsPanel").visible)
```

- [ ] **Step 2: 跑测试看失败**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 6 个新测试 FAIL

- [ ] **Step 3: 修改 main_menu.tscn 加 SettingsPanel**

文件末尾追加：

```
[node name="SettingsPanel" type="Panel" parent="."]
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -120.0
offset_right = 200.0
offset_bottom = 120.0
visible = false

[node name="VBox" type="VBoxContainer" parent="SettingsPanel"]
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
offset_left = 24.0
offset_top = 24.0
offset_right = -24.0
offset_bottom = -24.0
theme_override_constants/separation = 16

[node name="TitleLabel" type="Label" parent="SettingsPanel/VBox"]
text = "设 置"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 24
theme_override_colors/font_color = Color(0.949, 0.761, 0.396, 1)

[node name="VolumeRow" type="HBoxContainer" parent="SettingsPanel/VBox"]
theme_override_constants/separation = 12

[node name="Label" type="Label" parent="SettingsPanel/VBox/VolumeRow"]
custom_minimum_size = Vector2(80, 0)
text = "主音量"
theme_override_colors/font_color = Color(0.831, 0.71, 0.541, 1)

[node name="Slider" type="HSlider" parent="SettingsPanel/VBox/VolumeRow"]
custom_minimum_size = Vector2(200, 0)
min_value = 0.0
max_value = 100.0
step = 1.0
value = 100.0

[node name="ValueLabel" type="Label" parent="SettingsPanel/VBox/VolumeRow"]
custom_minimum_size = Vector2(40, 0)
text = "100"
theme_override_colors/font_color = Color(0.831, 0.71, 0.541, 1)

[node name="BackButton" type="Button" parent="SettingsPanel/VBox"]
custom_minimum_size = Vector2(0, 36)
text = "返回"
```

- [ ] **Step 4: 修改 main_menu.gd 接入设置面板**

替换 `_on_settings_pressed`：

```gdscript
func _on_settings_pressed() -> void:
	$SettingsPanel.visible = true
	$ButtonLayer/VBox.visible = false


func _on_settings_back_pressed() -> void:
	$SettingsPanel.visible = false
	$ButtonLayer/VBox.visible = true
```

加 `_setup_settings_panel`：

```gdscript
func _setup_settings_panel() -> void:
	var slider: HSlider = $SettingsPanel/VBox/VolumeRow/Slider
	var value_label: Label = $SettingsPanel/VBox/VolumeRow/ValueLabel
	var back_btn: Button = $SettingsPanel/VBox/BackButton
	# 初始化为当前 GameSettings 值
	slider.value = GameSettings.master_volume * 100.0
	value_label.text = "%d" % int(slider.value)
	slider.value_changed.connect(func(v):
		GameSettings.master_volume = v / 100.0
		value_label.text = "%d" % int(v)
	)
	_apply_button_style(back_btn)
	back_btn.pressed.connect(_on_settings_back_pressed)
```

修改 `_ready()` 末尾加：
```gdscript
	_setup_settings_panel()
```

- [ ] **Step 5: 跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_menu.gd 2>&1 | tail -15
```
Expected: 全部 19 个测试 PASS

- [ ] **Step 6: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -15
```

- [ ] **Step 7: 提交**

```bash
cd /workspace/teilaruia
git add scenes/ui/main_menu.tscn scripts/ui/main_menu.gd tests/unit/test_main_menu.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(menu): MainMenu 设置子面板 — 主音量滑条

Panel 居中显示，0-100 滑条实时写到 GameSettings.master_volume。
点设置按钮切到面板，点返回切回。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 11: main.gd 完整状态机 — 启动进 MainMenu + 切到 Game + 回主菜单

**Files:**
- Modify: `scripts/main.gd`
- Modify: `scenes/main.tscn`

- [ ] **Step 1: 重写 main.tscn 加 MainMenu/PauseMenu 子节点**

替换 `scenes/main.tscn` 全部内容：

```
[gd_scene load_steps=5 format=3 uid="uid://b4teilaruiamain"]

[ext_resource type="Script" path="res://scripts/main.gd" id="1_main"]
[ext_resource type="PackedScene" path="res://scenes/ui/death_screen.tscn" id="2_ds"]
[ext_resource type="PackedScene" path="res://scenes/ui/pause_menu.tscn" id="3_pm"]
[ext_resource type="PackedScene" path="res://scenes/ui/main_menu.tscn" id="4_mm"]

[node name="Main" type="Node"]
script = ExtResource("1_main")

[node name="DeathScreen" parent="." instance=ExtResource("2_ds")]

[node name="PauseMenu" parent="." instance=ExtResource("3_pm")]

[node name="MainMenu" parent="." instance=ExtResource("4_mm")]
```

- [ ] **Step 2: 重写 main.gd 为状态机**

替换 `scripts/main.gd` 全部内容：

```gdscript
# 游戏入口 + 状态机。
# 状态: "menu" (主菜单显示中) / "game" (世界+HUD+面板存在)。
# 启动进 menu。新游戏 → game。暂停菜单回主菜单 → menu。
extends Node

const WorldScene = preload("res://scenes/world/world.tscn")
const DebugHudScene = preload("res://scenes/ui/debug_hud.tscn")
const FloatingPromptScene = preload("res://scenes/ui/floating_prompt.tscn")
const HudScene = preload("res://scenes/ui/hud.tscn")
const CraftingPanelScene = preload("res://scenes/ui/crafting_panel.tscn")

@onready var _main_menu: CanvasLayer = $MainMenu
@onready var _pause_menu: CanvasLayer = $PauseMenu
@onready var _death_screen: CanvasLayer = $DeathScreen

var _state: String = "menu"  # "menu" | "game"
var _game_root: Node = null  # 包住 World/HUD/...，便于一次性销毁

# 暴露给测试和回收路径
var world: Node2D:
	get:
		if _game_root == null:
			return null
		return _game_root.get_node_or_null("World")


func _ready() -> void:
	_main_menu.start_game.connect(_start_game)
	_pause_menu.return_to_menu.connect(_return_to_menu)
	_death_screen.respawn.connect(_on_respawn)
	_show_menu_state()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_pause") and _state == "game":
		if _death_screen.visible:
			return
		_pause_menu.toggle()
		get_viewport().set_input_as_handled()


func _show_menu_state() -> void:
	_state = "menu"
	_main_menu.visible = true
	_pause_menu.close()
	_death_screen.hide_death()


func _start_game() -> void:
	_state = "game"
	_main_menu.visible = false
	_game_root = Node.new()
	_game_root.name = "GameRoot"
	add_child(_game_root)

	var w = WorldScene.instantiate()
	w.name = "World"
	_game_root.add_child(w)

	var hud = HudScene.instantiate()
	_game_root.add_child(hud)

	var crafting = CraftingPanelScene.instantiate()
	crafting.add_to_group("crafting_panel")
	_game_root.add_child(crafting)

	var floating = FloatingPromptScene.instantiate()
	floating.add_to_group("floating_prompt")
	_game_root.add_child(floating)

	var debug = DebugHudScene.instantiate()
	_game_root.add_child(debug)

	_wire_player.call_deferred()


func _wire_player() -> void:
	var w := world
	if w == null:
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	var hud: CanvasLayer = _game_root.get_node("HUD")
	hud.bind_player(player)
	var crafting: CanvasLayer = _game_root.get_node("CraftingPanel")
	crafting.bind_inventory(player.get_node("PlayerInventory"))
	var debug: CanvasLayer = _game_root.get_node("DebugHUD")
	debug.set_player(player)
	# 死亡信号 → 死亡屏
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		hp.died.connect(_death_screen.show_death)


func _return_to_menu() -> void:
	# 从暂停菜单回主菜单
	_pause_menu.close()
	if _game_root != null:
		_game_root.queue_free()
		_game_root = null
	get_tree().paused = false
	_show_menu_state()


func _on_respawn() -> void:
	var w := world
	if w != null:
		w.respawn_player()
	_death_screen.hide_death()
```

注意 main.tscn 现在直接 instance MainMenu/PauseMenu/DeathScreen 三个子节点，不再用代码 add_child。

- [ ] **Step 3: 检查 HUD/CraftingPanel/DebugHUD 节点名**

main.gd 用 `_game_root.get_node("HUD")` 等。各场景的根节点名要对：
- hud.tscn: 根节点 name="HUD" ✓ (前面看过)
- crafting_panel.tscn: 检查
- debug_hud.tscn: 检查
- floating_prompt.tscn: 检查

```bash
cd /workspace/teilaruia && head -5 scenes/ui/crafting_panel.tscn scenes/ui/debug_hud.tscn scenes/ui/floating_prompt.tscn
```

如果根节点名不是 "CraftingPanel" / "DebugHUD" / "FloatingPrompt"，要么改 tscn 的 root name 一致，要么改 main.gd 用 `_game_root.get_node` 的字符串。**最稳妥**：改 main.gd 的 `_wire_player`，按类型/group 找，不按名字：

如果 root name 不一致，把 _wire_player 改成这样（更稳健）：

```gdscript
func _wire_player() -> void:
	var w := world
	if w == null:
		return
	var player: Node2D = w.get_player()
	if player == null:
		return
	for child in _game_root.get_children():
		if child.has_method("bind_player"):
			child.bind_player(player)
		if child.has_method("bind_inventory"):
			child.bind_inventory(player.get_node("PlayerInventory"))
		if child.has_method("set_player"):
			child.set_player(player)
	# 死亡信号 → 死亡屏
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("died"):
		hp.died.connect(_death_screen.show_death)
```

**采用这个稳健版**，避免节点名陷阱。

- [ ] **Step 4: 跑全量测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```
Expected: 全部 PASS

- [ ] **Step 5: 手动验证 — 启动到主菜单**

```bash
cd /workspace/teilaruia && timeout 5 godot --headless 2>&1 | tail -10
```
Expected: 没有崩，启动后主菜单可见（headless 看不到画面，但至少不能崩）。

如果有报错，根据错误信息调。常见问题：
- 节点名错 → 改成稳健版 `_wire_player`
- DeathScreen autoload 冲突 → 改名
- 测试期间 `_main_menu` 是 null（因为没用 instance，是 add_child_autofree 的） → 跑测试时 main.tscn 的子节点 instance 还是有的，应该 OK

- [ ] **Step 6: 写集成测试 — 状态机切换**

新建 `tests/integration/test_main_state_machine.gd`:

```gdscript
extends GutTest

const MainScene = preload("res://scenes/main.tscn")


func _make() -> Node:
	var m = MainScene.instantiate()
	add_child_autofree(m)
	return m


func before_each():
	get_tree().paused = false


func after_each():
	get_tree().paused = false


func test_starts_in_menu_state():
	var m = _make()
	await get_tree().process_frame
	assert_eq(m._state, "menu")
	assert_true(m._main_menu.visible)


func test_start_game_transitions_to_game_state():
	var m = _make()
	await get_tree().process_frame
	m._start_game()
	await get_tree().process_frame
	await get_tree().process_frame  # _wire_player 是 call_deferred
	assert_eq(m._state, "game")
	assert_false(m._main_menu.visible)
	assert_ne(m.world, null, "world 已实例化")


func test_return_to_menu_clears_game_root():
	var m = _make()
	await get_tree().process_frame
	m._start_game()
	await get_tree().process_frame
	m._return_to_menu()
	await get_tree().process_frame
	assert_eq(m._state, "menu")
	assert_eq(m._game_root, null)
	assert_true(m._main_menu.visible)
```

- [ ] **Step 7: 跑集成测试**

```bash
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd -gselect=test_main_state_machine.gd 2>&1 | tail -15
```
Expected: 3 个测试 PASS

- [ ] **Step 8: 提交**

```bash
cd /workspace/teilaruia
git add scripts/main.gd scenes/main.tscn tests/integration/test_main_state_machine.gd
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "feat(main): 状态机 — 启动进主菜单 + 切到游戏 + 回主菜单

main.gd 维护 \"menu\" / \"game\" 状态。点新游戏 → 实例化 GameRoot
{World, HUD, CraftingPanel, FloatingPrompt, DebugHUD}。暂停菜单回主菜单
→ queue_free GameRoot + 显示 MainMenu。ESC 在 game 状态弹暂停菜单
(死亡屏可见时忽略)。

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

---

### Task 12: 端到端手动验证 + 收尾

**Files:** 无新文件，只跑游戏验证 + 修任何遗留问题。

- [ ] **Step 1: 全量跑测试**

```bash
cd /workspace/teilaruia && godot --headless --editor --quit 2>&1 | tail -3
cd /workspace/teilaruia && godot --headless -s addons/gut/gut_cmdln.gd 2>&1 | tail -20
```
Expected: 全部测试 PASS，没有失败/错误

- [ ] **Step 2: 跑游戏 5 秒看启动**

```bash
cd /workspace/teilaruia && timeout 6 godot 2>&1 | tail -20
```
看输出有无 ERROR 行。Warning 可忽略（libfontconfig 等已知）。

- [ ] **Step 3: 检查游戏路径**

如果第 2 步出错或有 ERROR，根据信息修。常见：
- node not found → 检查 main.tscn instance 路径
- signal not exists → 检查 connect 时信号名拼写
- group not found → 现有 `add_to_group("crafting_panel")` 之类的保留没动过

跑完所有测试 + 启动游戏无 ERROR 后才算完。

- [ ] **Step 4: 更新 MEMORY 索引（可选）**

如果用户的 `~/.claude/projects/-workspace-teilaruia/memory/` 里需要记录这次菜单/死亡屏的设计决策，跳过 — spec 文件已经在 docs/ 里持久了。

- [ ] **Step 5: 最终提交（如有任何遗留小修）**

如果上面 3 个 Step 有改动：

```bash
cd /workspace/teilaruia
git add -A
git -c user.email="claude@anthropic.com" -c user.name="Claude" commit -m "fix(menus): 端到端验证后的收尾修正

[列出实际改了什么]

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>"
```

如果没有改动，跳过。

---

## 完整改动清单（汇总）

新建文件:
- `scripts/autoload/game_settings.gd`
- `scripts/art/logo_art.gd`
- `scripts/art/menu_scene_art.gd`
- `scenes/ui/death_screen.tscn` + `scripts/ui/death_screen.gd`
- `scenes/ui/pause_menu.tscn` + `scripts/ui/pause_menu.gd`
- `scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd`
- `tests/unit/test_game_settings.gd`
- `tests/unit/test_logo_art.gd`
- `tests/unit/test_menu_scene_art.gd`
- `tests/unit/test_death_screen.gd`
- `tests/unit/test_pause_menu.gd`
- `tests/unit/test_main_menu.gd`
- `tests/integration/test_main_state_machine.gd`

修改:
- `project.godot` — 注册 GameSettings autoload + 注册 ui_pause action
- `scripts/main.gd` — 重写为状态机
- `scenes/main.tscn` — 加 MainMenu/PauseMenu/DeathScreen 子节点
- `scripts/world/world.gd` — `_on_player_died` 改名 `respawn_player`，删 died 自动连接

预计新增测试数：~30 个。

---

## 已知小坑（实施时注意）

1. **GUT class_name 索引**：每次新增 `extends GutTest` 的测试文件后，先跑一次 `godot --headless --editor --quit` 让 Godot 重建 class 索引，否则 GUT 找不到测试。这条来自 `[[reference_godot_gotchas]]`。
2. **libfontconfig 警告**：CLI 跑 godot 时会输出 `libfontconfig.so.1: cannot open shared object file`，可忽略。
3. **CanvasLayer process_mode**：DeathScreen 和 PauseMenu 都 `process_mode = 3 (ALWAYS)`，否则暂停时按钮无法响应。
4. **Tween 在暂停时**：用 `set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)` 让淡入动画在 `paused = true` 时仍跑。
5. **`_unhandled_input` vs `_input`**：用 `_unhandled_input` 避免 GUI 元素已消费的事件再触发暂停菜单。
6. **测试中的 paused 状态**：测试前后必须 `get_tree().paused = false`，否则跨测试污染。
