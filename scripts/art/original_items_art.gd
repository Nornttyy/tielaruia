# 新基础材料使用同一套少色像素轮廓，不借用无关物品图标。
extends RefCounted
const PixelArt = preload("res://scripts/art/pixel_art.gd")
const PAL := {".": Color.TRANSPARENT, "k": Color8(46, 43, 49), "s": Color8(81, 80, 88), "m": Color8(134, 139, 147), "h": Color8(202, 211, 211)}
const PATTERNS := {
	"iron_anvil": [
		"................", "................", "................", "................",
		".....kkkkkkkkk..", "..kkkhhhhhhhhhk.", ".kmmmmmmmmmmmmk.", "..kkssssssssssk.",
		"....kkkkmsskkk..", ".......kmssk....", ".......kmssk....", "......kmmsssk...",
		"....kkmmmsssskk.", "...ksssssssssssk", "...kkkkkkkkkkkkk", "................",
	],
	"chain": [
		"................", ".........kkkk...", "........khhmhk..", ".......khk..msk.",
		"......khmk..msk.", "......khsmkmmk..", "......kmkhkkk...", ".....khkksmk....",
		"....khk..msk....", "...khmmkmmk.....", "..khkkhkkk......", ".khk..msk.......",
		".khk..msk.......", "..kmmmmsk.......", "...kkkkk........", "................",
	],
	"hook": [
		"................", "......kkkk......", ".....khmmmk.....", ".....khk.msk....",
		".....khmmmk.....", "......kmkk......", "......khsk......", "......khsk......",
		"......khsk......", "......khsk..k...", "......khsk.kmk..", "......khskkmhk..",
		".......khmmmk...", "........kkkk....", "................", "................",
	],
}

static func get_texture(id: String) -> ImageTexture:
	return PixelArt.grid_to_texture(PATTERNS[id], PAL)
