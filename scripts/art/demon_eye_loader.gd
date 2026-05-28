# 恶魔眼 sprite 加载器: 单张 32×18 PNG (无动画).
# 原图: 766×420 head.png from JacPete (CC0). 已用 Pillow NEAREST 缩到 32×18.
# 用单帧 SpriteFrames 让 AnimatedSprite2D 兼容现有怪物代码.
extends RefCounted

const SHEET_PATH := "res://assets/animals/demon_eye.png"


static func build_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var tex: Texture2D = load(SHEET_PATH)
	if tex == null:
		push_error("demon_eye sheet load 失败: %s" % SHEET_PATH)
		var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 0, 1, 1))
		tex = ImageTexture.create_from_image(img)
	# 所有动画 (idle/move/attack) 都用同一帧 (用户要求"不用动画")
	for anim in ["idle", "move", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 4.0)
		sf.set_animation_loop(anim, true)
		sf.add_frame(anim, tex)
	return sf
