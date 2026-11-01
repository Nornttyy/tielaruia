# 从公开 TEdit .wld 夹具提取的局部建筑，不声称重现整个原版世界生成器。
extends RefCounted
const ROOT := "res://resources/prefabs/terraria_samples/"
const VISUAL_BASE := 20000
const BuildingArt = preload("res://scripts/art/building_art.gd")
static var _samples: Dictionary = {}
static var _frames: Array = []
static func sample(id: String) -> Dictionary:
	if not _samples.has(id): _samples[id] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + id + ".json"))
	return _samples[id]
static func frames() -> Array:
	if _frames.is_empty(): _frames = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "frames.json"))
	return _frames
static func stamp(c: Chunk, id: String, origin: Vector2i) -> void:
	for cell in sample(id).cells:
		var x := origin.x + int(cell[0]) - c.chunk_x * 64
		var y := origin.y + int(cell[1])
		if x < 0 or x >= 64 or y < 1 or y >= c.tiles[0].size() - 2: continue
		var tid := int(cell[2])
		c.tiles[x][y] = tid
		if int(cell[3]) >= 0: c.walls[x][y] = int(cell[3])
		if int(cell[4]) >= 0: c.original_visuals[Vector2i(x, y)] = [VISUAL_BASE + int(cell[4]), tid]
	# TEdit 样本只记录了物件锚点。按原版占格扩展宝箱，并让四格使用同一套原图裁切，
	# 避免锚点还在用单格样本帧、旁边却没有碰撞/交互格。
	for cell in sample(id).cells:
		var tid := int(cell[2])
		var base: int = BuildingArt.multi_base(tid)
		if base == -1 or base not in [Tiles.CHEST, Tiles.GOLD_CHEST, Tiles.DIAMOND_CHEST, Tiles.SHADOW_CHEST]:
			continue
		var anchor_x: int = origin.x + int(cell[0])
		var anchor_y: int = origin.y + int(cell[1])
		for part in BuildingArt.multi_parts(base):
			var world_x: int = anchor_x + BuildingArt.part_offset(part).x
			var local_x: int = world_x - c.chunk_x * 64
			var world_y: int = anchor_y + BuildingArt.part_offset(part).y
			if local_x < 0 or local_x >= 64 or world_y < 1 or world_y >= c.tiles[0].size() - 2:
				continue
			c.tiles[local_x][world_y] = part
			c.original_visuals.erase(Vector2i(local_x, world_y))
		if anchor_x >= c.chunk_x * 64 and anchor_x < (c.chunk_x + 1) * 64:
			var pos := Vector2i(anchor_x, anchor_y)
			if not c.treasure_spots.has(pos): c.treasure_spots.append(pos)
static func display_id(c: Chunk, pos: Vector2i, tid: int) -> int:
	if c == null: return tid
	var data: Array = c.original_visuals.get(Vector2i(pos.x - c.chunk_x * 64, pos.y), [])
	return int(data[0]) if data.size() == 2 and int(data[1]) == tid else tid
static func register_tiles(ts: TileSet) -> void:
	var pack = preload("res://scripts/art/terraria_sprite_pack.gd")
	for i in frames().size():
		var f: Array = frames()[i]
		var raw: Image = pack.source_image("Tiles_%d.png" % int(f[0]))
		var size := Vector2i(int(f[3]), int(f[4]))
		var img := Image.create(size.x * 16, size.y * 16, false, Image.FORMAT_RGBA8)
		for y in size.y:
			for x in size.x:
				img.blit_rect(raw, Rect2i(int(f[1]) + x * 18, int(f[2]) + y * 18, 16, 16), Vector2i(x, y) * 16)
		img.resize(size.x * 12, size.y * 12, Image.INTERPOLATE_NEAREST)
		var source := TileSetAtlasSource.new()
		source.texture = ImageTexture.create_from_image(img)
		source.texture_region_size = size * 12
		ts.add_source(source, VISUAL_BASE + i)
		source.create_tile(Vector2i.ZERO)
		var data := source.get_tile_data(Vector2i.ZERO, 0)
		data.texture_origin = Vector2i(-(size.x - 1) * 6, (size.y - 1) * 6)
		# 外观使用样本帧，碰撞仍沿用工程里的门/平台/家具规则。
		var base: TileSetAtlasSource = ts.get_source(int(f[5]))
		var base_data := base.get_tile_data(Vector2i.ZERO, 0)
		for layer in ts.get_physics_layers_count():
			for polygon in base_data.get_collision_polygons_count(layer):
				data.add_collision_polygon(layer)
				data.set_collision_polygon_points(layer, polygon, base_data.get_collision_polygon_points(layer, polygon))
				data.set_collision_polygon_one_way(layer, polygon, base_data.is_collision_polygon_one_way(layer, polygon))
