# Teilaruia · Demo P1.5 · Atmosphere & Feel · 设计

- **日期**：2026-05-18
- **状态**：v1 草案，等待用户复审
- **前置**：P1 Foundation 已完成（`tag demo-p1-foundation`）
- **位置**：插在 P1 与 P2 之间，独立 tag `demo-p1.5-feel`
- **动机**：当前画面是静态的（tile + 玩家）。加视差云、玩家尘埃、块破碎粒子、挖进度裂纹、放下弹动、交互提示，让 P2 上线时已经有质感骨架，P2 只需把粒子/裂纹的 trigger 接通。

---

## 1. 目标

P1.5 完成后玩家在没有 P2 的情况下也能感受到：

- 天空中云朵在不同深度/速度漂移
- 跳起时脚下扬起一团灰
- 落地时脚下扬起更大一团灰
- 走路时每隔半步在脚下喷出小尘
- 玩家碰到 workbench 头上浮个"按 E"提示（即使按 E 暂时没反应也行）

同时为 P2 提前预留好可调的 API：

- 块破碎粒子（P2 挖完调）
- 挖进度裂纹 overlay（P2 挖进度调）
- 块放下小弹动画（P2 放下调）

整局**手动验收不可行**，靠 GUT 集成测试 + 60 秒长跑 smoke 验证不崩。

---

## 2. 范围

### 2.1 In Scope

| 子系统 | 内容 |
|---|---|
| **视差云** | ParallaxBackground + 2-3 层不同深度+滚速；纯白/浅灰云形 (PixelArt 程序生成) |
| **玩家尘埃** | jump dust / land dust / walking puff 三种粒子，触发由 player_controller 的状态切换决定 |
| **块破碎粒子** | 调用 API `Effects.spawn_block_break(tile_coord, tile_id)`；4-8 个小方块碎片飞溅，色取自该 tile 调色板 |
| **挖进度裂纹** | CrackOverlay 节点，API `set_progress(tile_coord, ratio_0_to_1)` / `clear(tile_coord)`；视觉用 4 阶段裂纹纹理叠在 tile 上 |
| **块放下弹动** | API `Effects.spawn_place_bounce(tile_coord)`；该 tile 上叠一个 Sprite2D，scale 从 1.2 → 1.0 用 Tween 100ms |
| **交互提示浮标** | FloatingPrompt 场景；API `show(target_pos, text)` / `hide()`；P1.5 仅由 PlayerController 在靠近 workbench 时调用作为占位测试（即使 workbench 还没合成出来，spec 验收可在地图上预放一个） |

### 2.2 Out of Scope

| 推后到 | 内容 |
|---|---|
| P2 | 实际接 mining_progress → CrackOverlay；实际接 try_place → place_bounce；mining 完成 → block_break |
| P3 | 对话框摇晃、受伤闪红 |
| M2+ | 水波纹 ripple、雨/雪粒子 |

### 2.3 接口承诺

P1.5 提供以下 autoload / API，P2 直接调用（已写好且测试通过）：

```gdscript
# autoload Effects
Effects.spawn_block_break(tile_coord: Vector2i, tile_id: int)
Effects.spawn_place_bounce(tile_coord: Vector2i)
Effects.spawn_jump_dust(world_pos: Vector2)
Effects.spawn_land_dust(world_pos: Vector2)
Effects.spawn_walk_puff(world_pos: Vector2)

# Node in world tree
CrackOverlay.set_progress(tile_coord: Vector2i, ratio: float)  # 0..1
CrackOverlay.clear(tile_coord: Vector2i)

# Node in world tree
FloatingPrompt.show(target_world_pos: Vector2, text: String)
FloatingPrompt.hide()
```

---

## 3. 架构

### 3.1 新模块

