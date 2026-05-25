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
const WATER := 28           # 水

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
	"s": Color8(156, 144, 136),
	"S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158),
	"k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181),
	"m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),
	"o": Color8(184, 154, 130),
	"c": Color8(50, 40, 35),
	"C": Color8(28, 22, 20),
	"h": Color8(80, 65, 55),
	# 新增 (T3): 边缘语义槽 (与 STONE 同结构, 同色)
	"_o": Color8(40, 32, 28),    # 极暗轮廓
	"_e": Color8(95, 85, 78),    # 边缘暗影
	"_h": Color8(195, 180, 170), # 边缘高光
	"_H": Color8(222, 205, 188), # 顶强高光 (暖)
}

# 铁矿: STONE 底色 + r/R/H 系列铁锈
const _P_IRON_ORE := {
	"s": Color8(156, 144, 136),
	"S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158),
	"k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181),
	"m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),
	"o": Color8(184, 154, 130),
	"r": Color8(168, 100, 60),
	"R": Color8(130, 70, 40),
	"H": Color8(200, 140, 90),
	# 新增 (T3): 边缘语义槽 (与 STONE 同结构, 同色)
	"_o": Color8(40, 32, 28),    # 极暗轮廓
	"_e": Color8(95, 85, 78),    # 边缘暗影
	"_h": Color8(195, 180, 170), # 边缘高光
	"_H": Color8(222, 205, 188), # 顶强高光 (暖)
}

# ─── 新矿石调色板 (STONE 底色 + 矿色 + 边缘槽位 同 STONE) ─────────────

# 铜矿: STONE 底 + u/U/p 暖橙铜
const _P_COPPER_ORE := {
	"s": Color8(156, 144, 136), "S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158), "k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181), "m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),   "o": Color8(184, 154, 130),
	"u": Color8(192, 110, 60),  # 暖橙铜
	"U": Color8(150, 75, 35),   # 深铜
	"p": Color8(230, 150, 90),  # 高光铜
	"_o": Color8(40, 32, 28), "_e": Color8(95, 85, 78),
	"_h": Color8(195, 180, 170), "_H": Color8(222, 205, 188),
}

# 锡矿: STONE 底 + n/N/x 银白
const _P_TIN_ORE := {
	"s": Color8(156, 144, 136), "S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158), "k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181), "m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),   "o": Color8(184, 154, 130),
	"n": Color8(195, 200, 210), # 银白锡
	"N": Color8(140, 150, 160), # 深锡灰
	"x": Color8(235, 240, 248), # 高光锡 (近白)
	"_o": Color8(40, 32, 28), "_e": Color8(95, 85, 78),
	"_h": Color8(195, 180, 170), "_H": Color8(222, 205, 188),
}

# 金矿: STONE 底 + g/G/y 暖金
const _P_GOLD_ORE := {
	"s": Color8(156, 144, 136), "S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158), "k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181), "m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),   "o": Color8(184, 154, 130),
	"g": Color8(235, 195, 70),  # 暖金
	"G": Color8(180, 140, 25),  # 深金阴影
	"y": Color8(255, 230, 130), # 高光金
	"_o": Color8(40, 32, 28), "_e": Color8(95, 85, 78),
	"_h": Color8(195, 180, 170), "_H": Color8(222, 205, 188),
}

# 钻石矿: STONE 底 + d/D/x 青蓝
const _P_DIAMOND_ORE := {
	"s": Color8(156, 144, 136), "S": Color8(122, 110, 102),
	"l": Color8(182, 168, 158), "k": Color8(92, 80, 72),
	"L": Color8(204, 191, 181), "m": Color8(138, 125, 116),
	"b": Color8(110, 98, 90),   "o": Color8(184, 154, 130),
	"d": Color8(130, 205, 235), # 青蓝钻
	"D": Color8(55, 130, 175),  # 深钻阴影
	"x": Color8(220, 250, 255), # 高光钻 (近白透)
	"_o": Color8(40, 32, 28), "_e": Color8(95, 85, 78),
	"_h": Color8(195, 180, 170), "_H": Color8(222, 205, 188),
}

# 水: 半透明蓝, 不同深浅做波纹效果. 暗到亮 4 档蓝 + 透明.
const _P_WATER := {
	"a": Color8(50, 110, 200, 180),   # 深蓝半透 (波底)
	"b": Color8(85, 145, 225, 175),   # 中蓝
	"c": Color8(130, 180, 240, 170),  # 亮蓝
	"d": Color8(180, 215, 250, 160),  # 高光浅蓝
	"e": Color8(220, 235, 250, 150),  # 白沫
}

# 地狱晶体: DEEP_STONE 底 (更暗背景烘托) + h/H/y 烈火红
const _P_HELL_CRYSTAL := {
	"s": Color8(102, 88, 78),   "S": Color8(72, 60, 52),
	"l": Color8(125, 108, 96),  "k": Color8(48, 36, 28),
	"L": Color8(140, 122, 108), "m": Color8(88, 75, 66),
	"b": Color8(60, 50, 42),    "o": Color8(122, 96, 72),
	"h": Color8(255, 80, 30),   # 烈火红
	"H": Color8(180, 30, 10),   # 深岩浆红
	"y": Color8(255, 220, 120), # 黄红发光高光
	"_o": Color8(20, 15, 12), "_e": Color8(50, 40, 33),
	"_h": Color8(128, 110, 98), "_H": Color8(148, 126, 108),
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


# 水: 16×16 半透明波纹. 4 档蓝 + e 白沫 (高光). 横向波纹 + 偶发气泡.
# 上下 1 行 + 中间几行做波纹效果, 看着像水面在动 (静态贴图但纹理 busy).
const _WATER := [
	"dcdcdcdcdcdcdcdc",
	"cdcecdcedcdcecdc",
	"bcbcbcbcbcbcbcbc",
	"bcbcbcbcbcbcbcbc",
	"bcbecbcbcbecbcbc",
	"ababababababaaba",
	"ababababababaaba",
	"bababababababaab",
	"ababecabababecab",
	"bababababababaab",
	"ababababababaaba",
	"bababababababaab",
	"abababecabababec",
	"ababababababaaba",
	"bababababababaab",
	"abababababababab",
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
	CACTUS: [_CACTUS, _P_CACTUS],
	CACTUS_BODY: [_CACTUS_BODY, _P_CACTUS],
	COPPER_ORE: [_COPPER_ORE, _P_COPPER_ORE],
	TIN_ORE: [_TIN_ORE, _P_TIN_ORE],
	GOLD_ORE: [_GOLD_ORE, _P_GOLD_ORE],
	DIAMOND_ORE: [_DIAMOND_ORE, _P_DIAMOND_ORE],
	HELL_CRYSTAL: [_HELL_CRYSTAL, _P_HELL_CRYSTAL],
	WATER: [_WATER, _P_WATER],
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
