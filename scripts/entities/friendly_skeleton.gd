# 友方小骷髅 (骷髅法杖召唤): 帮玩家打怪。走向最近的敌怪, 撞它扣血, LIFETIME 后消失。
# 不在 "slimes"/"animals" 组 → 玩家近战打不到它; layer 0 + 玩家碰撞豁免 → 穿过玩家。
# 蓝染跟敌方骷髅一眼区分。
extends CharacterBody2D

const GRAVITY := 675.0
const WALK_SPEED := 58.0          # 比敌骷髅快 (积极找架打)
const AGGRO_RANGE_PX := 280.0
const CONTACT_DAMAGE := 12
const HIT_INTERVAL := 0.4         # 同一下别每帧狂扣 (自管节流)
const LIFETIME_SEC := 15.0        # 临时帮手, 15 秒后消失
const TILE_SIZE := 12
const JUMP_VY := -220.0

var _life_t: float = 0.0
var _hit_cd: float = 0.0
var _jump_cd: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("friendly_minions")
	if sprite != null:
		sprite.sprite_frames = ArtCache.skeleton_frames
		sprite.modulate = Color(0.55, 0.8, 1.3)   # 偏蓝 = 友方 (敌骷髅是白/红)
		sprite.play("walk")
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


# 找最近的敌怪 (slimes/animals 组里的, 跳过友方自己 + 联机影子)
func _find_target() -> Node2D:
	var best: Node2D = null
	var best_d: float = 1.0e20
	for grp in ["slimes", "animals"]:
		for e in get_tree().get_nodes_in_group(grp):
			if e == self or not (e is Node2D) or not is_instance_valid(e):
				continue
			if e.is_in_group("friendly_minions"):
				continue
			var d: float = global_position.distance_to((e as Node2D).global_position)
			if d < best_d:
				best_d = d
				best = e
	return best


func _physics_process(delta: float) -> void:
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		queue_free()
		return
	if _hit_cd > 0.0:
		_hit_cd -= delta
	if _jump_cd > 0.0:
		_jump_cd -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var target := _find_target()
	if target != null and global_position.distance_to(target.global_position) <= AGGRO_RANGE_PX:
		var dir: float = signf(target.global_position.x - global_position.x)
		velocity.x = dir * WALK_SPEED
		if sprite != null:
			sprite.flip_h = dir < 0
		_try_hit(target)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 120.0 * delta)
	move_and_slide()
	# 撞墙 + 落地 → 跳过坎追怪
	if is_on_wall() and is_on_floor() and _jump_cd <= 0.0:
		velocity.y = JUMP_VY
		_jump_cd = 0.7


# 贴到敌怪 → 扣它血 (节流: 每 HIT_INTERVAL 一下)
func _try_hit(target: Node2D) -> void:
	if _hit_cd > 0.0:
		return
	var radius: float = target.melee_hit_radius() if target.has_method("melee_hit_radius") else 0.0
	if global_position.distance_to(target.global_position) > 16.0 + radius:
		return
	if target.has_method("take_damage"):
		target.take_damage(CONTACT_DAMAGE, global_position, 80.0)
		_hit_cd = HIT_INTERVAL
