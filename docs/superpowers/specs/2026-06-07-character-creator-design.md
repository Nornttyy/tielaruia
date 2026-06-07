# 捏人系统 + 角色存档 (Character Creator & Character Save) — 设计文档

- 日期: 2026-06-07
- 状态: 已与用户确认方案, 待写实现计划
- 一句话: 把「玩家」从世界存档里抽出来变成独立的**人物卡 (CharacterData)**, 加一个**捏人界面**让玩家自定义长相 (性别/发型/衣裤款式+颜色), 菜单流程改成**先选角色再选世界** —— **泰拉瑞亚式角色/世界分离, 角色带着背包装备血量跨世界**。

## 目标

- 玩家能创建多个角色, 每个角色有: 名字 + 长相 (性别/发型/衬衫款/裤子款/4 个颜色) + 背包 + 装备 + 血量 + 魔力。
- 同一个角色能进**任何世界**, 背包/装备/血量/魔力跟着角色走 (真泰拉瑞亚)。
- 菜单流程: `开始游戏 → 选角色 (列表 + 捏新角色) → 选世界 → 进游戏`。
- 捏人界面有**活的小人预览** (会呼吸/走动), 改任意选项小人立刻变。
- 老存档无痛迁移: 第一次更新后自动从最新世界存档里的玩家数据生成一张「默认角色」, 世界地形/箱子全不动。

## 非目标 (明确不做)

- **联机里同步外观**: v1 远程玩家 (`remote_player.gd`) 仍用默认长相; 外观联网同步留作后续。
- **配饰** (帽子/眼镜等): 用户已确认不做。
- 不改世界生成 / 水晶刷新规则 / 怪物 / 战斗。
- 不做「角色之间共享仓库」等额外系统 (YAGNI)。

## 背景 (现状)

- 玩家是**固定像素画**: `scripts/art/player_art.gd` 用一个 `PALETTE` 字典 (头发 `h/H`、皮肤 `s/k`、衬衫 `w/W`、裤子 `b/B`、靴 `o/O`、眼 `e`、嘴 `m`) + 一组 ascii 帧 (`_IDLE_A/_IDLE_B/_WALK_A/_WALK_C/_JUMP/_FALL/_HURT`) 通过 `PixelArt.build_sprite_frames()` 烤成一张 `SpriteFrames`。衬衫色和裤子色**烤死在 ascii 里**。
- 存档系统 `scripts/save/`:
  - `save_data.gd` (`class_name SaveData`, `CURRENT_VERSION=4`): 一个 Resource, **同时**装世界 (seed/name/difficulty/size/creative/spawn/bed_spawn/time/chunk_deltas/wall_deltas/entities/chest_contents/水晶刷新记录/pyramid·mineshaft chunk 列表) **和玩家** (player_position/player_hp/player_max_hp/player_mana/player_max_mana/armor_*/inventory_slots/hotbar_selection)。
  - `save_manager.gd` (autoload `SaveManager`): 多存档 `user://saves/{world_name}.tres`; `save(main)` 从 world+player 收集写盘; `list_saves()/load_save_by_name()/delete_save_by_name()`; 原子写 (.tmp.tres → rename) + 网页 `_flush_web_filesystem()`。有「玩家未就绪不写档」护栏 (防丢三件套, 见代码注释)。
- 菜单 `scripts/ui/main_menu.gd` + `scenes/.../MainMenu` 子面板:
  - `开始游戏` → `WorldSelectPanel` (存档列表, 每行 `[进入][删除]` + `创建新世界` + `返回`)。
  - `创建新世界` → `NewGamePanel` (名字/种子/难度/大小/模式 → `start_game.emit(opts)`)。
  - `进入` 存档 → `continue_game.emit(save_data)`。
  - `main.gd` 监听 `start_game` / `continue_game` 启动世界。
