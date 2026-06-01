# 10 种方块的 16×16 像素画。每个方块用 3-4 色 (base + 高光/阴影 + 特征色)。
# 静态贴图，无动画。返回 ImageTexture。
#
# 用法:
#   var tex = BlocksArt.get_texture(BlocksArt.GRASS)
#   tile_set.add_source(...)
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

# Tile ID 常量 (与 TileData 单例同步)
const AIR := 0
const GRASS := 1
const DIRT := 2
# 新群系常量 (跟 Tiles.gd 一致)
const SNOW := 39
const ICE := 40
const JUNGLE_GRASS := 41
const MUD := 42
const SWAMP_GRASS := 43
const WOOD_PLATFORM := 44
const ROPE := 45
const JUNGLE_DIRT := 46
const SNOW_DIRT := 47
const JUNGLE_LEAVES := 48
const SILVER_ORE := 49
const WOOD_WALL := 50
const FURNACE := 51
const COOKING_POT := 74     # 铁锅 (架在炉子上的做饭台, 锅底带火)
const MUSHROOM := 52        # 蓝光蘑菇 (矿洞蘑菇地装饰)
const MIMIC_CHEST := 53     # 死人箱 (假宝箱陷阱), 视觉跟 CHEST 像但锁孔是红的
const GOLD_CHEST := 54      # 金宝箱 (金色金属包角)
const DIAMOND_CHEST := 55   # 钻石宝箱 (蓝水晶金属包角)
# === 地狱 (Phase 1) ===
const LAVA := 56            # 岩浆 (亮橙红, 玩家踩到扣血)
const HELL_STONE := 57      # 地狱石 (深红带黑裂纹 + 烈火高光)
const OBSIDIAN := 58        # 黑曜石 (黑底 + 紫光泽闪)
const HELL_FRUIT := 59      # 火果 (装饰, 红果 + 黄柄)
const SHADOW_CHEST := 60    # 阴影宝箱 (黑底 + 红光锁孔 + 红宝石)
const LIFE_CRYSTAL := 61    # 生命水晶 (用户加, _PATTERN_MAP 引用了, 补常量声明)
const HELL_ALLOY_ORE := 62  # 地狱合金矿 (深紫黑 + 银闪点)
const SANDSTONE := 63       # 砂岩 (暖黄, 有层纹, 金字塔骨架)
const MANA_CRYSTAL := 64    # 魔力水晶 (蓝紫五角星, 矿洞偶发)
const BED := 65             # 床 (木框 + 红被 + 白枕)
# 小麦 4 阶段 (菜园 v1)
const WHEAT_0 := 66         # 苗 (1-2 高小绿点)
const WHEAT_1 := 67         # 小 (3 高小芽)
const WHEAT_2 := 68         # 中 (有杆带叶)
const WHEAT_3 := 69         # 熟 (黄色穗子, 可收割)
const PLANT_GRASS := 70     # 装饰小草 (草地点缀, 挖 20% 掉种子)
const LAVA_L1 := 71         # 1/4 岩浆 (流动浅位)
const LAVA_L2 := 72         # 2/4 岩浆
const LAVA_L3 := 73         # 3/4 岩浆 (满格仍是 LAVA = 56)
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
const SLIME_TORCH := 13     # 史莱姆灯
const TORCH := 14           # 火把 (放置版本，含动画 fx)
const COAL_ORE := 15        # 煤矿
const IRON_ORE := 16        # 铁矿
const DEEP_STONE := 17      # 深层岩石 (暗暖灰)
const GRASS_WALL := 18      # 背景墙: 草墙 (近地表)
const DIRT_WALL := 19       # 背景墙: 土墙 (中层)
const STONE_WALL := 20      # 背景墙: 石墙 (深层)
const CACTUS := 21          # 仙人掌顶 (圆头, 堆叠时只用于最顶端)
const CACTUS_BODY := 27     # 仙人掌身体段 (堆叠时非顶端, 无 top outline)
const COPPER_ORE := 22      # 铜矿 (浅层, 暖橙铜)
const TIN_ORE := 23         # 锡矿 (浅层, 银白)
const GOLD_ORE := 24        # 金矿 (中深, 暖金黄)
const DIAMOND_ORE := 25     # 钻石矿 (深层, 青蓝发光)
const HELL_CRYSTAL := 26    # 地狱晶体 (接近基岩, 烈火红)
const WATER := 28           # 水 (满水 level 4)
const LOG_TOP := 29         # 树干顶帽 (接 canopy)
const LOG_ROOT_L := 30      # 树根 左
const LOG_ROOT_R := 31      # 树根 右
const BRANCH_L := 32        # 侧枝 向左 (带末端小叶簇)
const BRANCH_R := 33        # 侧枝 向右
const WATER_L1 := 34        # 1/4 水位
const WATER_L2 := 35        # 2/4 水位
const WATER_L3 := 36        # 3/4 水位
const CHEST := 37           # 箱子
const DOOR_TOP := 38        # 门上半截 (跟 DOOR=9 配对成 2 格高门)

# --- 调色板 (每方块独立) ---

const _P_GRASS := {
	"a": Color8(181, 214, 115),  # 暖黄绿高光
	"g": Color8(125, 173, 90),   # 暖绿基
	"G": Color8(79, 124, 62),    # 深暖绿
	"m": Color8(149, 194, 97),   # 中暖绿
	"y": Color8(220, 220, 120),  # 金黄草尖
	"s": Color8(199, 204, 90),   # 金黄草穗
	"d": Color8(156, 112, 72),   # 暖泥
	"D": Color8(126, 88, 64),    # 泥阴影
	"k": Color8(94, 65, 44),     # 小石子
	"l": Color8(186, 144, 112),  # 泥高光
	"r": Color8(160, 90, 48),    # 红棕根
	# 新增 (T3): 边缘语义槽
	"_o": Color8(32, 24, 12),    # 极暗轮廓 (k×0.55 darkened)
	"_e": Color8(88, 61, 40),    # 边缘暗影 (d×0.55)
	"_h": Color8(157, 216, 113), # 边缘高光 (g+25%)
	"_H": Color8(185, 220, 115), # 顶强高光 (暖, R+8 B-8)
}

const _P_DIRT := {
	"d": Color8(160, 122, 85),   # 暖泥基
	"D": Color8(126, 88, 64),    # 深暗
	"k": Color8(92, 63, 42),     # 石子
	"l": Color8(188, 149, 115),  # 高光
	"L": Color8(204, 166, 129),  # 凸起亮
	"r": Color8(160, 85, 46),    # 红棕
	"p": Color8(136, 97, 68),    # 冷棕
	"o": Color8(201, 126, 69),   # 暖橙
	# 新增 (T3): 边缘语义槽
	"_o": Color8(38, 23, 12),    # 极暗轮廓 (k×0.55 → 暗棕)
	"_e": Color8(88, 67, 47),    # 边缘暗影 (d×0.55)
	"_h": Color8(200, 153, 106), # 边缘高光 (d+25%)
	"_H": Color8(220, 165, 108), # 顶强高光 (暖, R+12 B-6)
}

const _P_STONE := {
	"s": Color8(156, 144, 136),  # 暖灰基 (warm warm-grey)
	"S": Color8(122, 110, 102),  # 暖灰阴影
	"l": Color8(182, 168, 158),  # 暖高光
	"k": Color8(92, 80, 72),     # 暖裂纹
	"L": Color8(204, 191, 181),  # 暖凸起
	"m": Color8(138, 125, 116),  # 中暖灰
	"b": Color8(110, 98, 90),    # 深暖灰
	"o": Color8(184, 154, 130),  # 砂岩调
	# 新增 (T3): 边缘语义槽
	"_o": Color8(40, 32, 28),    # 极暗轮廓 (k×0.55)
	"_e": Color8(95, 85, 78),    # 边缘暗影 (s×0.61)
	"_h": Color8(195, 180, 170), # 边缘高光 (s+25%)
	"_H": Color8(222, 205, 188), # 顶强高光 (暖, R+8 B-8)
}

const _P_SAND := {
	"y": Color8(229, 196, 133),  # 暖沙基
	"Y": Color8(184, 152, 104),  # 阴影
	"l": Color8(240, 220, 168),  # 高光
	"k": Color8(138, 110, 69),   # 石子
	"L": Color8(245, 227, 181),  # 凸起亮
	"o": Color8(213, 162, 107),  # 暖橙
	"r": Color8(193, 130, 80),   # 深暖
	"b": Color8(221, 183, 120),  # 沙变种
	# 新增 (T3): 边缘语义槽
	"_o": Color8(52, 38, 20),    # 极暗轮廓 (k×0.55 → 暗沙棕)
	"_e": Color8(126, 107, 73),  # 边缘暗影 (y×0.55)
	"_h": Color8(255, 245, 166), # 边缘高光 (y+25%)
	"_H": Color8(255, 252, 165), # 顶强高光 (暖, R+8 B-8 → 淡金黄)
}

const _P_LOG := {
	"b": Color8(124, 86, 64),    # 暖树皮基
	"B": Color8(85, 53, 41),     # 深沟
	"l": Color8(163, 133, 115),  # 树皮高光
	"R": Color8(108, 70, 54),    # 木结
	"r": Color8(148, 111, 88),   # 中树皮
	"p": Color8(136, 96, 76),    # 副基
	"s": Color8(161, 132, 114),  # 树皮变种
	"o": Color8(184, 131, 106),  # 樱木暖橙
}

# 麻绳: 偏暖黄棕色, 更亮更轻 (跟 log 树干区分)
const _P_ROPE := {
	"h": Color8(180, 145, 95),   # 麻绳基 (淡黄棕)
	"H": Color8(125, 95, 55),    # 麻绳深 (twist 暗边)
	"l": Color8(220, 185, 135),  # 麻绳高光 (亮淡)
}

const _P_LEAVES := {
	"l": Color8(125, 173, 92),   # 暖中绿
	"L": Color8(86, 129, 74),    # 暖阴影
	"d": Color8(58, 89, 56),     # 最深
	"h": Color8(164, 197, 122),  # 暖高光
	"y": Color8(201, 197, 111),  # 金橄榄
	"s": Color8(108, 142, 88),   # 中阴影
	"a": Color8(180, 185, 120),  # 鼠尾草
	"r": Color8(184, 100, 58),   # 秋红
	# 新增 (T3): 边缘语义槽
	"_o": Color8(18, 34, 16),    # 极暗轮廓 (d×0.55 → 近黑绿)
	"_e": Color8(60, 96, 51),    # 边缘暗影 (l×0.55)
	"_h": Color8(156, 216, 115), # 边缘高光 (l+25%)
	"_H": Color8(178, 228, 115), # 顶强高光 (暖黄绿, R+8 B-8)
}

# 松针：深暖绿 + 灰绿暗色，无透角更密实
const _P_LEAVES_PINE := {
	"l": Color8(82, 130, 78),    # 中绿
	"L": Color8(50, 95, 55),     # 阴影
	"d": Color8(28, 60, 35),     # 最深
	"h": Color8(120, 165, 95),   # 高光
	"s": Color8(70, 115, 70),    # 中阴影
	"y": Color8(155, 175, 90),   # 黄橄榄 (松果?)
	# 新增 (T3): 边缘语义槽
	"_o": Color8(10, 22, 13),    # 极暗轮廓 (d×0.55 → 近黑绿)
	"_e": Color8(38, 71, 43),    # 边缘暗影 (l×0.55)
	"_h": Color8(103, 163, 98),  # 边缘高光 (l+25%)
	"_H": Color8(118, 170, 96),  # 顶强高光 (R+8 B-8, 暗沉不过亮)
}

