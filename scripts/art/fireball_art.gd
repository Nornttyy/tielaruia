# 火球 (Imp 投射物) art. 单帧 8x8 (比方块小), 中心亮黄 + 外圈橙红 + 黑描边.
# 加个尾巴效果靠多帧轮播 (主体不变, 周边火苗位置抖).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(60, 20, 10),       # 黑红描边
	"r": Color8(220, 60, 30),      # 红外圈
	"o": Color8(255, 130, 40),     # 橙
	"y": Color8(255, 220, 80),     # 亮黄
	"h": Color8(255, 255, 220),    # 白热中心
}

# 法杖魔法弹按元素换色板 (形状复用同一套 _F0/_F1, 只换 5 个色槽):
#   n=深描边, r=外圈, o=中圈, y=亮圈, h=高光芯. 从外到内由暗到亮.
const ICE_PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(25, 45, 90),       # 深蓝描边
	"r": Color8(60, 120, 210),     # 冰蓝外圈
	"o": Color8(90, 175, 240),     # 亮蓝
	"y": Color8(170, 225, 255),    # 浅冰蓝
	"h": Color8(245, 250, 255),    # 白芯
}
const NATURE_PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(25, 55, 18),       # 深绿描边
	"r": Color8(70, 150, 50),      # 叶绿外圈
	"o": Color8(120, 200, 60),     # 亮绿
	"y": Color8(190, 230, 90),     # 黄绿
	"h": Color8(235, 255, 200),    # 嫩黄白芯
}

# 火球 16x16 (但实际只画中间 10x10), 主体圆球 + 外焰
const _F0 := [
	"................",
	"................",
	"................",
	".......nn.......",
	"......nrrn......",
	".....nroorn.....",
	"....nroyhyorrn..",
	"....nroyhhyorn..",
	"....nroyhyornn..",
	".....nroornn....",
	"......nrnn......",
	"....n.nn........",
	"...n............",
	"................",
	"................",
	"................",
]

# 第二帧: 火尾不同方向 (跳动感)
const _F1 := [
	"................",
	"................",
	"................",
	".......nn.......",
	"......nrrn......",
	".....nroorn.....",
	"....nroyhyorrn..",
	"....nroyhhyorn..",
	"....nroyhyornn..",
	"....nrorornn....",
	".......nrn......",
	"......nn.n......",
	".........n......",
	"................",
	"................",
	"................",
]


# element: "fire" (默认, Imp + 地狱法杖) / "ice" (铁法杖) / "nature" (木法杖).
# 形状不变, 只换色板 → 三种法杖弹一眼能分清.
static func build_sprite_frames(element: String = "fire") -> SpriteFrames:
	var pal: Dictionary = PALETTE
	if element == "ice":
		pal = ICE_PALETTE
	elif element == "nature":
		pal = NATURE_PALETTE
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0 := PixelArt.grid_to_texture(_F0, pal)
	var t1 := PixelArt.grid_to_texture(_F1, pal)
	sf.add_animation("fly")
	sf.set_animation_speed("fly", 10.0)
	sf.set_animation_loop("fly", true)
	sf.add_frame("fly", t0)
	sf.add_frame("fly", t1)
	return sf
