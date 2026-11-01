# 腐化/猩红的独立飞行怪；两者使用各自原图，共用盘旋、冲刺和碰撞避障。
extends CharacterBody2D
const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Metrics = preload("res://scripts/art/world_metrics.gd")
const Nav = preload("res://scripts/entities/flying_nav.gd")
const Players = preload("res://scripts/entities/players_util.gd")
const Drop = preload("res://scenes/items/item_drop.tscn")
@export_enum("eater_of_souls", "crimera") var species := "eater_of_souls"
static var _frames := {}
var max_health := 40
var current_health := 40
var _iframe := 0.0
var _cycle := 0.0
var _dash := Vector2.ZERO
var _knockback := Vector2.ZERO
var _turn := 0.0
var _far := 0.0
var _dead := false
var _nav = Nav.new()
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
static func frames_for(kind: String) -> SpriteFrames:
	if not _frames.has(kind):
		_frames[kind] = Pack.enemy_frames("NPC_173.png" if kind == "crimera" else "NPC_6.png", Vector2i(42, 80), Vector2i(42, 80), {"fly": [0, 1]})
	return _frames[kind]
func _ready():
	max_health = maxi(1, roundi(40 * GameSettings.enemy_hp_multiplier()))
	current_health = max_health
	sprite.sprite_frames = frames_for(species)
	sprite.scale = Vector2.ONE * 0.75
	sprite.position = $CollisionShape2D.position
	sprite.play("fly")
	add_to_group("slimes")
	add_to_group("evil_flyers")
	_cycle = randf_range(0.0, 1.5)
func _physics_process(delta: float):
	if _dead: return
	_iframe = maxf(0.0, _iframe - delta)
	sprite.modulate = Color(1.7, 0.8, 0.8) if _iframe > 0.08 else Color.WHITE
	var player := Players.nearest_player(get_tree(), global_position)
	if has_meta("is_remote"):
		sprite.rotation = rotate_toward(sprite.rotation, _turn, 8.0 * delta)
		_contact(player)
		return
	if player == null: return
	var toward := Metrics.body_rect(player).get_center() - Metrics.body_rect(self).get_center()
	_far = _far + delta if toward.length_squared() > 1000000.0 else 0.0
	if _far > 12.0:
		_remove()
		return
	_cycle += delta
	if _cycle >= 2.8:
		_cycle = 0.0
		_dash = toward.normalized() * 142.0
	var desired := _dash if _cycle < 0.65 and _dash.length_squared() > 0.0 else (toward + Vector2(sin(_cycle * 3.0) * 80.0, -60.0)).normalized() * 64.0
	desired = _nav.steer(self, player.global_position, desired, delta)
	velocity = velocity.move_toward(desired, 220.0 * delta) + _knockback
	_knockback = _knockback.move_toward(Vector2.ZERO, 280.0 * delta)
	if velocity.length_squared() > 1.0:
		# 原帧头朝下，旋转以头指向前进方向，不能套恶魔眼朝右的轴。
		sprite.rotation = rotate_toward(sprite.rotation, velocity.angle() - PI / 2.0, 8.0 * delta)
	move_and_slide()
	_contact(player)
func _contact(player: Node2D):
	if player == null or not Metrics.touching(self, player): return
	var hp := player.get_node_or_null("PlayerHealth")
	if hp != null: hp.take_damage(22, global_position, 85.0)
func network_facing() -> int:
	return 1000 + posmod(roundi(rad_to_deg(sprite.rotation)), 360)
func apply_network_facing(value: int):
	_turn = deg_to_rad(float(value - 1000))
func take_damage(amount: int, source_pos := Vector2.ZERO, knockback := 0.0) -> bool:
	if _dead or amount <= 0 or _iframe > 0.0: return false
	_iframe = 0.18
	var loss := mini(current_health, maxi(1, amount - 4)) # 8 防御
	current_health -= loss
	Effects.spawn_damage_number(global_position + Vector2(0, -15), loss)
	_knockback = (global_position - source_pos).normalized() * knockback * 0.5
	SfxBank.play_creature("demon_eye", global_position, current_health == 0)
	if current_health == 0:
		if randf() < 1.0 / 3.0:
			var drop = Drop.instantiate()
			drop.item_id = "vertebra" if species == "crimera" else "rotten_chunk"
			drop.count = 1
			drop.position = position
			get_parent().add_child(drop)
		_remove()
	return true
func _remove():
	_dead = true
	if NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	queue_free()
