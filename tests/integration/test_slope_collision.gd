# 斜砖在 tileset 里有单格 + 三角碰撞 (3 顶点, 区别于方块的 4 顶点).
extends GutTest
const TileSetBuilder = preload("res://scripts/world/tileset_builder.gd")

func test_slope_has_triangle_collision() -> void:
	var ts: TileSet = TileSetBuilder.build()
	for sid in [Tiles.GRASS_SLOPE_R, Tiles.GRASS_SLOPE_L]:
		var src: TileSetAtlasSource = _source_for(ts, sid)
		assert_true(src != null, "斜砖 %d 该有 source" % sid)
		if src == null:
			continue
		var td: TileData = src.get_tile_data(Vector2i.ZERO, 0)
		assert_eq(td.get_collision_polygons_count(0), 1, "斜砖 1 个碰撞多边形")
		assert_eq(td.get_collision_polygon_points(0, 0).size(), 3, "三角碰撞 = 3 顶点")

func _source_for(ts: TileSet, sid: int) -> TileSetAtlasSource:
	# 本项目注册时 source_id == tile_id (见 tileset_builder add_source(source, tile_id))
	if not ts.has_source(sid):
		return null
	return ts.get_source(sid)
