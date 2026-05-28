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
	# --- 铜 (暖橙) ---
	"p": Color8(140, 70, 30),      # 铜深 (描边侧阴影)
	"C": Color8(210, 120, 60),     # 铜中 (主色)
	"J": Color8(255, 185, 105),    # 铜亮 (闪点)
	# --- 银 (冷亮白) ---
	"s": Color8(140, 155, 180),    # 银深 (冷灰描边侧)
	"d": Color8(245, 250, 255),    # 银亮 (近白; 银无独立闪点, base=shine)
}

# 工具图标 V3: 全部垂直站立 — 剑朝上, 镐/斧头在上方, 柄笔直往下.
# 同一形状模板 + 7 套颜色 (M=边/暗, B=主/亮, F=极亮闪点).
# 木 (M=Y, B=y, F=I), 石 (M=V, B=x, F=x), 铁 (M=E, B=F, F=f),
# 金 (M=Z, B=z, F=P), 钻石 (M=N, B=X, F=Q),
# 铜 (M=p, B=C, F=J), 银 (M=s, B=d, F=d).
# V3 改动: 剑加长 + 尖头; 斧改方形刃 (】形, 平顶平底 + 小斧背);
# 镐 3 行扁横头 (画布边对边); 加 copper + silver 2 tier.

