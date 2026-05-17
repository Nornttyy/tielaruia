# 从 ArtCache.block_textures 构建 TileSet，每个 tile_id 作为独立 source。
# TileMapLayer.set_cell(coord, source_id, atlas_coords=Vector2i.ZERO) 时
# source_id 即 Tiles 的常量 (1=GRASS, 2=DIRT, ...)。
extends RefCounted


static func build() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(16, 16)

	# 先建物理层 (索引 0)，后续给实心 tile 加碰撞 polygon 才能引用
	ts.add_physics_layer()

	var tile_ids: Array[int] = [
		Tiles.GRASS, Tiles.DIRT, Tiles.STONE, Tiles.SAND,
		Tiles.LOG, Tiles.LEAVES, Tiles.PLANKS, Tiles.WORKBENCH,
		Tiles.DOOR, Tiles.BEDROCK,
	]
	for tile_id in tile_ids:
		var source := TileSetAtlasSource.new()
		source.texture = ArtCache.block_textures[tile_id]
		source.texture_region_size = Vector2i(16, 16)
		source.create_tile(Vector2i.ZERO)

		# 给实心 tile 加碰撞 (leaves 不实心)
		if Tiles.is_solid(tile_id):
			# 注意：source.get_tile_data 返回 Godot 内建 TileData 类型，故省略类型注解
			var tile_props = source.get_tile_data(Vector2i.ZERO, 0)
			tile_props.add_collision_polygon(0)
			tile_props.set_collision_polygon_points(0, 0, PackedVector2Array([
				Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8),
			]))

		ts.add_source(source, tile_id)

	return ts
