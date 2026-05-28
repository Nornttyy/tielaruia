# 飘叶子. 在玩家附近的树叶 tile 下方偶尔生成飘落叶子.
# 寻找玩家半径内的 LEAVES / LEAVES_PINE / LEAVES_AUTUMN tile, 每 0.8-2.0s 在其下方一格
# 生成一片叶子, 慢慢飘下来 + 左右摇摆.
extends Node2D

const SPAWN_MIN_INTERVAL := 0.8
const SPAWN_MAX_INTERVAL := 2.0
const SEARCH_RADIUS_TILES := 12
const FALL_SPEED := 18.0
const SWAY_AMPLITUDE := 12.0
const SWAY_PERIOD := 1.8
const LIFE_TIME := 6.0
const LEAF_SIZE := 3
const TILE_SIZE := 12

# 不同 leaves tile id → 叶子颜色 (用 id 数字, 不依赖 Tiles 常量)
const LEAF_COLORS := {
	6: Color(0.5, 0.7, 0.35),    # LEAVES (橡木) 暖绿
	11: Color(0.3, 0.5, 0.3),    # LEAVES_PINE 深绿
	12: Color(0.85, 0.45, 0.25), # LEAVES_AUTUMN 橙红
}

var _spawn_t: float = 0.0
var _player: Node2D = null
var _terrain: TileMapLayer = null
var _leaf_tex: ImageTexture = null
# 飞行中的叶子: [{sprite, base_x, life, phase}]
var _leaves: Array = []


func _ready() -> void:
	z_index = 3
	_reset_timer()
	_leaf_tex = _make_leaf_texture()


func bind_player(p: Node2D) -> void:
	_player = p


func _process(delta: float) -> void:
	# 处理在飞的叶子: 下落 + 摆动 + 寿命到了消失
	for i in range(_leaves.size() - 1, -1, -1):
		var leaf = _leaves[i]
		leaf["life"] += delta
		var s: Sprite2D = leaf["sprite"]
		if leaf["life"] >= LIFE_TIME or not is_instance_valid(s):
			if is_instance_valid(s):
				s.queue_free()
			_leaves.remove_at(i)
			continue
		s.position.y += FALL_SPEED * delta
		s.position.x = leaf["base_x"] + sin(leaf["life"] * TAU / SWAY_PERIOD + leaf["phase"]) * SWAY_AMPLITUDE
		s.modulate.a = 1.0 - (leaf["life"] / LIFE_TIME)  # 飘飘渐隐
	# 生成新叶子
	if _player == null:
		return
	if _terrain == null:
		_terrain = get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
		if _terrain == null:
			return
	_spawn_t -= delta
	if _spawn_t <= 0.0:
		_spawn_one()
		_reset_timer()


func _reset_timer() -> void:
	_spawn_t = randf_range(SPAWN_MIN_INTERVAL, SPAWN_MAX_INTERVAL)


func _spawn_one() -> void:
	var ppos: Vector2 = _player.global_position
	var ptx: int = int(floor(ppos.x / float(TILE_SIZE)))
	var pty: int = int(floor(ppos.y / float(TILE_SIZE)))
	# 试 5 次找树叶 tile
	for attempt in 5:
		var tx: int = ptx + randi_range(-SEARCH_RADIUS_TILES, SEARCH_RADIUS_TILES)
		var ty: int = pty + randi_range(-SEARCH_RADIUS_TILES, SEARCH_RADIUS_TILES)
		var tid: int = _terrain.get_cell_source_id(Vector2i(tx, ty))
		if tid == -1 or not LEAF_COLORS.has(tid):
			continue
		var spawn_pos: Vector2 = Vector2(tx * TILE_SIZE + TILE_SIZE / 2, (ty + 1) * TILE_SIZE + TILE_SIZE / 4)
		_spawn_leaf(spawn_pos, LEAF_COLORS[tid])
		return


func _spawn_leaf(start_pos: Vector2, color: Color) -> void:
	var s := Sprite2D.new()
	s.texture = _leaf_tex
	s.modulate = color
	s.position = start_pos
	add_child(s)
	_leaves.append({
		"sprite": s,
		"base_x": start_pos.x,
		"life": 0.0,
		"phase": randf() * TAU,
	})


func _make_leaf_texture() -> ImageTexture:
	var img := Image.create(LEAF_SIZE, LEAF_SIZE, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 0.95))
	return ImageTexture.create_from_image(img)
