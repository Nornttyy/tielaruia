# 火球: Imp 朝玩家发射的投射物.
# 用 Area2D 检测玩家命中, 手动查 chunk_manager 看撞墙. 直线飞 + 2s 自销.
# 击中玩家: 6 伤 + 击退. 击中实心方块: 直接消失. 飞 2s 也自销 (远射穿不到玩家就让步).
extends Area2D

const DAMAGE := 6
const SPEED := 180.0
const LIFETIME_SEC := 2.0
const TILE_SIZE := 12

var velocity: Vector2 = Vector2.ZERO
var _life_t: float = 0.0
var _cached_chunk_manager = null
var _is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func setup(start_pos: Vector2, target_pos: Vector2) -> void:
	global_position = start_pos
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED


func _ready() -> void:
	sprite.sprite_frames = ArtCache.fireball_frames
	sprite.play("fly")
	# 命中玩家 → take_damage + 销毁
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	# 检查下一步位置是不是实心 (撞墙)
	var next: Vector2 = global_position + velocity * delta
	var cm = _get_cm()
	if cm != null:
		var tx: int = int(floor(next.x / TILE_SIZE))
		var ty: int = int(floor(next.y / TILE_SIZE))
		var t: int = cm.get_tile(tx, ty)
		if t != Tiles.AIR and Tiles.is_solid(t):
			_destroy()
			return
	global_position = next


func _on_body_entered(body: Node) -> void:
	if _is_dead:
		return
	if not body.is_in_group("player"):
		return
	var hp: Node = body.get_node_or_null("PlayerHealth")
	if hp != null:
		hp.take_damage(DAMAGE, global_position, 180.0)
	_destroy()


func _destroy() -> void:
	if _is_dead:
		return
	_is_dead = true
	# 小爆炸视觉
	Effects.spawn_explosion(global_position)
	queue_free()


func _get_cm():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	_cached_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	return _cached_chunk_manager
