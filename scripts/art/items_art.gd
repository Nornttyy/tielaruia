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
	"y": Color8(212, 160, 90),   # 木刀身 (沙黄)
	"Y": Color8(157, 113, 56),   # 木刀身阴影
	"A": Color8(200, 45, 50),    # 苹果红
	"a": Color8(235, 90, 80),    # 苹果高光
	"L": Color8(85, 145, 65),    # 叶绿
	"S": Color8(95, 60, 30),     # 苹果梗棕
}

# 木剑：对角线刀身 + 木柄 + 护手 + 圆头柄
const _WOOD_SWORD := [
	"............yyy.",
	"...........yyYY.",
	"..........yyYY..",
	".........yyYY...",
	"........yyYY....",
	".......yyYY.....",
	"......yyYY......",
	".....yyYY.......",
	"....yyYY........",
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
	"....YYYYYYYY....",
	"...yyYYYYYYYy...",
	"....YYYYYYYY....",
	".....yYYYYy.....",
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
	"...YYYY.........",
	"..YYYYYy........",
	".YYYYYYYy.......",
	".YYYYYYYh.......",
	".YYYYYYhh.......",
	".YYYYYhH........",
	"..YYYhh.........",
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

# 石剑: bBK 灰刀身 + h/H 木柄
const _STONE_SWORD := [
	"................",
	"...........bBB..",
	"..........bBKB..",
	".........bBKBB..",
	"........bBKBB...",
	".......bBKBB....",
	"......bBKBB.....",
	".....bBKBB......",
	"....bBKBB.......",
	"...gggGG........",
	"..gggGGGG.......",
	"....hh..........",
	"....hH..........",
	"....hH..........",
	"....KK..........",
	"................",
]

# 石镐: 横 T 石头头 + 木柄
const _STONE_PICKAXE := [
	"................",
	"....BBBBBBBB....",
	"...BbbbbbbbbB...",
	"...BbBKKKKBbB...",
	"....BbbBBbbB....",
	"......BbbB......",
	"......hHrh......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......hH.......",
	".......KK.......",
	"................",
	"................",
]

# 石斧: 半月石头头 + 木柄
const _STONE_AXE := [
	"................",
	"....BBBBB.......",
	"...BbbbbbB......",
	"..BbbbbbbbB.....",
	".BbbbbBBKB......",
	"BbbBBBKK........",
	"BbBBKKr.........",
	"BBKKKhrh........",
	".....hHr........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....hH.........",
	".....KK.........",
	"................",
]

# 史莱姆果冻：方形果冻块 + 高光 (比 slime_ball 视觉略立方)
const _SLIME_JELLY := [
	"................",
	"...oqqqqqqo.....",
	"..oqqqqqqqqo....",
	"..oqyyqqqqqo....",
	"..oqyqqqqqqo....",
	"..oqqqqqqqqo....",
	"..oqqqqqqqqo....",
	"..oqqqqqqqqo....",
	"..oqqqqqqqqo....",
	"..oOOOOOOOOo....",
	"..oOOOOOOOOo....",
	"...OOOOOOOO.....",
	"................",
	"................",
	"................",
	"................",
]

# 苹果：圆形红身 + 棕梗 + 绿叶
const _APPLE := [
	"................",
	"........S.......",
	".......LSL......",
	"......LSLL......",
	".....AAaAA......",
	"....AaaaaAA.....",
	"...AaaAAaaaA....",
	"...AaaAaaaaA....",
	"...AaaaaaaaA....",
	"...AAaaaaaAA....",
	"....AaaaaaA.....",
	"....AAaaaAA.....",
	".....AAAAA......",
	"......AAA.......",
	"................",
	"................",
]

const _ICONS := {
	"wood_sword": _WOOD_SWORD,
	"wood_pickaxe": _WOOD_PICKAXE,
	"wood_axe": _WOOD_AXE,
	"slime_jelly": _SLIME_JELLY,
	"apple": _APPLE,
	"stone_sword": _STONE_SWORD,
	"stone_pickaxe": _STONE_PICKAXE,
	"stone_axe": _STONE_AXE,
}


static func get_icon(item_id: String) -> ImageTexture:
	assert(_ICONS.has(item_id), "未知物品 icon: %s" % item_id)
	return PixelArt.grid_to_texture(_ICONS[item_id], PALETTE)


static func has_icon(item_id: String) -> bool:
	return _ICONS.has(item_id)