# 秋叶：暖红橙 + 金黄 + 深红
const _P_LEAVES_AUTUMN := {
	"l": Color8(195, 110, 55),   # 橙基
	"L": Color8(160, 70, 35),    # 深橙阴影
	"d": Color8(110, 50, 30),    # 深红
	"h": Color8(225, 165, 95),   # 金橙高光
	"y": Color8(230, 200, 80),   # 黄秋叶
	"s": Color8(180, 90, 45),    # 中阴影
	"a": Color8(215, 145, 70),   # 桃色变种
	"r": Color8(140, 50, 30),    # 深红浆果
	# 新增 (T3): 边缘语义槽
	"_o": Color8(42, 14, 8),     # 极暗轮廓 (r×0.55 → 深红棕)
	"_e": Color8(84, 46, 22),    # 边缘暗影 (l×0.55 → 深橙棕)
	"_h": Color8(244, 138, 69),  # 边缘高光 (l+25%)
	"_H": Color8(255, 150, 68),  # 顶强高光 (暖金橙, R+8 B-8)
}

# 史莱姆灯: 暗木棍 + 顶部黄绿史莱姆胶发光感
const _P_SLIME_TORCH := {
	"b": Color8(74, 52, 41),    # 木棍深
	"r": Color8(110, 80, 67),   # 木棍中
	"g": Color8(120, 200, 100), # 胶体绿
	"G": Color8(76, 175, 80),   # 胶体阴影
	"h": Color8(220, 255, 180), # 高光
}

const _P_PLANKS := {
	"p": Color8(168, 116, 69),
	"P": Color8(141, 93, 53),
	"l": Color8(192, 143, 91),
	"k": Color8(109, 66, 38),   # 板缝
	# 新增 (T3): 边缘语义槽
	"_o": Color8(42, 26, 14),    # 极暗轮廓 (k×0.55 → 深木棕)
	"_e": Color8(92, 64, 38),    # 边缘暗影 (p×0.55)
	"_h": Color8(210, 145, 86),  # 边缘高光 (p+25%)
	"_H": Color8(232, 158, 88),  # 顶强高光 (暖, R+12 B-8)
}

const _P_WORKBENCH := {
	"p": Color8(168, 116, 69),
	"P": Color8(141, 93, 53),
	"o": Color8(191, 111, 58),  # 工具痕
	"k": Color8(67, 40, 24),
	"l": Color8(208, 158, 110),
}

const _P_CHEST := {
	"w": Color8(168, 116, 69),  # 木板主色 (planks 同款)
	"W": Color8(141, 93, 53),   # 木板阴影
	"l": Color8(208, 158, 110), # 木板高光
	"k": Color8(40, 25, 15),    # 黑描边
	"m": Color8(218, 165, 80),  # 黄铜包角
	"M": Color8(150, 105, 40),  # 黄铜阴影
	"f": Color8(248, 200, 110), # 黄铜亮闪
	"o": Color8(35, 18, 10),    # 锁孔黑
	"g": Color8(95, 60, 25),    # 钉子/暗木结
}

# 金宝箱: 深色木板 + 亮金属包角 + 红宝石锁芯, 富贵感.
const _P_GOLD_CHEST := {
	"w": Color8(120, 78, 40),    # 深棕木板 (比普通木箱更暗显档次)
	"W": Color8(80, 50, 25),     # 木板深影
	"l": Color8(165, 115, 70),   # 木板高光
	"k": Color8(28, 18, 8),      # 黑描边
	"m": Color8(245, 200, 70),   # 亮金主
	"M": Color8(175, 130, 30),   # 金阴影
	"f": Color8(255, 235, 130),  # 金极亮闪
	"o": Color8(35, 18, 8),      # 锁孔黑
	"g": Color8(225, 55, 70),    # 红宝石主
	"G": Color8(155, 25, 40),    # 红宝石阴影
}

# 钻石宝箱: 深蓝紫木板 + 4 角水晶 + 蓝宝石锁芯. 神秘冰冷感.
const _P_DIAMOND_CHEST := {
	"w": Color8(78, 65, 105),    # 深蓝紫木 (神秘感)
	"W": Color8(45, 38, 68),     # 深影
	"l": Color8(115, 100, 160),  # 蓝紫高光
	"k": Color8(20, 15, 35),     # 黑描边
	"m": Color8(135, 205, 245),  # 蓝水晶主
	"M": Color8(75, 145, 200),   # 蓝水晶阴影
	"f": Color8(235, 250, 255),  # 水晶白闪
	"o": Color8(25, 30, 60),     # 锁孔深蓝黑
	"g": Color8(85, 180, 235),   # 蓝宝石主
	"G": Color8(40, 110, 175),   # 蓝宝石阴影
}

# 岩浆: 亮黄 + 橙 + 红 (烫感) + 暗红气泡
const _P_LAVA := {
	"y": Color8(255, 235, 95),    # 亮黄 (主要)
	"o": Color8(255, 165, 35),    # 橙 (常见)
	"r": Color8(225, 85, 25),     # 红 (次)
	"R": Color8(165, 35, 15),     # 深红 (暗气泡)
	"h": Color8(255, 255, 200),   # 极亮黄 (闪点)
}

# 地狱石: 深红基础 + 暗黑裂纹 + 亮橙红高光 (像 STONE 风格但烈焰色调).
# 7 个色阶: s/S/b base + L/l 高光 + k 裂 + m 暗.
const _P_HELL_STONE := {
	"s": Color8(125, 32, 28),     # 深红 base
	"S": Color8(85, 18, 15),      # 极暗红阴影
	"b": Color8(150, 45, 35),     # 红主 (亮些)
	"L": Color8(225, 95, 45),     # 烈火亮高光
	"l": Color8(175, 60, 35),     # 中亮红
	"m": Color8(255, 165, 70),    # 极亮焰橙 (零星)
	"k": Color8(28, 8, 8),        # 黑裂纹
	"o": Color8(105, 25, 22),     # 暗红 (次阴影)
	# autotile 边缘 4 槽位 (跟 STONE 同思路): 暗轮廓 / 边影 / 边亮 / 顶亮
	"_o": Color8(20, 4, 4),       # 极暗轮廓 (近黑红)
	"_e": Color8(70, 18, 15),     # 边缘暗影 (S×0.8)
	"_h": Color8(190, 70, 40),    # 边缘高光 (L×0.85)
	"_H": Color8(230, 110, 55),   # 顶强高光 (烈焰亮橙)
}

# 黑曜石: 暗黑底 + 紫光泽闪 + 蓝紫高光 (玻璃质感)
const _P_OBSIDIAN := {
	"k": Color8(15, 10, 18),      # 极黑 (主要)
	"K": Color8(8, 5, 12),        # 更深 (阴影)
	"p": Color8(60, 35, 80),      # 暗紫
	"P": Color8(100, 70, 130),    # 紫光泽
	"v": Color8(150, 110, 190),   # 亮紫高光
	"V": Color8(190, 160, 230),   # 极亮紫 (闪点)
	"b": Color8(35, 30, 50),      # 蓝紫深 (过渡)
	# autotile 边缘 4 槽位: 玻璃般暗紫
	"_o": Color8(4, 2, 6),        # 极暗轮廓
	"_e": Color8(20, 12, 30),     # 边缘暗影 (K-darker)
	"_h": Color8(120, 90, 160),   # 边缘高光 (P-brighter)
	"_H": Color8(180, 150, 220),  # 顶强高光 (亮紫)
}

# 砂岩: 暖黄基 + 水平层纹 + 偶发裂纹. 比 SAND 暗 + 有结构感, 适合做"古老金字塔".
const _P_SANDSTONE := {
	"s": Color8(210, 175, 95),    # 砂岩主色 (暖黄)
	"S": Color8(165, 130, 60),    # 阴影
	"l": Color8(235, 200, 130),   # 高光
	"k": Color8(75, 50, 22),      # 黑裂纹
	"m": Color8(195, 155, 80),    # 中间过渡
	"o": Color8(180, 140, 70),    # 层纹深
	"L": Color8(245, 215, 150),   # 极亮
}

# 地狱合金矿: 深紫黑底 + 银闪点 + 紫光泽过渡. 嵌在地狱石上.
# s/S/b 紫黑基底 (像曜石但更紫), L/l 银闪闪点 (高对比, 不像金黄不像红).
const _P_HELL_ALLOY_ORE := {
	"s": Color8(45, 28, 55),     # 紫黑主 (深邃)
	"S": Color8(30, 18, 38),     # 紫黑阴影
	"b": Color8(58, 38, 70),     # 紫黑亮一档
	"L": Color8(225, 230, 245),  # 银亮闪点
	"l": Color8(165, 165, 185),  # 银中
	"m": Color8(195, 195, 215),  # 银偏亮
	"k": Color8(15, 10, 22),     # 极黑裂纹/描边
	"o": Color8(95, 65, 115),    # 紫光泽过渡 (深紫)
	"h": Color8(125, 90, 155),   # 紫光泽亮 (闪点旁)
	"H": Color8(70, 45, 90),     # 紫光泽暗
	"y": Color8(255, 255, 255),  # 极亮银白闪 (稀点)
	"_o": Color8(18, 12, 28), "_e": Color8(45, 30, 60),
	"_h": Color8(180, 180, 200), "_H": Color8(225, 225, 240),
}


# 火果: 红圆果 + 黄/橙高光 + 深红阴影 + 暗叶柄. 16x16 整格但只画下半 + 中间.
const _P_HELL_FRUIT := {
	"n": Color8(28, 10, 8),       # 黑描边
	"r": Color8(225, 65, 45),     # 红主
	"R": Color8(150, 30, 22),     # 深红阴影
	"y": Color8(255, 200, 60),    # 黄高光
	"o": Color8(255, 130, 50),    # 橙过渡
	"s": Color8(85, 50, 30),      # 棕叶柄
	"l": Color8(120, 175, 55),    # 绿叶
}

# 阴影宝箱: 焦黑木板 + 骨白金属 + 红色幽光 + 红眼锁芯, 地狱专属阴森感.
const _P_SHADOW_CHEST := {
	"w": Color8(48, 28, 30),     # 焦黑红木
	"W": Color8(22, 12, 18),     # 极深暗
	"l": Color8(85, 55, 50),     # 微红高光
	"k": Color8(8, 4, 8),        # 极黑描边
	"m": Color8(215, 210, 195),  # 骨白金属
	"M": Color8(150, 145, 130),  # 骨阴影
	"f": Color8(255, 70, 80),    # 红色幽光闪
	"o": Color8(15, 5, 8),       # 锁孔极黑
	"g": Color8(250, 75, 80),    # 红眼瞳
	"G": Color8(160, 20, 35),    # 红眼暗
}

# Mimic chest: 跟普通 chest 同 palette 大部分, 多一个红 r (锁孔/眼) 当线索
const _P_MIMIC_CHEST := {
	# 跟 _P_CHEST 同色, 但锁孔 r=红 (替代 o=黑)
	"w": Color8(168, 116, 69),
	"W": Color8(141, 93, 53),
	"l": Color8(208, 158, 110),
	"k": Color8(40, 25, 15),
	"m": Color8(218, 165, 80),
	"M": Color8(150, 105, 40),
	"f": Color8(248, 200, 110), # 黄铜亮闪 (跟 _P_CHEST 一致)
	"g": Color8(95, 60, 25),    # 木结 (跟 _P_CHEST 一致)
	"r": Color8(220, 35, 35),   # 锁孔红 (替代 o), 仔细看的线索
}

const _P_DOOR := {
	"d": Color8(109, 76, 65),
	"D": Color8(78, 52, 46),
	"l": Color8(141, 110, 99),
	"h": Color8(200, 200, 200), # 把手
}

const _P_BEDROCK := {
	"b": Color8(66, 66, 66),
	"B": Color8(33, 33, 33),
	"l": Color8(97, 97, 97),
	"k": Color8(15, 15, 15),
	# 新增 (T3): 边缘语义槽
	"_o": Color8(8, 8, 8),       # 极暗轮廓 (k×0.55 → 近黑)
	"_e": Color8(33, 33, 33),    # 边缘暗影 (b×0.5 → 深灰)
	"_h": Color8(83, 83, 83),    # 边缘高光 (b+25%)
	"_H": Color8(100, 96, 88),   # 顶强高光 (稍暖)
}

