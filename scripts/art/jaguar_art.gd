# 美洲豹: 用 LPC lioness sheet (Sevarihk, CC-BY 4.0). 见 LICENSES.md.
# Sheet 320×256, 64×64 cell, 5×4 布局 (5 frames × 4 directions).
# 行: 0=up, 1=left, 2=down, 3=right (LPC 标准)
# 我们用 row 3 (右朝向) walk 5 帧.
extends RefCounted

const LpcLoader = preload("res://scripts/art/lpc_loader.gd")
const SHEET_PATH := "res://assets/animals/lioness_lpc.png"


static func build_sprite_frames() -> SpriteFrames:
	# scale 0.5: 64px → 32px (跟其它动物 sprite 比例)
	var walk: Array = LpcLoader.load_lpc_row(SHEET_PATH, 64, 3, 5, 0.5)
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	if walk.size() > 0:
		sf.add_frame("idle", walk[0])
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 8.0)
	sf.set_animation_loop("walk", true)
	for tex in walk:
		sf.add_frame("walk", tex)
	sf.add_animation("hurt")
	sf.set_animation_speed("hurt", 5.0)
	sf.set_animation_loop("hurt", true)
	if walk.size() > 0:
		sf.add_frame("hurt", walk[0])
	return sf
