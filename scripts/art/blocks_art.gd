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
}

# 松针：深暖绿 + 灰绿暗色，无透角更密实
const _P_LEAVES_PINE := {
	"l": Color8(82, 130, 78),    # 中绿
	"L": Color8(50, 95, 55),     # 阴影
	"d": Color8(28, 60, 35),     # 最深
	"h": Color8(120, 165, 95),   # 高光
	"s": Color8(70, 115, 70),    # 中阴影
	"y": Color8(155, 175, 90),   # 黄橄榄 (松果?)
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

# 史莱姆灯: 顶部 4x3 绿胶 + 中间细木棍
const _SLIME_TORCH := [
	"................",
	"....hgggggggh...",
	"...gggGGGggggg..",
	"...ggGGgGGggGg..",
	"...gGgGGGgGGgg..",
	"....ggGGGgggg...",
	".....gggggg.....",
	".......bb.......",
	".......br.......",
	".......bb.......",
	".......br.......",
	".......bb.......",
	".......br.......",
	".......bb.......",
	"......bbbb......",
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