| 文件 | 责任 |
|---|---|
| `scripts/fx/effects.gd` (autoload) | 工厂方法，instantiate 各粒子场景，丢到当前场景的 `effects_root` 组 |
| `scripts/fx/particles_art.gd` | 程序生成小粒子贴图（参考 P0 BlocksArt 模式） |
| `scripts/fx/block_break_particle.gd` | 单个碎片节点：Sprite2D + 重力 + 30 帧后 queue_free |
| `scripts/fx/dust_particle.gd` | 灰尘云：Sprite2D + 渐隐淡出 + 短生命 |
| `scripts/fx/place_bounce.gd` | tile 放下后的 scale tween 节点 |
| `scripts/world/crack_overlay.gd` | TileMapLayer 子层 (或独立 Node2D 容器)，每 tile 一个 Sprite2D 覆盖裂纹 |
| `scripts/ui/floating_prompt.gd` | 跟随世界坐标的 label，比如"按 E" |
| `scripts/world/cloud_layer.gd` | ParallaxBackground 子层，多个云 Sprite2D 自滚动 |
| `scripts/fx/clouds_art.gd` | 程序生成云形纹理 (3-4 种形状) |
| `scenes/fx/block_break.tscn` | 单个碎片 |
| `scenes/fx/dust.tscn` | 单个灰尘 |
| `scenes/fx/place_bounce.tscn` | scale tween 节点 |
| `scenes/world/crack_overlay.tscn` | CrackOverlay 容器 |
| `scenes/world/cloud_layer.tscn` | 多层云背景 |
| `scenes/ui/floating_prompt.tscn` | 文字浮标 |

### 3.2 修改

- `project.godot` — autoload `Effects`
- `scripts/player/player_controller.gd` — 在 state 转换时调 `Effects.spawn_*`
- `scripts/world/world.gd` — 加入 CloudLayer + CrackOverlay + 把 `effects_root` 节点加 group
- `scripts/main.gd` — 实例化 FloatingPrompt CanvasLayer

### 3.3 美术资源生成

云形 / 粒子贴图全部走 P0 那套 PixelArt 程序生成路线，硬编码到 ClouddsArt / ParticlesArt 类，启动时 ArtCache 一次性生成好缓存。

云形：
- 形状 A：水平拉长椭圆（"flat" 云），8×4
- 形状 B：标准蓬松（中间高两侧低），12×6
- 形状 C：长条三段（带尾巴）16×5
- 色：纯白 / 浅灰 / 中灰 三种，用于不同视差层（远云更灰更小）

粒子贴图：
- 块碎片：3×3 像素小方块（取目标 tile 的 base 色 + dark 色）
- 灰尘 puff：5×5 圆点（带 alpha 渐变）

---

## 4. 关键数据流

### 4.1 视差云

```
World._ready():
  cloud_layer = CloudLayerScene.instantiate()
  add_child(cloud_layer)            # 自动跟 Camera2D 视差

CloudLayer._ready():
  for each (depth, speed) in [(0.2, 12), (0.5, 24), (0.8, 40)]:
    var parallax_layer = ParallaxLayer.new()
    parallax_layer.motion_scale = Vector2(depth, depth * 0.3)  # 垂直少动
    for i in 8:
      var sprite = make_cloud(rand_shape, rand_size, depth_color)
      sprite.position = Vector2(rand x, rand y)
      parallax_layer.add_child(sprite)
    parallax_root.add_child(parallax_layer)

# 云朵自滚动：在 _process 里加 sprite.position.x += speed * delta
# 出屏后 wrap 到对侧（mod 屏宽 + margin）
```

### 4.2 玩家尘埃触发

修改 `player_controller.gd._update_animation`：

```gdscript
var was_on_floor: bool = _was_on_floor
_was_on_floor = on_floor

# 跳起瞬间
if was_on_floor and not on_floor and velocity.y < -100:
  Effects.spawn_jump_dust(global_position)
# 落地瞬间
if not was_on_floor and on_floor and _previous_vy > 200:
  Effects.spawn_land_dust(global_position)
# 走路 (每 0.3s 一次)
if on_floor and abs(dir) > 0.01:
  _walk_step_timer -= delta
  if _walk_step_timer <= 0:
    Effects.spawn_walk_puff(global_position + Vector2(-_facing_sign * 4, 0))
    _walk_step_timer = 0.3
else:
  _walk_step_timer = 0
```

### 4.3 块破碎粒子（P2 接通）

API `Effects.spawn_block_break(tile, tile_id)`:
- 取 `Tiles.get_palette(tile_id)` 的 base/dark 两色
- 在 tile 中心生成 6 个 BlockBreakParticle 节点
- 每个赋随机 velocity（向上 + 向两侧扇形）
- 受重力，30 帧后 queue_free

### 4.4 挖进度裂纹（P2 接通）

