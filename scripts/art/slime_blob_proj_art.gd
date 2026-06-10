# 史莱姆弹 sprite (史莱姆枪). 16x16 绿色滴答果冻团 (重力弹跳). bullet.gd 按方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"g": Color8(80, 170, 70),        # 史莱姆绿边
	"G": Color8(120, 210, 90),       # 史莱姆绿亮
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	".....ggg........",
	"....gGGGg.......",
	"...gGGGGGg......",
	"...gGGGGGg......",
	"..gGGGGGGGg.....",
	"..gGGGGGGGg.....",
	"...gggggggg.....",
	"....g.g.g.......",
	"................",
	"................",
	"................",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var t := PixelArt.grid_to_texture(_PROJ, PALETTE)
	sf.add_animation("fly")
	sf.set_animation_speed("fly", 1.0)
	sf.set_animation_loop("fly", false)
	sf.add_frame("fly", t)
	return sf
