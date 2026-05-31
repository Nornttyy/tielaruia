# 火球: Imp 朝玩家发射的投射物 + 玩家法杖朝怪物发射.
# is_player_cast 标记区分 (true = 玩家法杖发, 撞怪而不是撞玩家)
extends Area2D

const DEFAULT_DAMAGE := 14
const SPEED := 180.0
const LIFETIME_SEC := 2.0
const TILE_SIZE := 12
const HIT_RADIUS_PX := 8.0   # 玩家方向手动碰怪距离

var velocity: Vector2 = Vector2.ZERO
var damage: int = DEFAULT_DAMAGE
var is_player_cast: bool = false  # true = 玩家法杖发, 撞 slimes 组扣血; false = Imp 发, 撞玩家扣血
var _life_t: float = 0.0
var _cached_chunk_manager = null
var _is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func setup(start_pos: Vector2, target_pos: Vector2, dmg: int = DEFAULT_DAMAGE, player_cast: bool = false) -> void:
	global_position = start_pos
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED
	damage = dmg
	is_player_cast = player_cast
	rotation = velocity.angle()


func _ready() -> void:
	sprite.sprite_frames = ArtCache.fireball_frames
	sprite.play("fly")
	# Imp 发的 (player_cast=false): 撞玩家 (body 在 player 组) — body_entered 信号
	# 玩家法杖发的 (player_cast=true): 撞怪 (slimes 组 collision_layer=0 收不到 body_entered, 改手动距离判)
	if not is_player_cast:
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
	# 玩家发的火球: 手动扫怪 (因为怪 collision_layer=0, Area2D body_entered 收不到)
	if is_player_cast:
		_check_enemy_hit()


func _check_enemy_hit() -> void:
	# 扫两组: slimes (敌对怪) + animals (牛羊猪 — 法杖应该能打). 否则火球穿过动物.
	for group in ["slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if not is_instance_valid(enemy) or not enemy is Node2D:
				continue
			if global_position.distance_to((enemy as Node2D).global_position) > HIT_RADIUS_PX:
				continue
			if enemy.has_method("take_damage"):
				# 同 arrow: 沿飞行反方向后退 32px 算 source_pos, 避免命中点重合导致击退退化为 UP
				var src: Vector2 = global_position - velocity.normalized() * 32.0
				enemy.take_damage(damage, src, 150.0)
			_destroy()
			return


func _on_body_entered(body: Node) -> void:
	if _is_dead:
		return
	if not body.is_in_group("player"):
		return
	var hp: Node = body.get_node_or_null("PlayerHealth")
	if hp != null:
		hp.take_damage(damage, global_position, 180.0)
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
