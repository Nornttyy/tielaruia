# Loading Screen — 进入世界加载动画

## 目标

玩家点 "进入" / "开始" 之后, 屏幕不再是黑屏干等. 显示一个有暮色背景 + 像素小人跑步 + 真实进度条 + 可点击切换的小贴士的加载层, 直到 world / HUD / 各种特效层全部就绪, 再淡出.

## 当前问题

`scripts/main.gd::_start_game()` 同步 instantiate 一连串场景 (World → HUD → CraftingPanel → FloatingPrompt → DebugHud → Dialogue). World 自身 `_ready()` 又同步跑完所有初始化 (TileSet 构建, ChunkManager.setup + ensure_loaded, 多个 FX 层, SkyLightGrid, spawn_player). 整段时间主菜单已 hide, 游戏未渲染, 用户看到全黑.

## 设计

### 视觉

```
+----------------------------------+
|  暮色渐变天空 (橙紫, 复用主菜单)   |
|       . *  .   .   *             |
|    *           .   *             |
|                                  |
|                                  |
|         O   <-- 玩家像素小人      |
|        /|\     (walk 动画 4 帧)  |
|        / \                       |
|                                  |
|   正在生成地形...                 |
|   ┌──────────────────┐           |
|   │█████░░░░░░░░░░░░│  37%      |
|   └──────────────────┘           |
|                                  |
|   小贴士: 按 E 和村民聊天 (点击换)|
+----------------------------------+
```

- **天空**: 复用 `main_menu.gd::_setup_sky_gradient()` 的暮色渐变 (顶深紫 → 暮色橙红 → 金橙 → 暖肉粉).
- **星星**: 14 颗 2×2 ColorRect, 顶部 28% 区域, 缓慢闪烁 tween (复用主菜单 `_setup_stars()` 逻辑).
- **像素小人**: AnimatedSprite2D, `PlayerArt.build_sprite_frames()`, 播放 `walk` 动画 (10 fps), scale 4×, 居中屏幕略偏上 (y ≈ 380).
- **阶段文字 (StageLabel)**: 加载小人下方, 文字暖白色 `Color8(242, 194, 101)`, 字号 22.
- **进度条**: 阶段文字下方, 宽 480 × 高 28. 外框暗棕 `Color8(58, 42, 26)` + 暖琥珀边框 `Color8(212, 181, 138)`. 内填暖金色 `Color8(255, 180, 110)`. 旁边 PercentLabel "37%".
- **小贴士 (TipLabel)**: 最底部, 字号 18, 颜色 `Color8(242, 194, 101)`. 包在一个 Button 里, hover 时字颜色提亮 `Color8(255, 245, 220)`, 文字尾部带 "(点击换一条)" 灰色小字提示.

### 加载阶段 (7 步, 真实进度)

| 进度 | 阶段文字 | 干啥 |
|---|---|---|
| 5% | 正在准备世界... | World 节点 instantiate (`defer_init=true`, 不跑 `_ready` 初始化) |
| 20% | 正在构建方块... | `TileSetBuilder.build()` + 给 terrain/wall layer 绑 tile_set |
| 40% | 正在生成地形... | ChunkManager.setup(seed) + `ensure_loaded(0)` + 信号 connect |
| 60% | 正在召唤天气... | WaterSim, MinimapData, RainLayer, Weather, Fireflies, ShootingStar, FallingLeaves, SparkPool |
| 75% | 正在召唤玩家... | `SkyLightGrid.recompute_from([])` + `_spawn_player()` + CursorManager + 联机回调 |
| 90% | 正在准备界面... | HUD + CraftingPanel + FloatingPrompt + DebugHud + Dialogue, 走 `_wire_player` |
| 100% | 进入世界! | LoadingScreen 淡出 0.5s, 关闭 |

每步之间 `await get_tree().process_frame`, 让 LoadingScreen 渲染一帧 + 进度条 tween + 小人跑动. 全程预计 0.8-1.5 秒 (取决于机器).

### 小贴士

20 条, 启动时打乱顺序. 默认每 4 秒自动切下一条. 点击 TipLabel (Button) → 立即切下一条 + 重置自动计时器.

**贴士池** (实现时按这个数组直译, 按键已核对 `project.godot`):

1. 小贴士: 按 A / D 左右移动
2. 小贴士: 按 空格 跳跃
3. 小贴士: 按住 鼠标左键 挖方块
4. 小贴士: 鼠标右键 (或 F) 放方块 / 吃食物
5. 小贴士: 按 E 和村民聊天
6. 小贴士: 按 数字 1-9 切换热键栏
7. 小贴士: 走到工作台前点一下打开合成
8. 小贴士: 砍树就能拿到木头
9. 小贴士: 挖矿要用更好的镐子
10. 小贴士: 火把可以照亮山洞
11. 小贴士: 晚上小心僵尸出没!
12. 小贴士: slime 弱, 适合新手练习
13. 小贴士: 牛 / 羊 / 猪 可以打掉拿肉
14. 小贴士: 肚子饿了记得吃东西
15. 小贴士: 按 Esc 暂停游戏
16. 小贴士: 下雨天会让水变多
17. 小贴士: 闪电过后空气会更清新
18. 小贴士: 萤火虫只在晚上出来
19. 小贴士: 死了会在出生点复活, 掉的东西在原地
20. 小贴士: 看到流星记得许愿

### 节点结构

`scenes/ui/loading_screen.tscn`:

