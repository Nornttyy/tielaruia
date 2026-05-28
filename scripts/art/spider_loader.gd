# 蜘蛛 sprite sheet 加载器.
# 原图: 210×42 PNG, 5 帧水平排列, 每帧 42×42.
# 帧顺序 (来自 OpenGameArt 描述): ready / attack / hurt / growl + 1 额外 (可能是 frame 0 阴影或额外姿势)
# 假设布局: [shadow?, ready, attack, hurt, growl] — 我们用 frame 1..4 做动画, frame 0 跳过.
#
# 用户偏好: 蜘蛛在 12-tile 世界里要显得小一点 (~16-18 px). 缩 0.4x.
#
# 许可: Heather Lee Harvey, CC-BY 3.0. 见 LICENSES.md.
extends RefCounted

const SHEET_PATH := "res://assets/animals/spider.png"
const FRAME_STRIDE := 42      # 原图每帧 42 像素步长 (含 1px 左边线 + 41px 内容)
const FRAME_CONTENT := 41     # 每帧实际内容宽 (跳过 col 0 的黑分隔线)
const FRAME_TOP_SKIP := 1     # 跳过 row 0 (顶部黑线)
const FRAME_BOTTOM := 41      # 内容高 (跳过 row 0, 保留 shadow)
const NUM_FRAMES := 5         # 共 5 帧
const RENDER_SCALE := 0.4     # 缩到 ~16 px, 跟 slime / zombie 同尺寸级别


# 加载并切帧. 返回 dict: {"idle": Array[ImageTexture], "attack": [...], "hurt": [...]}
static func build_sprite_frames() -> SpriteFrames:
	var tex: Texture2D = load(SHEET_PATH)
	if tex == null:
		push_error("spider sheet load 失败: %s" % SHEET_PATH)
		return _empty_sprite_frames()
	var img: Image = tex.get_image()
	if img == null:
		return _empty_sprite_frames()
	var frames: Array = []  # 5 个 ImageTexture
	var out_w: int = max(1, int(round(float(FRAME_CONTENT) * RENDER_SCALE)))
	var out_h: int = max(1, int(round(float(FRAME_BOTTOM) * RENDER_SCALE)))
	for i in NUM_FRAMES:
		# 跳过 col 0 (左边竖线) + row 0 (顶横线), 保留 shadow (rows 38-41)
		var cell: Image = img.get_region(Rect2i(
			i * FRAME_STRIDE + 1, FRAME_TOP_SKIP,
			FRAME_CONTENT, FRAME_BOTTOM))
		cell.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
		frames.append(ImageTexture.create_from_image(cell))
	# 帧映射 (按 description "ready/attack/hurt/growl"):
	# - idle: 帧 1 (ready) + 帧 4 (growl) 来回切, 1.5 fps 微抖
	# - attack: 帧 2 (attack), 4 fps
	# - hurt: 帧 3 (hurt), 单帧
	# - walk: 没有 walk 帧 → 用 idle frames (蜘蛛 walk 看起来跟 idle 差不多)
	# 帧 0 (额外/阴影?) 不用.
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# idle
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", frames[1])  # ready
	sf.add_frame("idle", frames[4])  # growl
	# walk (复用 idle 帧切换更快)
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 6.0)
	sf.set_animation_loop("walk", true)
	sf.add_frame("walk", frames[1])
	sf.add_frame("walk", frames[4])
	# attack
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 4.0)
	sf.set_animation_loop("attack", false)
	sf.add_frame("attack", frames[2])
	# hurt
	sf.add_animation("hurt")
	sf.set_animation_speed("hurt", 4.0)
	sf.set_animation_loop("hurt", false)
	sf.add_frame("hurt", frames[3])
	return sf


static func _empty_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	# 占位空帧防 crash
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))  # magenta 标识"贴图缺失"
	sf.add_frame("idle", ImageTexture.create_from_image(img))
	return sf
