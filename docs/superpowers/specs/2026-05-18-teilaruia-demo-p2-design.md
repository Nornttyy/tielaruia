# Teilaruia · Demo P2 · Items + Interaction + Crafting · 设计

- **日期**：2026-05-18
- **状态**：v1 草案，等待用户复审
- **前置**：P1 Foundation 已完成（`tag demo-p1-foundation`）
- **范围扩展说明**：相比顶层 spec（`2026-05-17-teilaruia-demo-design.md`）的原 P2/P3 切分，本 P2 把"合成系统"前移。理由：用户要求工作台合成工具构成可验证闭环。P3 后续只剩主背包 UI（drag-drop、shift-move 等手感打磨）+ 内容（史莱姆/村民/门/存档），见 §10。

---

## 1. 目标

让玩家从光秃秃出生开始能跑通完整生存开局：

1. 砍树 → 拿原木
2. 按 C 用 2×2 内置合成台 → 木板 → 木棍 → 工作台
3. 放工作台到地上
4. 靠近工作台 + E → 3×3 合成 → 木镚
5. 挖石头（无镚不能挖、有镚能挖）
6. 整个过程的物品在 hotbar 上可见

整局**手动验收不可行**（不开编辑器），全部靠 GUT 单元 + 集成 smoke 验证。

---

## 2. 范围

### 2.1 In Scope

| 子系统 | 内容 |
|---|---|
| 鼠标瞄准 + 距离限制 | 屏幕鼠标 → 世界坐标 → tile coord；玩家中心 4 tile 内才能交互 |
| 挖（mine） | 按住 LMB 累计进度；工具 tier 检查；达阈值后清 tile + spawn drops |
| 放（place） | RMB；当前热键格物品需 placeable；目标格空气 + 不重叠玩家 |
| ItemDrop 实体 | Area2D + Sprite + 30s 自毁 + 弹跳动量；玩家碰 → 拾取 |
| 拾取（pickup） | 自动，进入第一个可堆叠槽或第一个空槽 |
| Inventory 数据 | 36 槽：hotbar(9) + main(27)；合成 grid 由 CraftingPanel 独立持 |
| 热键栏 UI | 9 格底部居中；图标 + 计数；1-9/滚轮切换；选中描边 |
| 2×2 合成 UI | C 切换；2 输入 + 1 输出；ESC 关 |
| 3×3 工作台 UI | 靠近 ≤ 2 tile 的 workbench + E 触发；同 UI 风格但 3×3 |
| 6 个配方 | planks/stick/workbench/wood_sword/wood_pickaxe/wood_axe |
| 形状匹配 | 支持留白偏移；支持左右镜像；2×2 配方在 3×3 工作台也能匹配 |
| 工具行为 | 木镚开锁 STONE；木斧砍 LOG 速度 ×3 |
| 游标式物品移动 | Minecraft 风格：点击拿/放/堆叠/分半 |

### 2.2 Out of Scope（推后）

- 主背包 4×9 UI 显示（数据存在，仅不展示）→ P3
- 拖拽（drag-drop）→ P3，本 P 用点击式
- Shift+点击快速转移（hotbar ↔ main）→ P3
- 工具耐久度 → spec 已声明 Demo 永不消耗
- 武器伤害 / 攻击键 → P3 加入史莱姆时再做
- 史莱姆/村民/门/存档 → P3
- 声音/动画特效 → M5

---

## 3. 架构

### 3.1 新 autoload

```
Tiles="*res://scripts/world/tile_data.gd"             (P1)
SkyLightGrid="*res://scripts/world/sky_light_grid.gd" (P1)
ArtCache="*res://scripts/autoload/art_cache.gd"       (P0)
ItemDB="*res://scripts/items/item_db.gd"              (P2 new)
RecipeDB="*res://scripts/crafting/recipe_db.gd"       (P2 new)
```

