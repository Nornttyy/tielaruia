# Scenic Backgrounds (远山 + 日月星 + 矿洞远景)

## Goal

让世界视觉上不再"单调" — 玩家走在地表能看到远山、太阳/月亮按时间走弧线、夜里星星眨眼；挖到地下能看到远处岩壁、钟乳石剪影、依稀闪光的水晶。所有内容**程序生成**（procedural），不引入新美术资源。

## Motivation

现在 `sky_background.gd` 是纯色 ColorRect，`cloud_layer.gd` 已有云视差，但天空整体很空；地下背景是纯黑。玩家会觉得世界"少了点什么"。这是"丰富世界"路线图（背景 → biome → 特殊地点 → 水）的第一步。

## Scope

### In scope

**核心远景**
- 地表 3 层视差山（远 / 中 / 近丘）+ 山尖雪 + 大气透视染色
- 太阳走弧线（白天）+ 月亮走弧线（夜里）
- 50-80 颗夜空星星（仅夜里淡入 + 随机眨眼）
- 矿洞 3 层视差（远岩壁 / 钟乳石剪影 / 闪光水晶）
- 按相机/玩家 Y 在地表背景与矿洞背景之间平滑切换

**小点缀（共用 3 个机制实现）**
- 🦅 远处鸟群 V 字飞 + 🦇 矿洞蝠群掠过（共用 `flock_layer.gd`，参数化）
- 🌈 雨停后彩虹 + 🌌 夜里偶尔极光（共用 `rare_overlay_layer.gd`，参数化）
- 💧 矿洞岩浆滴落（独立粒子发射器 `lava_drip_layer.gd`）
- 🍄 矿洞发光蘑菇 + 💀 化石骨架（直接画进 `cave_bg_art` 纹理，不需要新代码）

**工程约束**
- 程序生成所有图片，跟现有 `clouds_art.gd` / `fireflies.gd` 一个套路
- 单元测试覆盖：所有新 art 生成器吐 ImageTexture，所有新 Layer ready 不报错

### Out of scope

- 不做雷电视差 / 雨在山后的效果（rain_layer 仍跟相机锁屏）
- 不做"看到"远处的村庄、敌人等动态背景对象
- 不做太阳/月亮真正发光（lighting） — 它们只是视觉 sprite，不影响地表光照（地表光照已由 TimeOfDay 控制）
- 不做不同 biome 不同山 — 留到 biome 系统时再分
- 不做水 / 河 / 海

## Architecture

### 新文件

```
scripts/art/
  mountains_art.gd        # 生成 3 种山脊纹理（jagged polyline → ImageTexture）
  celestial_art.gd        # 生成太阳圆盘、月亮圆盘
  cave_bg_art.gd          # 生成岩壁、钟乳石、水晶 + 🍄 蘑菇 + 💀 化石 (画进背景纹理)
  flock_art.gd            # 生成单只鸟/单只蝠的小剪影 texture (2 帧拍翅)
  rare_overlay_art.gd     # 生成彩虹弧 + 极光光带 texture

scripts/world/
  mountains_layer.gd      # ParallaxBackground，地表用
  celestial_layer.gd      # CanvasLayer，天空中日月+星
  cave_background_layer.gd  # ParallaxBackground，地下用
  flock_layer.gd          # 参数化飞行小群 (鸟/蝠 都用它)
  rare_overlay_layer.gd   # 参数化罕见全屏 overlay (彩虹/极光 都用它)
  lava_drip_layer.gd      # 矿洞远处橙色光点掉落粒子
  scenic_director.gd      # 按玩家 Y + 天气/时间 协调所有 layer 的 alpha / 触发
```

### 渲染层次（从远到近）

