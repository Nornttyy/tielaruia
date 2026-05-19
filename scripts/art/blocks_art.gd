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
const LEAVES := 6
const PLANKS := 7
const WORKBENCH := 8
const DOOR := 9
const BEDROCK := 10

# --- 调色板 (每方块独立) ---

const _P_GRASS := {
	"a": Color8(143, 179, 112),  # 高光 (柔化)
	"g": Color8(111, 149, 96),   # 基色 (降饱和)
	"G": Color8(84, 120, 74),    # 阴影
	"m": Color8(125, 158, 95),   # 中绿 (新)
	"y": Color8(176, 190, 110),  # 黄绿草尖 (新)
	"d": Color8(141, 111, 76),   # 泥土过渡 (变暖)
	"D": Color8(117, 89, 74),    # 泥土阴影
	"k": Color8(91, 69, 58),     # 小石子
}

const _P_DIRT := {
	"d": Color8(153, 120, 92),   # 基色 (柔化)
	"D": Color8(117, 89, 74),    # 阴影 (柔化)
	"k": Color8(91, 69, 58),     # 小石子 (变暖)
	"l": Color8(179, 149, 122),  # 高光 (柔化)
	"L": Color8(195, 169, 141),  # 凸起亮面 (柔化)
	"p": Color8(126, 106, 86),   # 冷棕调 (新)
	"r": Color8(139, 109, 79),   # 红棕调 (新)
}

const _P_STONE := {
	"s": Color8(163, 166, 171),  # 基色 (微冷蓝调)
	"S": Color8(126, 131, 137),  # 阴影
	"l": Color8(182, 186, 190),  # 高光
	"k": Color8(95, 100, 108),   # 裂纹 (柔化)
	"L": Color8(199, 202, 206),  # 凸起亮面 (柔化, 不再刺眼)
	"m": Color8(142, 146, 154),  # 中灰 (新)
	"b": Color8(107, 112, 122),  # 冷蓝灰 (新)
}

const _P_SAND := {
	"y": Color8(220, 190, 131),  # 基色 (大幅降饱和)
	"Y": Color8(184, 156, 110),  # 阴影
	"l": Color8(235, 215, 168),  # 高光 (柔和米黄)
	"k": Color8(147, 121, 77),   # 小石子
	"L": Color8(240, 222, 181),  # 凸起亮面 (柔化)
	"o": Color8(202, 168, 119),  # 暖中调 (新)
	"b": Color8(214, 189, 140),  # 沙色变种 (新)
}

const _P_LOG := {
	"b": Color8(110, 80, 67),    # 树皮基色 (柔化)
	"B": Color8(74, 52, 41),     # 树皮深沟
	"l": Color8(154, 131, 119),  # 树皮高光（凸条, 柔化)
	"R": Color8(92, 67, 56),     # 木结
	"r": Color8(132, 103, 87),   # 中树皮 (新)
	"p": Color8(120, 90, 75),    # 副基色 (新)
	"s": Color8(146, 119, 106),  # 树皮变种 (新)
}

