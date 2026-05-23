# 工具使用方法 & 全部贴图重画 设计稿

**日期**：2026-05-23
**范围**：泰拉瑞亚式工具手感（4 项）+ 7 个工具贴图重画 + 17 个方块贴图重画
**方案**：一波全部改（单 PR / 多 commit）

---

## 1. 目标

把工具从"左右朝向 + 固定角度挥砍"升级到泰拉瑞亚式"鼠标方向决定 + 跟着鼠标角度旋转 + 月牙拖尾"，同时把所有工具和方块贴图重画成 **RPG 金属闪闪风**，加深色彩层次与立体感。

非目标：
- 不改伤害数值、冷却时长、挖矿硬度（数值平衡保持）
- 不改工具种类（仍是剑/镐/斧 × 3 级）
- 不动方块行为（掉落物、碰撞、可挖性等不变）

---

## 2. A 部分：工具使用方法（4 项交互改动）

### A.1 挥剑方向跟随鼠标

**现状**：`player_action.gd:_swing_sword()` 用 `facing_dir()` 拿到 ±1，攻击中心点固定在玩家身前 ±SWORD_RANGE_PX×0.5、y=-8。

**改动**：
- 攻击中心点改为：从玩家中心指向鼠标方向，距离 `SWORD_RANGE_PX × 0.5`。
- 命中判定仍是圆形范围（半径 `SWORD_RANGE_PX × 0.7`）。
- `facing_dir()` 的左右概念保留（玩家精灵仍朝鼠标左/右翻面，但攻击方向更精细）。

**代码位置**：`scripts/player/player_action.gd` 第 394-423 行 `_swing_sword()`。

**伪代码**：
```gdscript
var player_pos: Vector2 = player.global_position
var mouse_pos: Vector2 = get_global_mouse_position()
var to_mouse: Vector2 = (mouse_pos - player_pos).normalized()
var center: Vector2 = player_pos + to_mouse * SWORD_RANGE_PX * 0.5
```

### A.2 按住左键持续使用

**现状**：挖矿（`_update_mining`）和挥剑（`_swing_sword`）**已经支持**按住 — 用的是 `Input.is_action_pressed("primary")`，不是 `just_pressed`。

**改动**：**无需改动**。已工作。

### A.3 月牙形挥击拖尾

**现状**：`_spawn_swing_arc()` 用 `Line2D` 画 3 个点的折线（⌒ 形状），淡出。

**改动**：
- 画法换成：弧形 Polygon2D，扇形填充 + 渐变（外缘亮白、内缘透明）。
- 弧线沿"挥击方向"展开，覆盖 ±50° 扇形。
- 半径 = `SWORD_RANGE_PX × 0.8`。
- 0.18s 内：先 0° → 完整 ±50°，再淡出。
- 颜色随等级：木剑 = 白色、石剑 = 浅青、（后续铁剑预留 = 金色）。

**实现思路**：
- 用 `Polygon2D` 顶点排成弧形（约 12 个点），每帧重算顶点完成"展开"动画，再 tween modulate.a → 0。
- 或更简单：一开始就画完整弧，只 tween modulate.a 从 1 → 0（先这样做最简，看效果再升级）。

**代码位置**：`scripts/player/player_action.gd:_spawn_swing_arc()`。

### A.4 工具图标跟着挥击角度旋转

**现状**：`held_item.gd:play_swing()` tween 在 ±75° 之间挥（基于 `_facing_right`）。

**改动**：
- 挥剑：起手角度 = 鼠标方向 -45°，结束角度 = 鼠标方向 +45°（沿鼠标方向展开 90° 挥击）。
- 挖矿/砍木：保持现在的 ±75° 动画（这是节奏性挥击，不是单次定向挥砍），但**朝向**改为玩家中心指向目标方块的方向。
- HeldItem 的 `position`（手部偏移点）保持现在的 `HAND_OFFSET_X/Y` 不变，仅 `rotation` 跟随鼠标。

**代码位置**：`scripts/player/held_item.gd:play_swing()`，需新增 `play_swing_directional(angle: float)` 或扩展现有方法。

**伪代码**：
```gdscript
func play_swing_directional(target_angle: float) -> void:
    var dir_sign: float = 1.0 if _facing_right else -1.0
    var start_a: float = target_angle - deg_to_rad(45.0) * dir_sign
    var end_a:   float = target_angle + deg_to_rad(45.0) * dir_sign
    rotation = start_a
    _tween = create_tween()
    _tween.tween_property(self, "rotation", end_a, SWING_DURATION)
```

---

## 3. B 部分：工具贴图重画（7 个工具）

### B.1 风格定义