| Z / Layer | 节点 | 备注 |
|-----------|------|------|
| CanvasLayer -10 | `SkyBackground` (已有) | 纯色 sky_color() |
| CanvasLayer -8 | `CelestialLayer` （新） | 星 + 日月，固定屏幕位置 |
| CanvasLayer -7 | `RareOverlayLayer` 彩虹/极光（新） | 罕见全屏 fade |
| ParallaxBg motion_scale 0.05 | `MountainsLayer` 远山（新） | jagged peaks，半透明蓝灰 + 雪顶 |
| ParallaxBg motion_scale 0.12 | `MountainsLayer` 中山（新） | 颜色稍深 |
| ParallaxBg motion_scale 0.20 | `MountainsLayer` 近丘（新） | 深绿/棕 |
| ParallaxBg motion_scale 0.10 | `CaveBackgroundLayer` 远岩壁（新） | 棕褐渐变 + 边缘 + 🍄 + 💀 |
| ParallaxBg motion_scale 0.18 | `CaveBackgroundLayer` 钟乳石（新） | 灰黑剪影 |
| ParallaxBg motion_scale 0.25 | `CaveBackgroundLayer` 水晶（新） | 小点闪光（cyan/紫/绿） |
| Z 0 (Node2D 跟相机) | `FlockLayer(bird)` 鸟群（新） | 间歇 V 字飞过 |
| Z 0 (Node2D 跟相机) | `FlockLayer(bat)` 蝠群（新） | 矿洞内间歇飞 |
| Z 0 (Node2D 跟相机) | `LavaDripLayer` 岩浆滴（新） | 矿洞内常驻 5-15 个橙点 |
| ParallaxBg motion_scale 0.2-0.8 | `CloudLayer` (已有) | 不变 |
| Z 0 | `TerrainLayer` (已有) | 不变 |
| CanvasLayer 5 | `RainLayer` (已有) | 不变 |
| CanvasLayer 1 | `HUD` (已有) | 不变 |

## Components

### MountainsLayer (`scripts/world/mountains_layer.gd`)

`extends ParallaxBackground`。内部 3 个 `ParallaxLayer`（motion_scale 0.05 / 0.12 / 0.20），每个 layer 含一张大 Sprite2D（宽 ≥ 4096px），texture 由 `MountainsArt` 生成。

- 各 layer 用 `motion_mirroring = Vector2(texture.width, 0)` 让山在世界 X 任何位置都能见
- 山顶 Y 偏移：远山最高 → 中山中 → 近丘最低
- 每层颜色按"大气透视": `远=Color(0.55,0.62,0.75)`, `中=Color(0.40,0.50,0.55)`, `近=Color(0.30,0.40,0.30)`
- 每帧 `modulate = base_color * mix_with_sky(TimeOfDay.day_factor())` 让黄昏偏橙、夜里偏蓝紫
- 远山随机 30% 山尖 paint 白色雪顶

### CelestialLayer (`scripts/world/celestial_layer.gd`)

`extends CanvasLayer`，`layer = -8`。三组内容：

1. **太阳** Sprite2D，texture 来自 `CelestialArt.sun()`。位置按 `TimeOfDay.time` 走半圆弧：
   - 日间 (0.3 ≤ t < 0.7) 可见
   - `theta = lerp(0, PI, (t - 0.3) / 0.4)`
   - `pos = (vp.x * 0.5 - cos(theta) * radius, horizon_y - sin(theta) * arc_height)`
   - 日出/日落附近 alpha 平滑淡入淡出（避开离散闪烁）

2. **月亮** Sprite2D，texture 来自 `CelestialArt.moon()`。夜间走对称弧：
   - 夜间 (t < 0.2 or t ≥ 0.8) 可见
   - 用 `night_t = (t + 0.2) mod 1.0 → 标准化到 [0, 0.4]` 走弧

3. **星星** `Node2D` 包含 ~60 个小 ColorRect（或单点 Sprite）。
   - 启动随机位置散布于屏幕上 60%
   - 每颗有 phase 随机偏移，alpha 按 `sin(time*twinkle_speed + phase)` 在 0.3-1.0 抖动
   - 整体 alpha = `1.0 - TimeOfDay.day_factor()`（白天为 0）

