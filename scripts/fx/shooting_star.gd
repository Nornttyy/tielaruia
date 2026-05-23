# 流星. 夜晚天空偶尔划过一道白光.
# 跟 TimeOfDay 联动: 夜晚每 15-40s 触发一次, 白天不触发.
extends Node2D

const STAR_SPAWN_MIN_INTERVAL := 15.0
const STAR_SPAWN_MAX_INTERVAL := 40.0
const STAR_DURATION := 0.6           # 流星划过持续时间 (s)
const STAR_LENGTH := 80.0            # 流星尾巴长度 (px)
const STAR_COLOR := Color(1.0, 0.95, 0.8, 1.0)
const SPAWN_Y_MIN := -200.0          # 在玩家上方这个 y 范围内出现 (天空)
const SPAWN_Y_MAX := -80.0

var _next_spawn_t: float = 0.0
var _player: Node2D = null


func _ready() -> void:
	z_index = 4  # 比萤火虫稍低 (在天空)
	_reset_timer()


func bind_player(p: Node2D) -> void:
	_player = p


func _process(delta: float) -> void:
	if not TimeOfDay.is_night() or _player == null:
		return
	_next_spawn_t -= delta
	if _next_spawn_t <= 0.0:
		_spawn_one()
		_reset_timer()


func _reset_timer() -> void:
	_next_spawn_t = randf_range(STAR_SPAWN_MIN_INTERVAL, STAR_SPAWN_MAX_INTERVAL)


func _spawn_one() -> void:
	# 起点: 玩家左上方屏外 (随机 y), 终点: 玩家右下方 (倾斜角约 -25°)
	var player_pos: Vector2 = _player.global_position
	var start: Vector2 = player_pos + Vector2(
		randf_range(-600.0, -200.0),
		randf_range(SPAWN_Y_MIN, SPAWN_Y_MAX)
	)
	var direction: Vector2 = Vector2(1.0, 0.45).normalized()
	var distance: float = randf_range(450.0, 700.0)
	# Line2D: 起点是流星头, 终点是尾巴尾
	var line := Line2D.new()
	line.add_point(Vector2.ZERO)
	line.add_point(-direction * STAR_LENGTH)
	line.width = 2.5
	line.default_color = STAR_COLOR
	line.global_position = start
	add_child(line)
	# 动画: 0.6s 内沿 direction 移动 distance + alpha 从 1 淡到 0
	var t := create_tween().set_parallel(true)
	t.tween_property(line, "global_position", start + direction * distance, STAR_DURATION)
	t.tween_property(line, "modulate:a", 0.0, STAR_DURATION).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(line.queue_free)
