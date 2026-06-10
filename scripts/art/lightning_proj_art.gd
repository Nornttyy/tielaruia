# 闪电弹 sprite (闪电链枪). 16x16 带尖刺的电球 (黄+白核). bullet.gd 按方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"y": Color8(255, 230, 90),       # 电黄
	"Y": Color8(220, 180, 40),       # 暗黄
	"w": Color8(255, 255, 235),      # 白热核心
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	"................",
	".......y........",
	"......yYy.......",
	"...y.ywwy.y.....",
	"..yYywwwyYy.....",
	"...y.ywwy.y.....",
	"......yYy.......",
	".......y........",
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
