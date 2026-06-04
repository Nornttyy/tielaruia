# 骷髅王的飞骨头投射物 (敌方投射物): 飞向玩家, 碰到扣血。
# 跟玩家的 arrow/fireball 反过来 — 这个伤害玩家, 不是怪。轻微抛物线, 超时/命中即销毁。
extends Node2D

const SkeletonKingArt = preload("res://scripts/art/skeleton_king_art.gd")

const SPEED := 155.0
const GRAVITY := 120.0          # 轻微抛物线 (要躲一下)
const LIFETIME_SEC := 3.0
const HIT_RADIUS_PX := 14.0     # 骨头到玩家身子中心 ≤ 此值算击中
const BODY_OFFSET_Y := -14.0    # 玩家中心约在脚上方 14px (玩家 2.5 格高)

var velocity: Vector2 = Vector2.ZERO
var damage: int = 12
var _life_t: float = 0.0
var _dead: bool = false
var _cached_player: Node2D = null


# start: 骷髅王手部; target: 玩家身子中心 (由王算好传入)
func setup(start_pos: Vector2, target_pos: Vector2, dmg: int) -> void:
	global_position = start_pos
	damage = dmg
	var dir: Vector2 = (target_pos - start_pos).normalized() if start_pos.distance_to(target_pos) > 0.01 else Vector2.RIGHT
	velocity = dir * SPEED


func _ready() -> void:
	add_to_group("enemy_projectiles")
	var spr := Sprite2D.new()
	spr.texture = SkeletonKingArt.build_bone_proj()
	add_child(spr)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	_life_t += delta
	if _life_t >= LIFETIME_SEC:
		_destroy()
		return
	velocity.y += GRAVITY * delta
	global_position += velocity * delta
	rotation = velocity.angle()   # 骨头随飞行方向转
	var player := _find_player()
	if player == null:
		return
	var body_center: Vector2 = player.global_position + Vector2(0.0, BODY_OFFSET_Y)
	if global_position.distance_to(body_center) <= HIT_RADIUS_PX:
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and hp.has_method("take_damage"):
			hp.take_damage(damage, global_position, 90.0)
		_destroy()


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	_cached_player = players[0] if not players.is_empty() else null
	return _cached_player


func _destroy() -> void:
	if _dead:
		return
	_dead = true
	queue_free()
