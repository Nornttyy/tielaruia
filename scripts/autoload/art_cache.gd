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
const CowArt = preload("res://scripts/art/cow_art.gd")
const SheepArt = preload("res://scripts/art/sheep_art.gd")
const PigArt = preload("res://scripts/art/pig_art.gd")
const DoorArt = preload("res://scripts/art/door_art.gd")
const ItemsArt = preload("res://scripts/art/items_art.gd")
const HeartsArt = preload("res://scripts/art/hearts_art.gd")
const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const CloudsArt = preload("res://scripts/fx/clouds_art.gd")
const MimicArt = preload("res://scripts/art/mimic_art.gd")
const SkeletonArt = preload("res://scripts/art/skeleton_art.gd")
const ImpArt = preload("res://scripts/art/imp_art.gd")
const HellWaspArt = preload("res://scripts/art/hell_wasp_art.gd")
const HarpyArt = preload("res://scripts/art/harpy_art.gd")
const FireballArt = preload("res://scripts/art/fireball_art.gd")
const ArrowProjArt = preload("res://scripts/art/arrow_proj_art.gd")
const BulletProjArt = preload("res://scripts/art/bullet_proj_art.gd")
const LaserProjArt = preload("res://scripts/art/laser_proj_art.gd")
const MagicProjArt = preload("res://scripts/art/magic_proj_art.gd")
const LightningProjArt = preload("res://scripts/art/lightning_proj_art.gd")
const StarProjArt = preload("res://scripts/art/star_proj_art.gd")
const SlimeBlobProjArt = preload("res://scripts/art/slime_blob_proj_art.gd")
const LeafProjArt = preload("res://scripts/art/leaf_proj_art.gd")
const WindProjArt = preload("res://scripts/art/wind_proj_art.gd")
const MummyArt = preload("res://scripts/art/mummy_art.gd")

var block_textures: Dictionary = {}        # int (tile_id) -> ImageTexture (atlas for autotile, single for others)
var block_icons: Dictionary = {}           # int (tile_id) -> 16x16 ImageTexture (UI / inventory)
var item_icons: Dictionary = {}            # String (item_id) -> ImageTexture
var door_closed_texture: ImageTexture
var door_open_texture: ImageTexture
var door_item_icon: ImageTexture           # 背包里门的图标 (整扇 3 格门, 看得出 3 段)
var player_frames: SpriteFrames
var slime_frames: SpriteFrames
var slime_crown_tex: ImageTexture          # 史莱姆王专属王冠贴图 (贴在头顶)
var zombie_frames: SpriteFrames
var cow_frames: SpriteFrames
var sheep_frames: SpriteFrames
var pig_frames: SpriteFrames
var spider_frames: SpriteFrames
var demon_eye_frames: SpriteFrames
var mimic_frames: SpriteFrames
var skeleton_frames: SpriteFrames
var imp_frames: SpriteFrames
var hell_wasp_frames: SpriteFrames
var harpy_frames: SpriteFrames
var fireball_frames: SpriteFrames
var spell_frames_ice: SpriteFrames      # 铁法杖蓝弹
var spell_frames_nature: SpriteFrames   # 木法杖绿弹
var arrow_proj_frames: SpriteFrames
var bullet_proj_frames: SpriteFrames
var laser_proj_frames: SpriteFrames
var magic_proj_frames: SpriteFrames
var lightning_proj_frames: SpriteFrames
var star_proj_frames: SpriteFrames
var slime_blob_proj_frames: SpriteFrames
var leaf_proj_frames: SpriteFrames
var wind_proj_frames: SpriteFrames
var mummy_frames: SpriteFrames
var cloud_textures: Array = []  # Array of {shape, color, texture}
var dust_puff_texture: ImageTexture
var crack_textures: Array = []  # 4 个阶段
var heart_full: ImageTexture
var heart_half: ImageTexture
var heart_empty: ImageTexture


func _ready() -> void:
	_build_blocks()
	_build_items()
	_build_doors()
	_build_entities()
	_build_clouds()
	_build_particles()
	_build_hearts()