视口尺寸变化时重算 horizon_y / 星星 x 位置（接 `get_viewport().size_changed`）。

### CaveBackgroundLayer (`scripts/world/cave_background_layer.gd`)

`extends ParallaxBackground`。3 个 ParallaxLayer：

1. **远岩壁** 大 Sprite，texture 是棕褐渐变 + 不规则边缘（程序生成 `cave_bg_art.rocks()`），motion_scale 0.10
2. **钟乳石** Sprite，texture 是从上往下的灰黑剪影，间距随机（`cave_bg_art.stalactites()`），motion_scale 0.18
3. **水晶** Node2D 含 ~25 个小发光点（ColorRect/Sprite），cyan/紫/绿三色随机，alpha 按 sin twinkle，motion_scale 0.25

整体 modulate 在 alpha 0.0（地表时）到 1.0（深矿洞）之间由 `ScenicDirector` 控制。

### ScenicDirector (`scripts/world/scenic_director.gd`)

`extends Node`，挂在 World 下。`_process` 每帧读 `world.get_player().global_position.y`，计算：

```
# WorldGenerator.SURFACE_BASE = 0.45, ChunkConstants.WORLD_HEIGHT = 256, TILE_SIZE = 16
surface_y_px = WorldGenerator.SURFACE_BASE * ChunkConstants.WORLD_HEIGHT * TILE_SIZE
            # = 0.45 * 256 * 16 ≈ 1843 px
depth_below_surface_px = max(0, player.y - surface_y_px)
cave_t = clamp(depth_below_surface_px / (10 * TILE_SIZE), 0, 1)  # 10 tile 内过渡
```

注意 SURFACE_BASE 是地表平均高度，玩家在 Y > surface_y 即"地下"。

- `mountains_layer.modulate.a = 1.0 - cave_t * 0.85`（地下时山仍微留 15% 阴影感，或全 0）
- `celestial_layer.modulate.a = 1.0 - cave_t`
- `cave_background_layer.modulate.a = cave_t`
- `sky_background.modulate.a = 1.0 - cave_t * 0.7`（地下天空也压暗但不全黑）
- 鸟群 `FlockLayer(bird).modulate.a = 1.0 - cave_t`
- 蝠群 `FlockLayer(bat).modulate.a = cave_t`
- `LavaDripLayer.modulate.a = cave_t`
- `RareOverlayLayer(rainbow/aurora).modulate.a = 1.0 - cave_t`（只有地表看到）

播放器没创建时不跑，等 World 报 player_ready（已有 `get_player()`）。

### FlockLayer (`scripts/world/flock_layer.gd`) — 鸟群 + 蝠群共用

`extends Node2D`，挂在 World 下（不视差，跟相机走）。

参数化：
```
setup(kind: String, spawn_interval_range: Vector2, count_range: Vector2i,
      y_range: Vector2, color: Color, scale: float)
```

- 内部 `_process` 跑一个 spawn_timer，触发时孵化一群（V 字 / 横排队形），每只飞过屏幕后自销毁
- `kind="bird"`：地表用，y 在屏幕上 15-35%，灰黑剪影，scale 1.0
- `kind="bat"`：矿洞用，y 在屏幕 20-60%，黑剪影，scale 0.7，飞速更快更乱
- 两只 `FlockLayer` 实例：一个 bird（地表），一个 bat（矿洞）。alpha 跟随对应的山/矿洞 modulate

### RareOverlayLayer (`scripts/world/rare_overlay_layer.gd`) — 彩虹 + 极光共用

`extends CanvasLayer`，挂在 World 下，layer = -7（在山前云后）。

参数化：
```
setup(kind: String, trigger_predicate: Callable, duration_sec: float, cooldown_sec: float)
```

