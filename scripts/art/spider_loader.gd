# 蜘蛛 sprite sheet 加载器.
# 当前图: 51×20 PNG, 3 帧水平排列, 每帧 17×20, 无分隔线.
# (用户换的 SpinachChicken DungeonSpider, OpenGameArt CC0)
#
# 帧顺序 (推测): 0 / 1 / 2 走动循环. 没专门的 attack/hurt 帧.
#
# 17×20 已经是合适尺寸 (1.5 tile), 不缩放.
#
# 许可: SpinachChicken, CC0 (公有领域). 见 LICENSES.md.
extends RefCounted

const SHEET_PATH := "res://assets/animals/spider.png"
const FRAME_STRIDE := 17      # 每帧 17 像素步长 (无分隔)
const FRAME_CONTENT := 17     # 每帧内容宽
const FRAME_TOP_SKIP := 0     # 无顶部分隔
const FRAME_BOTTOM := 20      # 帧高 20
const NUM_FRAMES := 3         # 共 3 帧
const RENDER_SCALE := 1.0     # 原尺寸 (17×20 已合适)
# 白色阈值: R/G/B 都 ≥ 240 视为白色 (蛛丝), 透明化.
# 用户要求: 蛛丝白像素剥掉 (不显示).
const WHITE_STRIP_THRESHOLD := 240


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
			i * FRAME_STRIDE, FRAME_TOP_SKIP,
			FRAME_CONTENT, FRAME_BOTTOM))
		# 蛛丝剥离: resize 前先扫白像素 (近白 → alpha 0). resize NEAREST 会保 alpha.
		_strip_white(cell)
		cell.resize(out_w, out_h, Image.INTERPOLATE_NEAREST)
		frames.append(ImageTexture.create_from_image(cell))
	# 帧映射 (3 帧, 简单 ABA 循环):
	# - walk: 0→1→2→1 循环, 6 fps 给走路感
	# - idle: 帧 0 + 帧 1 慢切, 2 fps
	# - attack: 帧 2 (腿伸最开), 4 fps
	# - hurt: 帧 1 (中间), 单帧
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	# idle
	sf.add_animation("idle")
	sf.set_animation_speed("idle", 2.0)
	sf.set_animation_loop("idle", true)
	sf.add_frame("idle", frames[0])
	sf.add_frame("idle", frames[1])
	# walk
	sf.add_animation("walk")
	sf.set_animation_speed("walk", 6.0)
	sf.set_animation_loop("walk", true)
	sf.add_frame("walk", frames[0])
	sf.add_frame("walk", frames[1])
	sf.add_frame("walk", frames[2])
	sf.add_frame("walk", frames[1])
	# attack
	sf.add_animation("attack")
	sf.set_animation_speed("attack", 4.0)
	sf.set_animation_loop("attack", false)
	sf.add_frame("attack", frames[2])
	# hurt
	sf.add_animation("hurt")
	sf.set_animation_speed("hurt", 4.0)
	sf.set_animation_loop("hurt", false)
	sf.add_frame("hurt", frames[1])
	return sf


# 扫每个像素, R/G/B 都 ≥ 阈值 → 透明化 (剥蛛丝). 改 img in-place.
# 仅处理 alpha > 0 的像素, 透明区不动. 灰阶高光会保留 (G != R 等微差).
static func _strip_white(img: Image) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for y in h:
		for x in w:
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			if c.r8 >= WHITE_STRIP_THRESHOLD and c.g8 >= WHITE_STRIP_THRESHOLD and c.b8 >= WHITE_STRIP_THRESHOLD:
				img.set_pixel(x, y, Color(0, 0, 0, 0))


static func _empty_sprite_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("idle")
	# 占位空帧防 crash
	var img := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0, 1, 1))  # magenta 标识"贴图缺失"
	sf.add_frame("idle", ImageTexture.create_from_image(img))
	return sf