func _build_hearts() -> void:
	heart_full = HeartsArt.build_full()
	heart_half = HeartsArt.build_half()
	heart_empty = HeartsArt.build_empty()


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
		BlocksArt.WATER_L4, BlocksArt.WATER_L5, BlocksArt.WATER_L6, BlocksArt.WATER_L7,
		BlocksArt.WATER_SOURCE,
		BlocksArt.CHEST,
		BlocksArt.DOOR_TOP, BlocksArt.DOOR_MID, BlocksArt.DOOR_OPEN,
		BlocksArt.SNOW, BlocksArt.ICE, BlocksArt.JUNGLE_GRASS, BlocksArt.MUD, BlocksArt.SWAMP_GRASS,
		BlocksArt.WOOD_PLATFORM, BlocksArt.ROPE,
		BlocksArt.JUNGLE_DIRT, BlocksArt.SNOW_DIRT, BlocksArt.JUNGLE_LEAVES,
		BlocksArt.SILVER_ORE,
		BlocksArt.FURNACE,
		BlocksArt.COOKING_POT,
		BlocksArt.CUTTING_BOARD,
		BlocksArt.RICE_0, BlocksArt.RICE_1, BlocksArt.RICE_2, BlocksArt.RICE_3,
		BlocksArt.MUSHROOM,
		BlocksArt.MIMIC_CHEST,
		BlocksArt.GOLD_CHEST,
		BlocksArt.DIAMOND_CHEST,
		BlocksArt.LAVA, BlocksArt.LAVA_L1, BlocksArt.LAVA_L2, BlocksArt.LAVA_L3,
		BlocksArt.HELL_STONE, BlocksArt.OBSIDIAN, BlocksArt.HELL_FRUIT,
		BlocksArt.SHADOW_CHEST,
		BlocksArt.LIFE_CRYSTAL,
		BlocksArt.HELL_ALLOY_ORE,
		BlocksArt.SANDSTONE,
		BlocksArt.MANA_CRYSTAL,
		BlocksArt.BED, BlocksArt.BED_RIGHT,
		BlocksArt.GRASS_SLOPE_R, BlocksArt.GRASS_SLOPE_L,
		BlocksArt.WHEAT_0, BlocksArt.WHEAT_1, BlocksArt.WHEAT_2, BlocksArt.WHEAT_3,
		BlocksArt.PLANT_GRASS,
		BlocksArt.CLOUD,
		BlocksArt.WATER_DESERT, BlocksArt.WATER_JUNGLE, BlocksArt.WATER_SWAMP,
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
		elif tile_id == BlocksArt.WATER_L4:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(4))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L5:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(5))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L6:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(6))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_L7:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas(7))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.WATER_DESERT or tile_id == BlocksArt.WATER_JUNGLE \
				or tile_id == BlocksArt.WATER_SWAMP:
			# 群系满水: 同 WATER 的 4 帧动画 atlas, 只换调色板染色
			var pal: Dictionary = BlocksArt.water_palette_for(tile_id)
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_water_animated_atlas_p(pal))
			block_icons[tile_id] = BlocksArt.get_texture(tile_id)
		elif tile_id == BlocksArt.LAVA_L1:
			# 岩浆深浅不是 item, icon 直接复用世界贴图 (避免缺 key 崩)
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(1))
			block_icons[tile_id] = block_textures[tile_id]
		elif tile_id == BlocksArt.LAVA_L2:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(2))
			block_icons[tile_id] = block_textures[tile_id]
		elif tile_id == BlocksArt.LAVA_L3:
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(BlocksArt.get_lava_level_atlas(3))
			block_icons[tile_id] = block_textures[tile_id]
		else:
			var single_16: ImageTexture = BlocksArt.get_texture(tile_id)
			single_16 = _apply_biome_tint(tile_id, single_16)
			# UI icon 用原 16x16; world tile 用 12x12 (匹配 TileSet)
			block_icons[tile_id] = single_16
			block_textures[tile_id] = _smart_resize_atlas_16_to_12(single_16)

	# 群系薄水 (visual-only, 21 张): 3 族 × 7 档, 同薄水 atlas 换调色板染色。
	# 不在上面 tile_ids 主循环里 (它们不进数据, 单独按族×档生成)。
	for base_id in [BlocksArt.WATER_DESERT_L1, BlocksArt.WATER_JUNGLE_L1, BlocksArt.WATER_SWAMP_L1]:
		var pal: Dictionary = BlocksArt.water_palette_for(base_id)
		for lvl in range(1, 8):
			var tid: int = base_id + (lvl - 1)
			var tex: ImageTexture = _smart_resize_atlas_16_to_12(BlocksArt.get_water_level_atlas_p(lvl, pal))
			block_textures[tid] = tex
			block_icons[tid] = tex   # 不是 item, icon 复用世界贴图防缺 key 崩