- `GameSettings.player_name`: 已有一个**全局**玩家名 (设置面板里, 联机 hello 用)。角色系统上线后, 进游戏时用**当前角色的名字**覆盖它。

## 设计

五个组件: A 人物卡数据 / B 角色管理器 / C 分层可定制美术 / D 捏人 + 选角色 UI / E 存档拆分 + 迁移。

### A. 人物卡数据 `CharacterData` (新 Resource)

新建 `scripts/save/character_data.gd`:

```gdscript
class_name CharacterData extends Resource

const CURRENT_VERSION := 1
@export var version: int = CURRENT_VERSION
@export var character_name: String = ""

# 长相 (捏人结果). 颜色存 Color; 款式/性别存 int 枚举.
@export var gender: int = 0            # 0=男 1=女
@export var hair_style: int = 0        # 0..3
@export var shirt_style: int = 0       # 0..7 (含 2 款泳衣上装, 见 C)
@export var pants_style: int = 0       # 0..8 (含 2 款泳衣下装, 见 C)
@export var cape_style: int = 0        # 0=无 1=短披风 2=长披风
@export var skin_color: Color = Color8(255, 218, 185)
@export var hair_color: Color = Color8(121, 85, 72)
@export var shirt_color: Color = Color8(229, 57, 53)
@export var pants_color: Color = Color8(38, 70, 130)
@export var cape_color: Color = Color8(150, 40, 50)   # cape_style=0 时忽略

# 跟着角色走的玩家状态 (从 SaveData 搬过来)
@export var player_hp: float = 100.0
@export var player_max_hp: int = 100
@export var player_mana: int = 100
@export var player_max_mana: int = 100
@export var armor_helmet_id: String = ""
@export var armor_chest_id: String = ""
@export var armor_pants_id: String = ""
@export var inventory_slots: Array = []     # 36 槽, 同 SaveData 结构 {item_id,count}|null
@export var hotbar_selection: int = 0
```

- 颜色阴影自动算: 阴影色 = 主色 `.darkened(0.28)` (头发/衬衫/裤子各自的 `H/W/B`)。皮肤阴影 = `skin_color.darkened(0.18)`。**不单独存阴影**, 渲染时算。
- 提供 `appearance_dict() -> Dictionary` 帮助方法, 返回 `{gender, hair_style, shirt_style, pants_style, cape_style, skin_color, hair_color, shirt_color, pants_color, cape_color}`, 给 `PlayerArt.build_sprite_frames()` 用 (避免渲染层依赖整个 CharacterData)。

### B. 角色管理器 `CharacterManager` (新 autoload)

新建 `scripts/save/character_manager.gd`, 注册为 autoload `CharacterManager` (在 `project.godot`)。跟 `SaveManager` 平行, 管 `user://characters/{name}.tres`:

```
const CHARS_DIR := "user://characters/"
var current: CharacterData = null            # 当前选中, 进世界时 main 读它

func _ready()                                # 建目录 + 迁移老存档 (见 E)
func list_characters() -> Array              # [{name, data, path}], 同 SaveManager.list_saves 结构
func save_character(c: CharacterData) -> bool # 原子写 user://characters/{清洗后名}.tres + 网页 flush
func load_character_by_name(n: String) -> CharacterData
func delete_character_by_name(n: String) -> void
func has_any() -> bool
```

- 文件名清洗 / 防路径注入 / 原子写 (.tmp.tres → rename) / `_flush_web_filesystem()`: **照抄 `save_manager.gd` 现成实现** (DRY 不了就照同款写, 测试覆盖)。
- `current` 是全局选中态; `main.gd` 进世界时从 `current` 读玩家状态, autosave/退出时把玩家状态写回 `current` 对应文件。

### C. 分层可定制美术 (改 `player_art.gd`)

把「烤死一套」改成「**按长相拼 4 层再烤**」。`player_art.gd` 重构成:

