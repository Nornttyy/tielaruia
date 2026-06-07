# 单个块碎片。受重力，30 帧 (0.5s @ 60fps) 后自删。
extends Sprite2D

const GRAVITY := 400.0
const LIFETIME := 0.5

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


func setup(start_pos: Vector2, color: Color, vel: Vector2) -> void:
	global_position = start_pos
	texture = _make_texture(color)
	velocity = vel


func _make_texture(color: Color) -> ImageTexture:
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	return ParticlesArt.get_block_chip(color)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	_age += delta
	if _age >= LIFETIME:
		queue_free()