# 群系 tile 复用现有 pattern, 用 tint 区分. 在 atlas / 单 cell 两种路径都用.
static func _apply_biome_tint(tile_id: int, tex: ImageTexture) -> ImageTexture:
	match tile_id:
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
	# 每个 16×16 cell 单独高质量缩到 12×12 (LANCZOS): 16px 原画的全部细节都参与, 不再像旧版
	# 硬扔 4 列像素 (第 3/6/9/12 列) — 那会丢掉落在那些列上的图案细节, 看着乱/糊。
	# 必须逐 cell 缩: autotile atlas 是 8×6 个 cell, 整图缩会跨 cell 边界糊到邻格。
	for cy in h_cells:
		for cx in w_cells:
			var cell := Image.create(16, 16, false, Image.FORMAT_RGBA8)
			cell.blit_rect(src, Rect2i(cx * 16, cy * 16, 16, 16), Vector2i.ZERO)
			cell.resize(12, 12, Image.INTERPOLATE_LANCZOS)
			# LANCZOS 是平滑插值, 会把不透明像素和透明像素在边界上混成"半透明"
			# → 草/树叶等带透明的方块看着半透明发虚。像素画每个点应非透即实:
			# 把 alpha 卡硬 (≥0.5 → 不透明, 否则全透明), 去掉半透明边缘, 保留 LANCZOS 的颜色细节。
			for py in 12:
				for px in 12:
					var c: Color = cell.get_pixel(px, py)
					if c.a >= 0.5:
						c.a = 1.0
						cell.set_pixel(px, py, c)
					else:
						cell.set_pixel(px, py, Color(0, 0, 0, 0))
			dst.blit_rect(cell, Rect2i(0, 0, 12, 12), Vector2i(cx * 12, cy * 12))
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
	# 非工具类 (老 ASCII pattern). 注意: 矿石原料 (coal / iron_ore / silver_ore / 等) 不在
	# 这里 — 它们在 _ITEM_TO_TILE 里映射到 block 图, 用世界里的"矿石方块"样子.
	for item_id in ["slime_jelly", "apple",
			"bone", "spider_eye", "lens",
			"raw_meat", "leather", "wool", "cooked_meat", "mushroom",
			"iron_ingot", "copper_ingot", "tin_ingot", "silver_ingot", "gold_ingot",
			"grappling_hook",
			"hell_fruit", "obsidian", "hell_stone",
			"wood_bow", "wood_arrow", "hell_crystal_ingot", "hell_alloy_ingot",
			# 枪械: 常规 4 + 特殊 3 + 手枪 + 子弹 (必须在这注册, 否则运行时 "未知 item icon")
			"pistol", "bullet", "smg", "assault_rifle", "shotgun", "sniper",
			"laser_gun", "flamethrower", "freeze_ray",
			"arcane_gun", "poison_gun", "lightning_gun", "star_gun", "slime_gun",   # 魔法枪 (耗魔力)
			"frost_gun", "leaf_gun",
			# 第二批枪 (用户加): 高速扫射 / 花式弹道 / 元素异常
			"minigun", "twin_magic_gun", "rocket_gun", "ricochet_gun",
			"tesla_gun", "cryo_gun", "venom_gun", "railgun",
			# 盔甲: 15 件 (5 tier × 3 件)
			"copper_helmet", "copper_chest", "copper_pants",
			"iron_helmet", "iron_chest", "iron_pants",
			"silver_helmet", "silver_chest", "silver_pants",
			"gold_helmet", "gold_chest", "gold_pants",
			"diamond_helmet", "diamond_chest", "diamond_pants",
			"hell_staff", "wood_staff", "iron_staff", "mana_potion", "health_potion",
			"lightning_staff", "poison_staff", "multi_staff",   # 新机制法杖 (A 波)
			"explosive_staff", "water_staff", "wind_staff",     # B 波法杖
			"heal_staff", "bird_staff", "crack_staff",          # C 波法杖 (治疗/召唤鸟/地裂)
			# 用户加: 小麦 / 种子 之前漏了, 收割掉地没图
			"wheat", "wheat_seed",
			# 史莱姆王 Boss 掉落 + 合成材料
			"slime_crown", "slime_ball",
			# 骷髅王 Boss: 召唤头骨 + 掉落骨剑(阔剑) + 骷髅盔甲(头/胸/腿) + 骷髅法杖
			"skull_summon", "bone_sword",
			"skeleton_helmet", "skeleton_chest", "skeleton_pants",
			"skull_staff",
			# 空岛: 羽毛(哈比鸟掉) + 云靴(二段跳) — 之前漏注册, 背包没图
			"feather", "cloud_boots",
			# 厨房第 1 步: 8 道料理 (cooked_meat 已在上面)
			"bread", "mushroom_soup", "apple_pie", "meat_skewer",
			"mushroom_stew", "apple_jam", "jelly_pudding",
			# 厨房第 2 步: 鱼竿 + 9 海鲜 + 烤鱼
			"fishing_rod", "grilled_fish",
			"salmon", "tuna", "octopus", "sea_urchin", "lobster",
			"eel", "sweet_shrimp", "scallop", "seaweed",
			# 厨房第 3 步 (逐任务加, 必须 items_art 已有图案才能加这, 否则 get_icon assert)
			"kitchen_knife", "rice", "rice_seed", "cooked_rice", "fish_slice",
			"sushi", "sashimi", "onigiri", "shrimp_sushi", "uni_gunkan"]:
		item_icons[item_id] = ItemsArt.get_icon(item_id)
	# 剑 + 镐 + 斧: 7 tier × 3 tool, 全用 ASCII pattern (16×16)
	# V3: 不再用外部 PNG (尺寸不对头), 改回 items_art.gd 手画像素画
	for tier in ["wood", "stone", "copper", "iron", "silver", "gold", "diamond", "hell"]:
		item_icons["%s_sword" % tier] = ItemsArt.get_icon("%s_sword" % tier)
		item_icons["%s_dagger" % tier] = ItemsArt.get_icon("%s_dagger" % tier)
		item_icons["%s_pickaxe" % tier] = ItemsArt.get_icon("%s_pickaxe" % tier)
		item_icons["%s_axe" % tier] = ItemsArt.get_icon("%s_axe" % tier)
		item_icons["%s_hammer" % tier] = ItemsArt.get_icon("%s_hammer" % tier)