```gdscript
# 旧: build_sprite_frames() 无参, 用常量 PALETTE + 固定 ascii
# 新: build_sprite_frames(appearance: Dictionary) -> SpriteFrames
#   appearance = {gender, hair_style, shirt_style, pants_style,
#                 skin_color, hair_color, shirt_color, pants_color}
```

**分层结构** (每个动画帧由 5 层 ascii 叠出来, 后画的盖前画的; 第 0 层在最底/最后面):
0. **披风层 (CAPE)** — 画在**最底 (身体后面)**: 按 `cape_style` 选 (0 无 / 1 短披风 / 2 长披风)。`0` 时整层透明。颜色 `cape_color`。
1. **身体层 (BODY)**: 按 `gender` 选模板组。只画**皮肤 + 靴**, 躯干/腿留空 (`.`)。男/女**各一套完整全帧** (idle_a/idle_b/walk_a/walk_c/jump/fall/hurt; walk_b=idle_a 复用)。
   - **男女身材比例不同 (用户要大区别)**: 男版 = 现状小人 (肩宽、躯干直); 女版 = **重画身材比例** —— 肩略窄、腰更收、腿型略不同, 脸加睫毛/大眼一眼区分。
   - **关键约束 (省美术 + 保对齐)**: 两套身体**同画布 (12×24)**, 且**头部行段、手臂行、腿/靴锚点行保持一致** —— 这样头发层和大多数衣服层在男女上都能用同一锚点对齐, 不必每件衣服画两遍。只有**躯干/腿宽窄**男女不同。
2. **裤子层 (PANTS)**: 按 `pants_style` 选。覆盖腿部区域, 跟随每帧腿的姿态 (走路帧腿分开)。
3. **衬衫层 (SHIRT)**: 按 `shirt_style` 选。覆盖躯干区域。
4. **头发层 (HAIR)**: 按 `hair_style` 选 (0 短发 / 1 长发 / 2 马尾 / 3 呆毛)。覆盖头顶, 跟随每帧头的位置 (idle_b 整体下沉 1px)。

**完整款式目录** (实现可分批上, 见「实现顺序」):

- **衬衫款 `shirt_style` (8)**: 0 T恤 / 1 背带 / 2 连帽卫衣 / 3 海魂衫(蓝白条纹) / 4 法师袍(上) / 5 骑士胸甲 / 6 泳衣·背心式 / 7 泳衣·吊带式(女=比基尼上衣, 男=吊带)。
- **裤子款 `pants_style` (9)**: 0 长裤 / 1 短裤 / 2 裙子 / 3 工装裤 / 4 公主裙(华丽蓬蓬裙) / 5 法师袍(下摆) / 6 骑士护腿 / 7 泳裤 / 8 泳裙(沙滩裤)。
- **披风款 `cape_style` (3)**: 0 无 / 1 短披风 / 2 长披风。
- **发型 `hair_style` (4)**: 0 短发 / 1 长发 / 2 马尾 / 3 呆毛。
- **泳衣** = 泳衣上装 (shirt 6/7) + 泳衣下装 (pants 7/8) 自由搭, 共 2×2=4 种泳衣组合。
- **主题套装**: 法师袍 = shirt 4 + pants 5 (可再配长披风); 骑士盔甲 = shirt 5 + pants 6。捏人 UI 各层独立选, 不强制成套。
- **衣服贴合身材**: 因男女躯干/腿宽窄不同, 衣服层覆盖躯干/腿的格子按**男女各画一版填充** (上下边界锚点一致, 只是宽窄跟随身体)。即每个衣服款式有 male-fit / female-fit 两份 ascii (大多只差 1-2 列), 由 `gender` 选。这是「大区别」的美术代价, 已计入分批计划。

