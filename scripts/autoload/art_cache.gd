# 启动时预生成所有像素画资源并缓存。Autoload 单例。
# 场景脚本通过 ArtCache.player_frames / ArtCache.get_inventory_icon("planks") 等获取。
#
# 在 project.godot 注册：
#   [autoload]
#   ArtCache="*res://scripts/autoload/art_cache.gd"
extends Node

# 用 preload 而非 class_name 引用，避免 autoload 启动时机早于 class_name 索引扫描的问题。
const PixelArt = preload("res://scripts/art/pixel_art.gd")
const BlocksArt = preload("res://scripts/art/blocks_art.gd")
const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")
const PlayerArt = preload("res://scripts/art/player_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")
const ZombieArt = preload("res://scripts/art/zombie_art.gd")
const VillagerArt = preload("res://scripts/art/villager_art.gd")
const CowArt = preload("res://scripts/art/cow_art.gd")
const SheepArt = preload("res://scripts/art/sheep_art.gd")
const PigArt = preload("res://scripts/art/pig_art.gd")
const DoorArt = preload("res://scripts/art/door_art.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
const HeartsArt = preload("res://scripts/art/hearts_art.gd")
const DrumstickArt = preload("res://scripts/art/drumstick_art.gd")
const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const CloudsArt = preload("res://scripts/fx/clouds_art.gd")
const MimicArt = preload("res://scripts/art/mimic_art.gd")
const SkeletonArt = preload("res://scripts/art/skeleton_art.gd")

var block_textures: Dictionary = {}        # int (tile_id) -> ImageTexture (atlas for autotile, single for others)
var block_icons: Dictionary = {}           # int (tile_id) -> 16x16 ImageTexture (UI / inventory)
var item_icons: Dictionary = {}            # String (item_id) -> ImageTexture
var door_closed_texture: ImageTexture
var door_open_texture: ImageTexture
var player_frames: SpriteFrames
var slime_frames: SpriteFrames
var zombie_frames: SpriteFrames
var villager_frames: SpriteFrames
var cow_frames: SpriteFrames
# var jaguar_frames: SpriteFrames  # 删除 (用户要求)
var sheep_frames: SpriteFrames
var pig_frames: SpriteFrames
var spider_frames: SpriteFrames
var demon_eye_frames: SpriteFrames
var mimic_frames: SpriteFrames
var skeleton_frames: SpriteFrames
var cloud_textures: Array = []  # Array of {shape, color, texture}
var dust_puff_texture: ImageTexture
var crack_textures: Array = []  # 4 个阶段
var heart_full: ImageTexture
var heart_half: ImageTexture
var heart_empty: ImageTexture
var drumstick_full: ImageTexture
var drumstick_half: ImageTexture
var drumstick_empty: ImageTexture


func _ready() -> void:
	_build_blocks()
	_build_items()
	_build_doors()
	_build_entities()
	_build_clouds()
	_build_particles()
	_build_hearts()
	_build_drumsticks()


func _build_hearts() -> void:
	heart_full = HeartsArt.build_full()
	heart_half = HeartsArt.build_half()
	heart_empty = HeartsArt.build_empty()


func _build_drumsticks() -> void:
	drumstick_full = DrumstickArt.build_full()
	drumstick_half = DrumstickArt.build_half()
	drumstick_empty = DrumstickArt.build_empty()


func _build_blocks() -> void:
	var tile_ids := [
		BlocksArt.GRASS, BlocksArt.DIRT, BlocksArt.STONE, BlocksArt.SAND,
		BlocksArt.LOG, BlocksArt.LEAVES, BlocksArt.PLANKS, BlocksArt.WORKBENCH,
		BlocksArt.DOOR, BlocksArt.BEDROCK,
		BlocksArt.LEAVES_PINE, BlocksArt.LEAVES_AUTUMN, BlocksArt.SLIME_TORCH,
		BlocksArt.DEEP_STONE, BlocksArt.COAL_ORE, BlocksArt.IRON_ORE, BlocksArt.TORCH,
		BlocksArt.GRASS_WALL, BlocksArt.DIRT_WALL, BlocksArt.STONE_WALL, BlocksArt.WOOD_WALL,
		BlocksArt.CACTUS, BlocksArt.CACTUS_BODY,
		BlocksArt.COPPER_ORE, BlocksArt.TIN_ORE, BlocksArt.GOLD_ORE,
		BlocksArt.DIAMOND_ORE, BlocksArt.HELL_CRYSTAL,
		BlocksArt.WATER,
		BlocksArt.LOG_TOP, BlocksArt.LOG_ROOT_L, BlocksArt.LOG_ROOT_R,
		BlocksArt.BRANCH_L, BlocksArt.BRANCH_R,
		BlocksArt.WATER_L1, BlocksArt.WATER_L2, BlocksArt.WATER_L3,
		BlocksArt.CHEST,
		BlocksArt.DOOR_TOP,
		BlocksArt.SNOW, BlocksArt.ICE, BlocksArt.JUNGLE_GRASS, BlocksArt.MUD, BlocksArt.SWAMP_GRASS,
		BlocksArt.WOOD_PLATFORM, BlocksArt.ROPE,
		BlocksArt.JUNGLE_DIRT, BlocksArt.SNOW_DIRT, BlocksArt.JUNGLE_LEAVES,
		BlocksArt.SILVER_ORE,
		BlocksArt.FURNACE,
		BlocksArt.MUSHROOM,
		BlocksArt.MIMIC_CHEST,
		BlocksArt.GOLD_CHEST,
		BlocksArt.DIAMOND_CHEST,
		BlocksArt.LAVA, BlocksArt.HELL_STONE, BlocksArt.OBSIDIAN, BlocksArt.HELL_FRUIT,
		BlocksArt.SHADOW_CHEST,
	]
	for tile_id in tile_ids:
		if EdgeTemplates.FAMILY_OF.has(tile_id):
			var atlas_16: ImageTexture = BlocksArt.build_atlas(tile_id)
			atlas_16 = _apply_biome_tint(tile_id, atlas_16)
			# UI icon 用原 16x16 (不缩, 库存里能看清);
			# 世界内 tile 用 smart-resize 后 12x12 (匹配 TileSet tile_size=12, 边线齐整)
			block_icons[tile_id] = _extract_interior_icon(atlas_16)
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(atlas_16)
		elif tile_id == BlocksArt.WATER:
			# 水: 64×16 → 48×12 智能缩放; UI icon 用原 16x16
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_animated_atlas())
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L1:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(1))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L2:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(2))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L3:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(3))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		else:
			var single_16: ImageTexture = BlocksArt.get_texture(tile_id)
			single_16 = _apply_biome_tint(tile_id, single_16)
			# UI icon 用原 16x16; world tile 用 12x12 (匹配 TileSet)
			block_icons[tile_id] = single_16
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(single_16)