# --- 剑 (垂直刀身 + 护手 + 木柄 + 黑描边) ---
const _WOOD_SWORD := [
	".......nn.......",
	"......nYYn......",
	".....nYyyYn.....",
	".....nYyyYn.....",
	".....nYyyYn.....",
	".....nYyyYn.....",
	".....nYyIYn.....",
	".....nYyyYn.....",
	".....nYyyYn.....",
	".....nYyyYn.....",
	".....nYyyYn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]
const _STONE_SWORD := [
	".......nn.......",
	"......nVVn......",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	".....nVxxVn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]
const _IRON_SWORD := [
	".......nn.......",
	"......nEEn......",
	".....nEFFEn.....",
	".....nEFFEn.....",
	".....nEFFEn.....",
	".....nEFFEn.....",
	".....nEFfEn.....",
	".....nEFFEn.....",
	".....nEFFEn.....",
	".....nEFFEn.....",
	".....nEFFEn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]
const _GOLD_SWORD := [
	".......nn.......",
	"......nZZn......",
	".....nZzzZn.....",
	".....nZzzZn.....",
	".....nZzzZn.....",
	".....nZzzZn.....",
	".....nZzPZn.....",
	".....nZzzZn.....",
	".....nZzzZn.....",
	".....nZzzZn.....",
	".....nZzzZn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]
const _DIAMOND_SWORD := [
	".......nn.......",
	"......nNNn......",
	".....nNXXNn.....",
	".....nNXXNn.....",
	".....nNXXNn.....",
	".....nNXXNn.....",
	".....nNXQNn.....",
	".....nNXXNn.....",
	".....nNXXNn.....",
	".....nNXXNn.....",
	".....nNXXNn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]

# --- 镐 (扁宽头在上, 垂直柄) ---
const _WOOD_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nYyyyyyIyyyyyYn",
	"..nYYYYYYYYYYn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _STONE_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nVxxxxxxxxxxxVn",
	"..nVVVVVVVVVVn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _IRON_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nEFFFFFfFFFFFEn",
	"..nEEEEEEEEEEn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _GOLD_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nZzzzzzPzzzzzZn",
	"..nZZZZZZZZZZn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _DIAMOND_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nNXXXXXQXXXXXNn",
	"..nNNNNNNNNNNn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

# --- 斧 (方头在上 + 收口 + 垂直柄) ---
const _WOOD_AXE := [
	"......nnn.......",
	"......nYYn......",
	"......nnnnnnn...",
	"......nYyyyyyn..",
	"......nYyIyyyn..",
	"......nYyyyyyn..",
	"......nnnnnnn...",
	"......nYYn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _STONE_AXE := [
	"......nnn.......",
	"......nVVn......",
	"......nnnnnnn...",
	"......nVxxxxxn..",
	"......nVxxxxxn..",
	"......nVxxxxxn..",
	"......nnnnnnn...",
	"......nVVn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _IRON_AXE := [
	"......nnn.......",
	"......nEEn......",
	"......nnnnnnn...",
	"......nEFFFFFn..",
	"......nEFfFFFn..",
	"......nEFFFFFn..",
	"......nnnnnnn...",
	"......nEEn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _GOLD_AXE := [
	"......nnn.......",
	"......nZZn......",
	"......nnnnnnn...",
	"......nZzzzzzn..",
	"......nZzPzzzn..",
	"......nZzzzzzn..",
	"......nnnnnnn...",
	"......nZZn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _DIAMOND_AXE := [
	"......nnn.......",
	"......nNNn......",
	"......nnnnnnn...",
	"......nNXXXXXn..",
	"......nNXQXXXn..",
	"......nNXXXXXn..",
	"......nnnnnnn...",
	"......nNNn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

# --- 铜工具 (M=p, B=C, F=J) ---
const _COPPER_SWORD := [
	".......nn.......",
	"......nppn......",
	".....npCCpn.....",
	".....npCCpn.....",
	".....npCCpn.....",
	".....npCCpn.....",
	".....npCJpn.....",
	".....npCCpn.....",
	".....npCCpn.....",
	".....npCCpn.....",
	".....npCCpn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]

const _COPPER_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".npCCCCCJCCCCCpn",
	"..nppppppppppn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

const _COPPER_AXE := [
	"......nnn.......",
	"......nppn......",
	"......nnnnnnn...",
	"......npCCCCCn..",
	"......npCJCCCn..",
	"......npCCCCCn..",
	"......nnnnnnn...",
	"......nppn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

# --- 银工具 (M=s, B=d, F=d 无独立闪点) ---
const _SILVER_SWORD := [
	".......nn.......",
	"......nssn......",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	".....nsddsn.....",
	"....nggGGggn....",
	"...nggGGGGggn...",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
]

const _SILVER_PICKAXE := [
	"..nnnnnnnnnnnn..",
	".nsdddddddddddsn",
	"..nssssssssssn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

const _SILVER_AXE := [
	"......nnn.......",
	"......nssn......",
	"......nnnnnnn...",
	"......nsdddddn..",
	"......nsdddddn..",
	"......nsdddddn..",
	"......nnnnnnn...",
	"......nssn......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
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



# 镜片 (demon eye 掉落): 圆形透明蓝玻璃 + 边缘高光
const _LENS := [
	"................",
	"................",
	"................",
	".....EEEEE......",
	"....EFFFFFE.....",
	"...EFffffffE....",
	"...EfffffffF....",
	"...EfffjfffE....",
	"...EfffjfffF....",
	"...EFffffffE....",
	"....EFFFFFE.....",
	".....EEEEE......",
	"................",
	"................",
	"................",
	"................",
]


# 蜘蛛眼: 圆形红眼 + 黑色十字瞳孔
const _SPIDER_EYE := [
	"................",
	"................",
	"................",
	".....AAAAA......",
	"....AaaaaaA.....",
	"...AAaaaaaAA....",
	"...AaaajaaaA....",
	"...AaajnjaaA....",
	"...AaaajaaaA....",
	"...AAaaaaaAA....",
	"....AaaaaaA.....",
	".....AAAAA......",
	"................",
	"................",
	"................",
	"................",
]


# 骨头: 水平向, 两端球节 (僵尸掉落)
const _BONE := [
	"................",
	"................",
	"................",
	"..jjj......jjj..",
	".jjjjj....jjjjj.",
	".jjwjj....jjwjj.",
	".jjjjjjjjjjjjjj.",
	"..jjjjjjjjjjjj..",
	"..jjjjjjjjjjjj..",
	".jjjjjjjjjjjjjj.",
	".jjwjj....jjwjj.",
	".jjjjj....jjjjj.",
	"..jjj......jjj..",
	"................",
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
	"copper_sword": _COPPER_SWORD,
	"copper_pickaxe": _COPPER_PICKAXE,
	"copper_axe": _COPPER_AXE,
	"silver_sword": _SILVER_SWORD,
	"silver_pickaxe": _SILVER_PICKAXE,
	"silver_axe": _SILVER_AXE,
	"raw_meat": _RAW_MEAT,
	"leather": _LEATHER,
	"wool": _WOOL,
	"grappling_hook": _GRAPPLING_HOOK,
	"bone": _BONE,
	"spider_eye": _SPIDER_EYE,
	"lens": _LENS,
}


# 钩爪 icon: 钩头朝上, 麻绳垂直挂下, 像泰拉瑞亚那种.
# n=黑边, B=金属基, b=高光, K=阴影, r=麻绳棕.
const _GRAPPLING_HOOK := [
	"................",
	".....nnnn.......",
	"....nbBBKn......",
	"....n.nKBn......",
	"...n...nBn......",
	"...nB..nBn......",
	"...nK.nBn.......",
	"....nKBn........",
	".....nrn........",
	".....nrn........",
	".....nrn........",
	".....nrn........",
	".....nrn........",
	".....nrn........",
	".....nrn........",
	"................",
]


static func get_icon(item_id: String) -> ImageTexture:
	assert(_ICONS.has(item_id), "未知物品 icon: %s" % item_id)
	return PixelArt.grid_to_texture(_ICONS[item_id], PALETTE)


static func has_icon(item_id: String) -> bool:
	return _ICONS.has(item_id)