- 拼装: 对每帧, 先铺 `CAPE`, 再 `BODY[gender]` 起底, 依次把 PANTS/SHIRT/HAIR 的非透明格覆盖上去, 得到一张合并 ascii, 再喂 `PixelArt.build_sprite_frames`。
- **调色板**: 拼装时按 appearance 的颜色生成 per-character `PALETTE` (skin/hair/shirt/pants/cape 主色+算出的阴影色)。靴、眼、嘴用固定色。
- **颜色数量** (可后续扩): 皮肤色 5、头发色 6、衬衫色 6、裤子色 6、披风色 6。
- **默认值** = 现状那个小人 (男/短发/T恤/长裤/无披风/暖棕发/红衫/蓝裤), 保证不捏也跟以前一样。
- 玩家场景挂的 `AnimatedSprite2D` 不变, 只是 `sprite_frames` 来自 `build_sprite_frames(current.appearance_dict())`。

### D. 捏人 + 选角色 UI (改 `main_menu.gd` + MainMenu 场景)

**新增两个面板** (照 `WorldSelectPanel` / `NewGamePanel` 的写法手写进 MainMenu.tscn):

1. **CharacterSelectPanel** (选角色): 标题 + 角色列表 (每行 `[角色名]` + `[选择]` + `[删除]`) + `捏个新角色` + `返回`。
   - `开始游戏` 按钮改成先开这个 (不再直接开 WorldSelectPanel)。
   - 点 `[选择]` → `CharacterManager.current = 该角色` → 开 `WorldSelectPanel`。
   - 点 `捏个新角色` → 开 CharacterCreatorPanel。
   - 列表为空时也显示 `捏个新角色` (引导先建角色)。

2. **CharacterCreatorPanel** (捏人): 左侧**活预览** (一个 `AnimatedSprite2D` 放大, 播 idle/walk 切换) + 右侧选项:
   - 名字 `LineEdit`。
   - 性别: 2 个互斥 toggle (照 NewGamePanel 难度 radio 写法)。
   - 发型 / 衬衫款 / 裤子款 / 披风款: 每个一行 `◀ 名称 ▶` 或一排小按钮切换 (名称走 `Locale.t()`)。
   - 皮肤/头发/衬衫/裤子/披风色: 每个一行**色块按钮**, 点哪个选哪个 (高亮选中)。披风款=无 时披风色行可禁用/灰掉。
   - 任意改动 → 重建预览 `SpriteFrames` (节流: 同步重建即可, 帧数少不卡)。
   - `保存` (名字空或重名给提示) → `CharacterManager.save_character()` → 回 CharacterSelectPanel; `取消` → 回 CharacterSelectPanel。
   - i18n: 所有静态文字走 `Locale.t()` (照现有面板), 新 key 加进 4 语言表; **款式/颜色名也要中文** (照 `_ZH_NAMES` 习惯)。

**流程图**:
```
开始游戏 → CharacterSelectPanel
            ├─ 捏个新角色 → CharacterCreatorPanel → 保存 → 回 CharacterSelectPanel
            ├─ [选择] 角色 → current=角色 → WorldSelectPanel → (现有流程) 进游戏
            └─ 返回 → 主菜单
```

### E. 存档拆分 + 迁移 (改 `save_data.gd` + `save_manager.gd` + `main.gd`)

**拆分原则**: 世界存档不再是玩家状态的来源, 玩家状态来自 `CharacterManager.current`。

- `save_data.gd` 升 `CURRENT_VERSION = 5`。玩家字段 (player_hp/max_hp/mana/max_mana/armor_*/inventory_slots/hotbar_selection/player_position) **保留定义** (不删, 防老 .tres 读不了), 但标注 deprecated, **新存档不再写有效值** (写默认/留空), load 也不再用它们还原玩家。
- `save_manager.save(main)`: 只收集**世界**部分。玩家部分改由 main 在同一拍写进 `CharacterManager.current` 文件 (见下)。
- `main.gd` 启动世界 (continue/start) 时:
  1. 世界地形/箱子/怪 从 world `SaveData` 还原 (现有逻辑)。
  2. 玩家背包/hp/mana/盔甲/长相 从 `CharacterManager.current` 还原 (新增)。出生位置用世界的 `bed_spawn_point`/`spawn_point` (不再用存档里的 player_position —— 进世界回出生点, 符合泰拉瑞亚)。
  3. `GameSettings.player_name = current.character_name` (让联机/UI 用角色名)。
