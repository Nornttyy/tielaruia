# 风弹 sprite (狂风法杖). 16x16 白/青气流条 (一阵风往右吹). bullet.gd 按方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"w": Color8(235, 250, 255),      # 白气流
	"c": Color8(150, 210, 240),      # 青边
}

const _PROJ := [
	"................",
	"................",
	"................",
	".....wcccccw....",
	"...wc.......w...",
	"..wc............",
	"................",
	".wcccccccccw....",
	"wc..........w...",
	"................",
	"..wcccccccw.....",
	".wc.......w.....",
	"..wc............",
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
