# 奥术魔弹 sprite (追踪魔弹枪). 单帧 16x16 紫色发光弹丸 + 拖尾. bullet.gd 按方向旋转.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"p": Color8(120, 60, 200),       # 紫外缘
	"P": Color8(170, 110, 240),      # 紫亮
	"w": Color8(235, 215, 255),      # 白热核心
	"t": Color8(150, 90, 220, 150),  # 半透拖尾
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....ppPPpp.....",
	"..tt.pPwwPp.....",
	".ttt.pPwwPp.....",
	"..tt.pPPPPp.....",
	".....ppPPpp.....",
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
