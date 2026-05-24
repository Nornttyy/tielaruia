# 方块自动连接 (Block Autotiling) 设计

> 让放置的方块根据邻居自动选择视觉变体，呈现泰拉瑞亚 (Terraria) 风格的「圆角、内凹、孤立块」连接外观。

## 目标

当前每种方块只有 1 张 16×16 贴图，无论是孤立单块还是大片地形，看上去都是「一格格贴图拼接」。本设计将每种适合的方块扩展为 **47 种变体**，根据 8 个邻居的「连接性」自动选择对应变体，呈现：

- 大片地形 → 中间无缝、外缘有描边
- 孤立块 → 四角圆，独立感强
- 凹陷处 → 内凹角有暗色细节
- 表面 → 顶部有高光（光从上方来的视觉暗示）

## 范围

### 参与自动连接的方块（15 种）

| 族 | tile_id | 共享边缘形状 |
|---|---|---|
| 土族 | GRASS, DIRT, SAND | ✅ 同族共形状 |
| 石族 | STONE, DEEP_STONE, BEDROCK, COAL_ORE, IRON_ORE | ✅ 同族共形状 |
| 木族 | PLANKS | （单方块） |
| 叶族 | LEAVES, LEAVES_PINE, LEAVES_AUTUMN | ✅ 同族共形状 |
| 墙族 | GRASS_WALL, DIRT_WALL, STONE_WALL | ✅ 同族共形状 |

### 不参与（保持单图）

WORKBENCH, DOOR, TORCH, SLIME_TORCH, LOG, AIR

LOG 是树干竖条，47 变体会怪异（树干通常是细窄竖列）；其他都是单格家具/装饰。

## 连接规则 (Connectivity)

**核心规则**：当且仅当邻居"与我同一连接族"时，二者之间无黑边过渡，视觉上视为连成一片。

| 连接族 | 包含的 tile_id | 实际效果 |
|---|---|---|
| 实心连接族 | 所有 `is_solid()==true` 的方块 (GRASS/DIRT/SAND/STONE/DEEP_STONE/BEDROCK/COAL_ORE/IRON_ORE/PLANKS) | 任意两个实心块相邻 → 无黑边 |
| 叶橡木 | LEAVES | LEAVES 旁边的 LEAVES_PINE 会被视为「外人」 |
| 叶松针 | LEAVES_PINE | 同上 |
| 叶秋叶 | LEAVES_AUTUMN | 同上 |
| 墙草 | GRASS_WALL | 不同种墙之间有边界 |
| 墙土 | DIRT_WALL | |
| 墙石 | STONE_WALL | |

> 注意：**「连接族」决定有无黑边**，「边缘族」决定**黑边长什么样**。两者不同。
> 例：草和石头相邻 → 同属实心连接族 → 无黑边；
> 但草方块的「向上外边缘」（朝空气那一面）画成土族风格的边，而石头方块的对应外边缘画成石族风格的边。

## 47 变体方案

### Blob 算法 (8 邻居 → 47 唯一变体)

参考泰拉瑞亚和经典 Wang-Blob 切片：根据「4 个角各看 3 个邻居」的状态压缩到 47 个唯一组合。Godot 4 的 TileSet terrain 「Match Corners and Sides」模式即此。

但本项目**不使用 Godot terrain**，原因：

1. 「实心连接族」横跨 9 个 tile_id，Godot terrain 是按 tile-set source 划分的，跨 source 不方便
2. 自己写 bitmask 查表更简单，~50 行代码
3. 与现有 `chunk.gd` / `chunk_manager.gd` 集成更直接

### 算法实现

```
对每个 tile (x, y) 渲染时：
  1. 读取 8 个邻居各自的 tile_id
  2. 计算邻居 mask: 8 bit (上左, 上, 上右, 左, 右, 下左, 下, 下右)
     - bit 设为 1 ⟺ 邻居与我同一「连接族」
  3. 应用 Wang-Blob 角折叠：4 个角各自只看「该角的 3 个邻居 (两边 + 对角)」
     - 对角生效仅当两条边都在
     - 折叠后 4 个角各有 5 种状态 → 5^4 = 625 但只有 47 个唯一图案
  4. mask → atlas_coord 查 47 项查表
  5. set_cell(layer, cell, source_id, atlas_coord)
```

查表是静态常量数组 `BLOB_LOOKUP[256]`（256 = 8 bit 邻居 mask 全空间），映射到 47 个 atlas 坐标之一。预计算后零成本。

### Atlas 布局

每方块 1 个 `TileSetAtlasSource`，atlas 内部排成 8×6 = 48 格（最后一格留空），存放 47 变体。

