# 骷髅王美术 (Phase 1): 身体复用普通骷髅帧 (实体里放大 2x + 红染), 头顶单独戴破铁王冠。
# 斗篷 / 专属骑士帧 后续精修步骤再加。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

# 破铁王冠 16×8: 两侧高尖 + 中间断尖 + 铁灰带 + 2 颗红宝石
const _CROWN := [
	"................",
	"...n......n.....",
	"...ngn..ngn.....",
	"...ngn.nngn.....",
	"..nGgGggGgGn....",
	"..nGgrggrgGn....",
	"..nGGGGGGGGn....",
	"...nnnnnnnn.....",
]
const _CROWN_PAL := {
	".": Color(0, 0, 0, 0),
	"n": Color8(22, 18, 20),     # 黑描边
	"g": Color8(150, 150, 162),  # 铁亮
	"G": Color8(95, 95, 108),    # 铁暗
	"r": Color8(235, 60, 50),    # 红宝石
}


static func build_crown() -> ImageTexture:
	return PixelArt.grid_to_texture(_CROWN, _CROWN_PAL)


# 飞骨头投射物 (骷髅王远程攻击): 狗骨头形, 白骨色
const _BONE_PROJ := [
	"nWWn...nWWn",
	"WBBWn.nWBBW",
	".nWWWWWWWn.",
	"WBBWn.nWBBW",
	"nWWn...nWWn",
]
const _BONE_PROJ_PAL := {
	".": Color(0, 0, 0, 0),
	"n": Color8(22, 18, 20),      # 黑描边
	"W": Color8(232, 228, 215),   # 骨白
	"B": Color8(180, 175, 160),   # 骨阴影
}


static func build_bone_proj() -> ImageTexture:
	return PixelArt.grid_to_texture(_BONE_PROJ, _BONE_PROJ_PAL)
