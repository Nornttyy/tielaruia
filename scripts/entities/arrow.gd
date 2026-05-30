# 玩家箭投射物. Area2D, 直线飞 (无重力, v1 简化).
# 命中怪 → 造成伤害 + 销毁. 命中实心方块 → 销毁. 3s 自销.
# 跟 fireball 同结构, 但反方向 (玩家发, 击中怪).
extends Area2D

const TILE_SIZE := 12
const SPEED := 260.0
const LIFETIME_SEC := 3.0
const BASE_DAMAGE := 5

var velocity: Vector2 = Vector2.ZERO
var damage: int = BASE_DAMAGE   # 由弓 tier 控制, 外部传入
var _life_t: float = 0.0
var _cached_chunk_manager = null
var _is_dead: bool = false
var _shooter: Node = null       # 谁射的 (玩家), 避免自伤

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func setup(start_pos: Vector2, target_pos: Vector2, dmg: int, shooter: Node) -> void:
	global_position = start_pos
	damage = dmg
	_shooter = shooter
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED
	rotation = velocity.angle()   # sprite 朝飞行方向


const HIT_RADIUS_PX := 8.0   # 箭中心到怪中心 ≤ 此值算击中

func _ready() -> void:
	sprite.sprite_frames = ArtCache.arrow_proj_frames
	sprite.play("fly")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	# 撞墙 (查 chunk_manager 实心)
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
	# 手动撞怪: 怪物 collision_layer=0 用不了 body_entered, 用距离检测
	_check_enemy_hit()


func _check_enemy_hit() -> void:
	# 扫两组: slimes (敌对怪) + animals (牛羊猪 — 弓应该能射). 否则箭穿过动物.
	for group in ["slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy == _shooter or not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			if global_position.distance_to((enemy as Node2D).global_position) > HIT_RADIUS_PX:
				continue
			if enemy.has_method("take_damage"):
				enemy.take_damage(damage, global_position, 120.0)
				_destroy()
				return


func _destroy() -> void:
	if _is_dead:
		return
	_is_dead = true
	queue_free()


func _get_cm():
	if _cached_chunk_manager != null and is_instance_valid(_cached_chunk_manager):
		return _cached_chunk_manager
	_cached_chunk_manager = get_tree().get_first_node_in_group("chunk_manager")
	return _cached_chunk_manager
