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
	# 先建物理层 (索引 0), 后续给实心 tile 加碰撞 polygon 才能引用
	ts.add_physics_layer()

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
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(16, 16)
		ts.add_source(source, tile_id)

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

	return ts