- `ItemDB`：硬编码 dict `_DEFS: {item_id → ItemDef}`。`ItemDef` 字段：`name, max_stack, placeable_tile_id (int or -1), tool_kind ("pickaxe"/"axe"/"sword"/""), tool_tier`
- `RecipeDB`：硬编码数组 `_RECIPES: Array[RecipeDef]`。`RecipeDef` 字段：`name, grid_size (Vector2i 2x2 or 3x3), pattern (Array[Array[String]] 形状, "" = 空), output_id, output_count, mirror_ok`

为什么硬编码而不 `.tres`：spec 提过 `.tres` 是 M2 之后的事。Demo 阶段硬编码足够，热重载靠 Godot reload。

### 3.2 新数据类型（RefCounted）

```gdscript
# scripts/items/inventory.gd
class_name Inventory extends RefCounted

const HOTBAR_SIZE := 9
const MAIN_SIZE := 27
const TOTAL := HOTBAR_SIZE + MAIN_SIZE   # 36；合成 grid 由 CraftingPanel 独立持有，见 §4.5

# slots[i] = null 或 {"item_id": String, "count": int}
var slots: Array = []

func _init():
    slots.resize(TOTAL)
    slots.fill(null)

# 0..8 = hotbar；9..35 = main
func add(item_id: String, count: int) -> int        # 返回剩余未塞下的
func remove(slot_idx: int, count: int) -> int       # 返回实际拿走数
func swap(a: int, b: int) -> void
func split_half(slot_idx: int) -> Dictionary        # 返回拆出的半堆
```

### 3.3 RefCounted 工具：RecipeMatcher

```gdscript
# scripts/crafting/recipe_matcher.gd
class_name RecipeMatcher extends RefCounted

# grid: Array[Array[String_or_null]] 比 grid_size 大也可（3x3 含 2x2 配方）
# 返回 null 或 {"recipe_id": String, "output_id": String, "output_count": int,
#                "input_slots": Array[Vector2i]}
static func find_match(grid: Array) -> Variant:
    # 1. 找 grid 中所有非空 cell 的最小 bounding box
    # 2. 平移 pattern 到所有可能的留白位置
    # 3. 形状对位匹配
    # 4. 若 recipe.mirror_ok，再对 pattern 做左右翻转再试
```

### 3.4 玩家场景扩展

`scenes/player/player.tscn` 加两个 child Node：

```
Player (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── PlayerInventory (Node, script: player_inventory.gd)
└── PlayerAction (Node2D, script: player_action.gd, holds mining progress + reach line)
```

- `PlayerInventory.inventory: Inventory`，`hotbar_selected: int (0..8)`
- 信号：`hotbar_changed`, `inventory_changed`
- `PlayerAction.try_mine(delta)`, `try_place()`, `aim_tile_coord() -> Vector2i`

### 3.5 UI 树

`scenes/ui/hud.tscn`（Main scene 实例化的 CanvasLayer 之一，与 DebugHUD 并列）：

```
HUD (CanvasLayer)
└── Hotbar (HBoxContainer)
    └── HotbarSlot ×9 (PanelContainer + TextureRect + Label)
```

`scenes/ui/crafting_panel.tscn`（按 C 或 E 弹出的浮层）：

```
CraftingPanel (CanvasLayer, visible=false)
└── Center (CenterContainer)
    └── Panel (PanelContainer)
        ├── InputGrid (GridContainer, columns=动态 2 或 3)
        │   └── CraftSlot ×(4 或 9)
        ├── ArrowLabel ("→")
        └── OutputSlot (CraftSlot)
```

每个 CraftSlot：`PanelContainer + TextureRect + Label`，点击事件由 `crafting_view.gd` 接管，触发 `_on_slot_clicked(slot_id)`。

游标显示：屏幕右下浮一个跟随鼠标的 `TextureRect`（独立 Control，z-index 高）。

---

## 4. 关键数据流

### 4.1 挖（hold-progress）

