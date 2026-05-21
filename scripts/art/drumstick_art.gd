# 10×10 鸡腿纹理 (full / half / empty)。用在 HungerHUD。
# 与 HeartsArt 对称：暖色棕褐肉身 + 浅黄高光 + 骨色杆。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _P_FULL := {
	"K": Color8(60, 35, 18),       # 深棕描边
	"H": Color8(135, 85, 50),      # 棕基
	"h": Color8(170, 115, 70),     # 棕中
	"y": Color8(220, 170, 95),     # 高光黄
	"w": Color8(240, 220, 175),    # 骨色
}

const _P_HALF := {
	# 左半填充 + 右半空心
	"K": Color8(60, 35, 18),
	"H": Color8(135, 85, 50),
	"h": Color8(170, 115, 70),
	"y": Color8(220, 170, 95),
	"w": Color8(240, 220, 175),
	"E": Color8(90, 90, 90),       # 空心描边
	"i": Color8(40, 40, 40),       # 空心内部
}

const _P_EMPTY := {
	"E": Color8(90, 90, 90),
	"i": Color8(40, 40, 40),
}

# Full: 右上肉球 (棕 + 黄高光) + 左下骨杆 (浅米色)
const _FULL := [
	"....KKKK..",
	"...KhhyhK.",
	"..KHhyyhHK",
	"..KHhyhHHK",
	"..KHHhhHHK",
	"KwHHHHHK..",
	"Kww.KKK...",
	".Kww......",
	"..Kw......",
	"..........",
]

# Half: 左半实心 (肉球左半 + 骨杆), 右半空心
const _HALF := [
	"....KEEE..",
	"...KhEiiE.",
	"..KHhEiiiE",
	"..KHhEiiiE",
	"..KHHEiiiE",
	"KwHHEEEE..",
	"Kww.EE....",
	".KwwE.....",
	"..Kw......",
	"..........",
]

# Empty: 全灰空心轮廓
const _EMPTY := [
	"....EEEE..",
	"...EiiiiE.",
	"..EiiiiiiE",
	"..EiiiiiiE",
	"..EiiiiiiE",
	"EiiiiiiE..",
	"EiiEEEE...",
	".Eii......",
	"..Ei......",
	"..........",
]


static func build_full() -> ImageTexture:
	return PixelArt.grid_to_texture(_FULL, _P_FULL)


static func build_half() -> ImageTexture:
	return PixelArt.grid_to_texture(_HALF, _P_HALF)


static func build_empty() -> ImageTexture:
	return PixelArt.grid_to_texture(_EMPTY, _P_EMPTY)
