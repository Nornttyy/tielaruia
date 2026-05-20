# 主菜单 + 暂停菜单 + 死亡屏幕 设计

**日期**: 2026-05-20
**范围**: 给 teilaruia 加上完整的游戏进入/退出/死亡循环界面

## 背景

目前 `scenes/main.tscn` 启动后直接实例化 World + HUD 进入游戏；玩家死亡触发 `world._on_player_died()` 瞬时复活（drop 物品 + 清 slime + 回出生点 + 满血）。缺少：
- 启动主菜单（无法选择"新游戏/退出"）
- 暂停菜单（无法回主菜单）
- 死亡屏幕（瞬时复活体验突兀，玩家来不及反应）

## 目标

1. 启动游戏后先进入主菜单（新游戏 / 继续(灰) / 设置 / 退出）
2. 玩家死亡时弹出死亡屏幕（黑屏 + "你死了" + 复活按钮），点按钮才复活
3. 游戏中按 ESC 弹出暂停菜单（继续 / 回主菜单 / 退出）

## 非目标 (YAGNI)

- 存档系统（"继续"按钮做出来但灰掉，不可点）
- 全屏/键位设置（设置页只有主音量滑条）
- 主菜单背景动画
- 确认退出对话框
- 多语言切换

## 架构

`scripts/main.gd` 升级为游戏状态机，负责在两种状态之间切换：

```
Main (Node) ── _state ──┬── "menu"  → MainMenu 显示中
                        └── "game"  → World + HUD + CraftingPanel + ... 实例存在

切换：
  menu → game: 点击新游戏 → 隐藏 MainMenu，实例化 game 节点组
  game → menu: 点击暂停菜单"回主菜单" → 销毁 game 节点组，显示 MainMenu
```

### 节点树

```
Main (Node, script=main.gd)
├── MainMenu        (CanvasLayer)        ← 启动可见
├── PauseMenu       (CanvasLayer)        ← 启动隐藏，process_mode = ALWAYS
├── DeathScreen     (CanvasLayer)        ← 启动隐藏，process_mode = ALWAYS
└── [Game 节点组]   ← 动态实例化/销毁
    ├── World       (Node2D)
    ├── HUD         (CanvasLayer)
    ├── CraftingPanel (CanvasLayer)
    ├── FloatingPrompt (CanvasLayer)
    └── DebugHUD    (CanvasLayer)
```

PauseMenu 和 DeathScreen 一直存在但隐藏，避免每次显示重建。MainMenu 同理（cheap，不影响）。

### Autoload 新增

`scripts/autoload/game_settings.gd`：
```gdscript
extends Node
# 主音量 0.0 ~ 1.0
var master_volume: float = 1.0:
    set(v):
        master_volume = clamp(v, 0.0, 1.0)
        var db = -80.0 if master_volume <= 0.001 else linear_to_db(master_volume)
        AudioServer.set_bus_volume_db(0, db)
```

注册到 `project.godot` [autoload]。

## 组件

### 1. MainMenu (`scenes/ui/main_menu.tscn` + `scripts/ui/main_menu.gd`)

主菜单是玩家对游戏的第一印象，做"高品质版"。分三层：背景层 / 标题层 / 按钮层。

#### 1.1 背景层 —— 动态像素场景

不复用游戏 World（开销大、控制难），而是手搓一个固定布局的小场景，绘制顺序由远及近：

```
天空 (CanvasLayer/back, layer=-2)
├── GradientSky (ColorRect with GradientTexture)
│   黄昏暖色：上方深紫 #2a1a3a → 中部橙红 #c46e3c → 地平线金黄 #f2c265
├── DistantClouds (Sprite2D x 3，水平慢速漂移，loop_x)
│   像素云：椭圆白云块，alpha 0.6，速度 4-8 px/s
│   绕屏：x 超出右侧后从左侧重新进入
├── DistantHills (Sprite2D, 紫灰色山形轮廓，无动画)
│   一行像素轮廓，颜色比天空暗 30%
├── Trees (Sprite2D x 4-6, 黑色森林剪影)
│   不同高度的尖顶树轮廓，错落分布在中下方
├── Ground (ColorRect 实色暗棕带噪点纹理，下方 1/4 屏)
└── Slimes (AnimatedSprite2D x 2, 复用现有 slime_art)
    在地面层上以慢速从一侧跳到另一侧（每 2-3 秒跳一次），到边缘后掉头
```

