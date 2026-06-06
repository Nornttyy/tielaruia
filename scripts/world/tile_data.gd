# Tile 属性表 (autoload 单例)。所有 tile 行为查询统一在这里。
extends Node

# Tile ID 常量 (与 BlocksArt 同步)
const AIR := 0
const GRASS := 1
const DIRT := 2
const STONE := 3
const SAND := 4
const LOG := 5
const LEAVES := 6           # 橡木叶 (默认)
const PLANKS := 7
const WORKBENCH := 8
const DOOR := 9
const BEDROCK := 10
const LEAVES_PINE := 11     # 松针 (深暖绿)
const LEAVES_AUTUMN := 12   # 秋叶 (红橙)
const SLIME_TORCH := 13     # 史莱姆灯 (装饰, 不实心)
const TORCH := 14
const COAL_ORE := 15
const IRON_ORE := 16
const DEEP_STONE := 17
# --- 背景墙 (background wall): 装饰用, 不实心, 不可挖, 显示在主方块后面 ---
const GRASS_WALL := 18      # 草墙: 接近地表第 1-2 行
const DIRT_WALL := 19       # 土墙: 中层 (土块对应)
const STONE_WALL := 20      # 石墙: 深层 (石头对应)
const CACTUS := 21          # 仙人掌: 沙漠地表装饰 (非实心, 可砍)
const COPPER_ORE := 22      # 铜矿: 浅层 (wood 镐可挖)
const TIN_ORE := 23         # 锡矿: 浅层 (wood 镐可挖)
const GOLD_ORE := 24        # 金矿: 中深 (iron 镐才挖)
const DIAMOND_ORE := 25     # 钻石矿: 深 (iron 镐才挖)
const HELL_CRYSTAL := 26    # 地狱晶体: 接近基岩 (iron 镐才挖)
const CACTUS_BODY := 27     # 仙人掌身体段 (堆叠时非顶端用, 无 top outline 衔接顶端 CACTUS)
const WATER := 28           # 水 (非实心, 玩家穿过, 视觉半透明蓝)
const LOG_TOP := 29         # 树干顶帽 (canopy 接头)
const LOG_ROOT_L := 30      # 树根 左侧
const LOG_ROOT_R := 31      # 树根 右侧
const BRANCH_L := 32        # 树干侧枝 向左伸
const BRANCH_R := 33        # 树干侧枝 向右伸
const WATER_L1 := 34        # 1/8 水位 (流水 level 1)
const WATER_L2 := 35        # 2/8 水位 (流水 level 2)
const WATER_L3 := 36        # 3/8 水位 (流水 level 3)
# 细水位升级: 水从 4 档→8 档 (更平更顺). WATER (=28) = 满水 level 8.
const WATER_L4 := 88        # 4/8 水位
const WATER_L5 := 89        # 5/8 水位
const WATER_L6 := 90        # 6/8 水位
const WATER_L7 := 91        # 7/8 水位
const CHEST := 37           # 箱子: 右键打开 24 格存储, 内容跟存档持久化
const DOOR_TOP := 38        # 门顶 (DOOR 底 / DOOR_MID 中 / DOOR_TOP 顶, 凑成 3 格高门)
const DOOR_MID := 84        # 门中段 (3 格门的中间一格)
const DOOR_OPEN := 85       # 门打开态: 3 格都换成它, 无碰撞谁都能穿; 离开后换回关门
# 新群系 tile (雪原 / 丛林 / 沼泽)
const SNOW := 39            # 雪原地表 (替代 GRASS), 偏白带浅蓝阴影
const ICE := 40             # 冰块 (雪原零星), 半透明蓝
const JUNGLE_GRASS := 41    # 丛林地表, 深绿带湿气黄绿斑
const MUD := 42             # 沼泽泥土 (替代 DIRT 在沼泽), 棕黑色
const SWAMP_GRASS := 43     # 沼泽地表, 深灰绿带泥点
# 平台: 站上面 + 下方能穿过 (单向碰撞). Terraria 风
const WOOD_PLATFORM := 44
# 绳子: 垂直挂着, 玩家碰到可爬上爬下 (W/S). 不阻挡走路.
const ROPE := 45
# 群系专属泥土 + 树叶
const JUNGLE_DIRT := 46     # 丛林泥土 (深泥黄, 比普通 DIRT 偏绿/棕黑)
const SNOW_DIRT := 47       # 雪原冻土 (灰白带蓝, 比 SNOW 暗)
const JUNGLE_LEAVES := 48   # 丛林树叶 (深湿绿, 比 LEAVES 暗)
const SILVER_ORE := 49      # 银矿 (铁和金之间, tier 3 用 iron 镐挖)
const WOOD_WALL := 50       # 木墙: 玩家造 (区别于自然生成的土墙/石墙), 木板纹路
const FURNACE := 51         # 熔炉: 玩家造, 实心. 附近能解锁冶炼配方
const MUSHROOM := 52        # 蓝光蘑菇 (装饰, 非实心, 矿洞蘑菇地长出来. 砍了掉 mushroom 物品)
const MIMIC_CHEST := 53     # 死人箱 (假宝箱陷阱): 右键 / 砍 → 弹出蜘蛛, 无掉落, 视觉跟 CHEST 像但带红眼
const GOLD_CHEST := 54      # 金宝箱 (中层 y 70-99): 金边 + 黄金锁孔, 内含铁/煤/锭
const DIAMOND_CHEST := 55   # 钻石宝箱 (深层 y >= 100): 蓝水晶边 + 蓝锁孔, 内含金锭/钻石
# === 地狱 (M_HELL Phase 1) ===
const LAVA := 56            # 岩浆: 非实心, 不可挖, 玩家踩到持续扣血. 出现在 y > HELL_DEPTH
const HELL_STONE := 57      # 地狱石: 替代 STONE/DEEP_STONE 在地狱区. 铁镐 (tier 4) 可挖
const OBSIDIAN := 58        # 黑曜石: 钻石镐 (tier 7) 才能挖. 围着岩浆池, 极硬
const HELL_FRUIT := 59      # 火果子 (地狱农圣果): 装饰 + 食物. 长地狱石顶, 可吃
const SHADOW_CHEST := 60    # 阴影宝箱 (地狱第 4 tier): 黑底 + 红光锁孔, 装地狱专属战利品
const LIFE_CRYSTAL := 61    # 生命水晶 (Terraria 风): 矿洞偶发, 右键吃 → 永久 +20 MAX HP (上限 400)
const HELL_ALLOY_ORE := 62  # 地狱合金矿: 深紫黑底 + 银闪点. 金/钻镐挖, 熔炉炼锭, 造 tier 8 武器主金属
const SANDSTONE := 63       # 砂岩: 金字塔骨架. 实心不掉 (跟 SAND 区分, 无重力 bug)
const MANA_CRYSTAL := 64    # 魔力水晶 (蓝紫星形): 矿洞偶发, 右键吃 → 永久 +20 MAX MANA (上限 200)
const BED := 65             # 床·左半 (床头): 双击睡觉 + 复活点. 跟 BED_RIGHT 凑成 2 格宽床
const BED_RIGHT := 87       # 床·右半 (床尾): 砍任一半联动消整张, 点任一半都能睡
# 小麦作物 4 阶段 (菜园 v1). 玩家右键 GRASS + 持 wheat_seed → 种 WHEAT_0.
# world.gd 每 15s tick 一次, 每个 WHEAT_0/1/2 有概率升一阶. WHEAT_3 挖 → 小麦 + 种子.
const WHEAT_0 := 66         # 苗 (刚种, 小绿点)
const WHEAT_1 := 67         # 小 (3 高小芽)
const WHEAT_2 := 68         # 中 (有杆带叶)
const WHEAT_3 := 69         # 熟 (黄色穗子, 可收割)
# 装饰小草 (草地表面). 1 格高, 非实心 (玩家穿过), 长在 GRASS 上方 AIR.
# 挖掉: 80% 啥都没有 / 20% wheat_seed (玩家拓荒, 用户要求).
const PLANT_GRASS := 70
const LAVA_L1 := 71         # 1/4 岩浆 (流动浅位)
const LAVA_L2 := 72         # 2/4 岩浆
const LAVA_L3 := 73         # 3/4 岩浆 (满格仍是 LAVA = 56)
const COOKING_POT := 74     # 铁锅: 玩家造, 实心, 只能叠在炉子上. 附近解锁料理配方, 发暖光
const CLOUD := 75           # 云块: 空岛岛体. 白软, 实心可站可挖可放, 无重力 (不像 SAND 会塌)
const CUTTING_BOARD := 76   # 菜板: 玩家造放置工作站. 站旁边解锁切鱼片/做寿司配方
const RICE_0 := 77          # 稻子 苗 (像小麦 4 阶段, 种子近水种, 熟了挖出米)
const RICE_1 := 78          # 稻子 小
const RICE_2 := 79          # 稻子 中
const RICE_3 := 80          # 稻子 熟 (挖 → 米 + 稻种)
# 群系满水 (level 4): 颜色不同, 行为同 WATER (非实心/不可挖/4帧动画). 森林/雪原/默认用通用 WATER.
const WATER_DESERT := 81    # 沙漠绿洲 = 青绿松石
const WATER_JUNGLE := 82    # 丛林 = 翠绿
const WATER_SWAMP := 83     # 沼泽 = 浑浊墨绿
const WATER_SOURCE := 86    # 水源块: 永远冒水的泉眼 (瀑布). 实心可挖, 挖掉就停; 不掉物=不可造, 防无限水

