# 单颗水珠 (纯视觉)。受重力下落, 短寿命渐隐后回池。
# 由 WaterGrainPool 管理 — 寿命到调 _pool.recycle(self) 复用, 没池兜底 queue_free。
# 重力比碎块(800)轻 → 水珠飘一点, 不像石头那样砸下去。
extends Sprite2D

const ParticlesArt = preload("res://scripts/fx/particles_art.gd")
const GRAVITY := 520.0
const LIFETIME := 0.6

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0
var _alpha0: float = 1.0   # 起始 alpha (群系水色自带), 渐隐基于它
var _pool: Node = null     # WaterGrainPool 持有, 死时回池


func setup(start_pos: Vector2, vel: Vector2, color: Color) -> void:
	global_position = start_pos
	velocity = vel
	texture = ParticlesArt.get_water_drop()
	modulate = color
	_alpha0 = color.a
	_age = 0.0   # 池复用必须归零, 否则立刻"老了"消失


func _process(delta: float) -> void:
	_age += delta
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	modulate.a = _alpha0 * clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		if _pool != null and _pool.has_method("recycle"):
			_pool.recycle(self)
		else:
			queue_free()   # 没池兜底
