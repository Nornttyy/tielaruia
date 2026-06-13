# 地狱恶魔领主美术: 飞行恶魔 (双角 + 蝙蝠翼 + 发光眼 + 獠牙)。24×16 三帧:
# idle (翼平展) / flap (翼下扇) / attack (张嘴喷火 + 眼亮)。实体里 BODY_SCALE 放大。
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const _PAL := {
	".": Color(0, 0, 0, 0),
	"n": Color8(20, 12, 18),       # 黑描边
	"D": Color8(95, 28, 38),       # 身暗 (深红)
	"d": Color8(150, 45, 55),      # 身中 (红)
	"h": Color8(200, 80, 80),      # 身高光
	"r": Color8(255, 170, 40),     # 眼 (暗金光)
	"R": Color8(255, 225, 90),     # 眼 (亮金光, 攻击时)
	"k": Color8(50, 16, 26),       # 翼暗
	"w": Color8(110, 35, 55),      # 翼膜 (紫红)
	"y": Color8(240, 228, 200),    # 角 / 獠牙 / 爪 (骨色)
}

const _IDLE := [
	".......n........n.......",
	"......nyn......nyn......",
	"......nDyDnnnnDyDn......",
	".....nkDDDDDDDDDDkn.....",
	"...nkwDhDDddddDDhDwkn...",
	"..nkwwDDrRddddRrDDwwkn..",
	".nkwwwDDddddddddDDwwwkn.",
	".nkwwwwDDddyyddDDwwwwkn.",
	".nkwwwDDddddddddDDwwwkn.",
	"..nkwwDDDddddddDDDwwkn..",
	"...nkwDDDDddddDDDDwkn...",
	".....nDDDDDDDDDDDDn.....",
	"......nDDddddddDDn......",
	".......nDDddddDDn.......",
	"........nyn..nyn........",
	".........ny....yn.......",
]

const _FLAP := [
	".......n........n.......",
	"......nyn......nyn......",
	"......nDyDnnnnDyDn......",
	".....nkDDDDDDDDDDkn.....",
	".....nDhDDddddDDhDn.....",
	".....nDDrRddddRrDDn.....",
	"....nkDDddddddddDDkn....",
	"...nkwDDddyyddDDwkn.....",
	"..nkwwDDddddddddDDwwkn..",
	".nkwwwDDDddddddDDDwwwkn.",
	".nkwwwwDDDDddDDDDwwwwkn.",
	".....nDDDDDDDDDDDDn.....",
	"......nDDddddddDDn......",
	".......nDDddddDDn.......",
	"........nyn..nyn........",
	".........ny....yn.......",
]

const _WINGS_UP := [
	".......n........n.......",
	"...k..nyn......nyn..k...",
	"..kw.nDyDnnnnDyDn.wk....",
	"..kw.nkDDDDDDDDDDkn.wk..",
	".kww.nDhDDddddDDhDn.wwk.",
	".kww.nDDrRddddRrDDn.wwk.",
	"..kwwnDDddddddddDDnwwk..",
	"...wknDDddyyddDDnkw.....",
	".....nDDddddddddDDn.....",
	"....nkDDDddddddDDDkn....",
	"...nkwDDDDddddDDDDwkn...",
	".....nDDDDDDDDDDDDn.....",
	"......nDDddddddDDn......",
	".......nDDddddDDn.......",
	"........nyn..nyn........",
	".........ny....yn.......",
]

const _ATTACK := [
	".......n........n.......",
	"......nyn......nyn......",
	"......nDyDnnnnDyDn......",
	".....nkDDDDDDDDDDkn.....",
	"...nkwDhDDddddDDhDwkn...",
	"..nkwwDDRRddddRRDDwwkn..",
	".nkwwwDDddddddddDDwwwkn.",
	".nkwwwwDDRyyyyRDDwwwwkn.",
	".nkwwwDDddddddddDDwwwkn.",
	"..nkwwDDDddddddDDDwwkn..",
	"...nkwDDDDddddDDDDwkn...",
	".....nDDDDDDDDDDDDn.....",
	"......nDDddddddDDn......",
	".......nDDddddDDn.......",
	"........nyn..nyn........",
	".........ny....yn.......",
]


static func build_frames() -> SpriteFrames:
	var up_tex: ImageTexture = PixelArt.grid_to_texture(_WINGS_UP, _PAL)   # 翅膀抬高
	var idle_tex: ImageTexture = PixelArt.grid_to_texture(_IDLE, _PAL)     # 翅膀平展
	var flap_tex: ImageTexture = PixelArt.grid_to_texture(_FLAP, _PAL)     # 翅膀下扇
	var atk_tex: ImageTexture = PixelArt.grid_to_texture(_ATTACK, _PAL)    # 张嘴喷火
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# idle = 平滑振翅循环 (下→中→上→中), 4 帧, 飞行更飘逸 (用户: 多帧更自然)
	sf.add_animation("idle"); sf.set_animation_loop("idle", true); sf.set_animation_speed("idle", 8.0)
	for fr in [flap_tex, idle_tex, up_tex, idle_tex]:
		sf.add_frame("idle", fr)
	# walk 复用同一套振翅 (飞行怪没走路)
	sf.add_animation("walk"); sf.set_animation_loop("walk", true); sf.set_animation_speed("walk", 8.0)
	for fr in [flap_tex, idle_tex, up_tex, idle_tex]:
		sf.add_frame("walk", fr)
	# attack = 抬翅蓄力 → 张嘴喷 (2 帧) → 收, 4 帧
	sf.add_animation("attack"); sf.set_animation_loop("attack", false); sf.set_animation_speed("attack", 10.0)
	for fr in [up_tex, atk_tex, atk_tex, idle_tex]:
		sf.add_frame("attack", fr)
	return sf