**RPG 金属闪闪风** 5 条规则：
1. **斜柄 45°**：木柄从左下 (12,15) 到右上 (3,4) 大致 45° 斜走（剑已经是斜的，镐/斧改）。
2. **金属高光**：刃部/头部 3 层色（深 → 中 → 高光），高光集中在刃缘上沿 1 像素。
3. **暖木柄**：木柄 3 色（基色 + 暗纹 + 一道反光），不再是单色双层。
4. **黑色描边**：工具外轮廓加 1 像素深黑 (`#1a1410`)，让工具在任意背景上都立体。
5. **等级配色**（一眼能区分）：
   - 木级：刃 = 沙黄 (`#d4a058` / `#9d7138`) ， 现行色基本保留。
   - 石级：刃 = 冷灰 (`#a8a8b0` / `#5a5a64` / `#bdbdc8`)，比现行更冷一点。
   - 铁级：刃 = 钢蓝白 (`#d8e0e8` / `#7a8c9a` / `#aab4c0`)，最闪。

### B.2 7 个工具列表

| 工具 | 当前问题 | 重画要点 |
|---|---|---|
| `wood_sword` | 已是斜刀身，但调色少层次、护手简陋 | 加金属高光带、护手 3 色立体、剑柄反光纹 |
| `wood_pickaxe` | 柄是竖直 | 改 45° 斜柄、镐头 T 字 + 木契钉表现 |
| `wood_axe` | 柄是竖直 | 改 45° 斜柄、斧刃加月形 + 高光 |
| `stone_sword` | 同木剑 | 同上 + 石质冷灰、刃缘缺口表现 |
| `stone_pickaxe` | 柄竖直 | 同木镐 + 石头粗糙凿痕 |
| `stone_axe` | 柄竖直 + 头肿胀 | 同木斧 + 石质磨损边缘 |
| `iron_pickaxe` | 柄竖直 | 同木镐 + 钢蓝白闪光 + 铆钉 |

### B.3 16×16 像素布局基准（斜柄工具）

镐/斧的统一布局：
```
....HHHH........   ← 工具头部 (3-5 行)
...HHHHHH.......
....HHHH........
.....HH.........   ← 头柄接合
......h.........   ← 木柄起点 (右上)
......hH........
.....hH.........
.....hH.........
....hH..........
....hH..........
...hH...........
...hH...........
..KK............   ← 柄端 (左下)
................
```

剑保持现有对角线刀身（已经是泰拉瑞亚风），只加高光层次。

### B.4 调色板扩展

`items_art.gd` 顶部 `PALETTE` 加新颜色：
- `e` = 深钢蓝阴影 `Color8(40, 50, 65)`
- `E` = 中钢蓝 `Color8(95, 115, 135)`
- `F` = 钢蓝高光 `Color8(180, 200, 220)`
- `f` = 极亮闪光 `Color8(230, 240, 250)`
- `n` = 黑描边 `Color8(26, 20, 16)`

---

## 4. C 部分：方块贴图重画（17 个方块）

### C.1 风格定义

**层次立体风** 4 条规则：
1. **3-5 色分层**：每个方块至少 3 色（基色 / 高光 / 阴影 / 特征色），不要单色面。
2. **顶部更亮 + 底部更暗**：所有方块上 2 行偏亮、下 2 行偏暗，模拟环境光。
3. **细节斑点**：石头加细密杂色斑、泥土加石子、木板加木纹、矿石原石加颗粒高光。
4. **保留可识别剪影**：颜色加层次但整体还是"那个方块"，避免变得花。

### C.2 17 个方块清单（按改动力度分类）

**地表类（4 个）— 重点重画**：
- `GRASS` (草地)：顶部草尖 3 色（黄绿 / 中绿 / 深绿暗），泥土带 2 行带石子，整体偏暖
- `DIRT` (泥土)：基色 + 暗纹 + 3-4 颗小石子，顶部 1 行略亮
- `STONE` (石头)：深灰基 + 中灰斑 + 黑缝 + 高光点；整体冷色不刺眼
- `SAND` (沙子)：金黄基 + 浅黄高光 + 细密颗粒纹

**木头类（5 个）**：
- `LOG` (原木)：树皮纵纹 + 顶部年轮 1 行
- `PLANKS` (木板)：水平木纹 + 钉子点 + 板缝
- `LEAVES` (橡树叶)：3 层绿 + 叶脉细节
- `LEAVES_PINE` (松针)：深绿基 + 针状高光
- `LEAVES_AUTUMN` (秋叶)：红橙基 + 黄高光 + 棕梗

