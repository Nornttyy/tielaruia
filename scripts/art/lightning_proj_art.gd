# 闪电弹 sprite (闪电链枪/特斯拉). 16x16 电球 + 四向电刺, 2 帧交替 (直刺/斜刺) = 闪烁感.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"y": Color8(255, 235, 90),       # 电黄亮
	"Y": Color8(212, 175, 30),       # 电黄深
	"w": Color8(255, 255, 235),      # 白热核心
}

const _F1 := [
	"................",
	"................",
	"................",
	".......y........",
	".......y........",
	"......yYy.......",
	"..yy.yYwYy......",
	".....yYwwYy.yy..",
	"......yYwYy.....",
	".......yYy......",
	"........y.......",
	"........y.......",
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
	"....y......y....",
	".....y....y.....",
	"......yYYy......",
	".....yYwwYy.....",
	"......yYYy......",
	".....y....y.....",
	"....y......y....",
	"................",
	"................",
	"................",
	"................",
	"................",
]


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("fly")
	sf.set_animation_speed("fly", 10.0)
	sf.set_animation_loop("fly", true)
	sf.add_frame("fly", PixelArt.grid_to_texture(_F1, PALETTE))
	sf.add_frame("fly", PixelArt.grid_to_texture(_F2, PALETTE))
	return sf
