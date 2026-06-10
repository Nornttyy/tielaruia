# 玩家手枪子弹投射物. Area2D, 笔直飞 (无重力, 跟箭的抛物线相反).
# 命中怪 → 造成伤害 + 销毁. 命中实心方块 → 销毁. 1.2s 自销.
# 跟 arrow.gd 同结构, 但: 无重力 / 更快 (560 vs 260) / 寿命更短.
extends Area2D

const TILE_SIZE := 12
const SPEED := 560.0            # 比箭(260)快一倍多 → 几乎点哪打哪
const LIFETIME_SEC := 1.2       # 飞得快, 不用活太久
const BASE_DAMAGE := 9

var velocity: Vector2 = Vector2.ZERO
var damage: int = BASE_DAMAGE   # 由枪 tier 控制, 外部传入
var _life_t: float = 0.0
var _cached_chunk_manager = null
var _is_dead: bool = false
var _shooter: Node = null       # 谁射的 (玩家), 避免自伤

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


# speed=0 → 用默认 SPEED; 不同枪传不同弹速 (步枪快/霰弹慢).
func setup(start_pos: Vector2, target_pos: Vector2, dmg: int, shooter: Node, speed: float = 0.0) -> void:
	global_position = start_pos
	damage = dmg
	_shooter = shooter
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	var spd: float = speed if speed > 0.0 else SPEED
	velocity = dir * spd
	rotation = velocity.angle()   # sprite 朝飞行方向 (子弹直线, 整程不变向)


const HIT_RADIUS_PX := 8.0   # 子弹中心到怪中心 ≤ 此值算击中

func _ready() -> void:
	sprite.sprite_frames = ArtCache.bullet_proj_frames
	sprite.play("fly")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	# 注意: 没有 velocity.y += GRAVITY — 子弹笔直飞, 不下坠 (跟箭最大区别)
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
	# 手动撞怪. 联机视觉副本 (is_remote) 不撞, 伤害由发起端 host 算.
	if not has_meta("is_remote"):
		_check_enemy_hit()


func _check_enemy_hit() -> void:
	# 扫两组: slimes (敌对怪) + animals (牛羊猪 — 枪也该能打). 照 arrow.gd.
	for group in ["slimes", "animals"]:
		for enemy in get_tree().get_nodes_in_group(group):
			if enemy == _shooter or not is_instance_valid(enemy):
				continue
			if not enemy is Node2D:
				continue
			# 大怪/Boss 给身子半径 (跟近战一致), 否则子弹只认中心一点, 从大身子飞过去不算命中
			var radius: float = enemy.melee_hit_radius() if enemy.has_method("melee_hit_radius") else 0.0
			if global_position.distance_to((enemy as Node2D).global_position) > HIT_RADIUS_PX + radius:
				continue
			# 击退源位置: 沿飞行反方向退 32px, 让 (enemy - source).normalized 指向飞行方向.
			var src: Vector2 = global_position - velocity.normalized() * 32.0
			if enemy.has_meta("is_remote"):
				# 联机 client: 远程怪 host 权威, 发伤害给 host, 不本地打视觉副本
				if NetworkManager != null and NetworkManager.connected():
					var rid: int = int(enemy.get_meta("remote_id", 0))
					if rid != 0:
						NetworkManager.send_entity_damage(rid, damage, 140.0, src.x, src.y)
			elif enemy.has_method("take_damage"):
				enemy.take_damage(damage, src, 140.0)
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