# 深石: STONE 同结构但整体降亮 35% + 暖深底
const _P_DEEP_STONE := {
	"s": Color8(102, 88, 78),
	"S": Color8(72, 60, 52),
	"l": Color8(125, 108, 96),
	"k": Color8(48, 36, 28),
	"L": Color8(140, 122, 108),
	"m": Color8(88, 75, 66),
	"b": Color8(60, 50, 42),
	"o": Color8(122, 96, 72),
	# 新增 (T3): 边缘语义槽
	"_o": Color8(20, 15, 12),    # 极暗轮廓 (k×0.55 → 近黑棕)
	"_e": Color8(50, 40, 33),    # 边缘暗影 (s×0.55 → 深灰棕)
	"_h": Color8(128, 110, 98),  # 边缘高光 (s+25%)
	"_H": Color8(148, 126, 108), # 顶强高光 (暖, R+8 B-8)
}

# 煤矿: STONE 底色 + c/C/h 系列煤块
const _P_COAL_ORE := {
	"s": Color8(75, 68, 60),     # 深煤灰
	"S": Color8(50, 44, 38),     # 暗煤灰
	"l": Color8(95, 85, 75),     # 中煤灰高
	"k": Color8(25, 20, 18),     # 极暗煤
	"L": Color8(115, 105, 95),   # 高煤灰
	"m": Color8(60, 54, 48),     # 中煤灰
	"b": Color8(38, 32, 28),     # 暗煤
	"o": Color8(85, 75, 65),     # 暖煤灰
	"c": Color8(50, 40, 35),
	"C": Color8(28, 22, 20),
	"h": Color8(80, 65, 55),
	"_o": Color8(15, 10, 8),
	"_e": Color8(40, 32, 26),
	"_h": Color8(120, 108, 96),
	"_H": Color8(150, 138, 125),
}

# 铁矿: STONE 底色 + r/R/H 系列铁锈
const _P_IRON_ORE := {
	"s": Color8(195, 100, 60),
	"S": Color8(155, 70, 35),
	"l": Color8(225, 130, 80),
	"k": Color8(95, 35, 15),
	"L": Color8(245, 165, 110),
	"m": Color8(175, 85, 45),
	"b": Color8(130, 55, 25),
	"o": Color8(215, 130, 75),
	"r": Color8(195, 90, 35),
	"R": Color8(145, 55, 20),
	"H": Color8(225, 130, 75),
	"_o": Color8(50, 18, 8),
	"_e": Color8(110, 45, 20),
	"_h": Color8(240, 165, 110),
	"_H": Color8(255, 185, 130),
}

# ─── 新矿石调色板 (STONE 底色 + 矿色 + 边缘槽位 同 STONE) ─────────────

# 铜矿: STONE 底 + u/U/p 暖橙铜
const _P_COPPER_ORE := {
	"s": Color8(220, 130, 60), "S": Color8(175, 80, 25),
	"l": Color8(245, 165, 90), "k": Color8(110, 50, 15),
	"L": Color8(255, 195, 130), "m": Color8(200, 110, 50),
	"b": Color8(150, 65, 20),   "o": Color8(240, 150, 75),
	"u": Color8(230, 115, 40),
	"U": Color8(175, 60, 15),
	"p": Color8(255, 165, 80),
	"_o": Color8(60, 28, 10), "_e": Color8(125, 55, 18),
	"_h": Color8(255, 175, 100), "_H": Color8(255, 200, 130),
}

# 锡矿: STONE 底 + n/N/x 银白
const _P_TIN_ORE := {
	"s": Color8(170, 195, 210), "S": Color8(125, 155, 175),
	"l": Color8(195, 220, 235), "k": Color8(85, 110, 130),
	"L": Color8(220, 240, 250), "m": Color8(150, 175, 195),
	"b": Color8(105, 130, 150), "o": Color8(180, 205, 220),
	"n": Color8(170, 220, 235),
	"N": Color8(95, 145, 175),
	"x": Color8(220, 250, 255),
	"_o": Color8(45, 65, 85), "_e": Color8(100, 125, 145),
	"_h": Color8(215, 235, 245), "_H": Color8(235, 250, 255),
}

# 金矿: STONE 底 + g/G/y 暖金
const _P_GOLD_ORE := {
	"s": Color8(225, 185, 95),  "S": Color8(175, 135, 50),
	"l": Color8(245, 215, 130), "k": Color8(110, 80, 20),
	"L": Color8(255, 235, 165), "m": Color8(205, 165, 75),
	"b": Color8(155, 115, 40),  "o": Color8(235, 195, 110),
	"g": Color8(235, 195, 70),
	"G": Color8(180, 140, 25),
	"y": Color8(255, 230, 130),
	"_o": Color8(70, 50, 8), "_e": Color8(135, 100, 30),
	"_h": Color8(255, 235, 145), "_H": Color8(255, 245, 175),
}

# 钻石矿: STONE 底 + d/D/x 青蓝
const _P_DIAMOND_ORE := {
	"s": Color8(130, 200, 230), "S": Color8(80, 155, 195),
	"l": Color8(170, 225, 245), "k": Color8(40, 100, 145),
	"L": Color8(205, 240, 250), "m": Color8(110, 180, 215),
	"b": Color8(65, 130, 175),  "o": Color8(140, 205, 235),
	"d": Color8(130, 205, 235),
	"D": Color8(55, 130, 175),
	"x": Color8(220, 250, 255),
	"_o": Color8(15, 65, 105), "_e": Color8(55, 120, 165),
	"_h": Color8(200, 235, 250), "_H": Color8(225, 250, 255),
}

# 水: 几乎纯色海蓝 + 极少数微亮点. 邻 tile 拼一起视觉无缝.
# 差别压到很小: a→b 颜色差 ~10, a→c 颜色差 ~20. 远看完全融成一片.
const _P_WATER := {
	"a": Color8(60, 130, 215, 220),   # 海蓝主色 (95% 区域)
	"b": Color8(70, 140, 220, 220),   # 微浅 (跟 a 差 10, 几乎看不出)
	"c": Color8(85, 155, 230, 220),   # 浅一点点 (跟 a 差 20, 像水下微光)
}

# 地狱晶体: DEEP_STONE 底 (更暗背景烘托) + h/H/y 烈火红
const _P_HELL_CRYSTAL := {
	# 用户改: 火魂黄 (亮金+橙+焰白闪点), 不再是红
	"s": Color8(180, 130, 30),  "S": Color8(125, 85, 15),    # 琥珀金底 + 深金影
	"l": Color8(225, 175, 55),  "k": Color8(50, 30, 8),      # 金中亮 + 黑裂纹
	"L": Color8(255, 220, 90),  "m": Color8(220, 130, 35),   # 亮黄高光 + 焰橙过渡
	"b": Color8(80, 50, 15),    "o": Color8(245, 200, 70),   # 黑棕暗 + 金亮
	"h": Color8(255, 245, 160), "H": Color8(255, 150, 50),   # 极亮黄白 + 烈焰橙
	"y": Color8(255, 255, 220),                              # 火魂闪点 (近白)
	"_o": Color8(40, 25, 5), "_e": Color8(95, 65, 15),       # 边暗
	"_h": Color8(245, 200, 100), "_H": Color8(255, 230, 140),# 边亮
}


# 背景墙: 比对应方块暗 ~50%, 图案更糊 (少高光多深色, 偶尔小石子)
# 草墙: 顶部 1 行深绿根 + 下面深棕土
const _P_GRASS_WALL := {
	"d": Color8(80, 62, 44),    # 深暖棕基 (DIRT 颜色 × 0.5)
	"D": Color8(58, 44, 30),    # 更深棕
	"v": Color8(54, 80, 38),    # 深绿根
	"V": Color8(38, 58, 28),    # 深绿根阴影
	"k": Color8(38, 28, 20),    # 黑石子
	# 新增 (T3): 边缘语义槽 (墙低对比度, 高光范围小)
	"_o": Color8(16, 11, 7),    # 极暗轮廓 (k×0.55)
	"_e": Color8(48, 36, 25),   # 边缘暗影 (d×0.6)
	"_h": Color8(90, 70, 50),   # 边缘高光 (d+12%, 低对比)
	"_H": Color8(102, 78, 54),  # 顶强高光 (d+20%, 暖)
}
# 木墙: 木板纹路 (跟 PLANKS 同构, 但偏暗 70% 适合背景), col 0 == col 15 可平铺
const _P_FURNACE := {
	"s": Color8(120, 110, 100),   # 石灰色身
	"S": Color8(85, 75, 68),      # 暗灰
	"k": Color8(40, 32, 28),      # 黑描边
	"R": Color8(220, 90, 40),     # 火焰橙红 (内部)
	"r": Color8(255, 160, 60),    # 火焰亮黄
	"y": Color8(255, 230, 130),   # 火焰最亮
}

const _P_COOKING_POT := {
	".": Color(0, 0, 0, 0),       # 透明背景
	"k": Color8(35, 30, 28),      # 黑铁描边
	"i": Color8(70, 66, 64),      # 铁锅身灰
	"I": Color8(105, 100, 96),    # 锅身高光
	"R": Color8(220, 90, 40),     # 火焰橙红
	"r": Color8(255, 160, 60),    # 火焰亮黄
	"y": Color8(255, 230, 130),   # 火焰最亮
}


const _P_WOOD_WALL := {
	"p": Color8(118, 80, 48),   # 木板基色 (planks p×0.7)
	"P": Color8(92, 60, 33),    # 暗木 (planks P×0.65)
	"l": Color8(140, 100, 65),  # 亮高光 (稀疏)
	"k": Color8(50, 32, 18),    # 板缝 (k×0.5)
	# 新增 (T3): 边缘语义槽 (墙低对比度)
	"_o": Color8(28, 18, 8),    # 极暗轮廓
	"_e": Color8(75, 50, 28),   # 边缘暗影 (e 由 _WALL_STYLE 引用)
	"_h": Color8(135, 95, 60),  # 边缘高光
	"_H": Color8(155, 110, 72), # 顶强高光
}
# 土墙: 均匀深棕 + 零星小石子, 偶尔微亮
const _P_DIRT_WALL := {
	"d": Color8(80, 60, 40),
	"D": Color8(58, 42, 28),
	"k": Color8(38, 26, 16),
	"l": Color8(96, 76, 54),    # 微亮 (稀疏)
	# 新增 (T3): 边缘语义槽 (墙低对比度)
	"_o": Color8(15, 10, 6),    # 极暗轮廓 (k×0.55)
	"_e": Color8(46, 34, 22),   # 边缘暗影 (d×0.58)
	"_h": Color8(90, 68, 46),   # 边缘高光 (d+12%)
	"_H": Color8(100, 74, 48),  # 顶强高光 (d+20%, 暖)
}
# 石墙: 均匀深暖灰 + 黑裂纹
const _P_STONE_WALL := {
	"s": Color8(78, 72, 68),    # 深暖灰 (STONE × 0.5)
	"S": Color8(56, 50, 46),
	"k": Color8(34, 28, 24),
	"l": Color8(96, 88, 80),    # 微亮
	# 新增 (T3): 边缘语义槽 (墙低对比度)
	"_o": Color8(14, 11, 9),    # 极暗轮廓 (k×0.55)
	"_e": Color8(44, 40, 38),   # 边缘暗影 (s×0.58)
	"_h": Color8(88, 81, 76),   # 边缘高光 (s+12%)
	"_H": Color8(100, 92, 86),  # 顶强高光 (s+20%, 稍暖)
}

