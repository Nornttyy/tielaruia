# 单个火花。向上飘 + 微弱重力下拉 + 后半段 alpha 渐隐 + 0.8s 自删。
# TorchFx 每 0.12-0.20s 实例化一个, 放到 effects_root。
extends Sprite2D

const GRAVITY := 200.0
const LIFETIME := 0.8

var velocity: Vector2 = Vector2.ZERO
var _age: float = 0.0


# 入参:
#   start_pos: 起点 (火苗顶部附近)
# 颜色: 90% 在亮黄 → 暖橙间随机, 5% 红 (剩 5% 偏黄端 = lerp 接近 0)
func setup(start_pos: Vector2) -> void:
	global_position = start_pos
	var color: Color
	var roll: float = randf()
	if roll < 0.05:
		color = Color(1.0, 0.3, 0.1)  # 5% 红
	else:
		var t: float = randf()
		color = Color(1.0, 0.9, 0.4).lerp(Color(1.0, 0.5, 0.2), t)
	var ParticlesArt = preload("res://scripts/fx/particles_art.gd")
	texture = ParticlesArt.get_torch_spark(color)
	velocity = Vector2(randf_range(-15.0, 15.0), randf_range(-80.0, -40.0))


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	_age += delta
	if _age > LIFETIME * 0.5:
		var t: float = (_age - LIFETIME * 0.5) / (LIFETIME * 0.5)
		modulate.a = clamp(1.0 - t, 0.0, 1.0)
	if _age >= LIFETIME:
		queue_free()
