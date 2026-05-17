# 非方块物品的 16×16 图标 (背包/热键栏显示)。
# 方块物品 (planks/log/dirt 等) 的图标直接复用 BlocksArt.get_texture()。
# 这里只放工具和素材物品。
#
# 工具的"挥动"动画不在这里——player_action.gd 用 Tween 旋转 Sprite2D 实现。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"b": Color8(189, 189, 189),  # 金属高光
	"B": Color8(117, 117, 117),  # 金属基色
	"K": Color8(66, 66, 66),     # 金属阴影
	"g": Color8(141, 141, 141),  # 护手
	"G": Color8(97, 97, 97),
	"h": Color8(168, 116, 69),   # 木 (planks color)
	"H": Color8(141, 93, 53),    # 木阴影
	"k": Color8(67, 40, 24),     # 极深 (绑带/护套)
	"r": Color8(165, 95, 60),    # 麻绳棕
	"o": Color8(76, 175, 80),    # 史莱姆球绿
	"O": Color8(46, 125, 50),
	"q": Color8(102, 187, 106),  # 史莱姆球高光
}

# 木剑：对角线刀身 + 木柄 + 护手 + 圆头柄
const _WOOD_SWORD := [
	"............bbb.",
	"...........bbBB.",
	"..........bbBB..",
	".........bbBB...",
	"........bbBB....",
	".......bbBB.....",
	"......bbBB......",
	".....bbBB.......",
	"....bbBB........",
	"..ggggGG........",
	".gggGGGG........",
	"....hh..........",
	"....hH..........",
	"....hH..........",
	"....KK..........",
	"................",
]

# 木镐：T 形头 + 直柄
const _WOOD_PICKAXE := [
	"....BBBBBBBB....",
	"...bbBBBBBBBb...",
	"....BBBBBBBB....",
	".....bBBBBb.....",
	".......hh.......",
	"......hHH.......",
	"......hH........",
	".......hh.......",
	".......hH.......",
	".......hh.......",
	".......hH.......",
	".......hh.......",
	".......hH.......",
	".......hh.......",
	".......hH.......",
	"................",
]

# 木斧：单侧斧头 + 直柄
const _WOOD_AXE := [
	"...BBBB.........",
	"..BBBBBb........",
	".BBBBBBBb.......",
	".BBBBBBBh.......",
	".BBBBBBhh.......",
	".BBBBBhH........",
	"..BBBhh.........",
	"....hH..........",
	"....hh..........",
	"....hH..........",
	"....hh..........",
	"....hH..........",
	"....hh..........",
	"....hH..........",
	"....hh..........",
	"................",
]

# 棍子：对角线短木条 + 末端打结
const _STICK := [
	"................",
	"................",
	".............rh.",
	"............hh..",
	"...........hh...",
	"..........hh....",
	".........hH.....",
	"........hH......",
	".......hH.......",
	"......hH........",
	".....hH.........",
	"....hH..........",
	"...hH...........",
	"..hH............",
	".rH.............",
	"................",
]

# 史莱姆球：小圆球
const _SLIME_BALL := [
	"................",
	".....oqqo.......",
	"....oqqqqo......",
	"...oqqqqqqO.....",
	"..oqqOOqqqO.....",
	"..oqqOqqqqO.....",
	"..oqqqqqqqO.....",
	"..ooqqqqqqO.....",
	"...OOqqqqqO.....",
	"....OOOOOO......",
	".....OOOO.......",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _ICONS := {
	"wood_sword": _WOOD_SWORD,
	"wood_pickaxe": _WOOD_PICKAXE,
	"wood_axe": _WOOD_AXE,
	"stick": _STICK,
	"slime_ball": _SLIME_BALL,
}


static func get_icon(item_id: String) -> ImageTexture:
	assert(_ICONS.has(item_id), "未知物品 icon: %s" % item_id)
	return PixelArt.grid_to_texture(_ICONS[item_id], PALETTE)


static func has_icon(item_id: String) -> bool:
	return _ICONS.has(item_id)