```
atlas (128×96 像素 = 8×6 格 × 16px):
┌──┬──┬──┬──┬──┬──┬──┬──┐
│ 0│ 1│ 2│ 3│ 4│ 5│ 6│ 7│
├──┼──┼──┼──┼──┼──┼──┼──┤
│ 8│ 9│10│11│12│13│14│15│
├──┼──┼──┼──┼──┼──┼──┼──┤
│16│17│18│19│20│21│22│23│
├──┼──┼──┼──┼──┼──┼──┼──┤
│24│25│26│27│28│29│30│31│
├──┼──┼──┼──┼──┼──┼──┼──┤
│32│33│34│35│36│37│38│39│
├──┼──┼──┼──┼──┼──┼──┼──┤
│40│41│42│43│44│45│46│  │
└──┴──┴──┴──┴──┴──┴──┴──┘
```

47 个 atlas 坐标与「邻居 mask 折叠值」的对应通过一份**共享常量表**实现（一次定义，所有方块复用查表）。

## 手画边缘模板系统

### 模板格式

每个边缘族（5 个）手画 **47 张 16×16 ASCII 网格**，存放在 `scripts/art/edge_templates.gd`（新文件）。

每张模板格子使用语义化字符（不是颜色），渲染时按方块自身调色板替换：

```
.  = 透明（露出下面的内部纹理）
o  = 外描边色 (outline, 最暗)
e  = 边缘暗影 (edge shadow, 比基底暗)
h  = 边缘高光 (edge highlight, 朝光面)
H  = 强高光 (顶部最亮)
```

举例：「上边沿开口、其他三边封闭」的变体（土族）可能长这样：

```
ooooooooooooooo.    ← 顶边: 朝空 → 高光 + 外描边
HHHHHHHHHHHHHHHH    ← 顶边亮 (光从上方)
.eeeeeeeeeeeeee.    ← 第 2 行: 朝下渐淡
................    ← 内部: 透明, 显示原图
... (中间 12 行透明) ...
................
.eeeeeeeeeeeeee.    ← 倒数第 2 行
oooooooooooooooo    ← 底边: 朝下封闭
```

### 5 族边缘风格区分

各族的边缘模板手画时应体现"材质感"差异：

- **土族**: 边缘碎、不齐, 有零星小颗粒掉落感, 顶部高光暖黄
- **石族**: 边缘硬、平整, 圆角更小, 顶部高光冷一点
- **木族**: 边缘有木纹路径, 外描边带木色
- **叶族**: 边缘呈簇状凹凸, 透明像素较多, 表现"叶子轮廓不规则"
- **墙族**: 边缘平淡 + 略凹陷, 表现"远在背后"

### 调色板扩展

每方块的调色板字典 (`_P_GRASS` 等) 新增 4 个语义槽位：

```gdscript
const _P_GRASS := {
    # ... 现有 ...
    "_o": Color8(...),  # outline (外描边)
    "_e": Color8(...),  # edge shadow
    "_h": Color8(...),  # edge highlight
    "_H": Color8(...),  # strong highlight (顶部)
}
```

下划线前缀以避免和现有图案字符冲突。

### 合成最终图

```gdscript
# 伪代码
func build_variant(tile_id, mask_index):
    var base_pattern = _PATTERN_MAP[tile_id][0]  # 现有 16×16
    var palette      = _PATTERN_MAP[tile_id][1]
    var edge_family  = FAMILY_OF[tile_id]        # "soil" / "rock" / ...
    var edge_template = EDGE_TEMPLATES[edge_family][mask_index]  # 16×16

    var img = Image.create(16, 16, ...)
    for y in 16:
        for x in 16:
            var edge_char = edge_template[y][x]
            if edge_char == ".":
                # 显示内部纹理
                img.set_pixel(x, y, palette[base_pattern[y][x]])
            else:
                # 显示边缘
                img.set_pixel(x, y, palette["_" + edge_char])
    return img
```

## 代码改动总览

### 新文件

- `scripts/art/edge_templates.gd` — 5 族 × 47 边缘模板 + 边缘族查表 `FAMILY_OF[tile_id]`
- `scripts/world/blob_lookup.gd` — 256 → 47 邻居 mask 查表 + connectivity-group 判定

### 修改文件

- `scripts/art/blocks_art.gd`
  - 每方块调色板新增 `_o/_e/_h/_H` 4 个槽位
  - 新增 `build_atlas(tile_id) -> ImageTexture`：生成 128×96 atlas
  - 保留 `get_texture(tile_id)` 用于 UI 图标（继续返回单图）

- `scripts/autoload/art_cache.gd`
  - `block_textures[tile_id]` 由单图 `ImageTexture` 改为 atlas `ImageTexture`
  - 新增 `block_icons[tile_id]` 缓存：单格 16×16 用于物品栏图标，取 mask=255（4 邻居全实心+4 角全实心）的"完全包围"变体合成图

- `scripts/world/tileset_builder.gd`
  - 每个 source 的 `texture_region_size = Vector2i(16, 16)` 保持
  - 每个 source 调用 `create_tile()` 创建 47 个 atlas cell, 不再只 1 个
  - 物理碰撞 polygon 给每个 atlas cell 都加（实心方块所有变体都要能挡）