- 内部维持 cooldown / active / fadeout 状态机
- `kind="rainbow"`：texture = 半圆彩虹弧，trigger = "刚从 rainy → clear"，duration=30s。订阅 `weather.weather_changed`
- `kind="aurora"`：texture = 几条绿色流动光带（水平），trigger = "夜里 + 随机 5min 检查一次 + 20% 概率"，duration=60s
- 出现时缓慢 fade in 2s，结束 fade out 2s
- 两只 RareOverlayLayer 实例

### LavaDripLayer (`scripts/world/lava_drip_layer.gd`)

`extends Node2D`，挂在 World 下。

- 每 N 秒（N=2-5 随机）从屏幕顶部远岩壁随机位置生成一个橙色光点（5x5 px 发光小圆），向下匀加速掉到屏幕下方消失
- 同时 5-15 个常驻
- alpha 跟随矿洞 modulate（地表时不可见）

## Procedural Art Generators

约定：所有生成器返回 `ImageTexture`，纯 GDScript 用 `Image.create()` + `Image.set_pixel()`。沿用 `clouds_art.gd` 的"一次生成 + 静态缓存"模式。

### `MountainsArt`

`generate_ridge(width, height, peaks, jaggedness, color, snow_cap) → ImageTexture`

- 用 1D Perlin/value noise 生成 height 数组
- 填充山下区域为 color
- 山尖（局部最高点 top 8%）若 snow_cap=true 用白色画三角

### `CelestialArt`

- `sun(radius) → ImageTexture`：径向渐变 中心白 → 边缘橙黄 + 外层柔光（alpha 软边）
- `moon(radius, phase=0.0) → ImageTexture`：灰白圆盘 + 几个深灰陨石坑斑点

### `CaveBgArt`

- `rocks(width, height) → ImageTexture`：纵向棕褐渐变，顶部用噪声边缘，**附加** 🍄 蘑菇丛（紫绿伞菌散落点 + 软光晕）和 💀 化石（白色恐龙骨/螺壳剪影 嵌入岩壁）
- `stalactites(width, height, count) → ImageTexture`：随机间隔下垂三角，灰黑剪影
- `crystals(width, height, count) → ImageTexture`：随机点位置 + 颜色（用于一次性生成；闪烁靠节点 alpha 抖）

### `FlockArt`

- `bird_silhouette() → ImageTexture`：8x6 V 型剪影，灰黑色（动画用 2 帧 wing-up/down 拼到一张）
- `bat_silhouette() → ImageTexture`：8x6 弧形翅膀剪影，纯黑色 + 微紫边

### `RareOverlayArt`

- `rainbow(width, height) → ImageTexture`：半圆 7 色弧 (红橙黄绿青蓝紫)，外缘软 alpha 渐变
- `aurora(width, height) → ImageTexture`：3-4 条波浪绿色光带（垂直方向 alpha 渐变，水平方向用 sin 摆动）

## Wiring into World

`scripts/world/world.gd::_ready()` 在创建 `rain_layer` 之前加（顺序固定：背景类先 add，director 最后 add，因为它在 _ready 就要拿到所有引用）：

