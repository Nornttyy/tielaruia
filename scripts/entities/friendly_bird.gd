# 雀宝宝 (雀宝宝法杖召唤): 飞着帮玩家打怪. 飞向最近的敌怪撞它扣血, LIFETIME 后消失.
# 不在 slimes/animals 组 → 玩家打不到它; 自由飞行 (无地形碰撞), 穿过玩家.
extends CharacterBody2D

const SPEED := 95.0
const AGGRO_RANGE_PX := 320.0
const CONTACT_DAMAGE := 8
const HIT_INTERVAL := 0.5
const LIFETIME_SEC := 18.0

var _life_t: float = 0.0
var _hit_cd: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	add_to_group("friendly_minions")
	if sprite != null:
		sprite.sprite_frames = ArtCache.harpy_frames
		sprite.modulate = Color(1.15, 1.1, 0.55)   # 偏黄暖 = 友方雀宝宝 (跟敌方哈比鸟区分)
		var names: PackedStringArray = sprite.sprite_frames.get_animation_names()
		if names.size() > 0:
			sprite.play(names[0])
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


# 最近的敌怪 (slimes/animals, 跳过友方 + 联机影子)
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
	_hit_cd = max(0.0, _hit_cd - delta)
	var target := _find_target()
	if target != null and global_position.distance_to(target.global_position) <= AGGRO_RANGE_PX:
		var dir: Vector2 = (target.global_position - global_position).normalized()
		velocity = dir * SPEED
		if sprite != null:
			sprite.flip_h = dir.x < 0
		_try_hit(target)
	else:
		# 没目标: 飘在玩家头顶附近
		var p = get_tree().get_first_node_in_group("player")
		if p != null:
			var d: Vector2 = (p.global_position + Vector2(0, -22)) - global_position
			velocity = d.normalized() * SPEED * 0.5 if d.length() > 18.0 else Vector2.ZERO
		else:
			velocity = Vector2.ZERO
	move_and_slide()


func _try_hit(target: Node2D) -> void:
	if _hit_cd > 0.0:
		return
	var radius: float = target.melee_hit_radius() if target.has_method("melee_hit_radius") else 0.0
	if global_position.distance_to(target.global_position) > 14.0 + radius:
		return
	_hit_cd = HIT_INTERVAL
	if target.has_method("take_damage"):
		target.take_damage(CONTACT_DAMAGE, global_position, 70.0)
