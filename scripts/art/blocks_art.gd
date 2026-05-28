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
const MUSHROOM := 52        # 蓝光蘑菇 (矿洞蘑菇地装饰)
const MIMIC_CHEST := 53     # 死人箱 (假宝箱陷阱), 视觉跟 CHEST 像但锁孔是红的
const GOLD_CHEST := 54      # 金宝箱 (金色金属包角)
const DIAMOND_CHEST := 55   # 钻石宝箱 (蓝水晶金属包角)
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
	"m": Color8(218, 165, 80),  # 金属包角 (黄铜色)
	"M": Color8(150, 105, 40),  # 金属阴影
	"o": Color8(60, 35, 20),    # 锁孔黑
}

# 金宝箱: 金属包角换成亮金, 木板换成深一档 (更显沉甸甸的"贵气").
const _P_GOLD_CHEST := {
	"w": Color8(148, 96, 55),    # 木板主色 (比普通深 ≈ 木材包浆)
	"W": Color8(115, 73, 38),    # 木板深阴影
	"l": Color8(190, 138, 90),   # 木板高光
	"k": Color8(40, 25, 15),     # 黑描边
	"m": Color8(255, 215, 80),   # 亮金属 (金黄, 比普通黄铜更鲜亮)
	"M": Color8(200, 155, 30),   # 金阴影
	"o": Color8(255, 235, 120),  # 锁孔金黄 (高亮)
}

# 钻石宝箱: 木板深棕 + 蓝水晶包角 + 蓝光锁孔, "终极" 视觉.
const _P_DIAMOND_CHEST := {
	"w": Color8(120, 75, 45),    # 木板深棕 (最贵感)
	"W": Color8(90, 55, 30),
	"l": Color8(165, 115, 75),
	"k": Color8(40, 25, 15),
	"m": Color8(120, 200, 250),  # 浅蓝水晶 (主色)
	"M": Color8(60, 140, 200),   # 蓝水晶阴影
	"o": Color8(220, 250, 255),  # 锁孔近白闪光
}

# Mimic chest: 跟普通 chest 同 palette 大部分, 多一个红 r (锁孔/眼) 当线索
const _P_MIMIC_CHEST := {
	"w": Color8(168, 116, 69),
	"W": Color8(141, 93, 53),
	"l": Color8(208, 158, 110),
	"k": Color8(40, 25, 15),
	"m": Color8(218, 165, 80),
	"M": Color8(150, 105, 40),
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
	"s": Color8(180, 50, 30),   "S": Color8(135, 25, 15),
	"l": Color8(215, 90, 60),   "k": Color8(75, 15, 8),
	"L": Color8(245, 130, 90),  "m": Color8(155, 35, 22),
	"b": Color8(100, 20, 12),   "o": Color8(195, 70, 45),
	"h": Color8(255, 80, 30),
	"H": Color8(180, 30, 10),
	"y": Color8(255, 220, 120),
	"_o": Color8(35, 5, 2), "_e": Color8(95, 18, 8),
	"_h": Color8(245, 130, 90), "_H": Color8(255, 165, 120),
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
	".kmmwwwwwwwwmmk.",
	".kmwlwwwwwwlwmk.",
	".kmwwwwwwwwwwmk.",
	".kkkkkkkkkkkkkk.",
	".kwwwwwmmwwwwwk.",
	".kwlwwwmomwwwlk.",
	".kwwwwwmmwwwwwk.",
	".kwwwwwwwwwwwwk.",
	".kwlwwwWWwwwlwk.",
	".kwwwwwwwwwwwwk.",
	".kWWwwwwwwwwWWk.",
	".kmmwwwwwwwwmmk.",
	".kkkkkkkkkkkkkk.",
	"................",
]

# Mimic 看起来像普通 chest, 但锁孔是红色 (o → r). 仔细看的玩家能识别陷阱.
const _MIMIC_CHEST := [
	"................",
	".kkkkkkkkkkkkkk.",
	".kmmwwwwwwwwmmk.",
	".kmwlwwwwwwlwmk.",
	".kmwwwwwwwwwwmk.",
	".kkkkkkkkkkkkkk.",
	".kwwwwwmmwwwwwk.",
	".kwlwwwmrmwwwlk.",
	".kwwwwwmmwwwwwk.",
	".kwwwwwwwwwwwwk.",
	".kwlwwwWWwwwlwk.",
	".kwwwwwwwwwwwwk.",
	".kWWwwwwwwwwWWk.",
	".kmmwwwwwwwwmmk.",
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
	"sssssssksbkssss",
	"sslkkkkbsskkkssl",
	"somsLLLsssLLLmss",
	"sssvssolksLLLkbs",
	"ssvVvslkkbskvsss",
	"sssVVVssolsvVvss",
	"sssvvssolssssvss",
	"sslLLLkssbkLLss",
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
	ROPE: [_LOG, _P_LOG],                 # 复用 log 颜色 (棕), 后续可做专属麻绳
	JUNGLE_DIRT: [_DIRT, _P_DIRT],        # 后面 ArtCache tint 深绿
	SNOW_DIRT: [_DIRT, _P_DIRT],          # 后面 ArtCache tint 灰蓝
	JUNGLE_LEAVES: [_LEAVES, _P_LEAVES],  # 后面 ArtCache tint 深湿绿
	SILVER_ORE: [_SILVER_ORE, _P_SILVER_ORE],   # 专属 sparkle 形 + 亮银调色
	MUSHROOM: [_MUSHROOM, _P_MUSHROOM],         # 蓝光蘑菇
	MIMIC_CHEST: [_MIMIC_CHEST, _P_MIMIC_CHEST], # 死人箱 (假宝箱)
	# 金/钻石宝箱: 复用 _CHEST 形状, 调色板换金/蓝 → 自动有区别 (palette swap)
	GOLD_CHEST: [_CHEST, _P_GOLD_CHEST],
	DIAMOND_CHEST: [_CHEST, _P_DIAMOND_CHEST],
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
