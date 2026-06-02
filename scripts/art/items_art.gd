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
	# --- 地狱合金 (紫黑) — 修 bug: 之前误用 N (钻石青蓝) 当地狱合金, 现在加专属紫黑 ---
	"@": Color8(45, 28, 55),       # 地狱合金主 (深紫黑)
	"#": Color8(28, 15, 38),       # 地狱合金暗 (极深紫)
	"+": Color8(85, 60, 115),      # 地狱合金高光 (亮紫)
	# --- 史莱姆王专用色 ---
	"1": Color8(160, 110, 20),     # 王冠金深 (阴影)
	"2": Color8(212, 175, 55),     # 王冠金中 (主色)
	"3": Color8(255, 224, 130),    # 王冠金亮 (高光)
	"!": Color8(220, 60, 60),      # 王冠红宝石
	"4": Color8(70, 130, 70),      # 史莱姆球深绿 (轮廓)
	"5": Color8(120, 200, 110),    # 史莱姆球中绿 (主色)
	"6": Color8(180, 240, 160),    # 史莱姆球亮绿 (高光)
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
	".....nyIyn......",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"....nYyIyYn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _STONE_SWORD := [
	".......nn.......",
	".....nVxVn......",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"....nvVxVvn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _IRON_SWORD := [
	".......nn.......",
	".....nEfEn......",
	"....neEfEen.....",
	"....neEfEen.....",
	"....neEfEen.....",
	"....neEfEen.....",
	"....neEfEen.....",
	"....neEfEen.....",
	"....neEfEen.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _GOLD_SWORD := [
	".......nn.......",
	".....nZzZn......",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"....nRZzZRn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]
