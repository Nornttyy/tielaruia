# 10×10 红心纹理 (full / half / empty)。用在 HealthHUD。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _P_FULL := {
	"D": Color8(50, 8, 8),       # 深红描边
	"R": Color8(195, 35, 40),    # 红
	"r": Color8(228, 75, 80),    # 红高光
	"h": Color8(255, 180, 180),  # 心顶亮点
}

const _P_HALF := {
	# 左半填充 + 右半空心
	"D": Color8(50, 8, 8),
	"R": Color8(195, 35, 40),
	"r": Color8(228, 75, 80),
	"h": Color8(255, 180, 180),
	"E": Color8(90, 90, 90),     # 空心描边
	"i": Color8(40, 40, 40),     # 空心内部 (深灰)
}

const _P_EMPTY := {
	"E": Color8(90, 90, 90),
	"i": Color8(40, 40, 40),
}

# Full heart: 满色填充
const _FULL := [
	"..........",
	".DD..DD...",
	"DRhDDRRRD.",
	"DRrRRRRRD.",
	"DRRRRRRRD.",
	".DRRRRRD..",
	"..DRRRD...",
	"...DRD....",
	"....D.....",
	"..........",
]

# Half heart: 左半填充 + 右半空心
const _HALF := [
	"..........",
	".DD..EE...",
	"DRhDDEiiE.",
	"DRrRREiiE.",
	"DRRRREiiE.",
	".DRRREiE..",
	"..DRREE...",
	"...DRE....",
	"....D.....",
	"..........",
]

# Empty heart: 灰色空心
const _EMPTY := [
	"..........",
	".EE..EE...",
	"EiiEEiiiE.",
	"EiiiiiiiE.",
	"EiiiiiiiE.",
	".EiiiiiE..",
	"..EiiiE...",
	"...EiE....",
	"....E.....",
	"..........",
]


static func build_full() -> ImageTexture:
	return PixelArt.grid_to_texture(_FULL, _P_FULL)


static func build_half() -> ImageTexture:
	return PixelArt.grid_to_texture(_HALF, _P_HALF)


static func build_empty() -> ImageTexture:
	return PixelArt.grid_to_texture(_EMPTY, _P_EMPTY)
