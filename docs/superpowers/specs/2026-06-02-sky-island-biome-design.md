# 空岛群系（Sky Island Biome）设计

- 日期：2026-06-02
- 状态：已确认，待写实现计划
- 里程碑：M2+（超出 Demo 范围，用户主动要求）

## 一句话

在天空层放几块飘着的草地浮岛，岛上有树、小水池、装好东西的大宝箱；附近有会飞的新怪「哈比鸟」掉羽毛；用羽毛+云块能合成「云靴」二段跳。整体分 3 步做，每步独立可玩、独立测试。

## 背景 / 现状

- 世界生成入口：`scripts/world/world_generator.gd` 的 `generate_chunk()`，地表 5 群系（forest/desert/snow/jungle/swamp）在固定槽位，地狱在最底。
- 世界尺寸：`WORLD_HEIGHT = 256`，`CHUNK_WIDTH = 64`，地表 surf ≈ 115。**天空层 = y < 115**，空岛放在 y ≈ 25–45。
- 已有可复用模板：
  - **金字塔** `_place_pyramid_chunk` / `_pyramid_chunks(world_seed)`：选 chunk（按世界大小缩放数量）→ 在 chunk 中部盖结构 → 记 `treasure_spots`（宝箱战利品）→ 记 `mummy_spawn_spots`（怪物生成点，`chunk_manager` 加载时召唤）。空岛**照抄这套**。
  - **飞行怪** `scripts/entities/demon_eye.gd`（160 行）、`hell_wasp.gd`（174 行）：已有飞行 AI、朝玩家移动、不与玩家碰撞。哈比鸟**照抄**。
  - **绿洲水池** `_fill_water_pools_chunk` 里的碗状填水逻辑：岛上小水池复用思路。
- 世界大小数量接口：`GameSettings.pyramid_count_range()`（小 `[1,1]` / 中 `[2,3]` / 大 `[3,5]`）。空岛新增一个 `skyisland_count_range()` 同款。
- 新 tile 登记三处缺一不可：①`scripts/world/tile_data.gd` 加常量+属性 ②`scripts/world/tileset_builder.gd` 的 `tile_ids` 数组加进去（漏了不显示也不报错）③`scripts/art/` 程序绘制贴图。
- 新 item 必须同步：`scripts/items/item_db.gd` 的 `_DEFS` + `scripts/ui/crafting_panel.gd` 的 `_ZH_NAMES`（漏了显英文 id）。

## 整体决策（用户已确认）

- 内容档位：**大套餐** = 草岛 + 云块 + 哈比鸟（+ 云靴）。
- 上岛方式：**两条路** = ①基础靠垫方块往上爬（无需新道具）②做了云靴后二段跳更轻松（奖励路线）。
- 数量：跟世界大小缩放，**小 1 / 中 2-3 / 大 3-5**（同金字塔）。
- 美术：全部 `@tool` 程序绘制；色板暖色系，云块例外（云块本来就该是白）。

---

## 第 1 步：空岛地形 + 云块 + 宝藏（核心，先做）

### 1.1 新方块「云块」CLOUD

- `tile_data.gd`：加 `const CLOUD := <下一个空闲 id>`，属性 = 实心、可挖、可放、**无重力**（不像 SAND 会塌）、挖掉返还 `cloud` 物品。
- `tileset_builder.gd`：把 `Tiles.CLOUD` 加入 `tile_ids` 数组。
- `scripts/art/`：程序绘制贴图——纯白底 + 浅灰阴影 puff 形状（**不是随机散点**，要可识别的云朵团块高光），参考现有树冠 `oak_cloud_*` 的画法。
- `item_db.gd` 加 `cloud` 物品 + `crafting_panel.gd` `_ZH_NAMES` 加 `"cloud": "云块"`。

### 1.2 空岛地形

新增 `_place_sky_island_chunk(c, world_seed, chunk_x, chunk_width, height)`，在 `generate_chunk()` 里**树木之后、墙之前**调用（位置仿金字塔那一段）。

- **选址**：`_sky_island_chunks(world_seed)` 仿 `_pyramid_chunks`，但**不限 biome**（天上哪都行），数量走 `GameSettings.skyisland_count_range()`，带 seed shuffle + 缓存。岛中心 x 居 chunk 中部，单岛宽 ≤ chunk_width 装进**一个 chunk**（跟金字塔一样，避免跨 chunk 复杂度）。
- **岛形**：椭圆/透镜形，宽 `ISLAND_WIDTH ≈ 30–44`（按 seed 在区间取），垂直放在 `island_y ≈ 28`（带 ±jitter）。
  - 底部厚云块（CLOUD），中间夹 DIRT，**顶面一层 GRASS**。形状用"中心厚两边薄"的半宽递减（仿金字塔层 + 上下对称做成透镜）。
  - 顶面要平整一段（给树和宝箱站）。