func _build_doors() -> void:
	door_closed_texture = DoorArt.get_closed_texture()
	door_open_texture = DoorArt.get_open_texture()
	door_item_icon = BlocksArt.get_door_icon_texture()


# 按角色外观出玩家 SpriteFrames (捏人/换装用)。player_frames (默认) 仍由 _build_entities 缓存。
func player_frames_for(appearance: Dictionary) -> SpriteFrames:
	return PlayerArt.build_sprite_frames(appearance)


func _build_entities() -> void:
	player_frames = PlayerArt.build_sprite_frames()
	slime_frames = SlimeArt.build_sprite_frames()
	slime_crown_tex = SlimeArt.build_crown_texture()   # 史莱姆王头顶王冠 (单独贴图)
	zombie_frames = ZombieArt.build_sprite_frames()
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
	# 火魔 (Imp): 飞行 + 火球远程
	imp_frames = ImpArt.build_sprite_frames()
	# 地狱蜂: 飞行 + 冲撞
	hell_wasp_frames = HellWaspArt.build_sprite_frames()
	# 哈比鸟: 天空浮岛飞行怪
	harpy_frames = HarpyArt.build_sprite_frames()
	# 火球投射物 (Imp + 地狱法杖红弹). 法杖另两种元素 (蓝/绿) 单独建.
	fireball_frames = FireballArt.build_sprite_frames("fire")
	spell_frames_ice = FireballArt.build_sprite_frames("ice")
	spell_frames_nature = FireballArt.build_sprite_frames("nature")
	# 玩家箭投射物 (弓用)
	arrow_proj_frames = ArrowProjArt.build_sprite_frames()
	# 玩家子弹投射物 (枪用)
	bullet_proj_frames = BulletProjArt.build_sprite_frames()
	# 激光投射物 (激光枪用, 穿透)
	laser_proj_frames = LaserProjArt.build_sprite_frames()
	# 奥术魔弹 (追踪魔弹枪用, 紫色追踪)
	magic_proj_frames = MagicProjArt.build_sprite_frames()
	# 闪电弹 / 星星弹 / 史莱姆弹 (3b 魔法枪)
	lightning_proj_frames = LightningProjArt.build_sprite_frames()
	star_proj_frames = StarProjArt.build_sprite_frames()
	slime_blob_proj_frames = SlimeBlobProjArt.build_sprite_frames()
	leaf_proj_frames = LeafProjArt.build_sprite_frames()
	wind_proj_frames = WindProjArt.build_sprite_frames()
	# 木乃伊: 金字塔守卫
	mummy_frames = MummyArt.build_sprite_frames()
	# Jaguar 已删 (用户要求)