- `scripts/world/chunk_manager.gd`（或现 chunk render 入口）
  - `set_cell(layer, cell, source_id, Vector2i.ZERO)` 改为
    `set_cell(layer, cell, source_id, blob_lookup(connectivity_mask(world_x, world_y)))`
  - 放置/破坏方块后，**重算该方块和 8 个邻居共 9 格的 atlas_coord**（跨 chunk 需通过 chunk_manager 访问邻居 chunk）
  - **前景层和背景墙层各自独立跑一遍 connectivity_mask**：tiles 数组查 tile 邻居，walls 数组查 wall 邻居，互不干扰

### 跨 chunk 邻居查询

方块在 chunk 边缘时，需要查邻接 chunk 的方块。新增 `chunk_manager.get_tile_world(world_x, y) -> int`，内部按 `chunk_x_of` 路由到对应 chunk。若邻接 chunk 未加载，按 AIR 处理（边缘瞬时显示外描边，加载后下次 redraw 自然修正）。

## 性能考虑

- **预生成 atlas**：游戏启动时一次性合成 15 个 128×96 atlas（≈ 180 KB 总像素，可忽略）
- **查表零成本**：邻居 mask → atlas_coord 是数组下标
- **每次方块变更只重绘 9 格**：可接受
- **每次 chunk 加载初次绘制**：每格 1 次 mask 计算 + 查表，对 64×n 的 chunk 不到 1 ms

## 保存/加载兼容

存档只存 `tile_id`，不存 atlas_coord（atlas_coord 完全由邻居推导）。**存档格式无变化**。加载时按现有流程把 tile 写入 chunk，然后 chunk 第一次渲染会算出所有变体。

## 测试策略

- **单元测试** (`test/test_blob_lookup.gd`): 256 个 mask 输入 → atlas_coord 输出，验证查表正确
- **单元测试** (`test/test_connectivity_groups.gd`): 各 tile_id 对组合的 `is_connected_for_visual()` 真值表
- **集成测试**: 在 4×4 网格放置不同 tile_id 组合，断言每格的 atlas_coord 符合预期
- **手动视觉验证**: 启动游戏，截图比对：
  - 单块孤立 GRASS (应见 4 圆角)
  - 一行 GRASS (应见左右无缝)
  - 草+土相邻 (应无黑边过渡)
  - 草+石相邻 (应无黑边过渡，但边缘风格各自不同)
  - 草+叶相邻 (草+叶不同族，叶要画自己的外边)

## 不在本设计范围

- LOG 的连接 (树干结构特殊，单列竖条不适合 blob)
- 火把/工作台/门 (装饰单件，不需要)
- 不同族之间的「平滑过渡贴图」（如草→石 之间专门画的过渡块）—— 现版本只用「边缘有无」区分
- 平台 (platform) 类方块 (M2+ 才有)
- 流体 (水/熔岩) 的连接 (M3+)

## 实施分期

| 阶段 | 内容 | 预估 |
|---|---|---|
| P1 | `blob_lookup.gd` + 单元测试 (256→47 查表) | 0.5 天 |
| P2 | 调色板扩展 4 槽位 + `edge_templates.gd` 框架 + **石族** 47 手画模板 | 1 天 |
| P3 | `blocks_art.build_atlas()` + `tileset_builder` 多 cell 改造 + 渲染管线接通 + 用石族跑通端到端 | 1 天 |
|    | （此阶段其他族 tile 暂无模板 → fallback：所有 47 atlas cell 都填同一张当前单图。看起来和现在一样，不会崩） | |
| P4 | **土族** 47 手画模板 | 0.5-1 天 |
| P5 | **叶族** 47 手画模板 | 0.5-1 天 |
| P6 | **墙族** + **木族** 47 手画模板 | 0.5 天 |
| P7 | 视觉验证 + 调色调边缘 + 跨 chunk 边界 bug 修 | 0.5 天 |
| **总计** | | **4-5 天** |

P3 跑通后即可看到效果（虽然只有石族），之后每加一族就有立即可见的进展。

## 风险与已知问题

1. **手画 47 模板的"内凹角"**：内凹角是 4 种角状态里最复杂的（一个角，3 邻居都在但对角缺）。手画时需要参考 Terraria 截图，否则容易画歪。建议先在纸上画 47 个示意图，确认形状后再写 ASCII。
2. **跨 chunk 邻居延迟**：方块在 chunk 边缘加载时，邻居 chunk 可能还没加载，会瞬时显示「孤立块」状态。等邻居加载完成后下次 redraw 即修正。如果视觉上明显，需在 chunk 加载完成后主动 redraw 边界 1 列。
3. **UI 图标**：物品栏里方块图标统一用 mask=255（全邻居）的"完全包围"变体，看上去最像"地形里的它"。

## 公开问题（需用户确认）

无 — 设计已闭合。