const _DIAMOND_SWORD := [
	".......nn.......",
	".....nNXNn......",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"....nTNXNTn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

# --- 镐 (扁宽头在上, 垂直柄) ---
const _WOOD_PICKAXE := [
	".....nnnnnn.....",
	"...nnIyyyyYnn...",
	".nnIyyyyyyyyYnn.",
	"nIIyyyyyyyyyyyYn",
	"nYyYnnnhinnnYyYn",
	"nYyn..nhin..nyYn",
	"nYn...nhin...nYn",
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
	".....nnnnnn.....",
	"...nnxVVVVvnn...",
	".nnxVVVVVVVVvnn.",
	"nxxVVVVVVVVVVVvn",
	"nvVvnnnhinnnvVvn",
	"nvVn..nhin..nVvn",
	"nvn...nhin...nvn",
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
	".....nnnnnn.....",
	"...nnFEEEEenn...",
	".nnFEEEEEEEEenn.",
	"nFfEEEEEEEEEEEen",
	"neEennnhinnneEen",
	"neEn..nhin..nEen",
	"nen...nhin...nen",
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
	".....nnnnnn.....",
	"...nnzZZZZRnn...",
	".nnzZZZZZZZZRnn.",
	"nzPZZZZZZZZZZZRn",
	"nRZRnnnhinnnRZRn",
	"nRZn..nhin..nZRn",
	"nRn...nhin...nRn",
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
	".....nnnnnn.....",
	"...nnXNNNNTnn...",
	".nnXNNNNNNNNTnn.",
	"nXQNNNNNNNNNNNTn",
	"nTNTnnnhinnnTNTn",
	"nTNn..nhin..nNTn",
	"nTn...nhin...nTn",
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
	".....nCJCn......",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"....npCJCpn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

const _COPPER_PICKAXE := [
	".....nnnnnn.....",
	"...nnJCCCCpnn...",
	".nnJCCCCCCCCpnn.",
	"nJJCCCCCCCCCCCpn",
	"npCpnnnhinnnpCpn",
	"npCn..nhin..nCpn",
	"npn...nhin...npn",
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
	".....ndddn......",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"....nsdddsn.....",
	"...nggGGGGggn...",
	"..nggGGGGGGggn..",
	"......nhin......",
	"......nhin......",
	"......nhin......",
	"......nKKn......",
	"................",
]

const _SILVER_PICKAXE := [
	".....nnnnnn.....",
	"...nndddddsnn...",
	".nndddddddddsnn.",
	"ndddddddddddddsn",
	"nsdsnnnhinnnsdsn",
	"nsdn..nhin..ndsn",
	"nsn...nhin...nsn",
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
# 注: coal / iron_ore / silver_ore 等矿物物品的图标已统一为"挖到的方块"样子,
# 走 art_cache.gd 的 _ITEM_TO_TILE → BlocksArt.COAL_ORE / IRON_ORE / SILVER_ORE.
# 以前这里有 _COAL / _IRON_ORE_ICON / _SILVER_ORE_ICON 小块岩屑图, 用户要求统一就删了.


# 金属锭 通用形状: 6x3 梯形 (上窄下宽), 16x16 居中. 不同金属换色.
const _IRON_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...uuuuuuuu.....",
	"..ttttttttu.....",
	"..uUUUUUUUu.....",
	".uUUUUUUUUUu....",
	".UUUUUUUUUUU....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _COPPER_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...pppppppp.....",
	"..tttttttpu.....",
	"..uuuuuuupu.....",
	".uuuuuuuuuup....",
	".pppppppppup....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _TIN_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...bbbbbbbb.....",
	"..BBBBBBBBb.....",
	"..bbbbbbbbb.....",
	".bBBBBBBBBBb....",
	".BBBBBBBBBBB....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SILVER_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...FFFFFFFF.....",
	"..fFFFFFFFF.....",
	"..FFFFFFFFF.....",
	".fFFFFFFFFFF....",
	".FFFFFFFFFFF....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _GOLD_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...zzzzzzzz.....",
	"..PzzzzzzzZ.....",
	"..zzzzzzzzZ.....",
	".PzzzzzzzzZZ....",
	".ZZZZZZZZZZZ....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# 木弓 icon: 弧形弓 (左侧朝外) + 麻绳竖线 + 手柄
# h=木板棕主, H=木板暗, I=木亮反光, r=麻绳棕, n=黑描边
const _WOOD_BOW := [
	"................",
	".......nnn......",
	"......nHHHn.....",   # 弓顶弯
	".....nHIHHn.....",
	"....nHHr..n.....",   # 弦从顶角出
	"....nHHr........",
	"...nHHIr........",
	"...nHIIr........",   # 弓中部最宽 + 弦
	"...nHIHr........",
	"...nHHHr........",
	"....nHHr........",
	"....nHHr..n.....",
	".....nHIHHn.....",
	"......nHHHn.....",
	".......nnn......",
	"................",
]

# 木箭 icon: 横向箭 (头朝右), 箭头三角 + 杆 + 尾羽
# h=木杆棕, n=黑, K=金属箭头, b=金属高光, L=绿尾羽
const _WOOD_ARROW := [
	"................",
	"................",
	"................",
	"..............n.",
	".............nKn",
	"............nKKn",
	".LL........nKbKn",
	".LLL.......nKbKn",
	"nLLLhhhhhhhKbKn.",
	".LLL.......nKbKn",
	".LL........nKKn.",
	"............nKn.",
	"..............n.",
	"................",
	"................",
	"................",
]

# 火果 icon: 圆果红身 + 棕枝 + 绿叶 + 高光. 用 items_art PALETTE: A=苹果红, a=红高光, m=暗红影, S=棕梗, L=绿叶, n=黑描边, y=沙黄高光.
const _HELL_FRUIT_ICON := [
	"................",
	"........S.......",
	".......LS.......",
	".......SL.......",
	".....nAAAn......",
	"....nAayyaAn....",
	"...nAyaAAayAn...",
	"...nAaaaaaaAn...",
	"...nAayyaayAn...",
	"...nAaaaaaaAn...",
	"...nmaaaaaamn...",
	"....nmaaaamn....",
	".....nmmmmn.....",
	"......nnnn......",
	"................",
	"................",
]

# 黑曜石 icon: 黑灰块 + 紫灰光泽 (items_art 没紫, 用 K/k 灰 + v 偏冷调).
# K=金属阴影 (主), k=深棕 (暗), v=石冷灰 (闪光), n=黑描边
const _OBSIDIAN_ICON := [
	"................",
	"................",
	".....nnnnn......",
	"....nKkkkKn.....",
	"...nKkvkkKn.....",
	"...nKkkKKkn.....",
	"...nKvkkkkn.....",
	"...nKkkkvKn.....",
	"...nKkvkkKn.....",
	"...nkkkkkKn.....",
	"....nKkkkn......",
	".....nnnn.......",
	"................",
	"................",
	"................",
	"................",
]

# 地狱石 icon: 红色矿石块状 + 黑裂纹 + 暗红高光.
# A=红主, a=红亮, m=暗红影, u=橙焰 (rust orange 偷用), n=黑裂.
const _HELL_STONE_ICON := [
	"................",
	"................",
	".....AAAAA......",
	"....AAaaaAAA....",
	"...AaanaaAaaA...",
	"...AaannnaaaA...",
	"...AauaaAAaAA...",
	"...AaaaaaaaaA...",
	"...AaaAuuuaaa...",
	"...AmAaaaaaAA...",
	"....AaaaaaAa....",
	".....AAAAA......",
	"................",
	"................",
	"................",
	"................",
]

# 魔晶锭 icon: 锭形 (圆角矩形) + 黄金主 + 焰橙过渡 + 白闪点 + 黑边
# Z=金中 (palette), z=金亮, P=金极亮, R=金深, u=铁锈/橙过渡 (复用 palette).
# 注: items_art PALETTE 没"魔晶"专属色, 借金 Z/z/P + 铁锈 u 拼出 "火焰金属" 感
const _HELL_CRYSTAL_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...nZzzzzzPZn...",
	"..nZzzPPPzzZRn..",
	".nRZzzzzzzZZRn..",
	".nRZzPzzzPzZRn..",
	".nRZzzzzzzzZRn..",
	".nRZuZzzzZuZRn..",
	"..nRRZZZZZRRn...",
	"...nnnnnnnnn....",
	"................",
	"................",
	"................",
]

# === 盔甲 icons (3 件 × 5 tier = 15) ===
# 形状: helmet (10×10), chest (12×11), pants (8×11).
# Tier 调色板字母对应 items_art.PALETTE:
#   铜 M=p, B=C, F=J;   铁 M=E, B=F, F=f;   银 M=s, B=d, F=d
#   金 M=Z, B=z, F=P;   钻 M=N, B=X, F=Q
# K (黑暗带) 跟 n (描边) 所有 tier 共用. 写 15 个 const 时只换 M/B/F 字母.

# --- HELMET ---
const _COPPER_HELMET := [
	"................",
	".....nnnnnn.....",
	"....npCCCCpn....",
	"...npCJJJJCpn...",
	"...npCCCCCCpn...",
	"...npCCCCCCpn...",
	"...npCKKKKCpn...",
	"...npCKKKKCpn...",
	"....npCCCCpn....",
	".....nppppn.....",
	".....nKKKKn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _IRON_HELMET := [
	"................",
	".....nnnnnn.....",
	"....nEFFFFEn....",
	"...nEFfffFEn....",
	"...nEFFFFFFEn...",
	"...nEFFFFFFEn...",
	"...nEFKKKKFEn...",
	"...nEFKKKKFEn...",
	"....nEFFFFEn....",
	".....nEEEEn.....",
	".....nKKKKn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _SILVER_HELMET := [
	"................",
	".....nnnnnn.....",
	"....nsddddsn....",
	"...nsddddddsn...",
	"...nsddddddsn...",
	"...nsddddddsn...",
	"...nsdKKKKdsn...",
	"...nsdKKKKdsn...",
	"....nsddddsn....",
	".....nssssn.....",
	".....nKKKKn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _GOLD_HELMET := [
	"................",
	".....nnnnnn.....",
	"....nZzzzzZn....",
	"...nZzPPPPzZn...",
	"...nZzzzzzzZn...",
	"...nZzzzzzzZn...",
	"...nZzKKKKzZn...",
	"...nZzKKKKzZn...",
	"....nZzzzzZn....",
	".....nZZZZn.....",
	".....nKKKKn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]
const _DIAMOND_HELMET := [
	"................",
	".....nnnnnn.....",
	"....nNXXXXNn....",
	"...nNXQQQQXNn...",
	"...nNXXXXXXNn...",
	"...nNXXXXXXNn...",
	"...nNXKKKKXNn...",
	"...nNXKKKKXNn...",
	"....nNXXXXNn....",
	".....nNNNNn.....",
	".....nKKKKn.....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# --- CHEST (胸甲) ---
const _COPPER_CHEST := [
	"................",
	"................",
	"...nnnnnnnnnn...",
	"..npCCCCCCCCpn..",
	"..npCJJJJJJCpn..",
	"..npCCCCCCCCpn..",
	".npCCKCCCCKCCpn.",
	".npCCKCCCCKCCpn.",
	".npCCKCCCCKCCpn.",
	".npCCCCCCCCCCpn.",
	".npCCCKKKKCCCpn.",
	"..npCCCCCCCCpn..",
	"...nKKKKKKKKn...",
	"................",
	"................",
	"................",
]
const _IRON_CHEST := [
	"................",
	"................",
	"...nnnnnnnnnn...",
	"..nEFFFFFFFFEn..",
	"..nEFfffffffEn..",
	"..nEFFFFFFFFEn..",
	".nEFFKFFFFKFFEn.",
	".nEFFKFFFFKFFEn.",
	".nEFFKFFFFKFFEn.",
	".nEFFFFFFFFFFEn.",
	".nEFFFKKKKFFFEn.",
	"..nEFFFFFFFFEn..",
	"...nKKKKKKKKn...",
	"................",
	"................",
	"................",
]
const _SILVER_CHEST := [
	"................",
	"................",
	"...nnnnnnnnnn...",
	"..nsddddddddsn..",
	"..nsddddddddsn..",
	"..nsddddddddsn..",
	".nsddKddddKddsn.",
	".nsddKddddKddsn.",
	".nsddKddddKddsn.",
	".nsddddddddddsn.",
	".nsdddKKKKdddsn.",
	"..nsddddddddsn..",
	"...nKKKKKKKKn...",
	"................",
	"................",
	"................",
]
const _GOLD_CHEST := [
	"................",
	"................",
	"...nnnnnnnnnn...",
	"..nZzzzzzzzzZn..",
	"..nZzPPPPPPPzn..",
	"..nZzzzzzzzzZn..",
	".nZzzKzzzzKzzZn.",
	".nZzzKzzzzKzzZn.",
	".nZzzKzzzzKzzZn.",
	".nZzzzzzzzzzzZn.",
	".nZzzzKKKKzzzZn.",
	"..nZzzzzzzzzZn..",
	"...nKKKKKKKKn...",
	"................",
	"................",
	"................",
]
const _DIAMOND_CHEST := [
	"................",
	"................",
	"...nnnnnnnnnn...",
	"..nNXXXXXXXXNn..",
	"..nNXQQQQQQQNn..",
	"..nNXXXXXXXXNn..",
	".nNXXKXXXXKXXNn.",
	".nNXXKXXXXKXXNn.",
	".nNXXKXXXXKXXNn.",
	".nNXXXXXXXXXXNn.",
	".nNXXXKKKKXXXNn.",
	"..nNXXXXXXXXNn..",
	"...nKKKKKKKKn...",
	"................",
	"................",
	"................",
]

# --- PANTS ---
const _COPPER_PANTS := [
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...npCCCCCCpn...",
	"...npCJJJJCpn...",
	"...npCCCCCCpn...",
	"...npnnnnnnpn...",
	"...npnCCCCnpn...",
	"...npnCCCCnpn...",
	"...npnCCCCnpn...",
	"...npnCCCCnpn...",
	"...nKnnnnnnKn...",
	"................",
	"................",
	"................",
]
const _IRON_PANTS := [
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...nEFFFFFFEn...",
	"...nEFfffffEn...",
	"...nEFFFFFFEn...",
	"...nEnnnnnnEn...",
	"...nEnFFFFnEn...",
	"...nEnFFFFnEn...",
	"...nEnFFFFnEn...",
	"...nEnFFFFnEn...",
	"...nKnnnnnnKn...",
	"................",
	"................",
	"................",
]
const _SILVER_PANTS := [
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...nsddddddsn...",
	"...nsddddddsn...",
	"...nsddddddsn...",
	"...nsnnnnnnsn...",
	"...nsnddddnsn...",
	"...nsnddddnsn...",
	"...nsnddddnsn...",
	"...nsnddddnsn...",
	"...nKnnnnnnKn...",
	"................",
	"................",
	"................",
]
const _GOLD_PANTS := [
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...nZzzzzzzZn...",
	"...nZzPPPPzZn...",
	"...nZzzzzzzZn...",
	"...nZnnnnnnZn...",
	"...nZnzzzznZn...",
	"...nZnzzzznZn...",
	"...nZnzzzznZn...",
	"...nZnzzzznZn...",
	"...nKnnnnnnKn...",
	"................",
	"................",
	"................",
]
const _DIAMOND_PANTS := [
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...nNXXXXXXNn...",
	"...nNXQQQQXNn...",
	"...nNXXXXXXNn...",
	"...nNnnnnnnNn...",
	"...nNnXXXXnNn...",
	"...nNnXXXXnNn...",
	"...nNnXXXXnNn...",
	"...nNnXXXXnNn...",
	"...nKnnnnnnKn...",
	"................",
	"................",
	"................",
]

# === 地狱武器 (tier 8): 用 N=紫黑深暗 (借钻石暗蓝) + s/d=银 (合金) + Z/z/P=金 (魔晶装饰) + n=黑.
# 整体紫黑刀身 + 金色护手 + 银柄, 凸显"魔法金属"感.

# 地狱剑: 紫黑刀刃 + 金黄魔晶护手 + 银柄 + 黑描边
const _HELL_SWORD := [
	".......nn.......",
	".....n@+@n......",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....n#@+@#n.....",
	"....nZzzPPzzn...",   # 金黄护手
	"...nZzzZZZZzzn..",
	"......nsdsn.....",   # 银柄
	"......nsdsn.....",
	"......nsdsn.....",
	"......nKKn......",
	"................",
]

# 地狱镐: 紫黑扁宽头 + 中央金魔晶 + 银杆 + 金柄装饰
const _HELL_PICKAXE := [
	".....nnnnnn.....",
	"...nn+@@@@#nn...",
	".nn+@@@@@@@@#nn.",
	"n+z@@@@@@@@@@@#n",   # 紫黑弧形双尖 + 金色高光
	"n#@#nnnsdsnn#@#n",
	"n#@n..nsds..n@#n",
	"n#n...nsds...n#n",
	"......nsds......",
	"......nsds......",
	"......nZzn......",   # 金环装饰
	"......nsds......",
	"......nsds......",
	"......nZzn......",
	"......nsds......",
	"......nKKn......",
	"................",
]

# 地狱斧: 紫黑方头斧 + 中央金魔晶 + 银柄
const _HELL_AXE := [
	"......nnn.......",
	"......n@@n......",
	"......nnnnnnn...",
	"......n@++++Zn..",
	"......n@+PPPzn..",   # 中央金光横线
	"......n@++++zn..",
	"......nnnnnnn...",
	"......n@@n......",
	"......nsds......",
	"......nsds......",
	"......nZzn......",
	"......nsds......",
	"......nsds......",
	"......nZzn......",
	"......nKKn......",
	"................",
]

# === 早期法杖 (wood/iron) + 魔力药水 ===

# 木法杖: 棕木杖身 + 顶端小绿魔草 (新手)
# h=木中, H=木暗, I=木亮, L=绿叶, n=黑
const _WOOD_STAFF := [
	"......nnnnn.....",
	".....nLLLLLn....",   # 绿叶/魔草
	".....nLLLLLn....",
	"....nLqLqLLn....",   # 草高光 (q=史莱姆球高光)
	".....nLLLLn.....",
	"......nnnn......",
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
]

# 铁法杖: 灰铁杖身 + 顶端蓝水晶球 (中期)
# E=铁深, F=铁亮, f=铁极亮, N=钻蓝中, X=蓝高, n=黑
const _IRON_STAFF := [
	"......nnnn......",
	".....nNXXNn.....",   # 蓝水晶球
	"....nNXfXNn....n",   # f 中央闪点
	"....nNXXXXNn....",
	"....nNXXXNn.....",
	".....nnnnn......",
	"......nEFn......",
	"......nEFn......",
	"......nEFn......",
	"......nEfn......",   # 中段高光
	"......nEFn......",
	"......nEFn......",
	"......nEFn......",
	"......nEFn......",
	"......nEFn......",
	"......nKKn......",
]

# 魔力药水: 蓝色玻璃瓶 + 蓝色魔法液体 + 软木塞
# K=金属阴影 (软木塞色), h=木 (软木塞), N=蓝深, X=蓝亮, Q=极亮蓝白, n=黑
const _MANA_POTION := [
	"................",
	"......nhhn......",   # 软木塞
	"......nhhn......",
	".....nNNNNn.....",   # 瓶颈
	".....nNQNNn.....",
	"....nNNXXNNn....",   # 瓶身
	"....nNXXXXNn....",
	"....nNXNXXNn....",
	"....nNNXXXNn....",
	"....nNXXXNNn....",
	"....nNXXNXNn....",
	"....nNNNNNNn....",
	"....nNNNNNNn....",
	".....nNNNNn.....",
	".....nnnnn......",
	"................",
]

# 地狱魔火法杖: 紫黑杖身 + 顶端金黄火球魔晶 + 银缠绕装饰
# N=紫黑深, s/d=银缠, Z/z/P=金黄魔晶, n=黑描边
const _HELL_STAFF := [
	"......nnnn......",
	".....nZzzZn.....",
	"....nZzPPzZn....",   # 金黄魔晶球
	"....nZzPPzZn....",
	".....nZzzZn.....",
	"......nnnn......",
	"......ndsdn.....",   # 银缠绕装饰
	"......n@@@n.....",   # 紫黑杖身 (修 bug: N 是蓝)
	"......n@+@n.....",
	"......ndsdn.....",   # 第 2 圈银缠
	"......n@@@n.....",
	"......n@+@n.....",
	"......n@@@n.....",
	"......ndsdn.....",
	"......n@@@n.....",
	"......nKKKn.....",   # 杖底黑
]

# 地狱合金锭 icon: 真·紫黑底 + 银闪光 (修 bug: 之前用 N/T 钻石蓝, 现在用 @/#/+ 紫).
const _HELL_ALLOY_INGOT := [
	"................",
	"................",
	"................",
	"................",
	"....nnnnnnnn....",
	"...n##@@@@##n...",
	"..n#@@ss##@@#n..",
	".n##@@s##@@@#n..",
	".n##@s+ss+s@#n..",   # + 紫亮 + s 银闪
	".n##@@sssss@#n..",
	".n##@@+@@+@s#n..",
	"..n###@@@@##n...",
	"...nnnnnnnnn....",
	"................",
	"................",
	"................",
]

# 蓝光蘑菇 icon: 蓝盖 + 白点 + 白柄 (复用钻石青蓝 + 羊毛白)
# N=盖中蓝, T=盖阴影, Q=白点闪光, W=柄主白, w=柄阴影, n=黑边
const _MUSHROOM_ICON := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"......nnnnn.....",
	".....nNNTTTn....",
	"....nNNQNTTTn...",
	"....nNNNNTTTn...",
	".....nNTTTTn....",
	"......nnnnn.....",
	"......nWWn......",
	"......nWwn......",
	"......nWwn......",
	"......nnnn......",
]

# 熟肉: 烤过的 raw_meat (颜色暗一点 + 焦边)
const _COOKED_MEAT := [
	"................",
	"................",
	"................",
	"....kkkkk.......",
	"...kMMMMMk......",
	"..kMmMMMMMk.....",
	"..kMMMMMMMk.....",
	"..kMMMMMMmk.....",
	"..kMmMMMMMk.....",
	"...kMMMMMk......",
	"....kkkkk.......",
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
const _FEATHER := [
	"................",
	".......jn.......",
	"......jwwn......",
	"......jwwn......",
	".....jjwwn......",
	".....jwwkn......",
	"....jjwwkn......",
	"....jwwwkn......",
	"...jjwwwkn......",
	"...jwwwwkn......",
	"...jwwwkn.......",
	"....jwwkn.......",
	".....jwkn.......",
	"......jkn.......",
	".......kn.......",
	"......n.........",
]

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


# 史莱姆王冠: 金色王冠形状 + 顶端三个尖 + 中央红宝石. 1=金深, 2=金中, 3=金亮, !=红宝石.
const _SLIME_CROWN := [
	"................",
	"................",
	"................",
	"....2......2....",
	"...23..2...32...",
	"...23.232..32...",
	"..232.232.232...",
	"..232222222232..",
	"..23232!23232...",
	"..2212222122....",
	"..222222222222..",
	"................",
	"................",
	"................",
	"................",
	"................",
]

# 史莱姆球: 圆形绿球 + 深绿轮廓 + 高光. 4=深绿轮廓, 5=主色, 6=高光.
const _SLIME_BALL := [
	"................",
	"................",
	".....4444.......",
	"...446666644....",
	"..46666666664...",
	"..46655566664...",
	".465555555554...",
	".455555555554...",
	".455555555554...",
	".455555555554...",
	"..45555555554...",
	"..44555555444...",
	"...44466644.....",
	".....4444.......",
	"................",
	"................",
]

# === 料理图标 (16×16, 复用 PALETTE 暖色键) ===
const _BREAD := [
	"................",
	"................",
	"....kkkkkkk.....",
	"...kHIIIIIIHk...",
	"..kHIhhhhhhIHk..",
	"..kHhhhhhhhhHk..",
	"..kHhhhhhhhhHk..",
	"..kHhhhhhhhhHk..",
	"..kHhhhhhhhhHk..",
	"...kHhhhhhHk....",
	"....kkkkkkkk....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _MUSHROOM_SOUP := [
	"................",
	".....j..j.......",
	"......j..j......",
	"................",
	"......AAA.......",
	".....AAAAA......",
	"......jjj.......",
	"..WWWWWWWWWWWW..",
	".WuuuuuuuuuuuuW.",
	".WuuuuuuuuuuuuW.",
	"..WuuuuuuuuuuW..",
	"...WWWWWWWWWW...",
	"....WWWWWWWW....",
	"................",
	"................",
	"................",
]

const _APPLE_PIE := [
	"................",
	"................",
	"................",
	".......II.......",
	"......IAAI......",
	".....IAhAAI.....",
	".....IAAhAI.....",
	"....IAAAAAAI....",
	"....IAhAAhAI....",
	"...IAAAAAAAAI...",
	"...IyyyyyyyyI...",
	"..IyYYYYYYYYyI..",
	"..IIIIIIIIIIII..",
	"................",
	"................",
	"................",
]

const _MEAT_SKEWER := [
	".......S........",
	"....kMMMMMk.....",
	"....kMmmMMk.....",
	"....kMMMMMk.....",
	".......S........",
	"....kMMMMMk.....",
	"....kMmmMMk.....",
	"....kMMMMMk.....",
	".......S........",
	"....kMMMMMk.....",
	"....kMmmMMk.....",
	"....kMMMMMk.....",
	".......S........",
	".......S........",
	"................",
	"................",
]

const _MUSHROOM_STEW := [
	"................",
	"......j..j......",
	".......j.j......",
	"................",
	"..KKKKKKKKKKKK..",
	".KuMuuAuuMuuuuK.",
	".KuuuMuuuuAuuuK.",
	".KuAuuuMuuuuuuK.",
	"..KuuuuuuuuuuK..",
	"...KKKKKKKKKK...",
	"....KKKKKKKK....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _APPLE_JAM := [
	"................",
	"....hhhhhhhh....",
	"...hHHHHHHHHh...",
	"....bbbbbbbb....",
	"...bAAAAAAAAb...",
	"..bAAAAAAAAAAb..",
	"..bAaAAAAAaAAb..",
	"..bAAAAAAAAAAb..",
	"..bAAAAAAAAAAb..",
	"..bAAAAAAAAAAb..",
	"..bAAAAAAAAAAb..",
	"...bBBBBBBBBb...",
	"....bbbbbbbb....",
	"................",
	"................",
	"................",
]

const _JELLY_PUDDING := [
	"................",
	"................",
	".....MMMMMM.....",
	"....MjjMMMMM....",
	"...MMMMMMMMMM...",
	"..MMMMMMMMMMMM..",
	"..MMMMMMMMMMMM..",
	"..MmMMMMMMMMmM..",
	"..MmMMMMMMMMmM..",
	"...mMMMMMMMMm...",
	"....mmmmmmmm....",
	"...WWWWWWWWWW...",
	"..WWWWWWWWWWWW..",
	"................",
	"................",
	"................",
]

const _KITCHEN_KNIFE := [
	"................",
	"........b.......",
	".......Bb.......",
	".......BBb......",
	"......BBBb......",
	"......BBBBb.....",
	".....BBBBBb.....",
	".....BBBBBBb....",
	"....BBBBBBBb....",
	"....KKKKKKKk....",
	".......hh.......",
	".......hh.......",
	".......hh.......",
	".......kk.......",
	"................",
	"................",
]

const _FISHING_ROD := [
	"................",
	"..............h.",
	".............hr.",
	"............h.r.",
	"...........h..r.",
	"..........h...r.",
	".........h....r.",
	"........h.....r.",
	".......h......r.",
	"......h.......r.",
	".....h.......br.",
	"....hh.......bb.",
	"....h........b..",
	"................",
	"................",
	"................",
]

# === 海鲜图标 (钓鱼获得, 16×16) ===
const _SALMON := [
	"................",
	"................",
	"................",
	"................",
	"......uuuu......",
	"....uuuuuuuu....",
	"...kuuuuuuuuut..",
	"..kuukuuuuuuYY..",
	"...kuuuuuuuuuY..",
	"....uuuuuuuu....",
	"......uuuu......",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _TUNA := [
	"................",
	"................",
	"................",
	"................",
	"......AAAA......",
	"....AAAAAAAA....",
	"...kAAAAAAAAAm..",
	"..kAAkAAAAAAmm..",
	"...kAAAAAAAAAm..",
	"....AAAAAAAA....",
	"......AAAA......",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _EEL := [
	"................",
	"................",
	".............OO.",
	"...........OOL..",
	"..........OLO...",
	".........OLO....",
	"........OLO.....",
	".......OLO......",
	"......OLO.......",
	".....OLO........",
	"....OLO.........",
	"...OkO..........",
	"..OOO...........",
	"................",
	"................",
	"................",
]

const _LOBSTER := [
	"................",
	"................",
	"..A........A....",
	".AAk......kAA...",
	".AA........AA...",
	"..AA......AA....",
	"...kAAAAAAk.....",
	"....AAAAAA......",
	"....AaaaaA......",
	"....AAAAAA......",
	"....AAAAAA......",
	".....AAAA.......",
	"....A.AA.A......",
	"................",
	"................",
	"................",
]

const _OCTOPUS := [
	"................",
	"................",
	"................",
	"....MMMMMM......",
	"...MMMMMMMM.....",
	"..MMMaMMMMMM....",
	"..MMkMMkMMMM....",
	"..MMMMMMMMMM....",
	"...MMMMMMMM.....",
	"..M.M.MM.M.M....",
	".M..M.MM.M..M...",
	".M...M..M...M...",
	"................",
	"................",
	"................",
	"................",
]

const _SEA_URCHIN := [
	"................",
	"................",
	"................",
	"......k.k.......",
	"......k.k.......",
	"...k..@@@..k....",
	"....@+++++@.....",
	"..k.@+++++@.k...",
	"....@+++++@.....",
	"..k.@+++++@.k...",
	"....@+++++@.....",
	"...k..@@@..k....",
	"......k.k.......",
	"................",
	"................",
	"................",
]

const _SWEET_SHRIMP := [
	"................",
	"................",
	"................",
	".........MMM....",
	"........MaaM....",
	".......Maa......",
	"......Maa.......",
	".....Maa........",
	".....Ma.........",
	".....Maa........",
	"......MaaM......",
	".......MMaMM....",
	"........kk.k....",
	"................",
	"................",
	"................",
]

const _SCALLOP := [
	"................",
	"................",
	"................",
	"......k..k......",
	".....kyYyYk.....",
	"....kyYyYyYk....",
	"...kyYyYyYyYk...",
	"..kyYyYyYyYyYk..",
	"..kYYYYYYYYYYk..",
	"...kWWWWWWWWk...",
	"....kkkkkkkk....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SEAWEED := [
	"................",
	"................",
	".....O...O......",
	"....OL...LO.....",
	"....LO...OL.....",
	".....O...O......",
	".....OL.LO......",
	"......OLO.......",
	"......LOL.......",
	".......O........",
	"......OLO.......",
	".....OL.LO......",
	"................",
	"................",
	"................",
	"................",
]

const _GRILLED_FISH := [
	"................",
	"................",
	"................",
	"......HHHH......",
	"....HuuuuuuH....",
	"...kuukuuuuuH...",
	"..HuuuuHuuuuYY..",
	"...kuuuuHuuuY...",
	"....HuuuuuuH....",
	"......HHHH......",
	".....hhhhhh.....",
	"....h........h..",
	"................",
	"................",
	"................",
	"................",
]

const _ICONS := {
	"fishing_rod": _FISHING_ROD,
	"kitchen_knife": _KITCHEN_KNIFE,
	"grilled_fish": _GRILLED_FISH,
	"salmon": _SALMON,
	"tuna": _TUNA,
	"eel": _EEL,
	"lobster": _LOBSTER,
	"octopus": _OCTOPUS,
	"sea_urchin": _SEA_URCHIN,
	"sweet_shrimp": _SWEET_SHRIMP,
	"scallop": _SCALLOP,
	"seaweed": _SEAWEED,
	"wood_sword": _WOOD_SWORD,
	"wood_pickaxe": _WOOD_PICKAXE,
	"wood_axe": _WOOD_AXE,
	"slime_jelly": _SLIME_JELLY,
	"apple": _APPLE,
	"stone_sword": _STONE_SWORD,
	"stone_pickaxe": _STONE_PICKAXE,
	"stone_axe": _STONE_AXE,
	# coal / iron_ore / silver_ore: 走 art_cache.gd _ITEM_TO_TILE 用 block 图, 不在这里
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
	"wheat_seed": _WHEAT_SEED,
	"wheat": _WHEAT_ITEM,
	"rice": _RICE,
	"rice_seed": _WHEAT_SEED,
	"cooked_rice": _COOKED_RICE,
	"fish_slice": _FISH_SLICE,
	"sushi": _SUSHI,
	"sashimi": _SASHIMI,
	"onigiri": _ONIGIRI,
	"shrimp_sushi": _SHRIMP_SUSHI,
	"uni_gunkan": _UNI_GUNKAN,
	"bone": _BONE,
	"spider_eye": _SPIDER_EYE,
	"feather": _FEATHER,
	"lens": _LENS,
	"iron_ingot": _IRON_INGOT,
	"copper_ingot": _COPPER_INGOT,
	"tin_ingot": _TIN_INGOT,
	"silver_ingot": _SILVER_INGOT,
	"gold_ingot": _GOLD_INGOT,
	"cooked_meat": _COOKED_MEAT,
	"bread": _BREAD,
	"mushroom_soup": _MUSHROOM_SOUP,
	"apple_pie": _APPLE_PIE,
	"meat_skewer": _MEAT_SKEWER,
	"mushroom_stew": _MUSHROOM_STEW,
	"apple_jam": _APPLE_JAM,
	"jelly_pudding": _JELLY_PUDDING,
	"mushroom": _MUSHROOM_ICON,
	"hell_fruit": _HELL_FRUIT_ICON,
	"obsidian": _OBSIDIAN_ICON,
	"hell_stone": _HELL_STONE_ICON,
	"hell_crystal_ingot": _HELL_CRYSTAL_INGOT,
	"hell_alloy_ingot": _HELL_ALLOY_INGOT,
	# 盔甲 (15 件)
	"copper_helmet": _COPPER_HELMET, "copper_chest": _COPPER_CHEST, "copper_pants": _COPPER_PANTS,
	"iron_helmet": _IRON_HELMET, "iron_chest": _IRON_CHEST, "iron_pants": _IRON_PANTS,
	"silver_helmet": _SILVER_HELMET, "silver_chest": _SILVER_CHEST, "silver_pants": _SILVER_PANTS,
	"gold_helmet": _GOLD_HELMET, "gold_chest": _GOLD_CHEST, "gold_pants": _GOLD_PANTS,
	"diamond_helmet": _DIAMOND_HELMET, "diamond_chest": _DIAMOND_CHEST, "diamond_pants": _DIAMOND_PANTS,
	"hell_sword": _HELL_SWORD, "hell_pickaxe": _HELL_PICKAXE, "hell_axe": _HELL_AXE,
	"hell_staff": _HELL_STAFF,
	"wood_staff": _WOOD_STAFF, "iron_staff": _IRON_STAFF,
	"mana_potion": _MANA_POTION,
	"wood_bow": _WOOD_BOW,
	"wood_arrow": _WOOD_ARROW,
	"slime_crown": _SLIME_CROWN,
	"slime_ball": _SLIME_BALL,
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


# 钩爪飞行时显示的小钩头 (16x16, 默认朝右; sprite 用 rotation 跟方向).
# 钩尖朝右上, 后面带一段绳子 (会被 Line2D 接上, 这里只画头).
const _HOOK_HEAD := [
	"................",
	"................",
	"................",
	"..........nKn...",
	"..........nKn...",
	".........nKBn...",
	".........nBBn...",
	"........nKBn....",
	".......nKBn.....",
	"......nKBn......",
	".....nKBn.......",
	"....nBBn........",
	"...nBn..........",
	"...nn...........",
	"................",
	"................",
]


static func get_hook_head_texture() -> ImageTexture:
	return PixelArt.grid_to_texture(_HOOK_HEAD, PALETTE)


# 小麦种子 (3 颗小米粒)
const _WHEAT_SEED := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....ZZz........",
	"....ZZZZz.......",
	".....zZZ........",
	"..........zZZ...",
	".........ZZZZz..",
	"..........zZZ...",
	".....ZZz........",
	"....ZZZZz.......",
	".....zZZ........",
	"................",
]


# 小麦 (黄穗 + 绿杆, 食物)
const _RICE := [
	"................",
	"................",
	"................",
	"................",
	".......jj.......",
	"......jjjj......",
	".....jjwwjj.....",
	".....jwwwwj.....",
	"......jjjj......",
	".......jj.......",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SUSHI := [
	"................",
	"................",
	"................",
	"................",
	"....uuuuuuuu....",
	"...uuuuuuuuuu...",
	"...WWWWWWWWWW...",
	"..WWWWWWWWWWWW..",
	"..WWWWWWWWWWWW..",
	"...WWWWWWWWWW...",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SASHIMI := [
	"................",
	"................",
	"................",
	"...MMMM.........",
	"...MmMM.........",
	"......MMMM......",
	"......MmMM......",
	".........MMMM...",
	".........MmMM...",
	"..WWWWWWWWWWWW..",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _ONIGIRI := [
	"................",
	"................",
	".......W........",
	"......WWW.......",
	".....WWWWW......",
	"....WWWWWWW.....",
	"...WWWWWWWWW....",
	"..WWWWWWWWWWW...",
	"..WWWWWWWWWWW...",
	"..OOOOOOOOOOO...",
	"..OOOOOOOOOOO...",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _SHRIMP_SUSHI := [
	"................",
	"................",
	"................",
	"................",
	"....MaaaaM......",
	"...MaaaaaaM.....",
	"...WWWWWWWWWW...",
	"..WWWWWWWWWWWW..",
	"..WWWWWWWWWWWW..",
	"...WWWWWWWWWW...",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _UNI_GUNKAN := [
	"................",
	"................",
	"................",
	"................",
	"....uuuuuuuu....",
	"...uuuuuuuuuu...",
	"..OWWWWWWWWWWO..",
	"..OWWWWWWWWWWO..",
	"..OWWWWWWWWWWO..",
	"..OOOOOOOOOOOO..",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _COOKED_RICE := [
	"................",
	"................",
	"................",
	"................",
	".....jjjjjj.....",
	"....jwjwjwjw....",
	"...jjjjjjjjjj...",
	"..WWWWWWWWWWWW..",
	"..WHHHHHHHHHHW..",
	"...WHHHHHHHHW...",
	"....WWWWWWWW....",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _FISH_SLICE := [
	"................",
	"................",
	"................",
	"................",
	"....uuuuuuuu....",
	"...uWuuuuWuu....",
	"..uuuuWuuuuuu...",
	"..uWuuuuuWuuu...",
	"...uuuuWuuuu....",
	"....uuuuuuuu....",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
]

const _WHEAT_ITEM := [
	"................",
	"................",
	".......ZzZ......",
	"......ZZZZZ.....",
	".....ZzZzZz.....",
	"......ZZZZZ.....",
	".......ZzZ......",
	".......L.L......",
	".......LLL......",
	"........L.......",
	".......LLL......",
	"........L.......",
	".......LLL......",
	"........L.......",
	"........L.......",
	"................",
]
