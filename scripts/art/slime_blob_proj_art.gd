# 史莱姆弹 sprite (史莱姆枪). 16x16 果冻团, 2 帧压扁/回弹 = 弹跳果冻感. 白高光 + 底部滴液.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"g": Color8(46, 125, 50),        # 果冻边深绿
	"G": Color8(76, 175, 80),        # 果冻主绿
	"q": Color8(140, 220, 130),      # 果冻亮
	"w": Color8(235, 255, 230),      # 白高光点
}

const _F1 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....gggggg.....",
	"....gGqwqGGg....",
	"....gGGGGGGg....",
	"....gGGGGGg.....",
	".....ggggg......",
	"......g.g.......",
	"................",
	"................",
	"................",
	"................",
]

const _F2 := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	"....gggggggg....",
	"...gGqwGGGGGg...",
	"...gGGGGGGGg....",
	"....gggggg......",
	".....g..g.......",
	"................",
	"................",
	"................",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("fly")
	sf.set_animation_speed("fly", 8.0)
	sf.set_animation_loop("fly", true)
	sf.add_frame("fly", PixelArt.grid_to_texture(_F1, PALETTE))
	sf.add_frame("fly", PixelArt.grid_to_texture(_F2, PALETTE))
	return sf
