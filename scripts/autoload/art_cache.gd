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
const PlayerArt = preload("res://scripts/art/player_art.gd")
const SlimeArt = preload("res://scripts/art/slime_art.gd")
const ZombieArt = preload("res://scripts/art/zombie_art.gd")
const VillagerArt = preload("res://scripts/art/villager_art.gd")
const DoorArt = preload("res://scripts/art/door_art.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
const HeartsArt = preload("res://scripts/art/hearts_art.gd")
const DrumstickArt = preload("res://scripts/art/drumstick_art.gd")
const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const CloudsArt = preload("res://scripts/fx/clouds_art.gd")

var block_textures: Dictionary = {}        # int (tile_id) -> ImageTexture
var item_icons: Dictionary = {}            # String (item_id) -> ImageTexture
var door_closed_texture: ImageTexture
var door_open_texture: ImageTexture
var player_frames: SpriteFrames
var slime_frames: SpriteFrames
var zombie_frames: SpriteFrames
var villager_frames: SpriteFrames
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
	]
	for tile_id in tile_ids:
		block_textures[tile_id] = BlocksArt.get_texture(tile_id)


func _build_items() -> void:
	for item_id in ["wood_sword", "wood_pickaxe", "wood_axe", "slime_jelly", "apple",
			"stone_sword", "stone_pickaxe", "stone_axe",
			"coal", "iron_ore", "iron_pickaxe"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)


func _build_doors() -> void:
	door_closed_texture = DoorArt.get_closed_texture()
	door_open_texture = DoorArt.get_open_texture()


func _build_entities() -> void:
	player_frames = PlayerArt.build_sprite_frames()
	slime_frames = SlimeArt.build_sprite_frames()
	zombie_frames = ZombieArt.build_sprite_frames()
	villager_frames = VillagerArt.build_sprite_frames()


# 统一的"取背包/热键栏图标"接口。
# - 方块类物品 (planks/log/dirt 等)：返回 16×16 方块纹理
# - 工具/素材物品 (wood_sword/stick 等)：返回 16×16 图标
# 物品 id → tile id 的映射在这里硬编码 (M2 改 ItemDatabase 后由 Item.placeable_tile_id 自动驱动)。
const _ITEM_TO_TILE := {
	"grass": BlocksArt.GRASS,
	"dirt": BlocksArt.DIRT,
	"stone": BlocksArt.STONE,
	"sand": BlocksArt.SAND,
	"log": BlocksArt.LOG,
	"leaves": BlocksArt.LEAVES,
	"pine_leaves": BlocksArt.LEAVES_PINE,
	"autumn_leaves": BlocksArt.LEAVES_AUTUMN,
	"planks": BlocksArt.PLANKS,
	"workbench": BlocksArt.WORKBENCH,
	"door": BlocksArt.DOOR,
	"slime_torch": BlocksArt.SLIME_TORCH,
	"torch": BlocksArt.TORCH,
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
		return block_textures[_ITEM_TO_TILE[item_id]]
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
