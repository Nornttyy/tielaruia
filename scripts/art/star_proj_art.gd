# 星星弹 sprite (星星炮). 16x16 五角星 (黄金). 撞墙反弹. bullet.gd 按方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"w": Color8(255, 235, 120),      # 星亮黄
	"W": Color8(240, 195, 60),       # 星金
}

const _PROJ := [
	"................",
	"................",
	".......w........",
	".......w........",
	"......wWw.......",
	"..wwwwWWWwwww...",
	"...wWWWWWWWw....",
	"....wWWWWWw.....",
	"....wWWWWWw.....",
	"...wWW.WWWw.....",
	"..wW.....Ww.....",
	"..w.......w.....",
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