```
LoadingScreen (CanvasLayer, layer=50)
├── Sky (ColorRect, 全屏, 暮色渐变 via 代码)
│   └── SkyGradient (TextureRect, 渐变纹理)
├── Stars (Control)        # 14 颗动态生成
├── PlayerRunner (AnimatedSprite2D, scale=4, centered)
├── StageLabel (Label)
├── ProgressBg (Panel, 480x28)
│   └── ProgressFill (ColorRect, anchor 左边, width 跟 percent 动)
├── PercentLabel (Label)
├── TipButton (Button, transparent style)
│   └── TipLabel (Label, 居中)
└── FadeOverlay (ColorRect, 全屏黑, 默认 alpha 0)
```

### API

`scripts/ui/loading_screen.gd`:

```gdscript
extends CanvasLayer

signal finished     # 淡出动画结束 → main.gd queue_free 它

func set_progress(percent: float, stage_text: String) -> void
func finish_and_fade() -> void   # 进度满, 触发 0.5s 淡出 → emit finished
```

进度条用 tween 平滑过渡 (0.2s easing) 而不是瞬切, 视觉更舒服.

### main.gd 改动

`_start_game(opts)` 改为 `async`:

```gdscript
func _start_game(seed_or_opts = 0) -> void:
    # ... 解析 opts ...
    _state = "game"
    _main_menu.visible = false

    var loading = LoadingScreenScene.instantiate()
    add_child(loading)
    await get_tree().process_frame  # 让 LoadingScreen 先渲染一帧

    # Step 1: World instantiate (defer_init)
    loading.set_progress(0.05, "正在准备世界...")
    var w = WorldScene.instantiate()
    w.name = "World"
    w.defer_init = true
    if world_seed != 0: w.world_seed = world_seed
    add_child(w)
    _game_nodes.append(w)
    await get_tree().process_frame

    # Step 2-6: world._init_step_N() 一个个跑
    var steps = w.init_steps   # Array of {label, callable}
    var step_count: int = steps.size()
    for i in step_count:
        var step: Dictionary = steps[i]
        loading.set_progress(0.20 + (0.55 * i / step_count), step["label"])
        step["callable"].call()
        await get_tree().process_frame

    # Step 7: HUD + 其他 UI
    loading.set_progress(0.90, "正在准备界面...")
    # ... instantiate HUD/CraftingPanel/... (现有逻辑) ...
    await get_tree().process_frame
    _wire_player.call_deferred()
    _start_autosave()

    # 100%: 完成 + 淡出
    loading.set_progress(1.0, "进入世界!")
    loading.finish_and_fade()
    await loading.finished
    loading.queue_free()
```

兼容 `boot_to_game(seed)` (测试): 测试入口不走 LoadingScreen, 直接 `_start_game_sync(seed)` 老路径 (世界 `defer_init=false` 自动跑 `_ready`).

### world.gd 改动

`_ready()` 拆出来:

```gdscript
@export var defer_init: bool = false   # true 时跳过自动初始化

func _ready() -> void:
    add_to_group("world")
    add_to_group("terrain_layer")  # 部分早期 setup
    if defer_init:
        return
    # 老路径: 顺序跑所有 step
    for step in init_steps:
        step["callable"].call()

var init_steps: Array:
    get:
        return [
            {"label": "正在构建方块...", "callable": _step_build_tileset},
            {"label": "正在生成地形...", "callable": _step_chunks},
            {"label": "正在召唤天气...", "callable": _step_fx_layers},
            {"label": "正在召唤玩家...", "callable": _step_spawn_player},
        ]

func _step_build_tileset() -> void:
    var ts := TileSetBuilder.build()
    terrain_layer.tile_set = ts
    wall_layer.tile_set = ts

func _step_chunks() -> void:
    if world_seed == 0: world_seed = randi()
    chunk_manager = ChunkManagerClass.new()
    chunk_manager.name = "ChunkManager"
    add_child(chunk_manager)
    chunk_manager.setup(world_seed)
    chunk_manager.chunk_loaded.connect(_on_chunk_loaded)
    chunk_manager.chunk_unloaded.connect(_on_chunk_unloaded)
    chunk_manager.ensure_loaded(0)

func _step_fx_layers() -> void:
    # WaterSim, MinimapData, RainLayer, Weather, Fireflies, ShootingStar, FallingLeaves, SparkPool
    # ... 现有代码原样搬 ...

func _step_spawn_player() -> void:
    SkyLightGrid.recompute_from([])
    spawn_point = _find_spawn_in_loaded()
    _spawn_player()
    var cursor_mgr := CursorManagerClass.new()
    cursor_mgr.name = "CursorManager"
    add_child(cursor_mgr)
    if NetworkManager != null:
        # ... 联机 setup 原样 ...
```

拆完之后 `_ready` 默认走老路径, 行为不变. 加载流程才走 `defer_init=true`.

## 测试

- 手动: 启动游戏 → 点新世界 → 应看到 LoadingScreen 显示, 进度条平滑前进 0→100%, 小人跑步, 7 个阶段文字依次出现, 小贴士可点击切换.
- 自动: `boot_to_game(seed)` 走老路径, GUT 测试不应被打断. 现有测试应继续通过.
- 单元: LoadingScreen.set_progress(0.5, "x") 后 PercentLabel 显 "50%", StageLabel 显 "x".

## 不在范围内

- 加载画面的"背景音乐淡入". (现有 BGM 在 `_start_autosave` 之后由 audio 系统接管, 不动)
- 异步流式加载 chunk (chunks 仍同步生成 64 列, 拆是为分阶段显示进度, 不是真异步).
- 联机加载状态. 联机的 hello/initial_state 流程不变, 仍由 NetworkManager 驱动.
