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
	"c": Color8(50, 40, 35),     # 煤块基 (暖深灰)
	"u": Color8(168, 100, 60),   # 铁锈基 (暖橙)
	"U": Color8(130, 70, 40),    # 铁锈阴影
	"t": Color8(200, 140, 90),   # 铁锈高光
	"M": Color8(220, 110, 110),  # 肉粉
	"m": Color8(180, 70, 75),    # 肉粉阴影
	"j": Color8(245, 240, 230),  # 骨白 / 羊毛
	"W": Color8(245, 240, 232),  # 羊毛主
	"w": Color8(215, 210, 200),  # 羊毛阴影
	"l": Color8(165, 110, 70),   # 皮革浅
	"D": Color8(110, 65, 35),    # 皮革深 (与第 28 行叶绿 L 冲突, 重命名为 D)
	# --- 工具重画新增色 (RPG 金属闪风) ---
	"n": Color8(26, 20, 16),       # 通用黑描边
	"e": Color8(40, 50, 65),       # 钢蓝深阴影 (iron blade shadow)
	"E": Color8(95, 115, 135),     # 钢蓝中
	"F": Color8(180, 200, 220),    # 钢蓝高光
	"f": Color8(235, 245, 255),    # 钢蓝极亮闪点
	"v": Color8(70, 70, 78),       # 石质冷灰深
	"V": Color8(130, 132, 142),    # 石质冷灰中
	"x": Color8(190, 195, 205),    # 石质冷灰高光
	"i": Color8(115, 78, 44),      # 木柄中间纹 (比 h 暗一档)
	"I": Color8(204, 156, 102),    # 木柄反光高光 (比 y 亮一档)
	# --- 新工具色 (T27): 金 (Z/z/P/R) + 钻石 (N/X/Q/T) ---
	"Z": Color8(220, 180, 60),     # 金中
	"z": Color8(255, 220, 110),    # 金高光
	"P": Color8(255, 245, 180),    # 金极亮 (闪光点)
	"R": Color8(160, 110, 20),     # 金深阴影
	"N": Color8(80, 175, 215),     # 钻石中 (青蓝)
	"X": Color8(180, 235, 255),    # 钻石高光 (淡蓝)
	"Q": Color8(225, 250, 255),    # 钻石极亮 (近白冰光)
	"T": Color8(40, 110, 165),     # 钻石深阴影 (深海蓝)
}

# 木剑：对角线刀身 + 木柄 + 护手 + 黑描边 (RPG 金属闪风)
const _WOOD_SWORD := [
	"............nnn.",
	"...........nyyn.",
	"..........nyYIn.",
	".........nyYIn..",
	"........nyYIn...",
	".......nyYIn....",
	"......nyYIn.....",
	".....nyYIn......",
	"....nyYIn.......",
	"...nggGGn.......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhin........",
	"....nhin........",
	"....nKKn........",
	"................",
]