const _P_LEAVES := {
	"l": Color8(111, 150, 112),  # 中绿 (柔化)
	"L": Color8(79, 116, 79),    # 阴影
	"d": Color8(53, 79, 52),     # 最深
	"h": Color8(143, 181, 144),  # 高光 (柔化)
	"y": Color8(181, 190, 116),  # 黄橄榄 (新)
	"s": Color8(91, 126, 91),    # 中阴影 (新)
	"a": Color8(162, 176, 122),  # 鼠尾草 (新)
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

# --- 图案 (每方块 16x16) ---

# 草方块：草尖 (y黄绿 + a高光 + .透空) + 中绿 m 增加色彩层次
const _GRASS := [
	".y..aa..a..ay..a",
	"amaagaagamagaaya",
	"agGmgmGggmgmgGga",
	"GgmgGgGmggGgGmgg",
	"gGddgdGddgGdgdgg",
	"ddggddgdgdggddgd",
	"dddgddddddddgddd",
	"dddddddddddddddd",
	"dDdddddDdddddddd",
	"ddDddddddddddddd",
	"DdddddddddDdkddd",
	"ddDddDdddddddddd",
	"dddddddDdkddDddd",
	"DddddDddddddddDd",
	"dddDddddddddDddd",
	"dDddddDdddddkddd",
]

# 泥土：凸起 (LL) + 石子 (k) + 红棕 (r) + 冷棕 (p) 色斑加色彩层次
const _DIRT := [
	"dDdDdpDddDpdDdDd",
	"ddlDdrdddddddkdd",
	"dDdddkdDdLLdrddd",
	"dddpdddddLLdkddd",
	"dDddDdpdddddrddd",
	"ddkddDdddddpdddD",
	"ddDdddddrdkLLddd",
	"dpddddddddDLLdkd",
	"dlddpdddDdddddDd",
	"ddddDddrdddddpDd",
	"DdpdddddddDddkdd",
	"ddddDkdrdddddddd",
	"ddDLLdpdddddDddD",
	"dpdLLddDdddddDDd",
	"ddddddDdrddkdDdd",
	"DddDdDdpdDddrdDd",
]

# 石头：凸起 (LL) + 裂纹 (k) + 中灰 (m) + 冷蓝灰 (b) 加色彩
const _STONE := [
	"sSmSsssSsSmSsSbs",
	"slksslLLslsmsLss",
	"ssksklLLslsssLbs",
	"ssklssklssbsklss",
	"sLLLLkssksssklms",
	"sLLLLklllksbsLss",
	"sLLLLklllksssLss",
	"sssklllllkLLkbss",
	"ssbklssklsLLkLss",
	"ssklksksslsklsLm",
	"slkssklllsmLLkss",
	"slksslssklsLLkms",
	"sssklssklsbsklss",
	"sssLLkssssklbsLs",
	"ssLLLkksssmklssb",
	"sSsSsbsSsSmSsSss",
]

# 沙：凸起 (LL) + 石子 (k) + 暖中调 (o) + 变种 (b) 加色彩
const _SAND := [
	"yyoyylyybyyyyyyy",
	"yyyykybyyyyoyLLy",
	"yoyLLyybyyyyyLLy",
	"yyLLLyobkyyybyyy",
	"yYybyyykyoyyyYyy",
	"yyyyYbyyyoyykyyy",
	"yyokyybyyYyyyyly",
	"yyobyyybyykLLyyy",
	"yobyybyyykLLLLby",
	"ylobyyYbyyLLLlyo",
	"yyobyykyyybyyyyo",
	"yyobyyyyybyyooyy",
	"yobyyybyyyyylyyo",
	"yyoykLLyybkyyybo",
	"yYyykLLybyyyyooy",
	"yyybyyybyyyooyyy",
]

# 原木：竖向树皮 + 凸条 (l) + 木结 (R) + 中树皮 (r) + 副基 (p) 增加色彩
const _LOG := [
	"bbBbbBbbBbbBbbBb",
	"bBblbBblbBblpBbl",
	"bbblbBblbbblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBblbBblbBblbBbl",
	"brblpBblbBblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBblbRRl",
	"bBblbBblbBblbRRl",
	"bBblbBblbBrlbBbl",
	"bbblbBblpBblbBbl",
	"bBblbBblbBblbBbl",
	"bbBbbBbpBbbBbbBb",
	"bbbBbbBbbBbbBbbb",
]

# 树叶：叶簇 + 高光 + 透角 + 黄橄榄 (y) + 中阴影 (s) + 鼠尾草 (a) 增色彩
const _LEAVES := [
	".lLyll....llylL.",
	"lLLddyllllyddLLl",
	"lLddhdLsLdhddLll",
	"lLaddhLLhLLddyLl",
	"llLLsLLLLLLsLLll",
	"llLLddddddddLLll",
	"lLydhhdLLdhhdyLl",
	"lLddhsLLLLshddLl",
	"lLddhsLLLLshddLl",
	"lLydhhdLLdhhdyLl",
	"llLLddddddddLLll",
	"llLLsLLLLLLsLLll",
	"lLaddhLLhLLddyLl",
	"lLddhdLsLdhddLll",
	"lLLddyllllyddLLl",
	".lyLll....llLyl.",
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