# 按元素取法杖魔法弹贴图: nature=绿 / ice=蓝 / 其它=fire 红 (默认).
func spell_frames_for(element: String) -> SpriteFrames:
	if element == "nature":
		return spell_frames_nature
	if element == "ice":
		return spell_frames_ice
	return fireball_frames


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
	"cooking_pot": BlocksArt.COOKING_POT,
	"cutting_board": BlocksArt.CUTTING_BOARD,
	"door": BlocksArt.DOOR,
	"slime_torch": BlocksArt.SLIME_TORCH,
	"torch": BlocksArt.TORCH,
	# 矿物物品 (挖矿掉的) 全部用对应的"矿石方块" tile 图: 跟世界里挖到的方块一致.
	# 熔炼后变成 *_ingot 物品, 才是干净的金属条 (见 items_art.gd _IRON_INGOT 等).
	"copper_ore": BlocksArt.COPPER_ORE,
	"tin_ore": BlocksArt.TIN_ORE,
	"gold_ore": BlocksArt.GOLD_ORE,
	"diamond": BlocksArt.DIAMOND_ORE,
	"hell_crystal": BlocksArt.HELL_CRYSTAL,
	"hell_alloy_ore": BlocksArt.HELL_ALLOY_ORE,
	"coal": BlocksArt.COAL_ORE,
	"iron_ore": BlocksArt.IRON_ORE,
	"silver_ore": BlocksArt.SILVER_ORE,
	"chest": BlocksArt.CHEST,
	# 用户加: 床 / 水晶 / 砂岩 之前漏了 _ITEM_TO_TILE, 物品掉地上没图 + console 刷 warning
	"bed": BlocksArt.BED,
	"life_crystal": BlocksArt.LIFE_CRYSTAL,
	"mana_crystal": BlocksArt.MANA_CRYSTAL,
	"sandstone": BlocksArt.SANDSTONE,
	"cloud": BlocksArt.CLOUD,
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
	"dirt_wall": BlocksArt.DIRT_WALL,
	"grass_wall": BlocksArt.GRASS_WALL,
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
	if item_id == "door":
		return door_item_icon   # 整扇 3 格门图标 (不用 block_icons 的单格 DOOR)
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
