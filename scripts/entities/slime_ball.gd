# 史莱姆球: 玩家专属投射物 (Boss 掉落武器发射). Area2D, 受重力抛物线飞,
# 撞实心方块/地面反弹 (最多 MAX_BOUNCES 次, 速度衰减), 命中怪 → 伤害 + 销毁.
extends Area2D

const TILE_SIZE := ChunkConstants.TILE_SIZE
const SPEED := 240.0
const GRAVITY := 480.0
const LIFETIME_SEC := 4.0
const BASE_DAMAGE := 16
const HIT_RADIUS_PX := 9.0
const MAX_BOUNCES := 3
const BOUNCE_DAMP := 0.6

var velocity: Vector2 = Vector2.ZERO
var damage: int = BASE_DAMAGE
var _life_t: float = 0.0
var _bounces: int = 0
var _cached_chunk_manager = null
var _is_dead: bool = false
var _shooter: Node = null

@onready var sprite: Sprite2D = $Sprite2D


func setup(start_pos: Vector2, target_pos: Vector2, dmg: int, shooter: Node) -> void:
	global_position = start_pos
	damage = dmg
	_shooter = shooter
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED


func _ready() -> void:
	sprite.texture = ArtCache.get_inventory_icon("slime_ball")
	add_to_group("slime_balls")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	velocity.y += GRAVITY * delta
	var next: Vector2 = global_position + velocity * delta
	var cm = _get_cm()
	if cm != null:
		var tx: int = int(floor(next.x / TILE_SIZE))
		var ty: int = int(floor(next.y / TILE_SIZE))
		var t: int = cm.get_tile(tx, ty)
		if t != Tiles.AIR and Tiles.is_solid(t):
			_bounces += 1
			if _bounces > MAX_BOUNCES:
				_destroy()
				return
			if abs(velocity.y) >= abs(velocity.x):
				velocity.y = -velocity.y * BOUNCE_DAMP
			else:
				velocity.x = -velocity.x * BOUNCE_DAMP
			velocity *= BOUNCE_DAMP
			return
	global_position = next
	_check_enemy_hit()


func _check_enemy_hit() -> void:
	for group in ["king_slime", "slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy == _shooter or not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			# 大怪/Boss 给身子半径 (跟近战一致), 否则只认中心一点
			var radius: float = enemy.melee_hit_radius() if enemy.has_method("melee_hit_radius") else 0.0
			if global_position.distance_to((enemy as Node2D).global_position) > HIT_RADIUS_PX + radius:
				continue
			var src: Vector2 = global_position - velocity.normalized() * 32.0
			if enemy.has_meta("is_remote"):
				# 联机 client: 远程怪 host 权威, 发伤害给 host (同 arrow/fireball), 否则打了没用
				if NetworkManager != null and NetworkManager.connected():
					var rid: int = int(enemy.get_meta("remote_id", 0))
					if rid != 0:
						NetworkManager.send_entity_damage(rid, damage, 120.0, src.x, src.y)
				_destroy()
				return
			elif enemy.has_method("take_damage"):
				enemy.take_damage(damage, src, 120.0)
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