- **保存玩家状态**: 给 `CharacterManager` 加 `save_current_from_player(player) -> bool`, 从 player 节点收集 hp/mana/inventory/armor/hotbar 写进 `current` 并落盘。autosave 与退出时, 在调 `SaveManager.save(main)` (存世界) 之后也调 `CharacterManager.save_current_from_player(player)` (存角色)。**复用现有「玩家未就绪不写档」护栏**, 防丢三件套。
- **迁移** (`CharacterManager._ready` 里, 仅当 `user://characters/` 为空且存在世界存档时跑一次):
  1. 取 `SaveManager.list_saves()` 第一个 (最新) 世界存档。
  2. 用它的玩家字段 (inventory_slots/player_hp/player_max_hp/mana/armor_*/hotbar_selection) + **默认长相** 造一张 `CharacterData`, 名字取 `GameSettings.player_name` (空则「默认角色」)。
  3. 写盘。世界存档**原样不动** (地形/箱子保留; 里头的玩家字段从此被忽略)。
- **死亡掉落** (Minecraft 风, 见 CLAUDE.md): 物品本就在玩家背包里, 改成人物卡来源后掉落逻辑不变 —— 死亡仍在死亡点掉物品、回世界出生点。回归测试确认。

## 不变项 (回归保障)

- 世界生成 / 水晶刷新世界上限 / 怪 / 战斗 / 箱子 / 墙 / 小地图 / 钓鱼 / 料理 —— 全不动。
- 世界存档的地形/箱子/实体格式不变 (只是玩家字段作废)。
- 不捏人 (老玩家迁移出的默认角色) 长相 = 现状小人, 像素逐格一致。
- 死亡复活 = Minecraft 风 (回出生点 + 死亡点掉物品), 不变。

## 测试策略

无 GUI 验收, 能抽纯函数的都写 GUT 单元测试; 端到端走 integration。

**单元 (`tests/unit/`)**:
- `test_character_data.gd`: `CharacterData` 存读往返 (写 .tres → 读回, 所有字段相等); 默认值正确。
- `test_character_manager.gd`: save/list/load_by_name/delete 往返; 重名覆盖; 非法名拒绝 (路径注入); 空目录 `has_any()=false`。用临时 `user://` 路径或 mock。
- `test_player_art_appearance.gd`: `build_sprite_frames(appearance)` 给定颜色 → 取某已知坐标像素 (如衬衫格) 断言等于所选 shirt_color; 换 hair_style 头顶像素变化; 默认 appearance 画出的 idle 第 0 帧与「现状基准」逐格一致 (锁住「不捏=老样子」)。
- `test_save_migration.gd`: 构造一个含玩家数据的老 world `SaveData` + 空 characters 目录 → 跑迁移 → 断言生成了一张默认角色且背包/hp 等于老存档玩家数据。

**集成 (`tests/integration/`)**:
- `test_character_world_split.gd`: 选一个角色 (背包放几样东西) → 进世界 A → 改地形 → 存 → 退 → 进世界 B → 断言背包还是角色的 (跟着人走), 世界 B 地形是 B 的; 回世界 A 地形改动还在。
- 回归: 跑现有 `test_*save*` / 死亡掉落相关 integration, 确认世界存读 + 死亡掉落不回归。

## 文件清单

**新增**:
- `scripts/save/character_data.gd` (`class_name CharacterData`)
- `scripts/save/character_manager.gd` (autoload `CharacterManager`)
- `tests/unit/test_character_data.gd`
- `tests/unit/test_character_manager.gd`
- `tests/unit/test_player_art_appearance.gd`
- `tests/unit/test_save_migration.gd`
- `tests/integration/test_character_world_split.gd`