# 每 tile 的属性。drops 为 [item_id, weight%, count_min, count_max] 数组。
# tool: "pickaxe"/"axe"/"sword"/"" (空 = 徒手)
# tier: -1 = 该工具挖不动；0 = 徒手也行；1 = 需 1 级 (木质)
const _PROPS := {
	AIR: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		# dirt 必掉 + 20% 概率额外掉 grass (稀有种子)
		"drops": [["dirt", 100, 1, 1], ["grass", 20, 1, 1]],
	},
	DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	SAND: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["sand", 100, 1, 1]],
	},
	LOG: {
		# 原木不实心 — 玩家可穿过树干 (像 Terraria).
		# 只能用斧砍 (像 Terraria/MC) — 镐/剑/徒手挖不动, 防止镐子砍树太快的 bug.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	LEAVES: {
		# 不实心. 2% 掉 leaves 物品 (做木法杖 + 当建材, 之前 0% 掉导致木法杖无法合成), 另 20% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1], ["leaves", 2, 1, 1]],
	},
	PLANKS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["planks", 100, 1, 1]],
	},
	WORKBENCH: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["workbench", 100, 1, 1]],
	},
	FURNACE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["furnace", 100, 1, 1]],
	},
	COOKING_POT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["cooking_pot", 100, 1, 1]],
	},
	CUTTING_BOARD: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["cutting_board", 100, 1, 1]],
	},
	DOOR: {
		# 门底部: 视觉占 1 格, 但和 DOOR_TOP (上一格) 配对成 2 格高门.
		# solid=false → tileset_builder 不会在物理层 0 加碰撞;
		# tileset_builder 单独在物理层 1 (门层, bit 1) 加碰撞, 怪挡住, 玩家放行.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["door", 100, 1, 1]],
	},
	DOOR_TOP: {
		# 门顶部: 跟 DOOR/DOOR_MID 一起 3 格高. 物理同 DOOR (单独物理层挡怪不挡玩家).
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		# 不掉东西 — 砍门任一段, 联动消整扇, 由 DOOR 掉 1 个 door item.
		"drops": [],
	},
	DOOR_MID: {
		# 门中段: 3 格门的中间. 物理同 DOOR (挡怪不挡玩家). 砍它联动消整扇.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [],
	},
	DOOR_OPEN: {
		# 门打开态: 完全可穿 (连怪也能过), 无碰撞. 砍它联动消整扇, 由 DOOR 掉落.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [],
	},
	BEDROCK: {
		"solid": true, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LEAVES_PINE: {
		# 松针 (老存档): 不实心, 不掉变种 leaves 物品, 仅 20% 掉 apple
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	LEAVES_AUTUMN: {
		# 秋叶 (老存档): 同上
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	SLIME_TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["slime_torch", 100, 1, 1]],
	},
	TORCH: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["torch", 100, 1, 1]],
	},
	COAL_ORE: {
		# 煤: 木镐就能挖 (最浅 + 最早期)
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["coal", 100, 1, 1]],
	},
	IRON_ORE: {
		# 铁: 铜镐 (tier 3) 才能挖 — 进阶, 用铜→挖铁→升铁工具
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 3, "axe": -1, "sword": -1},
		"drops": [["iron_ore", 100, 1, 1]],
	},
	DEEP_STONE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["stone", 100, 1, 1]],
	},
	GRASS_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	DIRT_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	STONE_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	WOOD_WALL: {
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	COPPER_ORE: {
		# 铜: 石镐 (tier 2) 才能挖 — 第一金属, 升级路线起点
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
		"drops": [["copper_ore", 100, 1, 1]],
	},
	TIN_ORE: {
		# 锡: 石镐 — 跟铜并列, 可代替铜也可单独装备
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 2, "axe": -1, "sword": -1},
		"drops": [["tin_ore", 100, 1, 1]],
	},
	GOLD_ORE: {
		# 金: 银镐 (tier 5) — 后期, 在银之后
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 5, "axe": -1, "sword": -1},
		"drops": [["gold_ore", 100, 1, 1]],
	},
	DIAMOND_ORE: {
		# 钻石: 金镐 (tier 6) — 后期门槛, 在金之后
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 6, "axe": -1, "sword": -1},
		"drops": [["diamond", 100, 1, 1]],
	},
	HELL_CRYSTAL: {
		# 地狱晶: 金镐 (tier 6) + 钻石镐 (tier 7) 都能挖 (用户改: 不仅钻石)
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 6, "axe": -1, "sword": -1},
		"drops": [["hell_crystal", 100, 1, 1]],
	},
	HELL_ALLOY_ORE: {
		# 地狱合金矿: 跟地狱晶同 tier (金镐 + 钻石镐 都能挖), 烧成锭后造装备
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 6, "axe": -1, "sword": -1},
		"drops": [["hell_alloy_ore", 100, 1, 1]],
	},
	CACTUS: {
		# 仙人掌: 不实心 (玩家穿过, 像 LOG), 任何工具都能砍, 掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["cactus", 100, 1, 1]],
	},
	CACTUS_BODY: {
		# 仙人掌身体段: 行为同 CACTUS, 砍了也掉 cactus 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["cactus", 100, 1, 1]],
	},
	WATER: {
		# 水: 非实心 (玩家穿过), 不可挖 (没法用工具收), 无掉落. 等以后加桶再说.
		"solid": false, "mineable": false,
		"tool_tiers": {},
		"drops": [],
	},
	LOG_TOP: {
		# 树干顶帽: 行为同 LOG, 砍了掉 log. 只能用斧 (跟 LOG 同).
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	LOG_ROOT_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_L: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	BRANCH_R: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": 0, "sword": -1},
		"drops": [["log", 100, 1, 1]],
	},
	# 流水 3 个低水位 tile. 行为同 WATER: 不实心 + 不可挖
	WATER_L1: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_L2: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_L3: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	# 细水位 4-7 档: 行为同 WATER (非实心/不可挖)
	WATER_L4: { "solid": false, "mineable": false, "tool_tiers": {}, "drops": [] },
	WATER_L5: { "solid": false, "mineable": false, "tool_tiers": {}, "drops": [] },
	WATER_L6: { "solid": false, "mineable": false, "tool_tiers": {}, "drops": [] },
	WATER_L7: { "solid": false, "mineable": false, "tool_tiers": {}, "drops": [] },
	# 群系满水: 行为完全同 WATER (只是颜色不同)
	WATER_DESERT: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_JUNGLE: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_SWAMP: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	WATER_SOURCE: {
		# 实心 (水从底下冒, 能站能挖), 木镐挖. 不掉物品 (世界生成专属, 玩家拿不到 → 不会无限水).
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [],
	},
	CHEST: {
		# 非实心 (玩家能站箱子里), 可挖 (任何工具都行), 砍掉 1 个 chest item
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["chest", 100, 1, 1]],
	},
	# === 新群系地表 (像 GRASS / DIRT / SAND 一样可挖, 徒手即可) ===
	SNOW: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["snow", 100, 1, 1]],
	},
	ICE: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": -1, "sword": -1},
		"drops": [["ice", 100, 1, 1]],
	},
	JUNGLE_GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["dirt", 100, 1, 1]],
	},
	MUD: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["mud", 100, 1, 1]],
	},
	SWAMP_GRASS: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["mud", 100, 1, 1]],
	},
	# 平台: solid=false (走路不阻挡), tileset_builder 单独加 one_way 碰撞
	WOOD_PLATFORM: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wood_platform", 100, 1, 1]],
	},
	# 绳子: solid=false (玩家穿过), 但 player_controller 检测到会切换爬绳模式
	ROPE: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rope", 100, 1, 1]],
	},
	# 群系泥土 / 树叶 (跟基础 DIRT/LEAVES 类似行为, 只颜色不同)
	JUNGLE_DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["jungle_dirt", 100, 1, 1]],
	},
	SNOW_DIRT: {
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["snow_dirt", 100, 1, 1]],
	},
	JUNGLE_LEAVES: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["apple", 20, 1, 1]],
	},
	SILVER_ORE: {
		# 银: 铁镐 (tier 4) 才能挖 — 在铁之后
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 4, "axe": -1, "sword": -1},
		"drops": [["silver_ore", 100, 1, 1]],
	},
	MUSHROOM: {
		# 矿洞蓝蘑菇: 非实心 (玩家穿过), 徒手就能采 (没工具也能拿吃的)
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["mushroom", 100, 1, 1]],
	},
	MIMIC_CHEST: {
		# 死人箱: 视觉跟 CHEST 像, 行为是陷阱. 右键 / 砍 → 爆炸 + 弹 mimic.
		# 不掉物品 (奖励是打死 mimic 后的掉落). mineable=true 让玩家挥镐能触发陷阱.
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [],
	},
	GOLD_CHEST: {
		# 金宝箱: 同 CHEST 行为, 只是视觉 + 内含战利品更好. 砍了掉普通 chest 物品.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["chest", 100, 1, 1]],
	},
	DIAMOND_CHEST: {
		# 钻石宝箱: 同 GOLD_CHEST 行为, 视觉更亮 + 战利品最豪华.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["chest", 100, 1, 1]],
	},
	LAVA: {
		# 岩浆: 非实心 (玩家穿过 → 扣血), 不可挖 (没法收岩浆). 跟 WATER 同行为, 但伤害.
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	# 流动岩浆 3 个低液位 tile. 行为同 LAVA: 不实心 + 不可挖 + 玩家踩到扣血.
	LAVA_L1: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	LAVA_L2: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	LAVA_L3: {
		"solid": false, "mineable": false,
		"tool_tiers": {}, "drops": [],
	},
	HELL_STONE: {
		# 地狱石: 实心, 铁镐 (tier 4) 才能挖, 没斧没剑能挖
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 4, "axe": -1, "sword": -1},
		"drops": [["hell_stone", 100, 1, 1]],
	},
	OBSIDIAN: {
		# 黑曜石: 钻石镐 (tier 7) 才能挖, 极硬
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 7, "axe": -1, "sword": -1},
		"drops": [["obsidian", 100, 1, 1]],
	},
	HELL_FRUIT: {
		# 火果子: 装饰, 非实心, 任何工具能采 (含徒手), 掉 hell_fruit 物品
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["hell_fruit", 100, 1, 1]],
	},
	SHADOW_CHEST: {
		# 阴影宝箱: 同 DIAMOND_CHEST 行为. 砍了掉 chest 物品.
		"solid": false, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["chest", 100, 1, 1]],
	},
	LIFE_CRYSTAL: {
		# 生命水晶: 不能挖 (右键吃专用). 实心防玩家穿过. 砸不掉 → 必须靠近右键.
		"solid": true, "mineable": false,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": -1, "sword": -1},
		"drops": [],
	},
	SANDSTONE: {
		# 砂岩: 实心, 木镐就能挖, 掉 sandstone 物品 (玩家能采来做建筑)
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["sandstone", 100, 1, 1]],
	},
	CLOUD: {
		# 云块: 实心 (能站), 木镐就能挖, 掉 cloud 物品. 不是 SAND → 不受沙重力, 挖了上面不塌.
		"solid": true, "mineable": true,
		"tool_tiers": {"": -1, "pickaxe": 1, "axe": -1, "sword": -1},
		"drops": [["cloud", 100, 1, 1]],
	},
	MANA_CRYSTAL: {
		# 魔力水晶: 跟生命水晶同款, 不能挖 (右键吃), 实心防穿过.
		"solid": true, "mineable": false,
		"tool_tiers": {"": -1, "pickaxe": -1, "axe": -1, "sword": -1},
		"drops": [],
	},
	BED: {
		# 床·左半 (床头): 玩家造装饰 + 复活点. 非实心 (玩家穿过), 徒手即可拆.
		# 砍它由 player_action 联动消掉右半 + 掉 1 床物品 (右半 drops 空, 不重复掉).
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["bed", 100, 1, 1]],
	},
	BED_RIGHT: {
		# 床·右半 (床尾): 不掉东西 — 砍任一半, 由 player_action 联动消整张, 左半 BED 掉 1 床.
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [],
	},
	# 小麦 4 阶段: 全非实心 (玩家踩过), 徒手即可挖. 未熟 (0/1/2) 挖只掉种子, 熟 (3) 挖掉小麦 + 种子.
	WHEAT_0: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wheat_seed", 100, 1, 1]],
	},
	WHEAT_1: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wheat_seed", 100, 1, 1]],
	},
	WHEAT_2: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wheat_seed", 100, 1, 1]],
	},
	WHEAT_3: {
		# 熟透小麦: 必掉 2-4 小麦 + 必掉 1-2 种子 (玩家自循环)
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wheat", 100, 2, 4], ["wheat_seed", 100, 1, 2]],
	},
	# 稻子 4 阶段 (像小麦). RICE_0/1/2 挖掉只回种子; RICE_3 熟透掉米 + 种子.
	RICE_0: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rice_seed", 100, 1, 1]],
	},
	RICE_1: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rice_seed", 100, 1, 1]],
	},
	RICE_2: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rice_seed", 100, 1, 1]],
	},
	RICE_3: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["rice", 100, 2, 4], ["rice_seed", 100, 1, 2]],
	},
	# 装饰小草: 80% 啥都没有 / 20% wheat_seed / 15% rice_seed (拓荒拿种子).
	PLANT_GRASS: {
		"solid": false, "mineable": true,
		"tool_tiers": {"": 0, "pickaxe": 0, "axe": 0, "sword": 0},
		"drops": [["wheat_seed", 20, 1, 1], ["rice_seed", 15, 1, 1]],
	},
}