```
_physics_process(delta):
  if Input.is_action_pressed("primary"):    # LMB
    var tile = aim_tile_coord()
    if tile == _mining_target:
      _mining_progress += delta * _current_tool_speed(tile)
      if _mining_progress >= _hardness(tile):
        _finish_mine(tile)
    else:
      _mining_target = tile
      _mining_progress = 0.0
  else:
    _mining_target = Vector2i.MIN
    _mining_progress = 0.0

_finish_mine(tile):
  var tile_id = TerrainLayer.get_cell_source_id(tile)
  TerrainLayer.set_cell(tile, -1)                # remove
  SkyLightGrid.invalidate_column(tile.x)
  for item_id, count in Tiles.drops_for(tile_id, _tool_kind()):
    for _i in count:
      _spawn_drop(item_id, tile)
  _mining_progress = 0.0
```

`_current_tool_speed(tile)`:
- 默认 1.0
- 木斧砍 LOG → 3.0
- 任何工具挖不动 (tier < required) → 0.0（永远不能完成）

`_hardness(tile)`: 草/泥/沙/叶/木板 = 0.3s; 木 = 0.6s; 石 = 1.2s; 工作台/门 = 0.5s。常量 dict 写在 PlayerAction 顶部。

### 4.2 放

```
on_input(InputEventMouseButton RMB pressed):
  var slot = inventory.slots[hotbar_selected]
  if slot == null: return
  var def = ItemDB.get(slot.item_id)
  if def.placeable_tile_id == -1: return
  var tile = aim_tile_coord()
  if not _in_reach(tile): return
  if TerrainLayer.get_cell_source_id(tile) != -1: return   # 已占用
  if _overlaps_player_aabb(tile): return
  TerrainLayer.set_cell(tile, def.placeable_tile_id, Vector2i.ZERO)
  inventory.remove(hotbar_to_slot_index(hotbar_selected), 1)
  SkyLightGrid.invalidate_column(tile.x)
```

### 4.3 拾取

`ItemDrop` 是 Area2D，monitor_areas=false, monitor_bodies=true，collision_mask 仅 player 层。

```
ItemDrop._ready():
  $Sprite2D.texture = ArtCache.get_inventory_icon(item_id)
  $Lifetime.start(30.0)
  $Lifetime.timeout → queue_free
  $Area2D.body_entered → _on_body_entered

_on_body_entered(body):
  if not body.has_node("PlayerInventory"): return
  var inv = body.get_node("PlayerInventory")
  var leftover = inv.inventory.add(item_id, count)
  if leftover == 0:
    queue_free()
  else:
    count = leftover                     # 留下还塞不下的部分
```

弹跳动量：`_ready` 时 `velocity = Vector2(randf_range(-30, 30), -60)`；`_physics_process` 加重力 + 摩擦 + ground check。

### 4.4 合成（游标式）

UI 状态：`crafting_view.gd` 维护一个 `_cursor: {item_id, count}` 或 null。

```
点击 slot：
  case 1: cursor == null, slot != null → 拿起整堆 (cursor = slot, slot = null)
  case 2: cursor != null, slot == null → 放下 cursor (slot = cursor, cursor = null)
  case 3: cursor != null, slot != null, 同 id → 合并（受 max_stack 限制）
  case 4: cursor != null, slot != null, 不同 id → 交换
  case 5: 右键点 slot, cursor != null → 放 1 个，cursor.count -= 1
  case 6: shift+左键点 slot → P2 不支持，记 TODO
  case 7: 点击 output slot：
    - 必须 cursor == null 或 cursor.item_id == output.item_id（能堆叠）
    - 把 output 加到 cursor
    - 各 input slot count -= 1，count==0 时清空 slot
    - 重算 find_match → 刷新 output preview
```

input grid 每次变动后调用 `RecipeMatcher.find_match`，命中则 output_slot 显示预览（preview 不可拿，需点击才实际消耗 input）。

### 4.5 工作台交互

```
PlayerAction._process(delta):
  if Input.is_action_just_pressed("interact"):   # E
    var nearby = _find_nearby_workbench()
    if nearby != Vector2i.MIN:
      CraftingPanel.open(3, get_workbench_ref())  # 3 = 3x3
    elif CraftingPanel.is_open:
      CraftingPanel.close()
    # else: 没工作台、没在面板 → noop

按 C 单独：
  if Input.is_action_just_pressed("crafting_2x2"):
    CraftingPanel.open(2, null)
```

