# 建筑使用 1.4.4.9 原始 PNG，剔除图集分隔线后按世界格网组装。
extends RefCounted
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Blob = preload("res://scripts/world/blob_lookup.gd")
const B = preload("res://scripts/art/blocks_art.gd")
const GLASS_WALL := 117
const BEAM_WALL := 118
const CHAIR := 119
const TABLE := 121
const WORKBENCH_RIGHT := 159
# 按左下锚点、从下往上逐行：底排左/中/右，再顶排左/中/右。
const FURNACE_PARTS := [B.FURNACE, 163, 164, 160, 161, 162]
const CHEST_PARTS := [B.CHEST, 165, 166, 167]
const GOLD_CHEST_PARTS := [B.GOLD_CHEST, 168, 169, 170]
const DIAMOND_CHEST_PARTS := [B.DIAMOND_CHEST, 171, 172, 173]
const SHADOW_CHEST_PARTS := [B.SHADOW_CHEST, 174, 175, 176]
const MIMIC_CHEST_PARTS := [B.MIMIC_CHEST, 177, 178, 179]
const BED_PARTS := [B.BED, B.BED_RIGHT, 180, 181]
const EXTRA_IDS := [117, 118, 119, 120, 121, 122, 123, 124, 125, 126, 127, 128, 129, 130, 131, 132, 133, 134, 135, 136, 137, 138, 139, 140, 141, 142, 143, 144, 145, 146, 147, 148, 149, 150, 151, 152, 153, 154, 155, 156, 157, 158, 159, 160, 161, 162, 163, 164, 165, 166, 167, 168, 169, 170, 171, 172, 173, 174, 175, 176, 177, 178, 179, 180, 181]
const ITEMS := {"glass_wall": 117, "wood_beam_wall": 118, "wood_chair": 119, "wood_table": 121}
const MULTI_LAYOUTS := {
	B.WORKBENCH: {"size": Vector2i(2, 1), "parts": [B.WORKBENCH, WORKBENCH_RIGHT], "sheet": 18, "origin": Vector2i.ZERO, "style": 0},
	B.FURNACE: {"size": Vector2i(3, 2), "parts": FURNACE_PARTS, "sheet": 17, "origin": Vector2i.ZERO, "style": 0},
	B.CHEST: {"size": Vector2i(2, 2), "parts": CHEST_PARTS, "sheet": 21, "origin": Vector2i.ZERO, "style": 0},
	B.GOLD_CHEST: {"size": Vector2i(2, 2), "parts": GOLD_CHEST_PARTS, "sheet": 21, "origin": Vector2i(2, 0), "style": 1},
	B.DIAMOND_CHEST: {"size": Vector2i(2, 2), "parts": DIAMOND_CHEST_PARTS, "sheet": 21, "origin": Vector2i(42, 0), "style": 21},
	B.SHADOW_CHEST: {"size": Vector2i(2, 2), "parts": SHADOW_CHEST_PARTS, "sheet": 21, "origin": Vector2i(6, 0), "style": 3},
	B.MIMIC_CHEST: {"size": Vector2i(2, 2), "parts": MIMIC_CHEST_PARTS, "sheet": 21, "origin": Vector2i(108, 0), "style": 54},
	B.BED: {"size": Vector2i(2, 2), "parts": BED_PARTS, "sheet": -1, "origin": Vector2i.ZERO, "style": 0},
}
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

static func multi_base(tid: int) -> int:
	for base in MULTI_LAYOUTS:
		if tid in MULTI_LAYOUTS[base].parts:
			return base
	return -1

static func multi_layout(base: int) -> Dictionary:
	return MULTI_LAYOUTS.get(base, {})

static func multi_parts(base: int) -> Array:
	return MULTI_LAYOUTS.get(base, {}).get("parts", [])

static func multi_footprint(base: int) -> Vector2i:
	return MULTI_LAYOUTS.get(base, {}).get("size", Vector2i.ONE)

static func footprint(base: int) -> Vector2i:
	return Vector2i(1, 2) if base == CHAIR else Vector2i(3, 2)

# 锚点始终是左下角，按底行到顶行编号；存档只新增 ID，不改旧编号。
static func part_offset(tid: int) -> Vector2i:
	var base := furniture_base(tid)
	if base != -1:
		var width := footprint(base).x
		return Vector2i((tid - base) % width, -((tid - base) / width))
	base = multi_base(tid)
	if base == -1:
		return Vector2i.ZERO
	var parts: Array = multi_parts(base)
	var index: int = parts.find(tid)
	var width: int = multi_footprint(base).x
	return Vector2i(index % width, -(index / width))

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

static func multi_image(base: int) -> Image:
	var layout: Dictionary = multi_layout(base)
	var size: Vector2i = layout.get("size", Vector2i.ONE)
	if base == B.BED:
		# Tiles_79 没包含在本地原图包里；床物品本身是原版 32×22 像素图。
		# 底对齐到 2×2 占位，既保留原像素，也不伪造床身细节。
		var source := Pack.source_image("Item_224.png")
		var padded := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		padded.blit_rect(source, Rect2i(0, 0, 32, 22), Vector2i(0, 10))
		return padded
	return source_object(int(layout.get("sheet", -1)), size, layout.get("origin", Vector2i.ZERO))

static func door_image() -> Image:
	return source_object(10, Vector2i(1, 3))

static func single(tid: int) -> ImageTexture:
	var img: Image
	if (tid >= 148 and tid <= 155) or tid in [157, 158]: return wall_atlas(tid)
	if tid >= 143 and tid <= 147:
		return mushroom_piece(tid)
	if multi_base(tid) != -1:
		var base := multi_base(tid)
		var dims := multi_footprint(base)
		var off := part_offset(tid)
		img = multi_image(base).get_region(Rect2i(off.x * 16, (dims.y - 1 + off.y) * 16, 16, 16))
	elif furniture_base(tid) != -1:
		var furniture_id := furniture_base(tid)
		var off := part_offset(tid)
		img = furniture_image(furniture_id).get_region(Rect2i(off.x * 16, (footprint(furniture_id).y - 1 + off.y) * 16, 16, 16))
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
	var source_id: int = {157: 9, 158: 27, 148: 78, 149: 7, 150: 82, 151: 34, 152: 80, 153: 3, 154: 83, 155: 187, B.WOOD_WALL: 4, B.DIRT_WALL: 2, B.STONE_WALL: 1}.get(tile_id, 4)
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

# 蘑菇柄取原始 18px 网格；伞盖由 TileSet 以整张精灵绘制，避免压成一个方块。
static func mushroom_piece(tid: int) -> ImageTexture:
	var source := Pack.source_image("Tiles_71.png" if tid == 143 else "Tiles_72.png")
	var origin := Vector2i(0, 6) if tid == 143 else Vector2i(0, 18)
	return ImageTexture.create_from_image(source.get_region(Rect2i(origin, Vector2i(16, 16))))

static func mushroom_crown() -> ImageTexture:
	var img := Image.create(64, 48, false, Image.FORMAT_RGBA8)
	img.blit_rect(Pack.source_image("Shroom_Tops.png"), Rect2i(0, 0, 60, 42), Vector2i(2, 6))
	img.resize(48, 36, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)