# 仙人掌: 暖深绿主体 + 白尖刺 + 浅绿高光
const _P_CACTUS := {
	"g": Color8(74, 138, 65),    # 暖中绿 (主体)
	"G": Color8(48, 95, 44),     # 深绿阴影
	"h": Color8(120, 180, 90),   # 黄绿高光
	"d": Color8(28, 58, 30),     # 最深绿 (轮廓)
	"w": Color8(255, 255, 220),  # 白尖刺
	"y": Color8(195, 200, 110),  # 微黄高光 (棱线)
}

# 火把 tile: 木棍底 + 暖色火苗 (静态视觉，动画 fx 由 TorchFx 叠加)
const _P_TORCH := {
	"b": Color8(74, 52, 41),
	"r": Color8(110, 80, 67),
	"h": Color8(150, 110, 80),
	"f": Color8(255, 180, 50),
	"F": Color8(220, 100, 30),
	"d": Color8(170, 60, 20),
}

# --- 图案 (每方块 16x16) ---

# 草方块：参差不齐草尖 (透空+金黄y+穗s) → 多层暖绿 (a/g/m/G) → 草根下垂 (r) → 暖泥
const _GRASS := [
	".y..s.y.s.a.y.s.",
	"ayasaysaygasaaya",
	"gagmgaGmgaGmgagm",
	"mgGmgmGgmGgmGgGm",
	"GgmGgGmgGgmGgGmg",
	"gGdgrgGdgrGdgrGd",
	"drddrddgddrddddg",
	"dDdldDddkddDdddl",
	"ddDdddDddlddrddd",
	"DdlrddddDddkdddd",
	"ddDddrdDddddddDd",
	"ddrdkddddrddDddd",
	"dDdddDdddrkddDdd",
	"drdddddDdldDdddd",
	"ddDdddrddkdDdddd",
	"Ddrdddrkddrdldrd",
]

# 泥土：暖土团块 (LL+边缘 o 暖橙) + 红棕 (r) 砂粒 + 冷棕 (p) + 深石子 (k) 细节
const _DIRT := [
	"dDdpdDdDdpdDdpdD",
	"dlddddrddpkddpdd",
	"ddoLLddddDLLdrdd",
	"dDoLLrdddDLLdkdd",
	"dpddDdoLLdrkdLLd",
	"ddpdrddLLddDddLd",
	"ddDdrkddrdkdrkdd",
	"dpdddDdpdldDdldD",
	"dllLdpddrdkdldDd",
	"dpdLLrddpdddrDdd",
	"DdddorddddLLkdpd",
	"ddpdDodddpdLLrdd",
	"dDdrdLLddpdddoDd",
	"dpddrdDdkddpdkdD",
	"drDdpdrddoddDddo",
	"DdpdrdDpdrdpDdrd",
]

# 石头：暖灰岩石块 (LL 凸块带 o 暖砂岩高光) + 横向裂纹 (kkkk) + 中灰 m / 深灰 b
const _STONE := [
	"SbsSsbsSsbsSsbsS",
	"smLLkssssooLLkss",
	"sLLLkssksslLLkss",
	"sslksskkkkksslkk",
	"somLLLsksslkmLss",
	"soLLLLssllksLLls",
	"ssLLLkssbkssLLLs",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sLLkssolksLLLkbs",
	"sLLslkkbskssLLls",
	"ssssLLLLossolssm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 沙：横向波纹 (Y 浅条) + 暖橙 o/b 沙粒 + 凸起沙丘 (LL) + 偶发暗石 (k)
const _SAND := [
	"yYyyyYyyyYyyyYyy",
	"yllyybyybyybyylo",
	"yobyyyykyyyybyyy",
	"yLLLlyybyobyyyly",
	"Ybobyybkyybobyyy",
	"yyyyobyyooyyybky",
	"yyobyLLlyybyykyo",
	"yyybLLLlobyykyly",
	"yyyobLLlyybyyooy",
	"yloyyybyobyykyyy",
	"Ybyyobyyyykyybyo",
	"yyobyybyyybobyyy",
	"yyybLLlyobyykyyy",
	"yYobLLlyyykyyybo",
	"Ybobyyykyybobyko",
	"yYyyyYyyyYyyyYyy",
]

# 树枝 / 树根 调色板 (混 log + leaves 用)
const _P_BRANCH := {
	"b": Color8(124, 86, 64),    # log 基
	"B": Color8(85, 53, 41),     # log 深
	"l": Color8(163, 133, 115),  # log 高光
	"r": Color8(108, 70, 54),    # log 中调
	"g": Color8(125, 173, 92),   # 叶绿
	"L": Color8(86, 129, 74),    # 叶阴
	"h": Color8(164, 197, 122),  # 叶高光
	"d": Color8(58, 89, 56),     # 叶深
}


# 树干顶帽: 像 LOG 但顶上多一条暗 "圆环 cap" 让树干顶部不那么生硬
const _LOG_TOP := [
	"bBBBBBBBBBBBBBBB",
	"BBlrBBlbBBblrBBb",
	"bBblbBblbBblbBbl",
	"brblbBplbBblbBol",
	"bBblbBblbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBpbBRRBbBblbBbl",
	"bBblbrblbBblbBbl",
	"brblbBblpBblrBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBplbRRl",
	"bBblbBblbBblbRRl",
	"bBblbBblobblbrbl",
	"brblbBplbBblbBbl",
	"bBblbBblbBblbBpl",
	"bbBbpBbpBbBbpBbB",
]


# 树根 左侧: 放在树干左下, 从右上 (连接树干) 向左下扩散
const _LOG_ROOT_L := [
	"................",
	"................",
	"................",
	"................",
	".............bBb",
	"............bBbl",
	"...........bBblb",
	"..........bBblbB",
	".........bBblbBb",
	"........bBblbBbb",
	".......bBblbBblb",
	"......bBblbBblbb",
	".....bBblbBblbBb",
	"....bBblbBblbBbl",
	"...bBplbBplbBplb",
	"..bBblbBblbBblbB",
]


# 树根 右侧: 镜像
const _LOG_ROOT_R := [
	"................",
	"................",
	"................",
	"................",
	"bBb.............",
	"lbBb............",
	"blbBb...........",
	"BblbBb..........",
	"bBblbBb.........",
	"bbBblbBb........",
	"blbBblbBb.......",
	"bblbBblbBb......",
	"bBblbBblbBb.....",
	"lbBblbBblbBb....",
	"blpBblpBblpBb...",
	"BblbBblbBblbBb..",
]


# 左侧枝: 从右 (贴树干) 向左伸出, 末端带小叶簇
const _BRANCH_L := [
	"................",
	"................",
	"................",
	"............bBb.",
	"...........bBblb",
	"....dhd.bBblbBbb",
	"...hLLLhbBblbBbb",
	"..hgLLLhbbBlbBbb",
	"..hgLLLhdbBlbBbb",
	"...hdgLhbbBlbBbb",
	"....hdhbbBblbBbb",
	".....hbBblbBblbb",
	"......bBblbBblbB",
	"................",
	"................",
	"................",
]


# 右侧枝: 镜像
const _BRANCH_R := [
	"................",
	"................",
	"................",
	".bBb............",
	"blbBb...........",
	"bbBblbBb.dhd....",
	"bbBblbBbhLLLh...",
	"bbBblbBbhLLLgh..",
	"bbBlbBbdhLLLgh..",
	"bbBlbBbbhLgdh...",
	"bbBlbBbbhdh.....",
	"bblbBblbBbh.....",
	"BblbBblbBb......",
	"................",
	"................",
	"................",
]


# 原木：暖竖纹树皮 (4 道凹沟 B + 凸条 l) + 2 个木结 (RR 带 B 框) + 中树皮 r + 樱木暖橙 o 微调
# 麻绳: 中央 4-6 px 宽双股扭绳, 透明边. 16×16. 用户改: 老复用 _LOG 太像木头, 现在专门画.
# 4px 窄段 (HhhH) 跟 6px 宽段 (HhllhH) 交替, 模拟扭股的明暗起伏.
const _ROPE := [
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
	"......HhhH......",
	".....HhllhH.....",
]

const _LOG := [
	"bBbpBbbBpbBbpBbB",
	"bBblrBblbBblrBbl",
	"brBlbBblpBblbBol",
	"bBblbBplbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBpbBRRBbBblbBbl",
	"bBblbrblbBblbBbl",
	"brblbBblpBblrBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBplbRRl",
	"bBblbBblbBblbRRl",
	"bBblbBblobblbrbl",
	"brblbBplbBblbBbl",
	"bBblbBblbBblbBpl",
	"bbBbpBbpBbBbpBbB",
	"bbbBbbBbbBbbBbpb",
]

# 橡木叶：4 角透空 + 多个叶簇 (簇心 h 高光 + d 阴影框) + 秋红浆果 r + 金橄榄 y + 鼠尾草 a
const _LEAVES := [
	".lhLh....hLhl.h.",
	"lLhddhlllhddhLls",
	"Lddyhddssddyhdds",
	"lLyddhsssddyaLls",
	"llLLLsLLLLsLLLll",
	"lLLddhhhhhhddLLs",
	"Lddhhddrrddhhddl",
	"Lddysssssyydddal",
	"lddysssssyyddddl",
	"Lddhhddrrddhhddl",
	"lLLddhhhhhhddLLs",
	"llLLLsLLLLsLLLll",
	"lLyddhsssddyaLls",
	"Lddyhddssddyhdds",
	"lLhddhlllhddhLls",
	".lhLh....hLhl.h.",
]

# 松针：密实无透角 + 矩形针簇 + 暗影包裹 + 偶发松果 y
const _LEAVES_PINE := [
	"ddLddLLLLLLddLdd",
	"dLLddssddssddLLd",
	"LdsshhhhhhhhssdL",
	"LdssddhhhhddssdL",
	"LhddssssssssddhL",
	"LssLLddddddLLssL",
	"LssLddhhhhddLssL",
	"LssLddhyyhddLssL",
	"LssLddhyyhddLssL",
	"LssLddhhhhddLssL",
	"LssLLddddddLLssL",
	"LhddssssssssddhL",
	"LdssddhhhhddssdL",
	"LdsshhhhhhhhssdL",
	"dLLddssddssddLLd",
	"ddLddLLLLLLddLdd",
]

# 秋叶：橡木叶骨架,色调换成橙红/金黄/深红浆果 r
const _LEAVES_AUTUMN := [
	".lhLh....hLhl.h.",
	"lLhddhlllhddhLla",
	"Lddyhddrrddyhddr",
	"lLyddhrrrddyaLla",
	"llLLLrLLLLrLLLll",
	"lLLddhhhhhhddLLs",
	"Lddhhddyyddhhddl",
	"LddyrrrrryydddrL",
	"lddyrrrrryyddddl",
	"Lddhhddyyddhhddl",
	"lLLddhhhhhhddLLs",
	"llLLLrLLLLrLLLll",
	"lLyddhrrrddyaLla",
	"Lddyhddrrddyhddr",
	"lLhddhlllhddhLla",
	".lhLh....hLhl.h.",
]

# 史莱姆灯: 跟 TORCH 同结构, 颜色换绿 — 像绿色火苗在木棍上
# h = 黄绿高光 (最亮核心), g = 绿基, G = 深绿阴影, b = 木棍, r = 木棍亮
const _SLIME_TORCH := [
	"................",
	"................",
	"......hh........",
	".....hggh.......",
	"....hggggh......",
	"....hggggh......",
	".....ggGg.......",
	".....rbhr.......",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"................",
]

# 蓝光蘑菇: 圆顶蓝盖 + 白柄 + 白点 (矿洞蘑菇地装饰, 站在 floor 行)
const _P_MUSHROOM := {
	"n": Color8(28, 30, 48),     # 极深蓝紫描边
	"b": Color8(110, 165, 235),  # 蓝盖主色 (亮蓝)
	"B": Color8(60, 105, 185),   # 蓝盖阴影
	"s": Color8(240, 245, 255),  # 白点 / 柄高光
	"w": Color8(220, 225, 240),  # 柄主色 (略带蓝白)
	"W": Color8(170, 180, 210),  # 柄阴影
}
const _MUSHROOM := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......nnnnn.....",
	".....nbbbBBn....",
	"....nbsbbBBBn...",
	"....nbbbbBBBn...",
	".....nbBBBBn....",
	"......nnnnn.....",
	"......nwwn......",
	"......nwWn......",
	"......nwWn......",
	"......nnnn......",
]

