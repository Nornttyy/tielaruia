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
	ts.tile_size = Vector2i(16, 16)
	# 物理层 0: 世界默认 (bit 0). 普通实心方块用.
	ts.add_physics_layer()
	# 物理层 1: 门专用 (bit 1). 门挡怪不挡玩家 — 玩家 collision_mask=1 跳过, 怪 mask=3 阻挡.
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(1, 2)  # 门碰撞放 bit 1
	ts.set_physics_layer_collision_mask(1, 0)

	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
		Tiles.LEAVES_PINE, Tiles.LEAVES_AUTUMN, Tiles.SLIME_TORCH,
		Tiles.DEEP_STONE, Tiles.COAL_ORE, Tiles.IRON_ORE, Tiles.TORCH,
		Tiles.GRASS_WALL, Tiles.DIRT_WALL, Tiles.STONE_WALL,
		Tiles.CACTUS, Tiles.CACTUS_BODY,
		Tiles.COPPER_ORE, Tiles.TIN_ORE, Tiles.GOLD_ORE,
		Tiles.DIAMOND_ORE, Tiles.HELL_CRYSTAL,
		Tiles.WATER,
		Tiles.LOG_TOP, Tiles.LOG_ROOT_L, Tiles.LOG_ROOT_R,
		Tiles.BRANCH_L, Tiles.BRANCH_R,
		Tiles.WATER_L1, Tiles.WATER_L2, Tiles.WATER_L3,
		Tiles.CHEST,
		Tiles.DOOR_TOP,
		# 新群系 tile + 平台 + 绳 + 群系泥土/树叶
		Tiles.SNOW, Tiles.ICE, Tiles.JUNGLE_GRASS, Tiles.MUD, Tiles.SWAMP_GRASS,
		Tiles.WOOD_PLATFORM, Tiles.ROPE,
		Tiles.JUNGLE_DIRT, Tiles.SNOW_DIRT, Tiles.JUNGLE_LEAVES,
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(16, 16)
		ts.add_source(source, tile_id)

		# 门 (上+下) 走物理层 1, 跟普通 solid 不同; 在下面专门处理
		var is_door: bool = tile_id == Tiles.DOOR or tile_id == Tiles.DOOR_TOP

		if EdgeTemplates.FAMILY_OF.has(tile_id):
			# Autotile 方块: 47 cell
			for i in BlobLookup.VARIANT_KEYS.size():
				var coord := Vector2i(i % 8, i / 8)
				source.create_tile(coord)
				if Tiles.is_solid(tile_id):
					var props = source.get_tile_data(coord, 0)
					props.add_collision_polygon(0)
					props.set_collision_polygon_points(0, 0, PackedVector2Array([
						Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
					]))
		else:
			# 非 autotile: 单 cell
			source.create_tile(Vector2i.ZERO)
			if Tiles.is_solid(tile_id):
				var props = source.get_tile_data(Vector2i.ZERO, 0)
				props.add_collision_polygon(0)
				props.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))
			elif is_door:
				# 门: 加碰撞但用物理层 1 (门层 bit 1, 玩家不 mask)
				var dprops = source.get_tile_data(Vector2i.ZERO, 0)
				dprops.add_collision_polygon(1)
				dprops.set_collision_polygon_points(1, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
				]))
			elif tile_id == Tiles.WOOD_PLATFORM:
				# 平台: 顶端一条薄碰撞 + one_way=true → 只能从上面落下来站住,
				# 下面跳不上来 (从下穿过). Terraria 风
				var pprops = source.get_tile_data(Vector2i.ZERO, 0)
				pprops.add_collision_polygon(0)
				# Polygon 在 tile 顶端 y=-8 处一条薄条带 (高 3 px), 给玩家落脚.
				# one_way: polygon 法线方向只有"顶 → 底"方向算碰撞 (从上落下被挡)
				pprops.set_collision_polygon_points(0, 0, PackedVector2Array([
					Vector2(-8, -8), Vector2(8, -8), Vector2(8, -5), Vector2(-8, -5),
				]))
				pprops.set_collision_polygon_one_way(0, 0, true)
			# 水 (4 个水位) 都启用 4 帧动画
			if tile_id == Tiles.WATER or tile_id == Tiles.WATER_L1 \
					or tile_id == Tiles.WATER_L2 or tile_id == Tiles.WATER_L3:
				source.set_tile_animation_frames_count(Vector2i.ZERO, 4)
				for f in range(4):
					source.set_tile_animation_frame_duration(Vector2i.ZERO, f, 0.4)

	return ts