```gdscript
const MountainsLayerClass = preload("res://scripts/world/mountains_layer.gd")
const CelestialLayerClass = preload("res://scripts/world/celestial_layer.gd")
const CaveBackgroundLayerClass = preload("res://scripts/world/cave_background_layer.gd")
const FlockLayerClass = preload("res://scripts/world/flock_layer.gd")
const RareOverlayLayerClass = preload("res://scripts/world/rare_overlay_layer.gd")
const LavaDripLayerClass = preload("res://scripts/world/lava_drip_layer.gd")
const ScenicDirectorClass = preload("res://scripts/world/scenic_director.gd")

# 远景核心
mountains_layer = MountainsLayerClass.new()
mountains_layer.name = "MountainsLayer"
add_child(mountains_layer)
celestial_layer = CelestialLayerClass.new()
celestial_layer.name = "CelestialLayer"
add_child(celestial_layer)
cave_bg_layer = CaveBackgroundLayerClass.new()
cave_bg_layer.name = "CaveBackgroundLayer"
add_child(cave_bg_layer)

# 点缀
bird_layer = FlockLayerClass.new()
bird_layer.name = "BirdLayer"
bird_layer.setup_bird()  # 内部封装好的 bird 参数预设
add_child(bird_layer)
bat_layer = FlockLayerClass.new()
bat_layer.name = "BatLayer"
bat_layer.setup_bat()
add_child(bat_layer)
rainbow_layer = RareOverlayLayerClass.new()
rainbow_layer.name = "RainbowLayer"
rainbow_layer.setup_rainbow(weather)  # 接 weather.weather_changed
add_child(rainbow_layer)
aurora_layer = RareOverlayLayerClass.new()
aurora_layer.name = "AuroraLayer"
aurora_layer.setup_aurora()  # 内部接 TimeOfDay
add_child(aurora_layer)
lava_drip_layer = LavaDripLayerClass.new()
lava_drip_layer.name = "LavaDripLayer"
add_child(lava_drip_layer)

# 协调器最后加 (要在所有 layer ready 后拿引用)
scenic_director = ScenicDirectorClass.new()
scenic_director.name = "ScenicDirector"
scenic_director.setup({
    "world": self,
    "mountains": mountains_layer,
    "celestial": celestial_layer,
    "cave_bg": cave_bg_layer,
    "sky_bg": sky_background,
    "bird": bird_layer,
    "bat": bat_layer,
    "rainbow": rainbow_layer,
    "aurora": aurora_layer,
    "lava_drip": lava_drip_layer,
})
add_child(scenic_director)
```

`SkyBackground` 需要拿到引用，可能要在 `scenes/world/world.tscn` 给它 unique name 或 World 用 `get_node("SkyBackground")`（看实际场景树）。注意 `rainbow_layer.setup_rainbow(weather)` 依赖 weather 已存在 — 调整 wiring 顺序让 weather 先建好（现有顺序里 rain_layer / weather 是后建的，这次要把 weather 提前建）。

## Testing

新增单元测试：
- `tests/unit/test_mountains_art.gd`：调用每个生成器 → 验证返回 ImageTexture 且尺寸/像素非空
- `tests/unit/test_celestial_art.gd`：同上
- `tests/unit/test_cave_bg_art.gd`：同上（包括 🍄 🦴 装饰版本）
- `tests/unit/test_flock_art.gd`：同上
- `tests/unit/test_rare_overlay_art.gd`：同上
- `tests/unit/test_celestial_layer.gd`：实例化 → _ready 不报错；设置 TimeOfDay.time = 0.5 → 一帧后 sun.visible=true, stars 总 alpha ≤ 0.1
- `tests/unit/test_flock_layer.gd`：实例化 bird/bat → _ready 不崩；调一次 spawn → 子节点 ≥1
- `tests/unit/test_rare_overlay_layer.gd`：实例化 rainbow → 模拟 weather "rainy→clear" 信号 → overlay alpha > 0
- `tests/unit/test_scenic_director.gd`：mock player Y 在地表/地下 → 验证所有 layer modulate.a 数值正确

集成测试不新增（现有 `test_smoke` 走到 world 已可发现 _ready 崩溃）。

## Out of scope（再次明确）

- 不动 `cloud_layer.gd` 已有的 3 层云
- 不改 `sky_background.gd` 的颜色逻辑（只动它的 modulate.a）
- 不引入新美术资源文件（.png/.svg）
- 不做"看远处地下河"或"看远处怪物剪影"这种动态背景对象
- 不做不同 biome 不同山 — 留给后续 biome 系统
- 测试不强求 GUT 高级 mock；用最小手写 stub
