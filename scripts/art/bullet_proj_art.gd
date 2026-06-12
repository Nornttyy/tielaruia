# 子弹投射物 sprite (玩家枪射出的飞行子弹). 单帧 16x16, 横向 (右飞).
# 黄铜壳 + 白热芯 + 铜尖朝右 + 身后半透速度线. bullet.gd 按飞行方向旋转 sprite.
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(26, 20, 16),        # 黑描边
	"y": Color8(214, 176, 108),     # 黄铜壳亮
	"Y": Color8(168, 128, 66),      # 黄铜壳暗
	"u": Color8(176, 108, 64),      # 铜尖基
	"t": Color8(220, 150, 96),      # 铜尖高光
	"w": Color8(255, 250, 220),     # 白热芯 (弹头发光感)
	"s": Color8(255, 238, 180, 170),# 速度线 (半透淡黄)
}

const _PROJ := [
	"................",
	"................",
	"................",
	"................",
	"................",
	"................",
	".....nnnnnnn....",
	"..ss.nyyyYutn...",
	".sssnyywyYuttn..",
	"..ss.nyyyYutn...",
	".....nnnnnnn....",
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
