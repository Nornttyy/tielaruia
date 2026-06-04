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


# === 专属骷髅骑士帧 (Phase: 美化, 24×30, 不再用放大的小骷髅) ===
# 头骨+红眼 / 暗红斗篷(裹身) / 肋骨 / 右手大骨刀 / 双腿. 王冠仍单独贴头顶.
const _KING_PAL := {
	".": Color(0, 0, 0, 0),
	"n": Color8(22, 18, 20),
	"b": Color8(232, 228, 215),
	"B": Color8(180, 175, 160),
	"H": Color8(248, 245, 235),
	"r": Color8(235, 60, 50),
	"c": Color8(130, 30, 38),
	"C": Color8(85, 18, 24),
	"g": Color8(150, 150, 162),
	"k": Color8(67, 40, 24),
}
const _KING_IDLE := [
	"........................",
	".......nnnnnn...........",
	"......nbbbbbbn..........",
	".....nbbHHHHbbn.........",
	".....nbrrnnrrbn....nn...",
	".....nbrrnnrrbn...nbbn..",
	".....nbbHnnHbbn...nbBn..",
	"......nbbnnbbn....nbBn..",
	"....ccnbbbbbbncc..nbBn..",
	"...cccnbnbbnbnccc.nbBn..",
	"..ccCCnbbbbbbnCCcc.nbBn.",
	"..cCCCnbBbBbbnCCCc.nbBn.",
	"..cCCnbBbBbBbbnCCc.nbBn.",
	"..cCCnbBbBbBbbnCCcnbBn..",
	"..cCCnbBbBbBbbnCCnbbBn..",
	"..cCCCnbbbbbbnCCCnggBn..",
	"..cCCCCnbbbbnCCCCcnkn...",
	"..cCCCCnbnnbnCCCCc.nn...",
	"...cCCCnbbbbnCCCc.......",
	"...cCCnbn..nbnCCc.......",
	"...cCnbbn..nbbnCc.......",
	"...cCnbbn..nbbnCc.......",
	"...cnbbn....nbbnc.......",
	"...cnbn......nbnc.......",
	"..ccCn........nCcc......",
	"...nbn........nbn.......",
	"..nbbn........nbbn......",
	"..nnn..........nnn......",
	"........................",
	"........................",
]



# 走路帧 (迈步) + 攻击帧 (举刀过头)
const _KING_WALK := [
	"........................",
	".......nnnnnn...........",
	"......nbbbbbbn..........",
	".....nbbHHHHbbn.........",
	".....nbrrnnrrbn....nn...",
	".....nbrrnnrrbn...nbbn..",
	".....nbbHnnHbbn...nbBn..",
	"......nbbnnbbn....nbBn..",
	"....ccnbbbbbbncc..nbBn..",
	"...cccnbnbbnbnccc.nbBn..",
	"..ccCCnbbbbbbnCCcc.nbBn.",
	"..cCCCnbBbBbbnCCCc.nbBn.",
	"..cCCnbBbBbBbbnCCc.nbBn.",
	"..cCCnbBbBbBbbnCCcnbBn..",
	"..cCCnbBbBbBbbnCCnbbBn..",
	"..cCCCnbbbbbbnCCCnggBn..",
	"..cCCCCnbbbbnCCCCcnkn...",
	"..cCCCCnbnnbnCCCCc.nn...",
	"...cCCCnbbbbnCCCc.......",
	"...cCCnbbn.nbnCCc.......",
	"..ccCnbbn...nbbnCc......",
	".ccCnbbn.....nbnCc......",
	".cnbbn.......nbnCc......",
	"ccnbn........nbbnc......",
	"cnbn.........nbnc.......",
	"nbbn.........nCcc.......",
	".nn..........nbn........",
	".............nbbn.......",
	".............nnn........",
	"........................",
]
const _KING_ATTACK := [
	".....nn.................",
	".....nbn....nnnnnn......",
	".....nbn...nbbbbbbn.....",
	".....nbBn.nbbHHHHbbn....",
	"....nbBn..nbrrnnrrbn....",
	"...nbBn...nbrrnnrrbn....",
	"..nbBn....nbbHnnHbbn....",
	"..nggn.....nbbnnbbn.....",
	"..nkn....ccnbbbbbbncc...",
	"...n....cccnbnbbnbnccc..",
	"......ccCCnbbbbbbnCCcc..",
	"......cCCCnbBbBbbnCCCc..",
	"......cCCnbBbBbBbbnCCc..",
	"......cCCnbBbBbBbbnCCc..",
	"......cCCnbBbBbBbbnCCc..",
	"......cCCCnbbbbbbnCCC...",
	"......cCCCCnbbbbnCCCC...",
	"......cCCCCnbnnbnCCCCc..",
	".......cCCCnbbbbnCCCc...",
	".......cCCnbn..nbnCCc...",
	".......cCnbbn..nbbnCc...",
	".......cCnbbn..nbbnCc...",
	".......cnbbn....nbbnc...",
	".......cnbn......nbnc...",
	"......ccCn........nCcc..",
	".......nbn........nbn...",
	"......nbbn........nbbn..",
	"......nnn..........nnn..",
	"........................",
	"........................",
]

# 骷髅王身体帧 (idle/walk/attack 暂共用这一精细帧, 走位靠状态机不靠帧)
static func build_frames() -> SpriteFrames:
	var idle_tex: ImageTexture = PixelArt.grid_to_texture(_KING_IDLE, _KING_PAL)
	var walk_tex: ImageTexture = PixelArt.grid_to_texture(_KING_WALK, _KING_PAL)
	var atk_tex: ImageTexture = PixelArt.grid_to_texture(_KING_ATTACK, _KING_PAL)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle"); sf.set_animation_loop("idle", true); sf.add_frame("idle", idle_tex)
	# 走: idle ↔ 迈步 两帧轮播
	sf.add_animation("walk"); sf.set_animation_speed("walk", 5.0); sf.set_animation_loop("walk", true)
	sf.add_frame("walk", idle_tex); sf.add_frame("walk", walk_tex)
	# 打: idle ↔ 举刀 两帧轮播
	sf.add_animation("attack"); sf.set_animation_speed("attack", 7.0); sf.set_animation_loop("attack", true)
	sf.add_frame("attack", idle_tex); sf.add_frame("attack", atk_tex)
	return sf