实现要点：
- 所有元素用 `Sprite2D.position` 动画，简单 Tween 循环；或 `_process` 累加 x 偏移取模屏宽
- 像素元素整体放 `scale = 4`（保持锐利），分辨率参考：背景画在 320×180 的逻辑像素上，放大到 1280×720
- 用 `Camera2D` 做轻微视差：鼠标移动时背景反向位移 5-10 px（可选，看实现复杂度）
- 全部用 `PixelArt.grid_to_texture` 从 ASCII 画

#### 1.2 标题层 —— 像素 LOGO

`teilaruia` 用 ASCII 网格手画，约 9 字符 × 5-6 像素高的字号，整体尺寸 ~80×8 像素，放大 6x = 480×48 显示。

风格：
- 主色 #f2c265（金黄）
- 1px 深棕描边 (#3a1a0a)
- 下方 2px offset 黑色阴影
- 居中靠上，距顶部约 18% 屏高

加微动画：标题整体 y 用 sin 缓慢上下浮动 ±2px，周期 3 秒（呼吸感）。

LOGO 像素图作为独立资源：`scripts/art/logo_art.gd`，跟 `slime_art.gd` / `villager_art.gd` 一个模式，导出 `static func make_texture() -> ImageTexture`。

副标题：LOGO 下方一行小字 "2D 沙盒 · Terraria 风" 字号 14 #d4b58a，淡化。

#### 1.3 按钮层

VBoxContainer 居中靠下方 1/3，4 个按钮（每个 240×44）：
- "新游戏"
- "继续"（disabled = true，灰色 + 旁边小字 "暂未开放"）
- "设置"
- "退出"

每个按钮做成 `Button` + 自定义 StyleBoxFlat：
- normal：#3a2a1a 底 + #d4b58a 描边 1px + #f2c265 文字
- hover：底变 #5a3a2a + 描边变 #f2c265 + 文字变白；同时左侧出现一个 ▶ 小箭头（用 Label 字符 "▶"，hover 时 visible=true）
- pressed：整个按钮下移 2px（用 StyleBoxFlat content_margin 实现）+ 底色变 #2a1a0a

实现：所有 4 个按钮共用一个 `_apply_button_style(btn)` 函数，初始化时遍历应用。

设置子面板（Panel，启动隐藏）：
- 跟主菜单一样的暖色风格 Panel
- 标题 "设置" + 主音量滑条（0~100 整数）+ 当前数值 Label
- "返回" 按钮回主菜单按钮列表
- 切换时主菜单按钮列表淡出 (0.2s)，设置面板淡入 (0.2s)

#### 1.4 进入游戏的过渡

点"新游戏"后：
- 按钮列表淡出 0.3s
- 整个 MainMenu 全屏黑场淡入 0.4s（一个 ColorRect 全屏覆盖，alpha 0→1）
- 黑场满了发 `start_game` 信号，Main 实例化 game 节点组并隐藏 MainMenu

信号：
- `start_game` → Main 监听
- 退出按钮：直接 `get_tree().quit()`
- 设置按钮：切到设置面板（内部状态）

### 2. PauseMenu (`scenes/ui/pause_menu.tscn` + `scripts/ui/pause_menu.gd`)

布局：
- 半透明黑底 ColorRect (alpha=0.6) 全屏
- 居中 VBox 3 按钮：继续 / 回主菜单 / 退出
- `process_mode = PROCESS_MODE_ALWAYS`（暂停时仍响应输入）

输入处理：监听 `ui_pause` action（在 `project.godot` 注册 ESC）。在 `_unhandled_input` 中切换可见性 + `get_tree().paused`。

注意：只在 game 状态下响应 ESC。判断方式：如果 DeathScreen 或 MainMenu 可见则忽略；自己已可见时按 ESC 等同于点"继续"。

信号：
- `resume` → 隐藏自己 + unpause
- `return_to_menu` → Main 监听 → 销毁 game 节点组 + 显示 MainMenu + unpause
- `quit` → `get_tree().quit()`

### 3. DeathScreen (`scenes/ui/death_screen.tscn` + `scripts/ui/death_screen.gd`)

布局：
- 全屏黑色 ColorRect（透明度从 0 淡入到 1，时长 0.4s，用 Tween）
- 红色大字 Label "你 死 了"（字号 64，居中；字与字间用全角空格）
- "回到出生点" 按钮（居中靠下，宽 200，淡入完成后才可点 —— 防误触）
- `process_mode = PROCESS_MODE_ALWAYS`

API：
- `show_death()` 方法：显示 + 暂停游戏 + 启动 Tween 淡入
- 复活按钮 → 发 `respawn` 信号 → Main 监听 → 调用 `world.respawn_player()` + 隐藏自己 + unpause

### 4. main.gd 重写

```gdscript
extends Node
const WorldScene = preload("res://scenes/world/world.tscn")
# ... 其他场景预加载

@onready var main_menu = $MainMenu
@onready var pause_menu = $PauseMenu
@onready var death_screen = $DeathScreen

var _game_root: Node = null  # 包住 World+HUD+... 的容器

func _ready() -> void:
    main_menu.start_game.connect(_start_game)
    pause_menu.return_to_menu.connect(_return_to_menu)
    death_screen.respawn.connect(_on_respawn)
    _show_menu()

func _start_game() -> void:
    main_menu.hide()
    _game_root = Node.new()
    _game_root.name = "GameRoot"
    add_child(_game_root)
    var world = WorldScene.instantiate()
    _game_root.add_child(world)
    # ... HUD/CraftingPanel/FloatingPrompt/DebugHUD 也加进 _game_root
    _wire_player.call_deferred(world)

func _wire_player(world) -> void:
    var player = world.get_player()
    # ... 现有的绑定逻辑
    # 关键：连 died 到 death_screen 而不是 world.respawn_player
    var hp = player.get_node("PlayerHealth")
    hp.died.connect(death_screen.show_death)

func _return_to_menu() -> void:
    if _game_root:
        _game_root.queue_free()
        _game_root = null
    get_tree().paused = false
    pause_menu.hide()
    death_screen.hide()
    _show_menu()

func _on_respawn() -> void:
    var world = _game_root.get_node("World")
    world.respawn_player()
    get_tree().paused = false
    death_screen.hide()
```

### 5. world.gd 改动

- `_on_player_died()` 改名 `respawn_player()` （public，主动调用语义清楚）
- 删掉 `_spawn_player` 末尾的 `hp.died.connect(_on_player_died)` —— 改由 main.gd 接管
- `get_player()` 保持不变

## 数据流

```
启动 → main._ready
       └→ 显示 MainMenu

点新游戏 → main._start_game
           └→ 实例化 GameRoot{World, HUD, ...}
              └→ World 自己生成地形 + 玩家
                 └→ main._wire_player: hp.died → death_screen.show_death

按 ESC（game 中） → PauseMenu._unhandled_input
                    └→ 切换可见 + paused

死亡 → PlayerHealth.died 信号
       └→ death_screen.show_death
          └→ paused = true, 淡入

点复活 → death_screen 发 respawn 信号
         └→ main._on_respawn
            └→ world.respawn_player() (drop+清 slime+回出生点+满血)
               + paused = false

点暂停菜单"回主菜单" → main._return_to_menu
                      └→ GameRoot.queue_free() + 显示 MainMenu
```

## 错误处理 / 边界情况

- **死亡时正好打开 PauseMenu**：DeathScreen 优先级高于 PauseMenu。如果死亡时 PauseMenu 显示，先隐藏 PauseMenu。
- **MainMenu 时按 ESC**：忽略（PauseMenu 自己判断 main_menu.visible 决定不响应）。
- **回主菜单后再开始新游戏**：World 是新实例化的，spawn point 重新生成（除非 world_seed 固定，目前是 export 值 20260517，每次同样地图，行为一致）。
- **音量滑条变化**：通过 GameSettings.master_volume setter 实时应用 AudioServer.set_bus_volume_db，不需要其他系统介入。

## 测试

沿用项目 GUT 风格（`tests/` 目录下 `test_*.gd`）。新增：

**tests/test_main_menu.gd**
- 实例化 MainMenu，验证 4 个按钮存在
- 模拟点击"新游戏"按钮 → 验证发出 start_game 信号（过渡淡出完成后）
- 验证"继续"按钮 disabled = true
- 验证 LOGO 纹理生成成功（非 null，尺寸大于 0）
- 验证按钮 hover 时左侧箭头变可见

**tests/test_pause_menu.gd**
- 实例化 PauseMenu，验证默认隐藏
- 调用 toggle()，验证显示 + paused = true
- 模拟点击"继续" → 验证隐藏 + paused = false

**tests/test_death_screen.gd**
- 实例化 DeathScreen，验证默认隐藏
- 调用 show_death() → 验证显示 + paused = true
- 模拟点击"复活" → 验证发出 respawn 信号

**tests/test_game_settings.gd**
- 验证 master_volume setter 调用 AudioServer.set_bus_volume_db
- 验证 0 → -80 dB（静音），1 → 0 dB

集成测试需要 Godot editor 跑 GUT，跟现有测试一样的方式：`--editor --quit-after`。

## 改动清单

| 文件 | 动作 |
|---|---|
| `scenes/ui/main_menu.tscn` | 新建（背景层 + 标题层 + 按钮层 + 设置面板） |
| `scripts/ui/main_menu.gd` | 新建（动画 + 按钮样式 + 状态切换） |
| `scripts/art/logo_art.gd` | 新建（teilaruia 像素 LOGO 的 ASCII 网格） |
| `scripts/art/menu_scene_art.gd` | 新建（云/山/树/地面 像素纹理生成） |
| `scenes/ui/pause_menu.tscn` | 新建 |
| `scripts/ui/pause_menu.gd` | 新建 |
| `scenes/ui/death_screen.tscn` | 新建 |
| `scripts/ui/death_screen.gd` | 新建 |
| `scripts/autoload/game_settings.gd` | 新建 |
| `scenes/main.tscn` | 加 4 个子节点（MainMenu/PauseMenu/DeathScreen 实例 + Marker for GameRoot 位置说明） |
| `scripts/main.gd` | 重写：状态切换 + 信号路由 |
| `scripts/world/world.gd` | `_on_player_died` → `respawn_player`，删掉 died 信号自动连接 |
| `project.godot` | 注册 GameSettings autoload + ui_pause input action (ESC) |
| `tests/test_main_menu.gd` | 新建 |
| `tests/test_pause_menu.gd` | 新建 |
| `tests/test_death_screen.gd` | 新建 |
| `tests/test_game_settings.gd` | 新建 |

## 视觉风格

跟现有 HUD/CraftingPanel 统一：
- 字体：Godot 默认（项目没引入自定义字体）
- 色调：暖色调（项目偏好 [[feedback_warm_detailed_textures]]）。深棕背景 (#2a1f1a) + 米色按钮 (#d4b58a) + 红色危险元素 (#a83232)
- 按钮 hover/pressed 状态：略亮/略暗
- 死亡屏的 "你 死 了" 用红色 (#a83232)，字与字之间用全角空格强化压迫感

## 实现顺序建议（写给写计划阶段参考）

1. GameSettings autoload（独立、最易测）
2. DeathScreen（依赖少，端到端可测：手动让 player 死亡）
3. main.gd 重写 + 接管 died 信号（替换瞬时复活）
4. MainMenu + main 的状态切换
5. PauseMenu + ESC input action

每步都应该可以独立提交 + 跑通现有测试不退步。