# 木镐: T 形头 + 45° 斜柄 + 黑描边
const _WOOD_PICKAXE := [
	"...nnnnnnnnn....",
	"..nyYYYYYYIIn...",
	".nyyYYYYYYIIIn..",
	"..nyYYYYYYIIn...",
	"...nnyYYYInn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]

# 木斧: 斧头 + 45° 斜柄 + 黑描边
const _WOOD_AXE := [
	"..nYYYYn........",
	".nYYYYYIn.......",
	"nYYYYYYYIn......",
	"nYYYYYYIIn......",
	"nYYYYYIIn.......",
	"nYYYYIIn........",
	".nYYIIn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
	"................",
]

# 石剑: 冷灰刀身 + 木柄 + 黑描边
const _STONE_SWORD := [
	"............nnn.",
	"...........nVVn.",
	"..........nVvVn.",
	".........nVvVxn.",
	"........nVvVxn..",
	".......nVvVxn...",
	"......nVvVxn....",
	".....nVvVxn.....",
	"....nVvVxn......",
	"...nggGGGn......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhIn........",
	"....nhin........",
	"....nKKn........",
	"................",
]

# 石镐: 冷灰石头头 + 45° 斜柄 + 黑描边
const _STONE_PICKAXE := [
	"...nnnnnnnnn....",
	"..nVVVVVVVVxn...",
	".nVxxxxxxxxVxn..",
	"..nVxvvvvvVxn...",
	"...nnVvvvVnn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]

# 石斧: 冷灰半月斧头 + 45° 斜柄 + 黑描边
const _STONE_AXE := [
	"..nVVVVn........",
	".nVxxxxxn.......",
	"nVxxxxxxxn......",
	"nVxxxvvvVn......",
	"nVxxxvVVn.......",
	"nVxxvVVn........",
	".nVvVVn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
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

# 煤块: 不规则块状堆叠, 中央深 k 阴影
const _COAL := [
	"................",
	"................",
	"....cccccc......",
	"...ckckckkc.....",
	"..ckccccccck....",
	"..ccckcccckcc...",
	"..cccccckkccc...",
	"...cccckcccc....",
	"....ccckcc......",
	".....ccc........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# 铁矿原石: 暖石底 + 几处铁锈斑
const _IRON_ORE_ICON := [
	"................",
	"................",
	"....utuuu.......",
	"...uUUtUUu......",
	"..uUUuuUUUu.....",
	"..uUuUuUUtu.....",
	"..uUttUuUUu.....",
	"...uUuUUUu......",
	"....uuutu.......",
	".....uuu........",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# 铁镐: 钢蓝白闪光镐头 + 45° 斜柄 + 黑描边 (RPG 金属闪风, 最闪)
const _IRON_PICKAXE := [
	"...nnnnnnnnn....",
	"..nEEEEEFfFEn...",
	".nEFFFFFFFFFEn..",
	"..nEeeEEEEEEn...",
	"...nnEeeeFnn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]

const _RAW_MEAT := [
	"................",
	"................",
	"................",
	"......MMMM......",
	".....MmmmmM.....",
	"....MmmmmmmM....",
	"....Mmmjjmmm....",
	"....Mmmmjjmm....",
	"....Mmmmmmm.....",
	".....MmmmmM.....",
	".....MMMMM......",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _LEATHER := [
	"................",
	"................",
	"...DDDDDDDDDD...",
	"...DllllllllD...",
	"...DlDDDDDDlD...",
	"...DlDllDllDD...",
	"...DllllllllD...",
	"...DlDlDDlDlD...",
	"...DllllllllD...",
	"...DDDDDDDDDD...",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _WOOL := [
	"................",
	"................",
	"......WWWWW.....",
	".....WwWWWwW....",
	"....WwWWWWWwW...",
	"....wWWWWWWWw...",
	"....WWWwWwWWW...",
	"....wWWWWWWWw...",
	"....WwWWwWWwW...",
	".....WwWWWwW....",
	"......WWWWW.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# --- 铁剑 / 铁斧 (T27): 钢蓝闪光刀身 + 木柄, 模仿 stone 形状 ---
const _IRON_SWORD := [
	"............nnn.",
	"...........nEEn.",
	"..........nEeEn.",
	".........nEeEFn.",
	"........nEeEFn..",
	".......nEeEFn...",
	"......nEeEFn....",
	".....nEeEFn.....",
	"....nEeEFn......",
	"...nggGGGn......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhIn........",
	"....nhin........",
	"....nKKn........",
	"................",
]

const _IRON_AXE := [
	"..nEEEEn........",
	".nEFFFFFn.......",
	"nEFFFFFFFn......",
	"nEFFFeeeEn......",
	"nEFFFeEEn.......",
	"nEFFeEEn........",
	".nEeEEn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
	"................",
]

# --- 金 (T27): 金黄刀身 + 1 点 P 闪光 ---
const _GOLD_SWORD := [
	"............nnn.",
	"...........nZZn.",
	"..........nZRZn.",
	".........nZRZzn.",
	"........nZRZPn..",
	".......nZRZzn...",
	"......nZRZzn....",
	".....nZRZzn.....",
	"....nZRZzn......",
	"...nggGGGn......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhIn........",
	"....nhin........",
	"....nKKn........",
	"................",
]

const _GOLD_PICKAXE := [
	"...nnnnnnnnn....",
	"..nZZZZZzPzZn...",
	".nZzzzzzzzzZRn..",
	"..nZRRZZZZZRn...",
	"...nnZRRRznn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]

const _GOLD_AXE := [
	"..nZZZZn........",
	".nZzzzzPn.......",
	"nZzzzzzzzn......",
	"nZzzzRRRZn......",
	"nZzzzRZZn.......",
	"nZzzRZZn........",
	".nZRZZn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
	"................",
]

# --- 钻石 (T27): 青蓝刀身 + Q 冰光 ---
const _DIAMOND_SWORD := [
	"............nnn.",
	"...........nNNn.",
	"..........nNTNn.",
	".........nNTNXn.",
	"........nNTNQn..",
	".......nNTNXn...",
	"......nNTNXn....",
	".....nNTNXn.....",
	"....nNTNXn......",
	"...nggGGGn......",
	"..nggGGGGn......",
	".nggGGGGn.......",
	"....nhIn........",
	"....nhin........",
	"....nKKn........",
	"................",
]

const _DIAMOND_PICKAXE := [
	"...nnnnnnnnn....",
	"..nNNNNNXQXNn...",
	".nNXXXXXXXXXNn..",
	"..nNTTNNNNNNTn..",
	"...nnNTTTXnn....",
	".....nhIn.......",
	"....nhIn........",
	"....nhin........",
	"...nhin.........",
	"...nhin.........",
	"..nhin..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nKKn............",
	"................",
]

const _DIAMOND_AXE := [
	"..nNNNNn........",
	".nNXXXXQn.......",
	"nNXXXXXXXn......",
	"nNXXXTTTNn......",
	"nNXXXTNNn.......",
	"nNXXTNNn........",
	".nNTNNn.........",
	"..nhIn..........",
	"..nhin..........",
	".nhin...........",
	".nhin...........",
	"nhin............",
	"nhin............",
	"nhin............",
	"nKKn............",
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
	"coal": _COAL,
	"iron_ore": _IRON_ORE_ICON,
	"iron_pickaxe": _IRON_PICKAXE,
	"iron_sword": _IRON_SWORD,
	"iron_axe": _IRON_AXE,
	"gold_sword": _GOLD_SWORD,
	"gold_pickaxe": _GOLD_PICKAXE,
	"gold_axe": _GOLD_AXE,
	"diamond_sword": _DIAMOND_SWORD,
	"diamond_pickaxe": _DIAMOND_PICKAXE,
	"diamond_axe": _DIAMOND_AXE,
	"raw_meat": _RAW_MEAT,
	"leather": _LEATHER,
	"wool": _WOOL,
}


static func get_icon(item_id: String) -> ImageTexture:
	assert(_ICONS.has(item_id), "未知物品 icon: %s" % item_id)
	return PixelArt.grid_to_texture(_ICONS[item_id], PALETTE)


static func has_icon(item_id: String) -> bool:
	return _ICONS.has(item_id)
