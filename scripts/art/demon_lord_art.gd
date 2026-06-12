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
	var idle_tex: ImageTexture = PixelArt.grid_to_texture(_IDLE, _PAL)
	var flap_tex: ImageTexture = PixelArt.grid_to_texture(_FLAP, _PAL)
	var atk_tex: ImageTexture = PixelArt.grid_to_texture(_ATTACK, _PAL)
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# idle = 振翅循环 (平展 ↔ 下扇)
	sf.add_animation("idle"); sf.set_animation_loop("idle", true); sf.set_animation_speed("idle", 4.0)
	sf.add_frame("idle", idle_tex); sf.add_frame("idle", flap_tex)
	# walk 复用 idle (飞行怪没走路)
	sf.add_animation("walk"); sf.set_animation_loop("walk", true); sf.set_animation_speed("walk", 6.0)
	sf.add_frame("walk", idle_tex); sf.add_frame("walk", flap_tex)
	# attack = 张嘴
	sf.add_animation("attack"); sf.set_animation_loop("attack", false); sf.set_animation_speed("attack", 6.0)
	sf.add_frame("attack", atk_tex); sf.add_frame("attack", idle_tex)
	return sf
