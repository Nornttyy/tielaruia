# 3 种鼠标光标的 16×16 像素画.
# - arrow(): 默认黄色箭头, 指左上, hotspot=(0,0) = 箭尖
# - sword(): 银白剑+金护手, 指右上, hotspot=(13,1) = 剑尖
# - pickaxe(): 银镐头+木把, 指左上, hotspot=(0,0) = 镐尖
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")


# --- 默认箭头: 黄+黑描边 (Terraria 风) ---
const _P_ARROW := {
	"o": Color8(20, 16, 8),     # 黑描边
	"y": Color8(255, 210, 80),  # 亮黄
	"h": Color8(255, 240, 160), # 高光
}

const _ARROW := [
	"o...............",
	"oo..............",
	"ohyo............",
	"ohyyo...........",
	"ohyyyo..........",
	"ohyyyyo.........",
	"ohyyyyyo........",
	"ohyyyyyyo.......",
	"ohyyyyyyyo......",
	"ohyyyyyyo.......",
	"ohyyyyo.........",
	"ohyyoyyo........",
	"ohyo.oyyo.......",
	"oo...oyyo.......",
	"......oyo.......",
	"......oo........",
]


# --- 镐: 银镐头 + 棕把, 镐尖左上 ---
const _P_PICK := {
	"o": Color8(20, 16, 8),     # 黑描边
	"m": Color8(195, 195, 205), # 银白镐头
	"g": Color8(140, 140, 155), # 暗银
	"b": Color8(115, 75, 40),   # 棕木把
	"l": Color8(170, 120, 75),  # 亮木
}

const _PICK := [
	"oo..............",
	"omoo............",
	"ommmo...........",
	"ommmmoo.........",
	"ommggmmoo.......",
	".ommggmmo.......",
	"..ooooobo.......",
	"......obo.......",
	".....oblo.......",
	"....oblo........",
	"...oblo.........",
	"..oblo..........",
	".oblo...........",
	"oblo............",
	"obo.............",
	"oo..............",
]


static func arrow() -> ImageTexture:
	return PixelArt.grid_to_texture(_ARROW, _P_ARROW)


static func pickaxe() -> ImageTexture:
	return PixelArt.grid_to_texture(_PICK, _P_PICK)
