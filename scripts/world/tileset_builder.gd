# 从 ArtCache.block_textures 构建 TileSet.
# - 不在 EdgeTemplates.FAMILY_OF 里的方块: 1 个 atlas cell (Vector2i.ZERO), 老行为.
# - 在 FAMILY_OF 里的方块 (15 种): 47 个 atlas cell (按 BlobLookup.VARIANT_KEYS 索引),
#   atlas 已是 128×96 (T3 build_atlas 合成), 每 cell 16×16.
#   实心方块的所有 47 cell 都加碰撞 polygon.
#
# TileMapLayer.set_cell(coord, source_id, atlas_coords) 时
# atlas_coords 由 Autotile.refresh_tile (T6) 算出, source_id == tile_id.
extends RefCounted

const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")
const BlobLookup = preload("res://scripts/world/blob_lookup.gd")


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(12, 12)  # 方块更小 (TILE_SIZE 16 → 12, 整体缩 75%)
	# 物理层 0: 世界默认 (bit 0). 普通实心方块用.
	ts.add_physics_layer()
	# 物理层 1: 门专用 (bit 1). 门挡怪不挡玩家 — 玩家 collision_mask=1 跳过, 怪 mask=3 阻挡.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 2)  # 门碰撞放 bit 1
	ts.set_physics_layer_collision_mask(1, 0)
	# 物理层 2: 木平台 (bit 2). 玩家 mask=5 撑住, 怪 mask=3 不挡 → 怪掉穿;
	# 玩家按 S 时临时关 bit 2 → 玩家也能落下.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(2, 4)
	ts.set_physics_layer_collision_mask(2, 0)

	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
		Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.SLIME_TORCH,
		Tiles.DEEP_STONE, Tiles.COAL_ORE, Tiles.IRON_ORE, Tiles.TORCH,
		Tiles.GRASS_WALL, Tiles.DIRT_WALL, Tiles.STONE_WALL, Tiles.WOOD_WALL,
		Tiles.CACTUS, Tiles.CACTUS_BODY,
		Tiles.COPPER_ORE, Tiles.TIN_ORE, Tiles.GOLD_ORE,
		Tiles.DIAMOND_ORE, Tiles.HELL_CRYSTAL,
		Tiles.WATER,
		Tiles.LOG_TOP, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R,
		Tiles.BRANCH_L, Tiles.BRANCH_R,
		Tiles.WATER_L1, Tiles.WATER_L2, Tiles.WATER_L3,
		Tiles.WATER_L4, Tiles.WATER_L5, Tiles.WATER_L6, Tiles.WATER_L7,
		Tiles.WATER_DESERT, Tiles.WATER_JUNGLE, Tiles.WATER_SWAMP,
		Tiles.WATER_SOURCE,   # 水源块 (实心, 走普通方块渲染, 不进下面的水视觉分支)
		Tiles.CHEST,
		Tiles.DOOR_TOP, Tiles.DOOR_MID, Tiles.DOOR_OPEN,
		# 新群系 tile + 平台 + 绳 + 群系泥土/树叶
		Tiles.SNOW, Tiles.ICE, Tiles.JUNGLE_GRASS, Tiles.MUD, Tiles.SWAMP_GRASS,
		Tiles.WOOD_PLATFORM, Tiles.ROPE,
		Tiles.JUNGLE_DIRT, Tiles.SNOW_DIRT, Tiles.JUNGLE_LEAVES,
		Tiles.SILVER_ORE,
		Tiles.FURNACE,
		Tiles.COOKING_POT,
		Tiles.CUTTING_BOARD,
		Tiles.RICE_0, Tiles.RICE_1, Tiles.RICE_2, Tiles.RICE_3,
		Tiles.MUSHROOM,
		Tiles.MIMIC_CHEST,
		Tiles.GOLD_CHEST,
		Tiles.DIAMOND_CHEST,
		Tiles.LAVA, Tiles.LAVA_L1, Tiles.LAVA_L2, Tiles.LAVA_L3,
		Tiles.HELL_STONE, Tiles.OBSIDIAN, Tiles.HELL_FRUIT,
		Tiles.SHADOW_CHEST,
		Tiles.LIFE_CRYSTAL,
		Tiles.HELL_ALLOY_ORE,
		Tiles.SANDSTONE,
		Tiles.MANA_CRYSTAL,
		Tiles.BED, Tiles.BED_RIGHT,
		Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L,
		# 菜园 + 装饰
		Tiles.WHEAT_0, Tiles.WHEAT_1, Tiles.WHEAT_2, Tiles.WHEAT_3,
		Tiles.PLANT_GRASS,
		Tiles.CLOUD,
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(12, 12)
		ts.add_source(source, tile_id)

		# 门 (底/中/顶) 走物理层 1 (挡怪不挡人); DOOR_OPEN 不在内 → 开门无碰撞谁都能穿
		var is_door: bool = tile_id == Tiles.DOOR or tile_id == Tiles.DOOR_TOP \
				or tile_id == Tiles.DOOR_MID

		if EdgeTemplates.FAMILY_OF.has(tile_id):
			# Autotile 方块: 47 cell
			for i in BlobLookup.VARIANT_KEYS.size():
				var coord := Vector2i(i % 8, i / 8)
				source.create_tile(coord)
				if Tiles.is_solid(tile_id):
					var props = source.get_tile_data(coord, 0)
					props.add_collision_polygon(0)
					props.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6),
					]))
		else:
			# 非 autotile: 单 cell
			source.create_tile(Vector2i.ZERO)
			if Tiles.is_slope(tile_id):
				# 斜砖: 三角形碰撞 (实心半边). ◢ 右下三角 / ◣ 左下三角.
				var spts: PackedVector2Array
				if tile_id == Tiles.GRASS_SLOPE_R:
					spts = PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(6, -6)])
				else:  # GRASS_SLOPE_L ◣
					spts = PackedVector2Array([Vector2(-6, 6), Vector2(6, 6), Vector2(-6, -6)])
				var sprops = source.get_tile_data(Vector2i.ZERO, 0)
				sprops.add_collision_polygon(0)
				sprops.set_collision_polygon_points(0, 0, spts)
			elif Tiles.is_solid(tile_id):
				var props = source.get_tile_data(Vector2i.ZERO, 0)
				props.add_collision_polygon(0)
				props.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6),
				]))
			elif is_door:
				# 门: 加碰撞但用物理层 1 (门层 bit 1, 玩家不 mask)
				var dprops = source.get_tile_data(Vector2i.ZERO, 0)
				dprops.add_collision_polygon(1)
				dprops.set_collision_polygon_points(1, 0, PackedVector2Array([
					Vector2(-6, -6), Vector2(6, -6), Vector2(6, 6), Vector2(-6, 6),
				]))
			elif tile_id == Tiles.WOOD_PLATFORM:
				# 平台 (2 行薄板): 碰撞框 y=-1..+1 在物理层 2 (bit 2)
				# 玩家 mask=5 (bit 0+2) 撑住; 玩家按 S 时切 mask=1 → 落下
				var pprops = source.get_tile_data(Vector2i.ZERO, 0)
				pprops.add_collision_polygon(2)
				pprops.set_collision_polygon_points(2, 0, PackedVector2Array([
					Vector2(-6, -1), Vector2(6, -1), Vector2(6, 1), Vector2(-6, 1),
				]))
				pprops.set_collision_polygon_one_way(2, 0, true)
			# 水 (8 档水位 + 3 个群系满水) 都启用 4 帧动画
			if Tiles.is_water(tile_id):
				source.set_tile_animation_frames_count(Vector2i.ZERO, 4)
				for f in range(4):
					source.set_tile_animation_frame_duration(Vector2i.ZERO, f, 0.4)

	return ts
