# 夜晚萤火虫. 在玩家身边随机生成发光黄点, 慢慢飘 + 一闪一闪.
# 跟 TimeOfDay 联动: 夜晚出现, 白天回收.
extends Node2D

const FIREFLY_COUNT := 14
const SPAWN_RADIUS_PX := 200.0       # 在玩家四周这个半径内随机出现
const DRIFT_SPEED := 12.0            # 飘动速度 (px/s)
const FLICKER_MIN_PERIOD := 1.5
const FLICKER_MAX_PERIOD := 3.0
const RESPAWN_RADIUS_PX := 280.0     # 离玩家太远就 teleport 回近处
const FIREFLY_COLOR := Color(1.0, 0.95, 0.4, 1.0)

var _fireflies: Array = []  # [{sprite, vel, flicker_phase, flicker_period}]
var _player: Node2D = null
var _enabled: bool = false
var _tex: ImageTexture = null


func _ready() -> void:
	z_index = 5  # 在玩家上方一点
	_tex = _make_glow_texture(8)


func bind_player(p: Node2D) -> void:
	_player = p


func _process(delta: float) -> void:
	# 跟 TimeOfDay 联动: 夜晚启用, 白天禁用
	var want_enabled: bool = TimeOfDay.is_night() and _player != null
	if want_enabled and not _enabled:
		_spawn_all()
	elif not want_enabled and _enabled:
		_despawn_all()
	_enabled = want_enabled
	if not _enabled:
		return
	# 移动 + flicker
	var player_pos: Vector2 = _player.global_position
	for ff in _fireflies:
		var sprite: Sprite2D = ff["sprite"]
		sprite.position += ff["vel"] * delta
		# 漂移方向偶尔变 (布朗运动感)
		if randf() < 0.02:
			ff["vel"] = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * DRIFT_SPEED
		# 远离玩家就 teleport 回近处
		if sprite.global_position.distance_to(player_pos) > RESPAWN_RADIUS_PX:
			sprite.global_position = player_pos + Vector2(
				randf_range(-SPAWN_RADIUS_PX, SPAWN_RADIUS_PX),
				randf_range(-SPAWN_RADIUS_PX * 0.6, SPAWN_RADIUS_PX * 0.2)
			)
		# Flicker: sin 调亮度 (0.3 ~ 1.0)
		ff["flicker_phase"] += delta / ff["flicker_period"] * TAU
		var brightness: float = 0.65 + 0.35 * sin(ff["flicker_phase"])
		sprite.modulate.a = brightness


func _spawn_all() -> void:
	var player_pos: Vector2 = _player.global_position
	for i in FIREFLY_COUNT:
		var s := Sprite2D.new()
		s.texture = _tex
		s.modulate = FIREFLY_COLOR
		s.position = player_pos + Vector2(
			randf_range(-SPAWN_RADIUS_PX, SPAWN_RADIUS_PX),
			randf_range(-SPAWN_RADIUS_PX * 0.6, SPAWN_RADIUS_PX * 0.2)
		)
		add_child(s)
		_fireflies.append({
			"sprite": s,
			"vel": Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * DRIFT_SPEED,
			"flicker_phase": randf() * TAU,
			"flicker_period": randf_range(FLICKER_MIN_PERIOD, FLICKER_MAX_PERIOD),
		})


func _despawn_all() -> void:
	for ff in _fireflies:
		ff["sprite"].queue_free()
	_fireflies.clear()


# 8x8 圆形渐变贴图, 给萤火虫用. 中心亮, 边缘透明.
func _make_glow_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c: float = size / 2.0
	for y in size:
		for x in size:
			var d: float = Vector2(x - c, y - c).length() / c
			d = clamp(d, 0.0, 1.0)
			var a: float = pow(1.0 - d, 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)
