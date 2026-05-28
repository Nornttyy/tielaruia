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


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t0 := PixelArt.grid_to_texture(_F0, PALETTE)
	var t1 := PixelArt.grid_to_texture(_F1, PALETTE)
	sf.add_animation("fly")
	sf.set_animation_speed("fly", 10.0)
	sf.set_animation_loop("fly", true)
	sf.add_frame("fly", t0)
	sf.add_frame("fly", t1)
	return sf
