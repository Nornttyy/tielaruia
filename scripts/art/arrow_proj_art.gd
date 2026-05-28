# 箭投射物 sprite (玩家射出的飞行箭). 单帧 16x16, 横向 (右飞).
# 玩家朝其他方向射时, 由 arrow.gd 旋转 sprite (rotation = velocity.angle).
extends RefCounted

const PixelArt = preload("res://scripts/art/pixel_art.gd")

const PALETTE := {
	".": Color(0, 0, 0, 0),
	"n": Color8(22, 18, 16),     # 黑描边
	"h": Color8(168, 116, 69),   # 木杆
	"H": Color8(120, 80, 45),    # 木暗
	"K": Color8(95, 95, 105),    # 金属箭头深
	"b": Color8(180, 180, 195),  # 金属箭头亮
	"L": Color8(120, 175, 55),   # 绿尾羽
}

const _PROJ := [
	"................",
	"................",
	"................",
	"..............n.",
	".............nKn",
	"............nKKn",
	".LL........nKbKn",
	".LLL.......nKbKn",
	"nLLLhhhhhhhKbKn.",
	".LLL.......nKbKn",
	".LL........nKKn.",
	"............nKn.",
	"..............n.",
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
