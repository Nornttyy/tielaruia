# 房屋前景、背景墙、家具分开落盘；仅清理每栋建筑占地，保留屋间树木。
class_name VillagePlacer extends RefCounted
const VillagePrefab = preload("res://scripts/world/village_prefab.gd")
const BuildingArt = preload("res://scripts/art/building_art.gd")
const Autotile = preload("res://scripts/world/autotile.gd")
const EdgeTemplates = preload("res://scripts/art/edge_templates.gd")

static func place(cm: ChunkManager, terrain: TileMapLayer, prefab: Dictionary, anchor: Vector2i, walls: TileMapLayer = null) -> void:
	var lighting: Node = terrain.get_parent().get_node_or_null("WorldLighting") if terrain != null else null
	for house in prefab.houses:
		var start := anchor + Vector2i(house.anchor_x, house.anchor_y)
		var rows: int = house.grid.size()
		if rows == 0: continue
		var cols: int = String(house.grid[0]).length()
		# 门分段和家具稍后盖，防止后续空气格把上半部分擦掉。
		for y in rows:
			for x in cols:
				if lighting != null: lighting.on_tile_removed(start.x + x, start.y + y, cm.get_tile(start.x + x, start.y + y))
				cm.set_tile(start.x + x, start.y + y, Tiles.AIR)
				cm.set_wall(start.x + x, start.y + y, Tiles.AIR)
		for y in rows:
			for x in cols:
				var pos := start + Vector2i(x, y)
				var tid: int = VillagePrefab.char_to_tile(String(house.grid[y])[x])
				if tid >= 0:
					cm.set_tile(pos.x, pos.y, tid)
					if lighting != null: lighting.on_tile_placed(pos.x, pos.y, tid)
					if tid == Tiles.DOOR:
						cm.set_tile(pos.x, pos.y - 1, Tiles.DOOR_MID)
						cm.set_tile(pos.x, pos.y - 2, Tiles.DOOR_TOP)
				if house.has("walls"):
					var wid: int = {"w": Tiles.WOOD_WALL, "g": Tiles.GLASS_WALL, "b": Tiles.WOOD_WALL, "s": Tiles.STONE_WALL}.get(String(house.walls[y])[x], Tiles.AIR)
					cm.set_wall(pos.x, pos.y, wid)
		for entry in house.get("furniture", []):
			var base: int = entry.tile
			var dims := BuildingArt.footprint(base)
			for i in dims.x * dims.y:
				var pos := start + Vector2i(entry.x, entry.y) + BuildingArt.part_offset(base + i)
				cm.set_tile(pos.x, pos.y, base + i)
		if terrain != null:
			for y in range(-1, rows + 1):
				for x in range(-1, cols + 1):
					var pos := start + Vector2i(x, y)
					_render_cell(terrain, pos, cm.get_tile(pos.x, pos.y), cm, false)
					if walls != null: _render_cell(walls, pos, cm.get_wall(pos.x, pos.y), cm, true)
					SkyLightGrid.invalidate_column(pos.x)

static func _render_cell(layer: TileMapLayer, pos: Vector2i, tid: int, cm: ChunkManager, is_wall: bool) -> void:
	if tid == Tiles.AIR:
		layer.erase_cell(pos)
	elif EdgeTemplates.FAMILY_OF.has(tid):
		var query := Autotile.make_wall_query(tid, cm) if is_wall else Autotile.make_terrain_query(tid, cm)
		Autotile.refresh_tile(layer, pos, tid, query, Callable() if is_wall else Autotile.make_solid_query(cm))
	else:
		layer.set_cell(pos, tid, Vector2i.ZERO)
