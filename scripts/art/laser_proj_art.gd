# 激光投射物 sprite. 单帧 16x16 横向发光青色光束. bullet.gd 按飞行方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"C": Color8(40, 160, 230),       # 青色外缘
	"c": Color8(90, 220, 255),       # 青亮
	"w": Color8(225, 250, 255),      # 白热核心
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"...CCCCCCCCCCC..",
	"..CcwwwwwwwwwcC.",
	"..CcwwwwwwwwwcC.",
	"...CCCCCCCCCCC..",
	"................",
	"................",
	"................",
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