**合成 grid 不在 Inventory 内**。CraftingPanel 自持 9 个 cell 的 temp grid（2x2 模式只用前 4 cell，其他 disabled）+ 1 个 output cell。

关闭面板时把 grid 里残留物品退回 Inventory（先塞 hotbar 同 id 堆 → main 同 id 堆 → 首个空槽顺序），塞不下的直接 spawn ItemDrop 在玩家脚下。

**最终 Inventory size = 36**（hotbar 9 + main 27）。

**工作台触发距离**：玩家中心 ↔ workbench tile 中心的 chebyshev 距离 ≤ 2 tile（即 8 邻 + 自身 + 再外一圈，等效 5×5 块）。算法上：`max(abs(player_tile.x - wb.x), abs(player_tile.y - wb.y)) <= 2`。同一时刻只有一个 CraftingPanel 打开，再按 E 关闭。

---

## 5. 6 个配方（spec §3.1.F 精确化）

| ID | 在哪 | 形状（"L"=log "P"=planks "S"=stick；". "=空）| 输出 |
|---|---|---|---|
| planks | 2×2 | `L .` / `. .`（任意位置，1 个 log） | 4 planks |
| stick | 2×2 | `P .` / `P .` （或镜像） | 4 sticks |
| workbench | 2×2 | `P P` / `P P` | 1 workbench |
| wood_sword | 3×3 | `. P .` / `. P .` / `. S .` | 1 wood_sword |
| wood_pickaxe | 3×3 | `P P P` / `. S .` / `. S .` | 1 wood_pickaxe |
| wood_axe | 3×3 | `P P .` / `P S .` / `. S .` | 1 wood_axe |

`mirror_ok` 全 `true`（spec 要求"支持左右镜像"）。

**对位算法**（在 RecipeMatcher 内）：

1. 收集 grid 所有非空 cell 的坐标集 `S_grid`，求 bbox
2. 同样收集 recipe.pattern 中所有非空 cell 的坐标集 `S_pat`，求 bbox
3. 若 bbox 尺寸不同 → 不匹配
4. 将 `S_pat` 平移到 `S_grid` bbox 起点，对位 item_id 比对
5. 若 mirror_ok，左右翻转 pattern 重试
6. 命中任一返回 recipe

---

## 6. ItemDB 内容

| item_id | placeable_tile_id | tool_kind | tool_tier | max_stack |
|---|---|---|---|---|
| dirt | DIRT | "" | 0 | 64 |
| grass | GRASS | "" | 0 | 64 |
| stone | STONE | "" | 0 | 64 |
| sand | SAND | "" | 0 | 64 |
| log | LOG | "" | 0 | 64 |
| leaves | LEAVES | "" | 0 | 64 |
| planks | PLANKS | "" | 0 | 64 |
| workbench | WORKBENCH | "" | 0 | 64 |
| door | DOOR | "" | 0 | 64 |
| stick | -1 | "" | 0 | 64 |
| wood_sword | -1 | "sword" | 1 | 1 |
| wood_pickaxe | -1 | "pickaxe" | 1 | 1 |
| wood_axe | -1 | "axe" | 1 | 1 |
| slime_ball | -1 | "" | 0 | 64 |

（slime_ball 列出但 P2 无来源，留位）

---

## 7. InputMap 新增

```
primary       LMB        # 挖
secondary     RMB        # 放
interact      E          # 工作台 + 后续 NPC
crafting_2x2  C          # 切 2x2 合成
inventory     Tab        # P3 用，本 P 仅占位（不绑）
hotbar_1..9   1..9       # 直接选热键
hotbar_scroll wheel      # 滚动选热键
```

P2 实际接 primary/secondary/interact/crafting_2x2/hotbar_1..9。滚轮在 player_action 里直接读 `InputEventMouseButton.button_index in [WHEEL_UP, WHEEL_DOWN]`。

