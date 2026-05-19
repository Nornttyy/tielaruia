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
	"a": Color8(102, 187, 106),  # 高光
	"g": Color8(76, 175, 80),    # 基色
	"G": Color8(56, 142, 60),    # 阴影
	"d": Color8(139, 90, 43),    # 泥土过渡
}

const _P_DIRT := {
	"d": Color8(139, 90, 43),
	"D": Color8(109, 68, 38),
	"k": Color8(74, 47, 26),     # 小石子
	"l": Color8(166, 124, 82),   # 高光
	"L": Color8(200, 149, 106),  # 凸起亮面
}

const _P_STONE := {
	"s": Color8(158, 158, 158),
	"S": Color8(117, 117, 117),
	"l": Color8(189, 189, 189),
	"k": Color8(89, 89, 89),     # 裂纹
	"L": Color8(221, 221, 221),  # 凸起亮面
}

const _P_SAND := {
	"y": Color8(244, 211, 94),
	"Y": Color8(230, 193, 77),
	"l": Color8(250, 234, 122),
	"k": Color8(186, 152, 56),
	"L": Color8(255, 244, 168),  # 凸起亮面
}

const _P_LOG := {
	"b": Color8(93, 64, 55),     # 树皮基色
	"B": Color8(62, 39, 35),     # 树皮深沟
	"l": Color8(161, 136, 127),  # 树皮高光（凸条）
	"R": Color8(78, 52, 46),     # 木结
}

const _P_LEAVES := {
	"l": Color8(76, 175, 80),
	"L": Color8(46, 125, 50),
	"d": Color8(27, 94, 32),
	"h": Color8(102, 187, 106), # 高光
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

# 草方块：顶部 1-2px 草尖 (透空 + 高光) + 渐变到泥土
const _GRASS := [
	".a..aa..a..aa..a",
	"agaagaagaagaagaa",
	"agGgggGggggGggga",
	"GgggGgGgggGggGgg",
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

# 泥土：散布凸起 (LL 簇) + 小石子 (k) + 阴影变化 (D)
const _DIRT := [
	"dDdDddDddDddDdDd",
	"ddlDdddddddddkdd",
	"dDdddkdDdLLddddd",
	"dddddddddLLdkddd",
	"dDddDddddddddddd",
	"ddkddDdddddddddD",
	"ddDdddddddkLLddd",
	"ddddddddddDLLdkd",
	"dlddddddDdddddDd",
	"ddddDdddddddddDd",
	"DdddddddddDddkdd",
	"ddddDkdddddddddd",
	"ddDLLdddddddDddD",
	"dddLLddDdddddDDd",
	"ddddddDddddkdDdd",
	"DddDdDdddDddddDd",
]

# 石头：凸起团 (LL) + 裂纹 (k) + 高光散点 (l) — 加块面感
const _STONE := [
	"sSsSsssSsSsSsSss",
	"slksslLLslsssLss",
	"ssksklLLslsssLss",
	"ssklssklssssklss",
	"sLLLLkssksssklss",
	"sLLLLklllksssLss",
	"sLLLLklllksssLss",
	"sssklllllkLLksss",
	"sssklssklsLLkLss",
	"ssklksksslsklsLs",
	"slkssklllssLLkss",
	"slksslssklsLLkss",
	"sssklssklsssklss",
	"sssLLkssssklssLs",
	"ssLLLkksssklssss",
	"sSsSsssSsSsSsSss",
]

# 沙：散落沙丘小凸起 (LL) + 偶发石子 (k)
const _SAND := [
	"yyyyylyyyyyyyyyy",
	"yyyykyyyyyyyyLLy",
	"yyyLLyyyyyyyyLLy",
	"yyLLLyyykyyyyyyy",
	"yYyyyyykyyyyyYyy",
	"yyyyYyyyyyyykyyy",
	"yyykyyyyyYyyyyly",
	"yyyyyyyyyykLLyyy",
	"yyyyyyyyykLLLLyy",
	"ylyyyyYyyyLLLlyy",
	"yyyyyykyyyyyyyyy",
	"yyyyyyyyyyyyyyyy",
	"yyyyyyyyyyyylyyy",
	"yyyykLLyyykyyyyy",
	"yYyykLLyyyyyyyyy",
	"yyyyyyyyyyyyyyyy",
]

# 原木从侧面看（用作树干）：竖向树皮纹理 + 凸起高光条 + 偶发木结
const _LOG := [
	"bbBbbBbbBbbBbbBb",
	"bBblbBblbBblbBbl",
	"bbblbBblbbblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBblbRRlbBblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBblbBbl",
	"bBblbBblbBblbRRl",
	"bBblbBblbBblbRRl",
	"bBblbBblbBblbBbl",
	"bbblbBblbBblbBbl",
	"bBblbBblbBblbBbl",
	"bbBbbBbbBbbBbbBb",
	"bbbBbbBbbBbbBbbb",
]

# 树叶：多个叶簇 + 簇心高光 + 四角透空 (打破方形轮廓)
const _LEAVES := [
	".lLLll....llLll.",
	"lLLddLllllLddLLl",
	"lLddhdLLLdhddLll",
	"lLLddhLLhLLddLll",
	"llLLLLLLLLLLLLll",
	"llLLddddddddLLll",
	"lLLdhhdLLdhhdLLl",
	"lLddhdLLLLdhddLl",
	"lLddhdLLLLdhddLl",
	"lLLdhhdLLdhhdLLl",
	"llLLddddddddLLll",
	"llLLLLLLLLLLLLll",
	"lLLddhLLhLLddLll",
	"lLddhdLLLdhddLll",
	"lLLddLllllLddLLl",
	".lLLll....llLll.",
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
