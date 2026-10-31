# 建筑使用 1.4.4.9 原始 PNG，剔除图集分隔线后按世界格网组装。
extends RefCounted
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Blob = preload("res://scripts/world/blob_lookup.gd")
const B = preload("res://scripts/art/blocks_art.gd")
const GLASS_WALL := 117
const BEAM_WALL := 118
const CHAIR := 119
const TABLE := 121
const EXTRA_IDS := [117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130]
const ITEMS := {"glass_wall": 117, "wood_beam_wall": 118, "wood_chair": 119, "wood_table": 121}
const DARK := Color8(65, 40, 24)
const SHADE := Color8(98, 61, 33)
const WOOD := Color8(151, 100, 52)
const LIT := Color8(190, 138, 75)

static func _rect(img: Image, rect: Rect2i, col: Color) -> void:
	img.fill_rect(rect, col)

static func furniture_base(tid: int) -> int:
	if tid in [119, 120]: return CHAIR
	if tid >= 121 and tid <= 126: return TABLE
	return -1

static func footprint(base: int) -> Vector2i:
	return Vector2i(1, 2) if base == CHAIR else Vector2i(3, 2)

# 锚点始终是左下角，按底行到顶行编号；存档只新增 ID，不改旧编号。
static func part_offset(tid: int) -> Vector2i:
	var base := furniture_base(tid)
	var width := footprint(base).x
	return Vector2i((tid - base) % width, -((tid - base) / width))

# 原始家具图集按 18px 步长分格；不再手画轮廓、木纹或高光。
static func source_object(sheet_id: int, size: Vector2i, origin := Vector2i.ZERO) -> Image:
	var source := Pack.source_image("Tiles_%d.png" % sheet_id)
	var img := Image.create(size.x * 16, size.y * 16, false, Image.FORMAT_RGBA8)
	for y in size.y:
		for x in size.x:
			img.blit_rect(source, Rect2i(origin + Vector2i(x, y) * 18, Vector2i(16, 16)), Vector2i(x, y) * 16)
	return img

static func furniture_image(base: int) -> Image:
	return source_object(15 if base == CHAIR else 14, footprint(base))

static func door_image() -> Image:
	return source_object(10, Vector2i(1, 3))

static func single(tid: int) -> ImageTexture:
	var img: Image
	if furniture_base(tid) != -1:
		var base := furniture_base(tid)
		var off := part_offset(tid)
		img = furniture_image(base).get_region(Rect2i(off.x * 16, (footprint(base).y - 1 + off.y) * 16, 16, 16))
	elif tid in [B.DOOR, B.DOOR_MID, B.DOOR_TOP]:
		var row := 2 if tid == B.DOOR else (1 if tid == B.DOOR_MID else 0)
		img = door_image().get_region(Rect2i(0, row * 16, 16, 16))
	elif tid == B.DOOR_OPEN:
		img = source_object(11, Vector2i(1, 1))
	elif tid == B.WOOD_PLATFORM:
		img = Pack.source_image("Tiles_19.png").get_region(Rect2i(0, 0, 16, 16))
	elif tid in [GLASS_WALL, BEAM_WALL]:
		# 旧存档木梁背景墙显示为木墙；不再向新游戏提供这个自创物品。
		img = wall_cell(21 if tid == GLASS_WALL else 4)
	elif tid in [B.IRON_ANVIL, B.IRON_ANVIL_RIGHT]:
		img = Pack.source_image("Tiles_16.png").get_region(Rect2i(18 if tid == B.IRON_ANVIL_RIGHT else 0, 0, 16, 16))

	else:
		return null
	if img.get_size() != Vector2i(16, 16): img.resize(16, 16, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

# 背景墙图集格宽为 32，步长 36；每格中间 16px 对应方块区域。
static func wall_cell(source_id: int, variant := 0) -> Image:
	return Pack.source_image("Wall_%d.png" % source_id).get_region(Rect2i(36 * (1 + variant % 3) + 8, 44, 16, 16))

static func wall_atlas(tile_id: int) -> ImageTexture:
	var source_id: int = {B.WOOD_WALL: 4, B.DIRT_WALL: 2, B.STONE_WALL: 1}.get(tile_id, 4)
	var atlas := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 8:
		for x in 8:
			atlas.blit_rect(wall_cell(source_id, x % 3), Rect2i(0, 0, 16, 16), Vector2i(x, y) * 16)
	return ImageTexture.create_from_image(atlas)

static func wood_wall_atlas() -> ImageTexture:
	return wall_atlas(B.WOOD_WALL)

static func icon(id: String) -> ImageTexture:
	if id == "wood_chair": return ImageTexture.create_from_image(furniture_image(CHAIR))
	if id == "wood_table": return ImageTexture.create_from_image(furniture_image(TABLE))
	return single(ITEMS[id])