# 木平台: 中间 2 行薄木板 (Terraria 风, 上下透明)
const _WOOD_PLATFORM := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"llllllllllllllll",
	"kkkkkkkkkkkkkkkk",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _PLANKS := [
	"pppppppppppppppp",
	"ppPpppppllpppPpp",
	"pppppPpppppPpppp",
	"kkkkkkkkkkkkkkkk",
	"pppppppppppPpppp",
	"pPpppllpppppppPp",
	"ppppppppPpppppll",
	"kkkkkkkkkkkkkkkk",
	"pppPpppllpppPppp",
	"pppppppppppppppp",
	"pPpppppPpppllppp",
	"kkkkkkkkkkkkkkkk",
	"ppplllpppPppppPp",
	"pPppppppppppppll",
	"ppppPpppppppPppp",
	"kkkkkkkkkkkkkkkk",
]

# 工作台：木板基底 + 顶部工具痕迹
const _WORKBENCH := [
	"kkkkkkkkkkkkkkkk",
	"klllllllllllllPk",
	"kloooooollolllPk",
	"klooPPoollloollk",
	"kloooooollllooll",
	"kllllllllllllllk",
	"kkkkkkkkkkkkkkkk",
	"pppppPppppPppppp",
	"pPpppppppppppPpp",
	"kkkkkkkkkkkkkkkk",
	"ppppppPpppppPppp",
	"pPpppppppppppppl",
	"kkkkkkkkkkkkkkkk",
	"ppllpppppPpppppp",
	"pPpppppPpppppllp",
	"kkkkkkkkkkkkkkkk",
]

# 箱子 (CHEST): 16x16, 上盖 + 金属包带 + 锁孔
const _CHEST := [
	"................",
	".kkkkkkkkkkkkkk.",
	".kmfmwlwwwlwmfm.",   # top: 黄铜角 + 木纹高光
	".kmmwwwwlwwwwmm.",
	".kmwlwgwwwgwlwk.",   # 木结 g
	".kkkkkkkkkkkkkk.",   # 盖体分隔条
	".kwlwwmfMmwwwlk.",   # 锁面板 + 锁孔
	".kwwwwmMomMmwwk.",   # o = 锁孔, M/m 锁面
	".kwlwwmMmMmwwlk.",
	".kwwwwwmmmwwwwk.",
	".kwlwwwwwwwwlwk.",
	".kwgwlwwwwlwgwk.",   # 木结 + 木纹
	".kkkkkkkkkkkkkk.",
	".kmfmwwwwwwwmfm.",   # 底带 + 角金属
	".kkkkkkkkkkkkkk.",
	"................",
]

# 岩浆: 主要黄橙 (y/o) + 偶发亮闪点 (h) + 暗气泡 (R) + 红丝 (r)
# 看起来"在动"的感觉靠不均匀分布, 不是真正动画 (后续可加 4 帧轮换)
const _LAVA := [
	"yyooyyyyooyyyooy",
	"yoyhyyyoryyooryo",
	"yyyooyyyyhyooyoy",
	"oyyooyyyrRyyyyyy",
	"yhyyooyyyyyooyor",
	"oyyyyooyyhyyyyyo",
	"yyooyyooyhooyyor",
	"yooooyooyooyyyhy",
	"oyooryyoryoryoyo",
	"yhyyyyyyhyyooyoo",
	"yooyrooyyoooohyo",
	"oyhyooyyhyooyyyo",
	"yyooyyoryyoryyoo",
	"oyyhoryooyooyooy",
	"yyooryooyhooyyor",
	"yoyyooyyooRyyyoy",
]