CrackOverlay 维护 `_active: Dictionary<Vector2i, Sprite2D>`：
- `set_progress(tile, ratio)`: 若没该 tile，instantiate 一个 Sprite2D；按 ratio 选 4 阶段贴图 (≤0.25/≤0.5/≤0.75/<1.0)
- `clear(tile)`: 找到 sprite，queue_free，从 dict 移除
- ratio=0 或 ratio>=1 自动 clear

### 4.5 块放下弹动（P2 接通）

`Effects.spawn_place_bounce(tile)`:
- 实例 PlaceBounce 节点（一个透明 Sprite2D 占位 + Tween）
- 取 tile 当前贴图作 Sprite 纹理
- Tween: scale (1.2, 1.2) → (1.0, 1.0) ease_out_cubic 100ms
- 完成后自删（保留 TileMapLayer 上原 tile）

### 4.6 交互提示浮标

`FloatingPrompt` 是 CanvasLayer 下的 Label。`show(world_pos, text)` 设位置（world → screen 转换）+ 显示。`hide()` 隐藏。

P1.5 触发：player_controller 在 `_physics_process` 末尾，检查 chebyshev ≤ 2 的 workbench tile（不存在就不显示）。P2 会扩到所有 interactables。

为了能测试，spec 允许在 World._ready 中预放 1 个 workbench tile 在出生点旁边作为测试 fixture（用 `if OS.has_feature("editor") or Engine.is_editor_hint()` 包裹 → 实际跑场景时不放，仅集成测试 fixture 用）。简化方案：直接给 World 加 `@export var debug_place_workbench: bool = false`，主场景默认 false，测试场景手动设 true。

---

## 5. 测试

### 5.1 单元

| 测试文件 | 覆盖 |
|---|---|
| `test_effects.gd` | spawn_* API 不崩；返回的节点正确加到 effects_root group |
| `test_crack_overlay.gd` | set_progress 创建 sprite；ratio=0 清除；同 tile 重复调更新而非堆叠 |
| `test_floating_prompt.gd` | show 后 visible=true；hide 后 visible=false；位置转换正确 |

### 5.2 集成

| 测试文件 | 覆盖 |
|---|---|
| `test_player_dust_emits.gd` | 玩家跳起 / 落地 / 走路时 effects_root 下出现对应粒子 |
| `test_cloud_layer_loaded.gd` | World _ready 后 cloud_layer 存在 + 至少有 1 个 ParallaxLayer |
| `test_smoke_p1_5.gd` | 跑 600 帧无 crash + effects_root 节点数有界 (粒子能自删) |

---

## 6. 验收

每 task：
1. GUT 全测试通过
2. `godot --headless` 无 error
3. git 干净

整 P1.5：
- `test_smoke_p1_5.gd` 通过
- 整局测试套件累计通过数有增长，老测试不退化
- tag `demo-p1.5-feel`

---

## 7. 风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 粒子节点泄漏（每帧 spawn 不释放） | 中 | 高 | smoke 60s 测试断言 effects_root.get_child_count() ≤ 100 |
| ParallaxBackground 在 Camera2D zoom=2 时坐标错乱 | 中 | 低 | 用 Camera2D.zoom 调 ParallaxLayer.motion_scale 反向补偿 |
| CrackOverlay 占内存（每挖一格一个 Sprite2D） | 低 | 低 | clear 后立即 queue_free；一次最多 1 个进行中 |
| Tile 取调色板 API 不存在 | 中 | 低 | 给 BlocksArt 加 `static func get_palette(tile_id) -> Array[Color]`；默认色作 fallback |

---

## 8. 与 P2 的衔接

P2 plan 需要追加 5 个 hook (1-2 行代码每个)：
1. `_update_mining` 进度变化 → `CrackOverlay.set_progress(tile, ratio)`
2. `_finish_mine` → `Effects.spawn_block_break(tile, tid)` + `CrackOverlay.clear(tile)`
3. `try_place` 成功 → `Effects.spawn_place_bounce(tile)`
4. `_has_workbench_nearby` → 改 player_controller 来调 FloatingPrompt.show
5. P2 task 列表加 "P1.5 hooks 接通" 作为 sub-step（不新增 task）

实施 P2 时这些 hook 是直接 `Effects.xxx()` 一行调用，不影响测试结构。