# 群系 tile 复用现有 pattern, 用 tint 区分. 在 atlas / 单 cell 两种路径都用.
static func _apply_biome_tint(tile_id: int, tex: ImageTexture) -> ImageTexture:
	match tile_id:
		BlocksArt.SNOW:          return _tint_texture(tex, Color(0.55, 0.7, 1.6), 0.55)
		BlocksArt.ICE:           return _tint_texture(tex, Color(0.5, 1.1, 1.8), 0.6)
		BlocksArt.JUNGLE_GRASS:  return _tint_texture(tex, Color(0.35, 1.4, 0.4), 0.5)
		BlocksArt.SWAMP_GRASS:   return _tint_texture(tex, Color(0.55, 0.85, 0.45), 0.5)
		BlocksArt.MUD:           return _tint_texture(tex, Color(0.6, 0.45, 0.3), 0.55)
		BlocksArt.JUNGLE_DIRT:   return _tint_texture(tex, Color(0.65, 1.1, 0.5), 0.55)
		BlocksArt.SNOW_DIRT:     return _tint_texture(tex, Color(0.7, 0.85, 1.3), 0.55)
		BlocksArt.JUNGLE_LEAVES: return _tint_texture(tex, Color(0.4, 1.4, 0.55), 0.55)
	return tex


# 染色 helper: 把图像每个非透明像素 * lerp(原色, tint, strength).
static func _tint_texture(src: ImageTexture, tint: Color, strength: float) -> ImageTexture:
	var img: Image = src.get_image().duplicate()
	for y in img.get_height():
		for x in img.get_width():
			var c: Color = img.get_pixel(x, y)
			if c.a < 0.01:
				continue
			# 乘色相当于"染色 + 保持明暗结构"
			var tinted := Color(c.r * tint.r, c.g * tint.g, c.b * tint.b, c.a)
			img.set_pixel(x, y, c.lerp(tinted, strength))
	return ImageTexture.create_from_image(img)