# 地狱石: 跟 _STONE 同形 (4 角 highlight + L/L 簇 + k 裂纹 + m 焰点)
# 通过 palette 切换成烈火红, 视觉熔岩石. 复用 STONE 结构保证 autotile 兼容.
const _HELL_STONE := [
	"SbsSsbsSsbsSsbsS",
	"smLLkssssooLLkss",
	"sLLLkssksslLLkss",
	"sslksskkkkksslkk",
	"somLLLsksslkmLss",
	"soLLLLssllksLLls",
	"ssLLLkssbkssLLLs",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sLLkssolksLLLkbs",
	"sLLslkkbskssLLls",
	"ssssLLLLossolssm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 黑曜石: 大量黑底 + 紫光闪点散布. 看起来像火山玻璃, 反着光.
const _OBSIDIAN := [
	"KkkkKkkkkKkkkKkk",
	"kkkpkkkkkkpkkkkk",
	"kkkkkkKkkbkkPkkk",
	"kkbkkkkkkkkkkkkk",
	"kkkkkVkkkkkkkkkk",
	"KkkkkkkKbkkkpkkk",
	"kkpkkkkkkkkkkkkb",
	"kkkkkkkbkkkbkkkK",
	"kkkkkPkkkkkkkkkk",
	"kbkkkkkkKkkkpkkk",
	"kkkkkkkkkkkkkkVk",
	"kkkkkkkkkkkkkkkk",
	"kkkkkkkkkkpkkkkK",
	"kkkpkkbkkkkkkkkk",
	"Kkkkkkkkkkkkkkkk",
	"kkkkkkkkkkPkkkkk",
]

# 火果: 红圆果挂在天花板, 上有短棕枝 + 1 片绿叶. 视觉像泰拉瑞亚地狱农圣果.
const _HELL_FRUIT := [
	"................",
	".......s........",
	".......s........",
	"......sl........",
	".....nrrn.......",
	"....nrrrrn......",
	"...nryyyrrn.....",
	"..nryryyyrrn....",
	"..nrrryyrrrn....",
	"..nrrrrrrrrn....",
	"..nRrrrrrrRn....",
	"...nRrrrrRn.....",
	"....nRRRRn......",
	".....nnnn.......",
	"................",
	"................",
]

# Mimic 看起来像普通 chest, 但锁孔是红色 (o → r). 仔细看的玩家能识别陷阱.
# 金宝箱: 顶/底厚金边 + 中央大红宝石锁面板. 看一眼就识别 "贵气".
const _GOLD_CHEST_PAT := [
	"................",
	".kmmmmmmmmmmmmk.",   # 顶部宽金边
	".kmfmfmfmfmfmmk.",   # 金高光纹
	".kmmmmmmmmmmmmk.",
	".kwwwlwwwwwlwwk.",   # 深木板身
	".kwlwwwwwwwwwlk.",
	".kwwmMGggGMmwwk.",   # 锁盘 + 红宝石 g/G
	".kwwmGgggggGmwk.",   # 红宝中央
	".kwwmMGgGGgMmwk.",
	".kwwwmMmmmMmwwk.",   # 锁盘下沿
	".kwwwwwwwwwwwwk.",
	".kwlwwwwlwwwwlk.",
	".kmmmmmmmmmmmmk.",   # 底厚金边
	".kmfmfmfmfmfmmk.",
	".kmmmmmmmmmmmmk.",
	"................",
]

# 钻石宝箱: 4 角水晶突出 + 中央蓝宝石锁. 神秘冰冷.
const _DIAMOND_CHEST_PAT := [
	"................",
	".kmmkkkkkkkkmmk.",   # 顶 2 角水晶 m
	".kmffkwwwwwkffmk",   # 水晶高光 f
	".kkkkwwwwwwwkkk.",
	".kwwlwwwwwlwwwk.",   # 深蓝紫木身
	".kwwwwwwwwwwwwk.",
	".kwwlmMGgGMmlwk.",   # 锁面 + 蓝宝石
	".kwwwmGgggGmwwk.",
	".kwwlmMGgGMmlwk.",
	".kwwwwwwwwwwwwk.",
	".kwlwwwwwwwwlwk.",
	".kkkkwwwwwwwkkk.",
	".kmffkwwwwwkffmk",   # 底 2 角水晶
	".kmmkkkkkkkkmmk.",
	".kkkkkkkkkkkkkk.",
	"................",
]

# 阴影宝箱: 锯齿黑顶/底 + 红色幽光裂缝 + 骨白金属 + 红眼锁芯. 地狱阴森.
const _SHADOW_CHEST_PAT := [
	"................",
	".kmkmkmkmkmkmkm.",   # 锯齿黑顶
	".kmmmmmmmmmmmmk.",
	".kkkkkkkkkkkkkk.",
	".kwwlfwwwwwfwlw.",   # 红光闪点 f
	".kwwwwwwfwwwwwk.",   # 中央火光
	".kwwlmGggggGmlwk",   # 锁面 + 红眼
	".kwwwmgggGggmwwk",
	".kwwlmGggggGmlwk",
	".kwwwwwwfwwwwwk.",   # 又一火光
	".kwfwwwwwwwwfwk.",
	".kkkkkkkkkkkkkk.",
	".kmmmmmmmmmmmmk.",
	".kmkmkmkmkmkmkm.",   # 锯齿黑底
	"................",
	"................",
]


# Mimic: 跟新 _CHEST 形状几乎一样, 只有锁孔从 o 换 r (红眼). 仔细看的玩家才能识别陷阱.
const _MIMIC_CHEST := [
	"................",
	".kkkkkkkkkkkkkk.",
	".kmfmwlwwwlwmfm.",
	".kmmwwwwlwwwwmm.",
	".kmwlwwwwwwwlwk.",
	".kkkkkkkkkkkkkk.",
	".kwlwwmfMmwwwlk.",
	".kwwwwmMrmMmwwk.",   # r = 红眼 (替代 o 锁孔)
	".kwlwwmMmMmwwlk.",
	".kwwwwwmmmwwwwk.",
	".kwlwwwwwwwwlwk.",
	".kwwwlwwwwlwwwk.",
	".kkkkkkkkkkkkkk.",
	".kmfmwwwwwwwmfm.",
	".kkkkkkkkkkkkkk.",
	"................",
]

# 门 (关) — 占 1 tile，门顶用 Door scene 上方延伸
const _DOOR_CLOSED := [
	"DDDDDDDDDDDDDDDD",
	"DllllllllllllllD",
	"DldddddddddddldD",
	"DldDDDDDDDDDDldD",
	"DldDddddddddDldD",
	"DldDdhhdddddDldD",
	"DldDdhhdddddDldD",
	"DldDddddddddDldD",
	"DldDddddddddDldD",
	"DldDddddddddDldD",
	"DldDddddddddDldD",
	"DldDddddddddDldD",
	"DldDddddddddDldD",
	"DldDDDDDDDDDDldD",
	"DllllllllllllllD",
	"DDDDDDDDDDDDDDDD",
]

# 门上半截 (DOOR_TOP): 顶端 + 小窗 + 木板. 跟 DOOR 接缝, 整体 2 格高门.
const _DOOR_TOP_CLOSED := [
	"DDDDDDDDDDDDDDDD",
	"DllllllllllllllD",
	"DlDDDDDDDDDDDDlD",
	"DlDddddddddddDlD",
	"DlDdwwwwwwwwdDlD",
	"DlDdwddddddwdDlD",
	"DlDdwddddddwdDlD",
	"DlDdwwwwwwwwdDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DlDddddddddddDlD",
	"DllllllllllllllD",
	"DDDDDDDDDDDDDDDD",
]

# 门 (开) — 显示为侧面窄条
const _DOOR_OPEN := [
	"DDDDDDDDDDDD....",
	"DllllllllllD....",
	"DldddddddldD....",
	"DldDDDDDDldD....",
	"DldDdddddldD....",
	"DldDdhhddldD....",
	"DldDdhhddldD....",
	"DldDdddddldD....",
	"DldDdddddldD....",
	"DldDdddddldD....",
	"DldDdddddldD....",
	"DldDdddddldD....",
	"DldDdddddldD....",
	"DldDDDDDDldD....",
	"DllllllllllD....",
	"DDDDDDDDDDDD....",
]

const _BEDROCK := [
	"bbbBBbbbbBBbbbbb",
	"bbBkBbbBBkkBbbBb",
	"bblBBblbBkkBbbbb",
	"bbBBblbbbbbBbBBb",
	"BbbBbbblbblbBkBb",
	"bbblbbbBkBbbBkBb",
	"bbBBbbblbbbbbblB",
	"bblBBbbBkkBbbblB",
	"bbBkkBbBkkBbBBbb",
	"bbBkkBbBBBbbbBkB",
	"bbBBBbblbbbbbBkB",
	"bbblbbbBkBbbbBBb",
	"bbBkBbbBkBbblbbb",
	"bbBkBbblBBblbbbb",
	"BbbBBblbbbbbbblB",
	"bblbbbbbbbblbbbB",
]

# 深石: STONE 同骨架但更密裂纹 + 暗调
const _DEEP_STONE := [
	"SbsSsbsSsbsSsbsS",
	"smbbkssssoobbkss",
	"sbbbkssksslbbkss",
	"sslksskkkkksslkk",
	"sombbbsksslkmbss",
	"sobbbbsslbksbbls",
	"ssbbbkssbkssbbbs",
	"sbkkkkbsslkkkkls",
	"sombsbbbsskbbbms",
	"sbbkssolksbbbkbs",
	"sbbslkkbskssbbls",
	"ssssbbbbossolssm",
	"sombsbbbkssbkbbs",
	"sslkkkbsslkbbbss",
	"sombssklllksmsbs",
	"sSsbsSsSsbsSsSss",
]

# 煤矿: STONE 底 + 3 簇煤块 (左上 / 中右 / 左下)
const _COAL_ORE := [
	"SbsSsbsSsbsSsbsS",
	"sccChssssooLLkss",
	"scCCkssksslLLkss",
	"scchkkkkkkksslkk",
	"somLLLsksslcCCss",
	"soLLLLssllkcChls",
	"ssLLLkssbkscCCks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"scCkssolksLLLkbs",
	"cCCslkkbskssLLls",
	"chsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 铁矿: STONE 底 + 3 簇铁锈斑
const _IRON_ORE := [
	"SbsSsbsSsbsSsbsS",
	"srRHkssssooLLkss",
	"sRRRkssksslLLkss",
	"srhkkskkkkksslkk",
	"somLLLsksslrRHss",
	"soLLLLssllkrRhls",
	"ssLLLkssbkssRRks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sRhkssolksLLLkbs",
	"rRRslkkbskssLLls",
	"sHsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# ─── 新矿石图案 (STONE 骨架, 替换 r/R/H → 各矿色) ──────────────────────

# 铜矿: u 暖橙铜基 + U 深铜 + p 高光
const _COPPER_ORE := [
	"SbsSsbsSsbsSsbsS",
	"suUpkssssooLLkss",
	"sUUUkssksslLLkss",
	"supkkskkkkksslkk",
	"somLLLsksslUUUss",
	"soLLLLssllkUUpls",
	"ssLLLkssbkssUUks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sUpkssolksLLLkbs",
	"uUUslkkbskssLLls",
	"spsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 锡矿: n 银白基 + N 深锡 + x 高光近白
const _TIN_ORE := [
	"SbsSsbsSsbsSsbsS",
	"snNxkssssooLLkss",
	"sNNNkssksslLLkss",
	"snxkkskkkkksslkk",
	"somLLLsksslNNNss",
	"soLLLLssllkNNxls",
	"ssLLLkssbkssNNks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sNxkssolksLLLkbs",
	"nNNslkkbskssLLls",
	"sxsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 金矿: g 暖金 + G 深金 + y 高光
const _GOLD_ORE := [
	"SbsSsbsSsbsSsbsS",
	"sgGykssssooLLkss",
	"sGGGkssksslLLkss",
	"sgykkskkkkksslkk",
	"somLLLsksslGGGss",
	"soLLLLssllkGGyls",
	"ssLLLkssbkssGGks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sGykssolksLLLkbs",
	"gGGslkkbskssLLls",
	"sysLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 钻石矿: d 青蓝基 + D 深钻 + x 高光近白
const _DIAMOND_ORE := [
	"SbsSsbsSsbsSsbsS",
	"sdDxkssssooLLkss",
	"sDDDkssksslLLkss",
	"sdxkkskkkkksslkk",
	"somLLLsksslDDDss",
	"soLLLLssllkDDxls",
	"ssLLLkssbkssDDks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sDxkssolksLLLkbs",
	"dDDslkkbskssLLls",
	"sxsLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 银矿: STONE 底 + 散落 5-6 颗亮闪 sparkle (跟其它矿不同形状 — 稀疏点而非团块)
const _SILVER_ORE := [
	"SbsSsbsSsbsSsbsS",
	"sssssvssssssssss",
	"sssvVvsssssssvss",
	"sssVVVssssssvVvs",
	"ssssvssssssssvss",
	"sssssssksbksssss",
	"sslkkkkbsskkkssl",
	"somsLLLsssLLLmss",
	"sssvssolksLLLkbs",
	"ssvVvslkkbskvsss",
	"sssVVVssolsvVvss",
	"sssvvssolssssvss",
	"sslLLLkssbkLLsss",
	"sslkkkbsslkLLLss",
	"sssvsklllksmsLls",
	"sSsbsSsSsbsSsSss",
]

# 银矿 palette: STONE 灰 + v 银白 sparkle
const _P_SILVER_ORE := {
	"s": Color8(195, 200, 210), "S": Color8(150, 158, 175),
	"l": Color8(220, 225, 235), "k": Color8(100, 105, 120),
	"L": Color8(240, 245, 250), "m": Color8(175, 180, 195),
	"b": Color8(130, 138, 155), "o": Color8(205, 210, 225),
	"v": Color8(240, 248, 255),
	"V": Color8(190, 205, 225),
	"_o": Color8(60, 65, 80), "_e": Color8(115, 122, 140),
	"_h": Color8(230, 235, 245), "_H": Color8(248, 250, 255),
}

# 地狱晶体: DEEP_STONE 骨架更暗 + h 烈火红 + H 深岩浆 + y 黄红发光
# 砂岩 pattern: 横向层纹 (像古埃及石材) + 偶发小裂纹 + 暖色调
const _SANDSTONE := [
	"slslslslslslslsl",
	"smmmmmmmmommmmms",
	"slsssssssssssssl",
	"sLsssssssssssssL",   # 高光层
	"slsssssssssssssl",
	"smmmmmmmmmmmommm",
	"oooooooooooooooo",   # 深层纹
	"slkslslslslslsls",   # 小裂纹 k
	"sLssssssssssssss",
	"slsssssssssssssl",
	"smmmmmmmmmmmmmms",
	"oooooooooooooooo",   # 又一深层纹
	"slssksssssssssss",
	"slsssssssssssssl",
	"smmmmmmmmmmmmmms",
	"sSslslslslslslsS",
]

# 地狱合金矿: 紫黑基底 + 银闪点 + 偶发紫光泽. STONE 形结构 + 不同颜色族.
const _HELL_ALLOY_ORE := [
	"sSsbsSsSsbsSsSss",
	"sbssLLlssoOOLLbs",
	"sssbssksLLLsskks",
	"sslkkskkkkksslkk",
	"sbosLLLsklssLLls",
	"sooLLLLsslmkmLls",
	"ssLLLkssbkssLLLs",
	"slkkkkbsylkkkkls",
	"sbosLLLshkLLLoss",
	"sLLkssolksLLLkbs",
	"sLLsHHkbskssLLls",
	"sssoLLLLossolssm",
	"sbosLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"sbosshlllksmsLls",
	"sSsbsSsSsbsSsSss",
]


const _HELL_CRYSTAL := [
	"SbsSsbsSsbsSsbsS",
	"shHykssssooLLkss",
	"sHHHkssksslLLkss",
	"shykkskkkkksslkk",
	"somLLLsksslHHHss",
	"soLLLLssllkHHyls",
	"ssLLLkssbkssHHks",
	"slkkkkbsslkkkkls",
	"somsLLLsskLLLmss",
	"sHykssolksLLLkbs",
	"hHHslkkbskssLLls",
	"sysLLLLossolssmm",
	"somsLLLkssbkLLss",
	"sslkkkbsslkLLLss",
	"somssklllksmsLls",
	"sSsbsSsSsbsSsSss",
]


# 生命水晶 palette: 透明背景 + 粉红心形, 4 层颜色让心立体
const _P_LIFE_CRYSTAL := {
	"k": Color8(80, 12, 25),       # 暗红外框
	"r": Color8(170, 45, 65),      # 暗粉过渡
	"R": Color8(230, 80, 110),     # 亮粉主色
	"P": Color8(255, 180, 200),    # 高光浅粉
}


# 魔力水晶: 16x16 蓝紫五角星结晶 (透明背景, 右键吃 → 永久 +20 MAX MANA)
# 对应 mana_hud 的星型 + 蓝紫色调
const _P_MANA_CRYSTAL := {
	"k": Color8(20, 15, 55),       # 深蓝紫边
	"r": Color8(60, 50, 130),      # 暗紫过渡
	"R": Color8(110, 90, 230),     # 蓝紫主色
	"P": Color8(200, 195, 255),    # 浅紫高光
}


# 5 角星结晶 (尖朝上 + 4 个外角): 跟 mana_hud 同 5 角星形状, 但实心 tile 块.
const _MANA_CRYSTAL := [
	"................",
	"................",
	".......kk.......",
	"......kRRk......",
	"......kRRk......",
	"kkk..kRRRRk..kkk",
	"kRRkkRRPPRRkkRRk",
	"kRRRRRRPPRRRRRRk",
	".kRRRRrRRrRRRRk.",
	"..kRRRRRRRRRRk..",
	"...kRRRRRRRRk...",
	"..kRRrkkkkrRRk..",
	".kRRkk....kkRRk.",
	"kkkk........kkkk",
	"................",
	"................",
]


# 床 palette: 深木 + 浅木 + 白枕 + 红被.
const _P_BED := {
	"B": Color8(70, 40, 20),       # 深木 (外框 + 阴影)
	"b": Color8(135, 85, 45),      # 浅木 (内框)
	"W": Color8(245, 240, 230),    # 枕头白
	"w": Color8(200, 195, 185),    # 枕头阴影
	"R": Color8(200, 50, 55),      # 红被子主色
	"r": Color8(150, 30, 35),      # 红被子暗
	"H": Color8(240, 110, 110),    # 红被子高光
}


# 床: 16x16 横放矩形, 透明上半 + 下方床体. 左端白枕头, 中右红被子, 木框.
const _BED := [
	"................",
	".BB.............",
	".Bb.............",
	".Bb.............",
	".Bb.............",
	".Bb.............",
	".BBBBBBBBBBBBBB.",
	"BbWWwRRHRRRRRRrB",
	"BbWWWRRRRRRHRRrB",
	"BbWWwRRRRRRRRRrB",
	"BbRRRrrrrrrrrrrB",
	".BBBBBBBBBBBBBB.",
	".B............B.",
	".B............B.",
	"BB............BB",
	"................",
]


# 小麦 4 阶段调色板: g 嫩绿 / G 深绿 / Y 黄穗 / y 浅黄
const _P_WHEAT := {
	"g": Color8(120, 200, 80),    # 嫩绿苗
	"G": Color8(80, 160, 60),     # 深绿杆
	"Y": Color8(240, 215, 95),    # 黄穗
	"y": Color8(255, 235, 130),   # 浅黄高光
	"k": Color8(60, 90, 40),      # 深绿描边
}


# 阶段 0: 苗 (刚发芽, 1-2 高小绿点, 底部居中)
const _WHEAT_0 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".......gg.......",
	"......gGGg......",
	"................",
]


# 阶段 1: 小苗 (3 高, 几片叶) — 16 wide
const _WHEAT_1 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......g..g......",
	".....gGgGg......",
	".......GG.......",
	".....gGGGg......",
	"....gGGGGGg.....",
	"....GGGGGGG.....",
	"................",
]


# 阶段 2: 中 (有杆 + 散叶, 还没穗) — 16 wide
const _WHEAT_2 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	".....g.....g....",
	".....G..g..G....",
	".....G.GgG......",
	".....GGGGg......",
	"....gG..GGg.....",
	".....GG.G.......",
	"....gGGGGg......",
	"....GGGGGG......",
	"...gGGGGGGg.....",
	"...GGGGGGGG.....",
	"................",
]


# 阶段 3: 熟 (黄穗 + 散叶 + 茎绿) — 16 wide
const _WHEAT_3 := [
	"................",
	"................",
	"......YyYY......",
	".....YYYYY......",
	"....YyYyYyY.....",
	"....YYYYYYY.....",
	"....YyYYyYY.....",
	"....YYYYYYY.....",
	"....GYGYGYG.....",
	"....GGGGGGG.....",
	"...gGGGGGGGg....",
	"...GGGGGGGGG....",
	"..gGGGGGGGGGg...",
	"..GGGGGGGGGGG...",
	".gGGGGGGGGGGGg..",
	"................",
]


# 装饰小草: 几片摇曳的绿叶, 长在 GRASS 上, 透明背景
const _PLANT_GRASS := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....g..........",
	".....G.gg..g....",
	"....gGGG..gG....",
	"....GGGGgGGG....",
	"...gGGGGGGGGg...",
	"...gGGGGGGGGg...",
	"....GGGGGGGG....",
	"................",
]


# 生命水晶: 16x16 心形粉色结晶 (透明背景, 玩家右键吃 → 永久 +20 MAX HP)
const _LIFE_CRYSTAL := [
	"................",
	"................",
	"....kk....kk....",
	"...kPPk..kPPk...",
	"..kPRRPkkPRRPk..",
	".kRRRRrkkrRRRRk.",
	".kRRRRRRRRRRRRk.",
	".kRRRPRRRRRPRRk.",
	"..kRRRRRRRRRRk..",
	"...kRRRRRRRRk...",
	"....kRRrrRRk....",
	".....kRRRRk.....",
	"......kRRk......",
	".......kk.......",
	"................",
	"................",
]


# 水: 4 帧动画, 高光位置渐移做"水波闪动"感. 邻 tile 拼起来视觉无缝.
# 边缘行/列 100% 'a' → 跟邻 tile 必无缝. 帧 0-3 内部高光位置依次右移.
const _WATER := [    # 帧 0 (做静态 fallback 用, 也作动画首帧)
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaabaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaacaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aacaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaabaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
]

# 帧 1: 高光右移 1 + 添 1 个新位置 (像水下闪光在游)
const _WATER_F1 := [
	"aaaaaaaaaaaaaaaa",
	"aaaaaaabaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaca",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aabaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaacaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaabaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
]

# 帧 2: 高光再右移 1 + 位置组合不同
const _WATER_F2 := [
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaabaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaca",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaabaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaacaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaabaaa",
	"aaaaaaaaaaaaaaaa",
]

# 帧 3: 完整移完一轮, 不同稀疏布局
const _WATER_F3 := [
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaabaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaca",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaabaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaacaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaaaaa",
	"aaaaaaaaaaaaabaa",
]


# 火把 tile: 中央木棍 + 顶部火苗 (4×3)
const _TORCH := [
	"................",
	"................",
	"......ff........",
	".....fFFf.......",
	"....fFFFFf......",
	"....fFFFFf......",
	".....FdFd.......",
	".....rbhr.......",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"......bh........",
	"................",
]

# 草墙: 顶部 2 行有绿根, 下面是深棕土纹
const _GRASS_WALL := [
	"vVvvVvvVvvVvvvVv",
	"VvdVDdvdDdvDdvDv",
	"dDddDddDdDddDddD",
	"DddDddDdDdkdDddd",
	"dDddDddDdDdkdDdD",
	"ddDddkdDdDddDddd",
	"dDddDddDdDdDdkdD",
	"DdDddDddDdkdDddd",
	"dDddDddkddDddDdD",
	"ddDddDddDdkddDdd",
	"dDddDdDddDdDdDdd",
	"DdDdkdDddDdDddDd",
	"dDddDdDdDdDdkdDd",
	"ddDdDddDdDddDddD",
	"dDddDddDdkdDdDdd",
	"DdDdDdkdDdDddDdD",
]

# 土墙: 全是深棕基, 稀疏小石子, 偶尔微亮
const _DIRT_WALL := [
	"dDddDddDdDddDddD",
	"Dddldddkdldddddd",
	"dDdDddDdDdDdkdDd",
	"ddDddDddDddDddDd",
	"DdDddDdkddDddDdD",
	"dDddDdDddDdDdldd",
	"ddDddDdDdkdDdDdd",
	"dlddDddDdDddDddD",
	"DdDdDddkdDdDddDd",
	"dDddDdDdDdDddDdl",
	"ddDddDddDdkdDddD",
	"DdDdDdDdDddDddDd",
	"dDddDddDdDddDdDd",
	"dlDddDdDdkdDdDdD",
	"DdDddDddDdDddDdd",
	"dDdDddDdDddDdDdD",
]

# 木墙: 4 横木板, 每 4 行 1 道板缝 (k). 跟 PLANKS 同结构, 颜色偏暗.
# 关键: 每行 col 0 == col 15 (都是 p 或 k), 拼贴时左右无缝.
# row 0 (plank top) 跟 row 15 (sep k) 不同 → 上下拼时显示一道板缝 (这是要的视觉, 不是 bug)
const _FURNACE := [
	"kkkkkkkkkkkkkkkk",
	"kssssssssssssssk",
	"ksSsssssssssSsSk",
	"ksssSsskkssSssSk",
	"ksSsSskRRksssssk",
	"kssssskRrkssSssk",
	"ksSssskRykSsssSk",
	"ksssSskryksssSsk",
	"ksSsSskRrkssssSk",
	"ksssssskkksSsssk",
	"kSssSssssSssssSk",
	"ksssssSsssssssSk",
	"kSsSsssssSssSssk",
	"kssssSsssssssssk",
	"ksSsssssssSssSsk",
	"kkkkkkkkkkkkkkkk",
]


const _COOKING_POT := [
	"................",
	"....kkkkkkkk....",
	"...kiiIIiiiik...",
	"..kiiIIiiiiiik..",
	"k.kiiiiiiiiiik.k",
	"k.kiiIiiiiiiik.k",
	".kkiiiiiiiiiikk.",
	"..kiiiiiiiiiik..",
	"..kiiiiiiiiiik..",
	"...kiiiiiiiik...",
	"....kiiiiiik....",
	"....kkkkkkkk....",
	".....RrrrrR.....",
	"....RyyrryyR....",
	"...RryryyryrR...",
	"..RyrRRrrRRryR..",
]


const _WOOD_WALL := [
	"pppppppppppppppp",
	"pPppppppllpppPpp",
	"pppppPppppllpppp",
	"kkkkkkkkkkkkkkkk",
	"ppppllpppppppPpp",
	"pPppppppllpppppp",
	"pppppPppppllpppp",
	"kkkkkkkkkkkkkkkk",
	"ppllpppppppPpppp",
	"pppPppppllpppppp",
	"ppppppllpppPpppp",
	"kkkkkkkkkkkkkkkk",
	"pPpppllppppppppp",
	"ppppppppPpppllpp",
	"ppPppppppppllppp",
	"kkkkkkkkkkkkkkkk",
]

# 石墙: 全是深暖灰, 黑裂纹, 偶尔微亮
const _STONE_WALL := [
	"sSssSssSsSssSssS",
	"SsslssksSsslssss",
	"sSsSssSsSsSskssS",
	"ssSssSssSssSssSs",
	"SsSssSskssSssSss",
	"sSssSsSssSsSsSss",
	"ssSssSsSskssSsSs",
	"slssSssSsSssSssS",
	"SsSsSssksSsSssSs",
	"sSssSsSsSsSssSls",
	"ssSssSssSskSsssS",
	"SsSsSsSsSssSssSs",
	"sSssSssSsSssSsSs",
	"slSssSsSskSsSsSS",
	"SsSssSssSsSssSss",
	"sSsSssSssSsSsSsS",
]

# 仙人掌顶 (CACTUS): 顶部圆头 + body. 底部 4 行还是 body, 跟 CACTUS_BODY 无缝.
# 用于堆叠最顶端 (单 1 格高也用这个).
const _CACTUS := [
	"......dddd......",
	".....dGggGd.....",
	"....dGgyhgGd....",
	"..w.dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd.w..",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"..w.dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd.w..",
]

# 仙人掌身体段 (CACTUS_BODY): 上下全 body, 跟上/下方的 CACTUS 或 CACTUS_BODY 无缝.
# 顶 (row 0) 和底 (row 15) 都是 body 像素 → 任意方向堆叠都连续.
const _CACTUS_BODY := [
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"..w.dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd.w..",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"..w.dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd....",
	"....dGgyhgGd.w..",
]

const _PATTERN_MAP := {
	GRASS: [_GRASS, _P_GRASS],
	DIRT: [_DIRT, _P_DIRT],
	STONE: [_STONE, _P_STONE],
	SAND: [_SAND, _P_SAND],
	LOG: [_LOG, _P_LOG],
	LEAVES: [_LEAVES, _P_LEAVES],
	PLANKS: [_PLANKS, _P_PLANKS],
	WORKBENCH: [_WORKBENCH, _P_WORKBENCH],
	DOOR: [_DOOR_CLOSED, _P_DOOR],
	BEDROCK: [_BEDROCK, _P_BEDROCK],
	LEAVES_PINE: [_LEAVES_PINE, _P_LEAVES_PINE],
	LEAVES_AUTUMN: [_LEAVES_AUTUMN, _P_LEAVES_AUTUMN],
	SLIME_TORCH: [_SLIME_TORCH, _P_SLIME_TORCH],
	DEEP_STONE: [_DEEP_STONE, _P_DEEP_STONE],
	COAL_ORE: [_COAL_ORE, _P_COAL_ORE],
	IRON_ORE: [_IRON_ORE, _P_IRON_ORE],
	TORCH: [_TORCH, _P_TORCH],
	GRASS_WALL: [_GRASS_WALL, _P_GRASS_WALL],
	DIRT_WALL: [_DIRT_WALL, _P_DIRT_WALL],
	STONE_WALL: [_STONE_WALL, _P_STONE_WALL],
	WOOD_WALL: [_WOOD_WALL, _P_WOOD_WALL],
	FURNACE: [_FURNACE, _P_FURNACE],
	COOKING_POT: [_COOKING_POT, _P_COOKING_POT],
	CACTUS: [_CACTUS, _P_CACTUS],
	CACTUS_BODY: [_CACTUS_BODY, _P_CACTUS],
	COPPER_ORE: [_COPPER_ORE, _P_COPPER_ORE],
	TIN_ORE: [_TIN_ORE, _P_TIN_ORE],
	GOLD_ORE: [_GOLD_ORE, _P_GOLD_ORE],
	DIAMOND_ORE: [_DIAMOND_ORE, _P_DIAMOND_ORE],
	HELL_CRYSTAL: [_HELL_CRYSTAL, _P_HELL_CRYSTAL],
	WATER: [_WATER, _P_WATER],
	LOG_TOP: [_LOG_TOP, _P_LOG],
	LOG_ROOT_L: [_LOG_ROOT_L, _P_BRANCH],
	LOG_ROOT_R: [_LOG_ROOT_R, _P_BRANCH],
	BRANCH_L: [_BRANCH_L, _P_BRANCH],
	BRANCH_R: [_BRANCH_R, _P_BRANCH],
	# 流水低水位 pattern 复用 _WATER + _P_WATER (icon 用; 真正贴图由 get_water_level_atlas 动画给)
	WATER_L1: [_WATER, _P_WATER],
	WATER_L2: [_WATER, _P_WATER],
	WATER_L3: [_WATER, _P_WATER],
	CHEST: [_CHEST, _P_CHEST],
	DOOR_TOP: [_DOOR_TOP_CLOSED, _P_DOOR],
	# 新群系 tile: 暂复用现有 pattern (后续可以做专属调色板)
	SNOW: [_GRASS, _P_GRASS],
	ICE: [_STONE, _P_STONE],
	JUNGLE_GRASS: [_GRASS, _P_GRASS],
	MUD: [_DIRT, _P_DIRT],
	SWAMP_GRASS: [_GRASS, _P_GRASS],
	WOOD_PLATFORM: [_WOOD_PLATFORM, _P_PLANKS],  # 上 4 行木梁 + 下面透明
	ROPE: [_ROPE, _P_ROPE],               # 专属麻绳: 双股扭, 淡黄棕
	JUNGLE_DIRT: [_DIRT, _P_DIRT],        # 后面 ArtCache tint 深绿
	SNOW_DIRT: [_DIRT, _P_DIRT],          # 后面 ArtCache tint 灰蓝
	JUNGLE_LEAVES: [_LEAVES, _P_LEAVES],  # 后面 ArtCache tint 深湿绿
	SILVER_ORE: [_SILVER_ORE, _P_SILVER_ORE],   # 专属 sparkle 形 + 亮银调色
	MUSHROOM: [_MUSHROOM, _P_MUSHROOM],         # 蓝光蘑菇
	MIMIC_CHEST: [_MIMIC_CHEST, _P_MIMIC_CHEST], # 死人箱 (假宝箱)
	# 金/钻石宝箱: 复用 _CHEST 形状, 调色板换金/蓝 → 自动有区别 (palette swap)
	GOLD_CHEST: [_GOLD_CHEST_PAT, _P_GOLD_CHEST],
	DIAMOND_CHEST: [_DIAMOND_CHEST_PAT, _P_DIAMOND_CHEST],
	# === 地狱 Phase 1 ===
	LAVA: [_LAVA, _P_LAVA],
	HELL_STONE: [_HELL_STONE, _P_HELL_STONE],
	OBSIDIAN: [_OBSIDIAN, _P_OBSIDIAN],
	HELL_FRUIT: [_HELL_FRUIT, _P_HELL_FRUIT],
	SHADOW_CHEST: [_SHADOW_CHEST_PAT, _P_SHADOW_CHEST],   # 独立锯齿形 + 红眼骨白
	LIFE_CRYSTAL: [_LIFE_CRYSTAL, _P_LIFE_CRYSTAL],   # 心形粉色结晶, 矿洞偶发
	MANA_CRYSTAL: [_MANA_CRYSTAL, _P_MANA_CRYSTAL],   # 星形蓝紫结晶, 矿洞偶发
	HELL_ALLOY_ORE: [_HELL_ALLOY_ORE, _P_HELL_ALLOY_ORE],   # 地狱合金矿 (紫黑+银)
	SANDSTONE: [_SANDSTONE, _P_SANDSTONE],                  # 砂岩 (暖黄+层纹)
	BED: [_BED, _P_BED],                                    # 床 (木框 + 红被 + 白枕)
	# 菜园: 小麦 4 阶段 (共用调色板, pattern 不同)
	WHEAT_0: [_WHEAT_0, _P_WHEAT],
	WHEAT_1: [_WHEAT_1, _P_WHEAT],
	WHEAT_2: [_WHEAT_2, _P_WHEAT],
	WHEAT_3: [_WHEAT_3, _P_WHEAT],
	# 装饰小草 (复用 _P_WHEAT 绿色, 几片小叶)
	PLANT_GRASS: [_PLANT_GRASS, _P_WHEAT],
}


const _PALETTES := {
	GRASS:     [_P_GRASS["g"],     _P_GRASS["G"]],
	DIRT:      [_P_DIRT["d"],      _P_DIRT["D"]],
	STONE:     [_P_STONE["s"],     _P_STONE["S"]],
	SAND:      [_P_SAND["y"],      _P_SAND["Y"]],
	LOG:       [_P_LOG["b"],       _P_LOG["B"]],
	LEAVES:    [_P_LEAVES["l"],    _P_LEAVES["L"]],
	PLANKS:    [_P_PLANKS["p"],    _P_PLANKS["P"]],
	WORKBENCH: [_P_WORKBENCH["p"], _P_WORKBENCH["P"]],
	DOOR:      [_P_DOOR["d"],      _P_DOOR["D"]],
	BEDROCK:   [_P_BEDROCK["b"],   _P_BEDROCK["B"]],
	LEAVES_PINE:   [_P_LEAVES_PINE["l"],   _P_LEAVES_PINE["L"]],
	LEAVES_AUTUMN: [_P_LEAVES_AUTUMN["l"], _P_LEAVES_AUTUMN["L"]],
	SLIME_TORCH:   [_P_SLIME_TORCH["g"],   _P_SLIME_TORCH["G"]],
	DEEP_STONE:    [_P_DEEP_STONE["s"],    _P_DEEP_STONE["S"]],
	COAL_ORE:      [_P_COAL_ORE["c"],      _P_COAL_ORE["C"]],
	IRON_ORE:      [_P_IRON_ORE["r"],      _P_IRON_ORE["R"]],
	TORCH:         [_P_TORCH["F"],         _P_TORCH["d"]],
}
const _DEFAULT_PALETTE := [Color(0.7, 0.7, 0.7), Color(0.4, 0.4, 0.4)]


static func get_palette(tile_id: int) -> Array:
	return _PALETTES.get(tile_id, _DEFAULT_PALETTE)


static func get_texture(tile_id: int) -> ImageTexture:
	assert(_PATTERN_MAP.has(tile_id), "未知 tile_id: %d" % tile_id)
	var entry: Array = _PATTERN_MAP[tile_id]
	return PixelArt.grid_to_texture(entry[0], entry[1])


static func get_door_open_texture() -> ImageTexture:
	return PixelArt.grid_to_texture(_DOOR_OPEN, _P_DOOR)


# 水动画 atlas: 4 帧水平排列, 64×16. TileSetAtlasSource 用 set_animation_frames_count 自动循环.
static func get_water_animated_atlas() -> ImageTexture:
	var frames: Array = [_WATER, _WATER_F1, _WATER_F2, _WATER_F3]
	var dst := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for i in range(4):
		var frame_img: Image = PixelArt.grid_to_image(frames[i], _P_WATER)
		dst.blit_rect(frame_img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	return ImageTexture.create_from_image(dst)


# 水位 (1/4, 2/4, 3/4) 动画 atlas: 同样 4 帧但顶部 (4-level)*4 行透明 (水位低).
# level: 1 = 1/4 满 (顶 12 行透明), 2 = 1/2 满 (顶 8 行透明), 3 = 3/4 满 (顶 4 行透明)
static func get_water_level_atlas(level: int) -> ImageTexture:
	assert(level >= 1 and level <= 3, "level 必须 1-3")
	var clip_rows: int = (4 - level) * 4  # 顶部清除多少行
	var frames: Array = [_WATER, _WATER_F1, _WATER_F2, _WATER_F3]
	var dst := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	var transparent := Color(0, 0, 0, 0)
	dst.fill(transparent)
	for i in range(4):
		var clipped: Array = _clip_water_top(frames[i], clip_rows)
		var frame_img: Image = PixelArt.grid_to_image(clipped, _P_WATER)
		dst.blit_rect(frame_img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	return ImageTexture.create_from_image(dst)


# 岩浆深浅 atlas: 跟 get_water_level_atlas 同结构 (64×16), 4 帧相同 (岩浆不动画).
# level: 1 = 1/4 满 (顶 12 行透明), 2 = 1/2 满 (顶 8 行透明), 3 = 3/4 满 (顶 4 行透明)
static func get_lava_level_atlas(level: int) -> ImageTexture:
	assert(level >= 1 and level <= 3, "level 必须 1-3")
	var clip_rows: int = (4 - level) * 4  # 顶部清除多少行
	var clipped: Array = _clip_water_top(_LAVA, clip_rows)
	var dst := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	for i in range(4):
		# 4 帧画一样的 (岩浆不动画), 复用同一 clipped pattern
		var frame_img: Image = PixelArt.grid_to_image(clipped, _P_LAVA)
		dst.blit_rect(frame_img, Rect2i(0, 0, 16, 16), Vector2i(i * 16, 0))
	return ImageTexture.create_from_image(dst)


# 把 pattern 顶部 clip_rows 行全替换成透明 (".") 模拟低水位
static func _clip_water_top(pattern: Array, clip_rows: int) -> Array:
	var out: Array = []
	var blank := "................"
	for y in range(16):
		if y < clip_rows:
			out.append(blank)
		else:
			out.append(pattern[y])
	return out


# 返回方块完整调色板 (含 _o/_e/_h/_H 边缘槽位).
static func get_full_palette(tile_id: int) -> Dictionary:
	assert(_PATTERN_MAP.has(tile_id), "未知 tile_id: %d" % tile_id)
	return _PATTERN_MAP[tile_id][1]


# 构建 47 变体 atlas (128×96 = 8 列 × 6 行 × 16 px).
# 仅对 EdgeTemplates.FAMILY_OF 里有的方块有效; 其它方块抛 assert.
static func build_atlas(tile_id: int) -> ImageTexture:
	var EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
	var BlobLookup = preload("res://scripts/world/blob_lookup.gd")

	assert(EdgeTemplates.FAMILY_OF.has(tile_id),
		"tile %d 没在 FAMILY_OF 里, 不支持 autotile" % tile_id)

	var family: String = EdgeTemplates.FAMILY_OF[tile_id]
	var family_tpl: Dictionary = EdgeTemplates.TEMPLATES[family]
	var base_pattern: Array = _PATTERN_MAP[tile_id][0]
	var palette: Dictionary = _PATTERN_MAP[tile_id][1]
	var transparent := Color(0, 0, 0, 0)

	var atlas_img := Image.create(128, 96, false, Image.FORMAT_RGBA8)
	atlas_img.fill(transparent)

	for i in BlobLookup.VARIANT_KEYS.size():
		var variant_key: String = BlobLookup.VARIANT_KEYS[i]
		var edge: Array = family_tpl[variant_key]
		var col: int = i % 8
		var row: int = i / 8
		var ox: int = col * 16
		var oy: int = row * 16
		for y in 16:
			var base_row: String = base_pattern[y]
			var edge_row: String = edge[y]
			for x in 16:
				var edge_ch: String = edge_row.substr(x, 1)
				var color: Color
				if edge_ch == ".":
					# 显示内部纹理
					var base_ch: String = base_row.substr(x, 1)
					if palette.has(base_ch):
						color = palette[base_ch]
					else:
						color = transparent
				else:
					# 边缘装饰: 用 _o/_e/_h/_H 槽位
					var slot: String = "_" + edge_ch
					if palette.has(slot):
						color = palette[slot]
					else:
						push_warning("tile %d 缺槽位 %s (variant %s)" % [tile_id, slot, variant_key])
						color = transparent
				atlas_img.set_pixel(ox + x, oy + y, color)

	return ImageTexture.create_from_image(atlas_img)
