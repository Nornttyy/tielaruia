# 树叶弹 sprite (绿叶枪). 16x16 斜置叶片 (尖头 + 斜叶脉 + 叶柄). bullet.gd 按飞行方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"g": Color8(90, 160, 70),        # 叶边
	"G": Color8(130, 205, 95),       # 叶亮
	"v": Color8(70, 120, 55),        # 叶脉
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	"..........g.....",
	"........gGGg....",
	".......gGGvGg...",
	"......gGvGGGg...",
	".....gGGvGGg....",
	"....gGvGGg......",
	"...gGGGg........",
	"...gg...........",
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
