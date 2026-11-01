extends RefCounted

# 原始素材 16px 对应一格，世界坐标一格 12px；图标不要再次按格子压缩。
const PIXEL_SCALE := 12.0 / 16.0

static func align_feet(sprite: AnimatedSprite2D, size_multiplier := 1.0) -> void:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_meta("foot_anchor"): return
	var anchor: float = sprite.sprite_frames.get_meta("foot_anchor", -10.0)
	sprite.position.y = anchor * size_multiplier

static func body_rect(body: Node2D) -> Rect2:
	var collider := body.get_node_or_null("CollisionShape2D") as CollisionShape2D
	if collider != null and collider.shape != null:
		return collider.global_transform * collider.shape.get_rect()
	# 无实体碰撞的远程玩家仍使用同一身体范围。
	return Rect2(body.global_position + Vector2(-7.2, -30), Vector2(14.4, 30))

static func touching(a: Node2D, b: Node2D) -> bool:
	return body_rect(a).intersects(body_rect(b))

static func segment_hits(body: Node2D, start: Vector2, end: Vector2, padding := 2.0) -> bool:
	var rect := body_rect(body).grow(padding)
	if rect.has_point(start) or rect.has_point(end): return true
	var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(start, end, corners[i], corners[(i + 1) % 4]) != null: return true
	return false
