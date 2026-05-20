# 主菜单背景元素：云、远山、树剪影、地面噪点。
# 全部用 ASCII 网格 + PixelArt 生成。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _CLOUD_PALETTE := {
	".": Color(0, 0, 0, 0),
	"w": Color8(255, 245, 230, 200),   # 暖白半透
	"W": Color8(240, 220, 200, 230),   # 略暗高光
}

# 24×8 椭圆云
const _CLOUD_ROWS := [
	"........wwwwwww.........",
	".....wwwwwwwwwwwww......",
	"...wwwwWWWWWWwwwwwww....",
	"..wwwwWWWWWWWWWwwwwwww..",
	"..wwwwwWWWWWWWWwwwwwww..",
	"...wwwwwwwwwwwwwwwww....",
	".....wwwwwwwwwwwww......",
	".........wwwww..........",
]

const _HILL_PALETTE := {
	".": Color(0, 0, 0, 0),
	"h": Color8(74, 56, 88),    # 紫灰
	"H": Color8(54, 40, 64),    # 深紫
}

# 80×10 起伏远山轮廓
const _HILL_ROWS := [
	"...........................hh.........................hhh.......................",
	"..........................hhhh.......................hhhhhh.....................",
	".....hh..................hhhhhh......hhh............hhhhhhhh..........hhh.......",
	"....hhhh................hhhhhhhh....hhhhh..........hhhhhhhhhh........hhhhh......",
	"...hhhhhh..............hhhhHHHHhh..hhhhhhh........hhhhHHHHHHhh......hhhhhhh.....",
	"..hhhhhhhh............hhhhHHHHHHhhhhhhHHhhhh.....hhhHHHHHHHHHHhh...hhhhHHhhhh...",
	".hhhhHHHHhh..........hhhHHHHHHHHHhhhHHHHHhhhh...hhHHHHHHHHHHHHHh..hhhHHHHHhhh...",
	"hhhhHHHHHHhh........hhHHHHHHHHHHHHhHHHHHHHHhhh.hhHHHHHHHHHHHHHHhhhhHHHHHHHHhhhhh",
	"hhHHHHHHHHHHhhhhhhhhHHHHHHHHHHHHHHHHHHHHHHHHHhhhHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHhh",
	"HHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHHH",
]

const _TREE_PALETTE := {
	".": Color(0, 0, 0, 0),
	"t": Color8(20, 14, 24),    # 近黑剪影
}

# 12×16 尖顶树剪影
const _TREE_ROWS := [
	".....tt.....",
	"....tttt....",
	"...tttttt...",
	"..tttttttt..",
	"...tttttt...",
	"..tttttttt..",
	".tttttttttt.",
	"..tttttttt..",
	".tttttttttt.",
	"tttttttttttt",
	".tttttttttt.",
	"tttttttttttt",
	".....tt.....",
	".....tt.....",
	".....tt.....",
	".....tt.....",
]

const _GROUND_PALETTE := {
	".": Color8(58, 36, 22),    # 暗棕底
	"d": Color8(74, 50, 30),    # 略亮棕
	"D": Color8(42, 26, 16),    # 更暗
}

# 16×8 重复用噪点地面贴图
const _GROUND_ROWS := [
	"..d...D...d..D..",
	".D...d...D..d...",
	"d..D...d...D...d",
	"...d..D...d.D...",
	".D...d..D..d...D",
	"d.D..d.D..d.D..d",
	"..d..D..d.D...d.",
	"D..d.D..d.D...D.",
]


static func make_cloud() -> ImageTexture:
	return PixelArt.grid_to_texture(_CLOUD_ROWS, _CLOUD_PALETTE)


static func make_hill() -> ImageTexture:
	return PixelArt.grid_to_texture(_HILL_ROWS, _HILL_PALETTE)


static func make_tree() -> ImageTexture:
	return PixelArt.grid_to_texture(_TREE_ROWS, _TREE_PALETTE)


static func make_ground_noise() -> ImageTexture:
	return PixelArt.grid_to_texture(_GROUND_ROWS, _GROUND_PALETTE)