- **小水池**：岛顶中部挖碗状坑填 WATER（复用绿洲碗状逻辑，宽 4–8）。
- **树**：岛顶 GRASS 上长 2–4 棵橡树（调 `_place_trees_chunk` 同款 canopy，或在本函数内直接种），注意树冠别越出岛顶被裁。
- **宝箱**：岛中心 GRASS 上方放 1 个 `GOLD_CHEST` 或 `DIAMOND_CHEST`，`treasure_spots.append()`。战利品池含：羽毛（`feather`）、云块若干、稀有装备（沿用现有金/钻箱战利品表，确保至少给到 feather 让后续合成链通）。

### 1.3 验收测试（GUT integration）

- 给定 seed，中世界生成 → 天空层存在 ≥1 块含 CLOUD+GRASS 的浮岛，且岛上有宝箱（`treasure_spots` 落在 y<60）。
- CLOUD tile 可挖（返还 cloud 物品）、可放、不受重力（放置后不下落）。
- 确定性：同 seed 两次生成，岛位置/内容一致。

---

## 第 2 步：哈比鸟（会飞的新怪）

- `scripts/entities/harpy.gd`：照 `demon_eye.gd` / `hell_wasp.gd` 写——天空巡逻、玩家靠近就朝玩家飞/冲，碰撞掉血。
  - `collision_layer/mask` 按 `feedback_no_creature_collision`：不与玩家+彼此物理碰撞，加 player exception。
  - 掉落：`feather`（羽毛）1–2 个；少量金币（沿用现有怪掉落写法）。
  - 贴图：`@tool` 程序绘制（白/浅色鸟身 + 翅膀，可识别形状）。
- 生成接线：空岛生成时在岛上方记 `harpy_spawn_spots`（仿 `mummy_spawn_spots`，加到 `chunk.gd` + `world_generator.gd` + `chunk_manager.gd` 消费）。`chunk_manager` 加载该 chunk 时在空岛附近召 1–3 只。
- 联机：怪物生成走 host 权威（沿用现有怪的同步路径，确定性生成 + host 召唤）。

### 验收测试

- 空岛 chunk 加载 → `harpy_spawn_spots` 非空 → 召出哈比鸟。
- 哈比鸟死亡掉 `feather`。
- 哈比鸟不与玩家物理碰撞。

## 第 3 步：云靴（新装备，二段跳）

- `item_db.gd` 加 `cloud_boots`（装备类）+ `_ZH_NAMES` `"cloud_boots": "云靴"`。贴图程序绘制。
- 配方：`recipe_db.gd` 加 `feather ×N + cloud ×M → cloud_boots`，工作台合成；`output_id` 中文名同步。
- 效果：穿上后**二段跳**（空中可再跳一次）。改 `scripts/entities/player`（或玩家脚本）跳跃逻辑：记录是否已用二段跳，落地重置，装备了云靴才允许第二跳。
- 装备/穿戴接入现有装备槽系统（按现有护甲/饰品的穿法，若无装备槽则做成"持有即生效"的最简版——实现计划阶段确认现状）。

### 验收测试

- 穿云靴 → 空中能触发第二次跳（速度被重置为跳跃初速）。
- 没穿 → 空中跳不动。
- `feather + cloud` 在工作台能合成 `cloud_boots`，面板显示中文名。

---

## 不做（YAGNI）

- 不做天空背景视差专属图层（用现有 sky/cloud 背景即可）。
- 单岛不跨 chunk（装进一个 chunk）。
- 不做哈比鸟远程羽毛弹幕（先做近身冲撞，够用再说）。
- 不做翅膀飞行（云靴二段跳已满足"上下更轻松"）。

## 执行约定

- 分 3 步顺序做，**每步做完给用户 3-5 行报告**（做了啥 + commit SHA + 累计测试数），再开下一步。
- 全程无 GUI 验收，靠 GUT integration test。
- 新 tile / item / recipe 三处同步登记（见背景）。
- 改了 class_name / autoload / 资源后 `./run.sh --rebuild`；跑测试前先 `godot --headless --editor --quit` 建 class_name 索引。