# 16x16 → 12x12 智能缩放: 保留 4 个边缘行/列, 内部 12 行/列压到 8.
# 用途: TileSet tile_size=12 后, 让 16x16 ASCII pattern 在 Godot 渲染前先缩成 12x12,
# 避免 Godot 内部缩时不均匀采样导致边线 (autotile edge) 厚薄不一.
static func _smart_resize_atlas_16_to_12(tex: ImageTexture) -> ImageTexture:
	var src: Image = tex.get_image()
	var w_cells: int = src.get_width() / 16
	var h_cells: int = src.get_height() / 16
	if w_cells <= 0 or h_cells <= 0:
		return tex
	var dst := Image.create(w_cells * 12, h_cells * 12, false, Image.FORMAT_RGBA8)
	dst.fill(Color(0, 0, 0, 0))
	# dst[i] → src[?] 映射: 12 行/列里, 前 2 + 后 2 保留 src 0/1/14/15
	# 中间 8 行/列采自 src 2..13: 跳 src 3/6/9/12 → 取 2,4,5,7,8,10,11,13
	var map12: PackedInt32Array = PackedInt32Array([0, 1, 2, 4, 5, 7, 8, 10, 11, 13, 14, 15])
	for cy in h_cells:
		for cx in w_cells:
			for dr in 12:
				var sr: int = cy * 16 + map12[dr]
				for dc in 12:
					var sc: int = cx * 16 + map12[dc]
					dst.set_pixel(cx * 12 + dc, cy * 12 + dr, src.get_pixel(sc, sr))
	return ImageTexture.create_from_image(dst)


# 从 12x12 atlas 抽 mask=255 (CCCCIIII, 全包围) 那一格做 UI 图标
static func _extract_interior_icon_12(atlas: ImageTexture) -> ImageTexture:
	var coord: Vector2i = BlobLookup.ATLAS_COORD[255]
	var ox: int = coord.x * 12
	var oy: int = coord.y * 12
	var src: Image = atlas.get_image()
	var dst := Image.create(12, 12, false, Image.FORMAT_RGBA8)
	for y in 12:
		for x in 12:
			dst.set_pixel(x, y, src.get_pixel(ox + x, oy + y))
	return ImageTexture.create_from_image(dst)


# 从 atlas 抽 mask=255 (CCCCIIII, 全包围) 那一格做 UI 图标. 16×16.
static func _extract_interior_icon(atlas: ImageTexture) -> ImageTexture:
	var coord: Vector2i = BlobLookup.ATLAS_COORD[255]
	var ox: int = coord.x * 16
	var oy: int = coord.y * 16
	var src: Image = atlas.get_image()
	var dst := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	dst.blit_rect(src, Rect2i(ox, oy, 16, 16), Vector2i.ZERO)
	return ImageTexture.create_from_image(dst)


func _build_items() -> void:
	# 非工具类 (老 ASCII pattern)
	for item_id in ["slime_jelly", "apple",
			"coal", "iron_ore", "bone", "spider_eye", "lens",
			"raw_meat", "leather", "wool", "cooked_meat", "mushroom",
			"iron_ingot", "copper_ingot", "tin_ingot", "silver_ingot", "gold_ingot",
			"grappling_hook",
			"hell_fruit", "obsidian", "hell_stone"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)
	# 剑 + 镐 + 斧: 7 tier × 3 tool, 全用 ASCII pattern (16×16)
	# V3: 不再用外部 PNG (尺寸不对头), 改回 items_art.gd 手画像素画
	for tier in ["wood", "stone", "copper", "iron", "silver", "gold", "diamond"]:
		item_icons["%s_sword" % tier] = ItemsArt.get_icon("%s_sword" % tier)
		item_icons["%s_pickaxe" % tier] = ItemsArt.get_icon("%s_pickaxe" % tier)
		item_icons["%s_axe" % tier] = ItemsArt.get_icon("%s_axe" % tier)
	item_icons["silver_ore"] = ItemsArt.get_icon("silver_ore")


func _build_doors() -> void:
	door_closed_texture = DoorArt.get_closed_texture()
	door_open_texture = DoorArt.get_open_texture()


func _build_entities() -> void:
	player_frames = PlayerArt.build_sprite_frames()
	slime_frames = SlimeArt.build_sprite_frames()
	zombie_frames = ZombieArt.build_sprite_frames()
	villager_frames = VillagerArt.build_sprite_frames()
	cow_frames = CowArt.build_sprite_frames()
	sheep_frames = SheepArt.build_sprite_frames()
	pig_frames = PigArt.build_sprite_frames()
	# 蜘蛛: OpenGameArt PNG sprite sheet (Heather Lee Harvey, CC-BY 3.0)
	spider_frames = preload("res://scripts/art/spider_loader.gd").build_sprite_frames()
	# 恶魔眼: OpenGameArt head.png 缩 32x18 (JacPete, CC0)
	demon_eye_frames = preload("res://scripts/art/demon_eye_loader.gd").build_sprite_frames()
	# Mimic: 自画 ASCII (chest + 红嘴牙)
	mimic_frames = MimicArt.build_sprite_frames()
	# 骨架战士: 地狱近战怪
	skeleton_frames = SkeletonArt.build_sprite_frames()
	# Jaguar 已删 (用户要求)