---

## 8. 测试

### 8.1 单元（TDD）

| 测试文件 | 覆盖 |
|---|---|
| `test_inventory.gd` | add 进空槽；add 堆叠；超 max_stack 溢出；remove；swap；split_half |
| `test_item_db.gd` | get(unknown) 返回 null；placeable / 工具属性正确 |
| `test_recipe_db.gd` | 6 配方都能 load；shape 字段非空 |
| `test_recipe_matcher.gd` | 6 配方正例；镜像；平移；2x2 在 3x3；反例不匹配 |
| `test_player_action.gd` | 距离限制；工具 tier 拦截；hardness 阈值 |

### 8.2 集成

| 测试文件 | 场景 |
|---|---|
| `test_mine_drop_pickup.gd` | spawn 玩家 + 在脚下放 grass → 挖 → ItemDrop 落地 → 玩家走过 → inventory 有 grass |
| `test_place_block.gd` | inventory 塞 5 dirt → 选中 → 在空格 RMB → 减 1 + tile 出现 |
| `test_craft_loop.gd` | inventory 塞 1 log → 2x2 craft → 4 planks → 塞 4 planks → workbench → spawn workbench drop |
| `test_workbench_3x3.gd` | inventory 塞 3 planks + 2 sticks → 工作台 3x3 → wood_pickaxe |

### 8.3 不能自动测试的

- 鼠标瞄准 UI（需 mouse position）
- UI 视觉对齐
→ 用集成 test 时直接调 `PlayerAction.set_aim_override(Vector2)` 模拟。

---

## 9. 验收门禁

每 task 完成：
1. GUT 全测试通过（约 30+ 用例新增）
2. `godot --headless` 无 error（除 libfontconfig 警告）
3. git 干净

P2 最终判定（既然手动验收不可行）：
- `test_craft_loop.gd` 和 `test_workbench_3x3.gd` 完整跑通整局闭环
- 跑 60 秒 main scene 无 crash、无内存泄漏 ObjectDB warn 之外的 error
- tag `demo-p2-items`

---

## 10. 对顶层 spec 的修订（P3 重定义）

本 P2 完成后，顶层 spec 的 P3 缩为：

> **P3 Inventory UI + Content + Persistence**
> - 主背包 4×9 UI（按 Tab 开/关）
> - 拖拽（drag-and-drop）替换游标点击
> - Shift+点击快速转移（hotbar ↔ main）
> - 史莱姆/村民/门
> - 存档（save/load）

P4 在新切分下可能不再需要，或留作未来空间。本设计实施时会在顶层 spec 加变更日志记录。

---

## 11. 风险

| 风险 | 概率 | 影响 | 缓解 |
|---|---|---|---|
| 合成形状匹配镜像逻辑 bug | 高 | 中 | 6 配方每个 8+ 测试用例（正/反/镜像/平移）覆盖 |
| Inventory + UI 同步 bug | 中 | 中 | 信号驱动；UI 只读 inventory；任何 inventory mutate 触发 inventory_changed |
| 鼠标瞄准在 zoom 2 下坐标换算错 | 中 | 低 | `get_global_mouse_position()` 已经考虑 camera transform；写单测验证 |
| ItemDrop 卡墙缝 / 穿地板 | 中 | 低 | gravity + ground check + 限速；缝隙宽度 ≥ player CollisionShape |
| 工作台同时多个被打开 | 低 | 低 | CraftingPanel 单例，一次只开一个 |
| spec §3.1.F 的形状描述歧义 | 高 | 中 | 用 §5 表格的 ASCII pattern 作为唯一真实来源 |

---

## 12. 风险已知遗留

- 工具速度系数（×3 axe-on-log）通过 `_current_tool_speed` 实现，但 axe 砍 leaves/planks 速度=1.0 还是 ×3？**决定：仅 LOG ×3**，与 spec §3.1.G "砍其他无加成"一致。
- ItemDrop 摞在一起时的视觉抖动 → 忽略，P2 内仅功能正确。
