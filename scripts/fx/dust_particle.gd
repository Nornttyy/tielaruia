# 灰尘云。固定贴图，渐隐淡出 + 短上飘。
extends Sprite2D

const LIFETIME := 0.35
const RISE_SPEED := 18.0  # 缓慢上飘 (像素/秒)

var _age: float = 0.0


func setup(start_pos: Vector2, scale_factor: float = 1.0) -> void:
	global_position = start_pos
	texture = ArtCache.dust_puff_texture
	scale = Vector2(scale_factor, scale_factor)
	modulate = Color(1, 1, 1, 1.0)


func _process(delta: float) -> void:
	_age += delta
	global_position.y -= RISE_SPEED * delta
	modulate.a = clamp(1.0 - _age / LIFETIME, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
