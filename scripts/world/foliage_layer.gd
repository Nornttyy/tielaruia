# 树冠、树枝和草叶共用世界空间的风；镜头移动、重新进入视野不会重置相位。
extends Node2D

const SWAY_TILES := [Tiles.LOG_TOP, Tiles.BRANCH_L, Tiles.BRANCH_R, Tiles.PLANT_GRASS]
const MAX_LEAVES := 32
const LEAF_COLORS := [Color8(96, 155, 45), Color8(135, 173, 55), Color8(63, 152, 69), Color8(129, 91, 160), Color8(163, 68, 70)]
var terrain: TileMapLayer
var world: Node2D
var wind_time := 0.0
var _scan_timer := 0.0
var _leaf_timer := 0.8
var _visible_parts: Array[Dictionary] = []
var _textures: Dictionary = {}
var _leaves: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func setup(target: Node2D, layer: TileMapLayer) -> void:
	world = target
	terrain = layer
	_rng.randomize()

static func trunk_column(cell: Vector2i, tid: int) -> int:
	return cell.x + (1 if tid == Tiles.BRANCH_L else -1 if tid == Tiles.BRANCH_R else 0)

static func sway_angle(time: float, cell: Vector2i, tid: int) -> float:
	var phase := float(trunk_column(cell, tid)) * 0.73
	var gust := 0.65 + 0.35 * sin(time * 0.31 + phase * 0.09)
	var wave := sin(time * 1.35 + phase) * 0.75 + sin(time * 2.1 + phase) * 0.25
	var amplitude := 0.09 if tid == Tiles.PLANT_GRASS else 0.035 if tid != Tiles.LOG_TOP else 0.022
	return wave * gust * amplitude

func _process(delta: float) -> void:
	if terrain == null or terrain.tile_set == null: return
	wind_time += delta
	_scan_timer -= delta
	if _scan_timer <= 0.0:
		_scan_timer = 0.25
		_refresh_visible()
	_leaf_timer -= delta
	if _leaf_timer <= 0.0:
		_leaf_timer = _rng.randf_range(0.8, 1.6)
		_spawn_leaf()
	_advance_leaves(delta)
	queue_redraw()

func _view_rect() -> Rect2:
	var inverse := get_canvas_transform().affine_inverse()
	return Rect2(inverse * Vector2.ZERO, get_viewport_rect().size / get_canvas_transform().get_scale()).grow(100)

func _refresh_visible() -> void:
	_visible_parts.clear()
	var view := _view_rect()
	for tid in SWAY_TILES:
		for cell in terrain.get_used_cells_by_id(tid):
			var center := terrain.map_to_local(cell)
			if not view.has_point(center): continue
			var frame := terrain.get_cell_atlas_coords(cell)
			var key := Vector3i(tid, frame.x, frame.y)
			var source := terrain.tile_set.get_source(tid) as TileSetAtlasSource
			if not _textures.has(key):
				var tex := AtlasTexture.new()
				tex.atlas = source.texture
				tex.region = source.get_tile_texture_region(frame)
				tex.filter_clip = true
				_textures[key] = tex
			var tex: AtlasTexture = _textures[key]
			var data := source.get_tile_data(frame, 0)
			var pivot := center + Vector2(0, 6)
			if tid == Tiles.BRANCH_L: pivot = center + Vector2(6, 0)
			elif tid == Tiles.BRANCH_R: pivot = center - Vector2(6, 0)
			var top_left := center - Vector2(data.texture_origin) - tex.get_size() / 2.0
			_visible_parts.append({"cell": cell, "tid": tid, "frame": frame, "texture": tex,
				"pivot": pivot, "rect": Rect2(top_left - pivot, tex.get_size())})

func _still_present(part: Dictionary) -> bool:
	return terrain.get_cell_source_id(part.cell) == part.tid and terrain.get_cell_atlas_coords(part.cell) == part.frame

func _draw() -> void:
	for part in _visible_parts:
		if not _still_present(part): continue
		draw_set_transform(part.pivot, sway_angle(wind_time, part.cell, part.tid))
		draw_texture_rect(part.texture, part.rect, false)
	draw_set_transform(Vector2.ZERO)
	for leaf in _leaves:
		var color: Color = leaf.color
		color.a *= clampf(leaf.life, 0.0, 1.0)
		var width := 1.0 if sin(leaf.phase + leaf.age * 5.0) < 0.0 else 3.0
		draw_rect(Rect2(leaf.pos, Vector2(width, 1)), color)
		draw_rect(Rect2(leaf.pos + Vector2(1, 1), Vector2(1, 1)), color.darkened(0.2))

func _spawn_leaf() -> void:
	if _leaves.size() >= MAX_LEAVES: return
	var crowns: Array[Dictionary] = []
	var view := _view_rect().grow(-60)
	for part in _visible_parts:
		# 雪原的枯枝不掉绿叶；被砍掉的树冠不能继续产生落叶。
		if part.tid == Tiles.LOG_TOP and part.frame.y != 1 and view.has_point(part.pivot) and _still_present(part):
			crowns.append(part)
	if crowns.is_empty(): return
	var crown := crowns[_rng.randi_range(0, crowns.size() - 1)]
	var start: Vector2 = crown.pivot + Vector2(_rng.randf_range(-18, 18), _rng.randf_range(-50, -30))
	_leaves.append({"pos": start, "age": 0.0, "life": _rng.randf_range(6.0, 10.0),
		"phase": _rng.randf_range(0, TAU), "speed": _rng.randf_range(10, 18), "landed": false,
		"color": LEAF_COLORS[clampi(crown.frame.y, 0, 4)]})

func _advance_leaves(delta: float) -> void:
	var view := _view_rect()
	for i in range(_leaves.size() - 1, -1, -1):
		var leaf := _leaves[i]
		leaf.age += delta
		leaf.life -= delta
		if not leaf.landed:
			leaf.pos += Vector2(9.0 + sin(wind_time * 0.7 + leaf.phase) * 7.0, leaf.speed) * delta
			if world != null and world.get("chunk_manager") != null:
				var cell := Vector2i((leaf.pos / 12.0).floor())
				var tid: int = world.chunk_manager.get_tile(cell.x, cell.y)
				if Tiles.is_solid(tid) or Tiles.is_water(tid):
					leaf.landed = true
					leaf.life = minf(leaf.life, 0.6)
		if leaf.life <= 0.0 or not view.has_point(leaf.pos): _leaves.remove_at(i)