# 统一的"取背包/热键栏图标"接口。
# - 方块类物品 (planks/log/dirt 等)：返回 16×16 方块纹理
# - 工具/素材物品 (wood_sword/stick 等)：返回 16×16 图标
# 物品 id → tile id 的映射在这里硬编码 (M2 改 ItemDatabase 后由 Item.placeable_tile_id 自动驱动)。
const _ITEM_TO_TILE := {
	"grass": BlocksArt.GRASS,
	"dirt": BlocksArt.DIRT,
	"stone": BlocksArt.STONE,
	"sand": BlocksArt.SAND,
	"cactus": BlocksArt.CACTUS,
	"log": BlocksArt.LOG,
	"leaves": BlocksArt.LEAVES,
	"pine_leaves": BlocksArt.LEAVES_PINE,
	"autumn_leaves": BlocksArt.LEAVES_AUTUMN,
	"planks": BlocksArt.PLANKS,
	"workbench": BlocksArt.WORKBENCH,
	"furnace": BlocksArt.FURNACE,
	"door": BlocksArt.DOOR,
	"slime_torch": BlocksArt.SLIME_TORCH,
	"torch": BlocksArt.TORCH,
	"copper_ore": BlocksArt.COPPER_ORE,
	"tin_ore": BlocksArt.TIN_ORE,
	"gold_ore": BlocksArt.GOLD_ORE,
	"diamond": BlocksArt.DIAMOND_ORE,
	"hell_crystal": BlocksArt.HELL_CRYSTAL,
	"chest": BlocksArt.CHEST,
	# 新群系
	"snow": BlocksArt.SNOW,
	"ice": BlocksArt.ICE,
	"jungle_grass": BlocksArt.JUNGLE_GRASS,
	"mud": BlocksArt.MUD,
	"swamp_grass": BlocksArt.SWAMP_GRASS,
	# 平台 + 墙 + 绳
	"wood_platform": BlocksArt.WOOD_PLATFORM,
	"wood_wall": BlocksArt.WOOD_WALL,    # 木墙: 真木板纹路
	"stone_wall": BlocksArt.STONE_WALL,
	"rope": BlocksArt.ROPE,
	"jungle_dirt": BlocksArt.JUNGLE_DIRT,
	"snow_dirt": BlocksArt.SNOW_DIRT,
	"jungle_leaves": BlocksArt.JUNGLE_LEAVES,
}


func _build_clouds() -> void:
	for shape in CloudsArt.all_shapes():
		for color in CloudsArt.all_colors():
			cloud_textures.append({
				"shape": shape,
				"color": color,
				"texture": CloudsArt.get_texture(shape, color),
			})


func _build_particles() -> void:
	dust_puff_texture = ParticlesArt.get_dust_puff()
	for stage in 4:
		crack_textures.append(ParticlesArt.get_crack_stage(stage))


func get_inventory_icon(item_id: String) -> ImageTexture:
	if _ITEM_TO_TILE.has(item_id):
		return block_icons[_ITEM_TO_TILE[item_id]]
	if item_icons.has(item_id):
		return item_icons[item_id]
	push_warning("未知 item icon: %s" % item_id)
	return null


# 径向白色渐变纹理，供 Light2D / 火把光晕等使用。size = 边长 (px)。
# 圆形软盘: 内 40% 半径满亮, 之后到外 100% 半径平滑淡到 0. 外圆完全透明 → 视觉清晰圆形.
# 三次方衰减让边缘更柔同时保留明显圆形轮廓.
func radial_gradient(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var center := Vector2(size * 0.5, size * 0.5)
	var outer_r := size * 0.5
	var inner_r := outer_r * 0.4
	for y in size:
		for x in size:
			var d: float = Vector2(x, y).distance_to(center)
			var a: float
			if d <= inner_r:
				a = 1.0
			elif d >= outer_r:
				a = 0.0
			else:
				var t: float = (d - inner_r) / (outer_r - inner_r)  # 0..1
				a = 1.0 - t
				a = a * a * a  # 三次方让圆形轮廓更清晰
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