func is_solid(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].solid


# 是不是矿石 (洞穴/火山挖掘时跳过, 别把稀有矿吞掉). 加新矿石只改这里.
func is_ore(tile_id: int) -> bool:
	return tile_id == COAL_ORE or tile_id == IRON_ORE or tile_id == COPPER_ORE \
			or tile_id == TIN_ORE or tile_id == SILVER_ORE or tile_id == GOLD_ORE \
			or tile_id == DIAMOND_ORE or tile_id == HELL_CRYSTAL or tile_id == HELL_ALLOY_ORE


# 是不是水 (任意水位 L1-3 + 满水 + 任意群系水色). 统一判定: 加新水方块只改这里,
# 别处 (游泳/钓鱼/小地图/模拟) 一律用 Tiles.is_water(), 别再写 == WATER or == WATER_L1...
func is_water(tile_id: int) -> bool:
	return tile_id == WATER or tile_id == WATER_L1 or tile_id == WATER_L2 or tile_id == WATER_L3 \
			or tile_id == WATER_L4 or tile_id == WATER_L5 or tile_id == WATER_L6 or tile_id == WATER_L7 \
			or tile_id == WATER_DESERT or tile_id == WATER_JUNGLE or tile_id == WATER_SWAMP


func is_mineable(tile_id: int) -> bool:
	if not _PROPS.has(tile_id):
		return false
	return _PROPS[tile_id].mineable


# 返回该 tool 挖该 tile 所需的最低 tier。-1 = 不行。0 = 徒手也行。
func required_tool_tier(tile_id: int, tool: String) -> int:
	if not _PROPS.has(tile_id):
		return -1
	var tiers: Dictionary = _PROPS[tile_id].tool_tiers
	if tiers.has(tool):
		return tiers[tool]
	return tiers.get("", -1)


# 按 drops 表权重抽样，返回 {item_id: count}。
func drops_for(tile_id: int, _tool: String) -> Dictionary:
	if not _PROPS.has(tile_id):
		return {}
	var result := {}
	for entry in _PROPS[tile_id].drops:
		var item_id: String = entry[0]
		var weight: int = entry[1]
		var roll := randi() % 100
		if roll < weight:
			var n := randi_range(entry[2], entry[3])
			if n > 0:
				result[item_id] = result.get(item_id, 0) + n
	return result
