# 牛: 使用 LPC sheet (右朝向走路 4 帧).
# 原作者: Daniel Eddeland (CC-BY 3.0), 见 LICENSES.md.
extends RefCounted

const LpcLoader = preload("res://scripts/art/lpc_loader.gd")
const SHEET_PATH := "res://assets/animals/cow_lpc.png"


static func build_sprite_frames() -> SpriteFrames:
	# 0.6 缩放 = 71x44 → 43x26 (~2.7 tile 宽, 1.6 tile 高)
	return LpcLoader.build_sprite_frames(SHEET_PATH, 0.6)
