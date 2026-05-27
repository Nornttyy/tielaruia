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
var jaguar_frames: SpriteFrames
var sheep_frames: SpriteFrames
var pig_frames: SpriteFrames
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
		BlocksArt.GRASS_WALL, BlocksArt.DIRT_WALL, BlocksArt.STONE_WALL,
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
	]
	for tile_id in tile_ids:
		if EdgeTemplates.FAMILY_OF.has(tile_id):
			var atlas: ImageTexture = BlocksArt.build_atlas(tile_id)
			atlas = _apply_biome_tint(tile_id, atlas)
			block_textures[tile_id] = atlas
			block_icons[tile_id] = _extract_interior_icon(atlas)
		elif tile_id == BlocksArt.WATER:
			# 水: 64×16 动画 atlas (4 帧). icon 用单帧.
			block_textures[tile_id] = BlocksArt.get_water_animated_atlas()
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L1:
			block_textures[tile_id] = BlocksArt.get_water_level_atlas(1)
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L2:
			block_textures[tile_id] = BlocksArt.get_water_level_atlas(2)
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L3:
			block_textures[tile_id] = BlocksArt.get_water_level_atlas(3)
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		else:
			var single: ImageTexture = BlocksArt.get_texture(tile_id)
			single = _apply_biome_tint(tile_id, single)
			block_textures[tile_id] = single
			block_icons[tile_id] = single


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
	for item_id in ["wood_axe", "slime_jelly", "apple",
			"stone_axe",
			"coal", "iron_ore",
			"iron_axe",
			"gold_axe",
			"diamond_axe",
			"copper_axe",
			"raw_meat", "leather", "wool",
			"grappling_hook"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)
	# 剑 + 镐: 共享 base PNG, 按 tier 染色
	# sword: opengameart pixel-sword-1 (CC-BY 3.0)
	# pickaxe: opengameart tools-icons-0 (CC0)
	const ToolLoader = preload("res://scripts/art/tool_loader.gd")
	for tier in ["wood", "stone", "copper", "iron", "gold", "diamond"]:
		item_icons["%s_sword" % tier] = ToolLoader.build_icon("sword", tier)
		item_icons["%s_pickaxe" % tier] = ToolLoader.build_icon("pickaxe", tier)


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
	# Jaguar: LPC lioness (Sevarihk CC-BY 4.0). 见 LICENSES.md
	jaguar_frames = preload("res://scripts/art/jaguar_art.gd").build_sprite_frames()


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
	"wood_wall": BlocksArt.DIRT_WALL,    # 复用 dirt_wall 视觉
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