**修改**:
- `scripts/art/player_art.gd` — 重构成分层 `build_sprite_frames(appearance)` (5 层: 披风/身体/裤子/衬衫/头发) + 男/女身体、4 发型、8 衬衫款、9 裤子款、3 披风款 ascii 模板
- `project.godot` — 注册 autoload `CharacterManager` (改 autoload 后需 `./run.sh --rebuild`)
- `scripts/save/save_data.gd` — `CURRENT_VERSION→5`, 玩家字段标 deprecated (保留定义)
- `scripts/save/save_manager.gd` — `save()` 只收集世界部分 (玩家部分不再写有效值)
- `scripts/ui/main_menu.gd` — `开始游戏` 改开 CharacterSelectPanel; 加选角色 + 捏人面板逻辑
- `scenes/.../MainMenu.tscn` (主菜单场景) — 手写加 CharacterSelectPanel + CharacterCreatorPanel 两个面板节点
- `scripts/main.gd` — 进世界时从 `CharacterManager.current` 还原玩家 + 出生用世界 spawn; autosave/退出时存角色
- 玩家创建处 (player 场景实例化时) — `AnimatedSprite2D.sprite_frames = PlayerArt.build_sprite_frames(current.appearance_dict())`
- i18n 语言表 (`scripts/autoload/locale.gd` 或 4 语言资源) — 加捏人/选角色 UI 文字 key

## 风险

- **美术量大** (服装多 + 男女身材不同后翻倍): 男+女身体各 7 帧 + 4 发型 + (8 衬衫款 + 9 裤子款) **× 男女 fit** + 3 披风款, 每个跨帧对齐。控制法: **分批上** (见实现顺序 —— 先框架+男版默认, 再女身体, 再日常款, 再主题套装+披风), 每批能独立跑测试上线; 走路帧腿/靴位置抽成共享坐标常量避免每帧手算; 男女身体共用头/臂/腿锚点行, 让头发+多数衣服只在宽窄上分 male/female-fit (大多差 1-2 列), 不全重画; 款式美术加进来不改框架代码 (纯加 ascii 模板 + 1 个 case)。
- **存档迁移丢数据**: 迁移只读不删世界存档; 默认角色取最新存档玩家数据; 写测试锁住。万一多个老世界各有不同背包, 只迁最新那个 (其余世界背包字段被忽略) —— spec 已说明, 属预期。
- **autosave 时序 (历史踩过)**: 玩家未就绪不写档的护栏必须同样用在存角色上, 否则重演「丢三件套」。
- **并发 WIP**: 仓库长期有别的 session 在改 `player_art.gd` / 存档 / 菜单。每步实现前 `git status`, 精确 `git add`, 不卷入无关 WIP。

## 实现顺序建议

1. A `CharacterData` (含 cape 字段) + 单测 (能独立存读)。
2. B `CharacterManager` autoload + 单测 (`--rebuild` 建索引)。
3. C `player_art.gd` 分层重构 —— **分批**:
   - C1 5 层框架 + 男身体 + 默认款 (短发/T恤/长裤/无披风) + 逐格基准测试 (锁「不捏=老样子」)。
   - C2 女身体 (重画身材比例) + 4 发型 + 颜色替换跑通; 默认款做出女版 fit。
   - C3 日常款 (背带/连帽/海魂衫 · 短裤/裙子/工装裤), 每款男女 fit 各一版。
   - C4 泳衣 (2 上装 + 2 下装) + 披风层 (短/长披风)。
   - C5 主题套装 (法师袍 上+下 · 骑士胸甲+护腿 · 公主裙)。
   每批加完跑一次像素断言测试。
4. E 存档拆分 + 迁移 + main 接线 + 单测/集成 (角色跟人走)。
5. D 捏人 + 选角色 UI (最后接, 因为它依赖 A/B/C 都就位; 含披风款/披风色选择行)。