**矿石类（4 个）**：
- `BEDROCK` (基岩)：极深灰 + 黑裂纹 + 暗紫斑（特殊性）
- `DEEP_STONE` (深石)：暖深灰 + 细矿脉
- `COAL_ORE` (煤矿)：石底 + 黑色煤块斑（颗粒分明）
- `IRON_ORE` (铁矿)：石底 + 橙锈斑 + 金属高光

**家具/功能类（4 个）**：
- `WORKBENCH` (工作台)：木板顶 + 木腿 + 锯子/锤子细节剪影
- `DOOR` (门)：木板纹 + 把手金属点 + 横档
- `TORCH` (火把)：木棒 + 火焰核心黄 + 外焰橙红
- `SLIME_TORCH` (史莱姆灯)：木棒 + 史莱姆球身 + 内核高光

### C.3 现状评估

现有 `blocks_art.gd` **已经做得不错**（每块独立调色板、3-5 色），需要的是**细节升级**而不是推倒重画。所以这部分主要是：
- 调色板再加几个梯度（每块多 1-2 色）
- 16×16 像素图重排，强化上亮下暗
- 加细节斑点（不破坏剪影）

### C.4 工作量估计

- 工具贴图：7 张 16×16，每张需新画或大改 — ~7×20min
- 方块贴图：17 张 16×16，约一半（地表/矿石）需大改、另一半（家具/叶子）小改 — ~17×15min
- 总像素图工作量：~7.5 小时（AI 画图）

---

## 5. 文件改动清单

| 文件 | 改动 | 说明 |
|---|---|---|
| `scripts/player/player_action.gd` | 改 `_swing_sword()`、`_spawn_swing_arc()` | 鼠标方向 + 月牙拖尾 |
| `scripts/player/held_item.gd` | 加 `play_swing_directional(angle)` | 工具图标跟鼠标角度旋转 |
| `scripts/art/items_art.gd` | PALETTE 扩展 + 7 个工具像素图重画 | RPG 金属闪风 |
| `scripts/art/blocks_art.gd` | 17 个方块的 PALETTE + 像素图升级 | 层次立体风 |

不动的文件：
- `scripts/items/item_db.gd`（工具定义不变）
- `scripts/world/tile_data.gd`（方块行为不变）
- `scripts/player/player_inventory.gd`、`player_controller.gd`（无关）

---

## 6. 提交计划（一波全部改，分多个 commit 保持 history 清晰）

按子任务分 commit：
1. `feat(combat): 挥剑方向跟鼠标 + HeldItem 角度跟随`
2. `fx(combat): 月牙形挥击拖尾 (Polygon2D + 渐变)`
3. `art(tools): 7 个工具重画为 RPG 金属闪风 + 斜柄`
4. `art(blocks): 地表 4 方块层次升级 (草/土/石/沙)`
5. `art(blocks): 木头 5 方块层次升级 (原木/木板/3 种叶)`
6. `art(blocks): 矿石 4 方块层次升级 (基岩/深石/煤/铁)`
7. `art(blocks): 家具 4 方块层次升级 (工作台/门/2 种火把)`

每个 commit 跑一次启动测试（开个游戏看一眼，确认没崩）。

---

## 7. 测试计划

**手测**：
- 启动游戏 → 进入世界 → 左键扫一圈鼠标，看剑挥击方向是否跟随
- 按住左键挖石头，工具是否持续摆动、月牙是否每次出现
- 切到镐挖、切到斧砍、切到剑打史莱姆，3 种工具都正常
- 打开背包看 7 个工具的图标，确认风格统一
- 在地表/地下/沙漠/树林切几个场景，看方块新贴图

**单元测试**（GUT）：
- `test_player_action_combat.gd`：新增 `test_sword_swing_aims_at_mouse` — 注入 `aim_override` 测攻击中心点计算
- `test_held_item.gd`（如不存在则新建）：`test_swing_directional_rotates_to_angle`
- 像素图测试：不写（视觉东西测试意义低）

---

## 8. 风险

| 风险 | 应对 |
|---|---|
| 鼠标方向挥击导致玩家朝向翻转抖动 | `facing_dir()` 仍按 ±X 翻面，挥击方向独立计算 |
| 月牙 Polygon2D 性能（每帧重算顶点） | 一次性画完整弧、只 tween α，简化实现 |
| 17 个方块改完发现风格不喜欢 | 第一批（地表 4 块）改完先停下让用户看一眼 |
| RPG 金属闪风跟现有 UI 不搭 | 工具风格出来后跟 HUD 对比；不搭再调和 |

---

## 9. 退路 (rollback)

每个 commit 独立可 revert：
- 风格不喜欢 → revert 美术 commit，逻辑 commit 保留
- 月牙不好看 → revert fx commit，鼠标方向保留

---

## 10. 暂未决定的点

无。所有问题用户已用 AskUserQuestion 选定。
