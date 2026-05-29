# 灰尘云。固定贴图，渐隐淡出 + 短上飘。
# 由 DustPool 管理 — 寿命到回池复用, 不再 queue_free.
extends Sprite2D

const LIFETIME := 0.35
const RISE_SPEED := 18.0  # 缓慢上飘 (像素/秒)

var _age: float = 0.0
var _pool: Node = null   # DustPool 持有, _pool.recycle(self) 回池


func setup(start_pos: Vector2, scale_factor: float = 1.0) -> void:
	global_position = start_pos
	texture = ArtCache.dust_puff_texture
	scale = Vector2(scale_factor, scale_factor)
	modulate = Color(1, 1, 1, 1.0)
	_age = 0.0   # 池复用必须归零, 不然立刻又"老了"消失


func _process(delta: float) -> void:
	_age += delta
	global_position.y -= RISE_SPEED * delta
	modulate.a = clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		if _pool != null and _pool.has_method("recycle"):
			_pool.recycle(self)
		else:
			queue_free()   # 没池兜底
