# 骷髅王 Boss (Phase 1: 本体). 骷髅骑士, 体型 ≈ 玩家身高再高一点 (放大 2x 的骷髅 + 王冠)。
# 走向玩家 + 接触伤害; 4 招 (扔骨头/冲刺/横扫/召唤小骷髅) 在 T5 加。
# HP 1200。死: 掉 bone ×15-25 + bone_sword。玩家死/远离 → despawn (不掉)。
# 照搬 king_slime.gd 模式: group boss + take_damage + boss_display_name + 不与玩家物理碰撞。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const SkeletonKingArt = preload("res://scripts/art/skeleton_king_art.gd")

const BASE_MAX_HEALTH := 1200
const CONTACT_DAMAGE := 15      # 摸到身子
const GRAVITY := 675.0
const TILE_SIZE := 12
const WALK_SPEED := 42.0        # 骑士慢走 (比小骷髅 35 稍快, 有压迫感)
const AGGRO_RANGE_PX := 600.0
const HIT_FLASH_SEC := 0.1
const ENEMY_IFRAME_SEC := 0.12
const JUMP_VY := -240.0
const DESPAWN_DISTANCE_PX := 1100.0
const DESPAWN_AFTER_SEC := 5.0
const BONE_DROP_MIN := 15
const BONE_DROP_MAX := 25
const BODY_SCALE := 2.0         # 普通骷髅 16px → 32px ≈ 玩家(30px)高一点

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _far_timer: float = 0.0
var _jump_cooldown: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _crown: Sprite2D = $Crown


func _ready() -> void:
	# 难度缩放最前 (测试 .new() 时无 sprite 子节点, max_health 仍要对)
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	if sprite != null:
		sprite.sprite_frames = ArtCache.skeleton_frames   # 复用普通骷髅帧 (它本来就握剑)
		sprite.scale = Vector2(BODY_SCALE, BODY_SCALE)
		sprite.modulate = Color(1.15, 0.82, 0.82)         # 偏红, 跟普通白骷髅一眼区分
		sprite.play("idle")
	if _crown != null:
		_crown.texture = SkeletonKingArt.build_crown()    # 头顶破铁王冠 (独立, 不被身体染红)
	add_to_group("skeleton_king")
	add_to_group("skeletons")
	add_to_group("boss")
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


# 屏幕顶部 Boss 血条用名字
func boss_display_name() -> String:
	return "骷髅王"


# 近战命中半径: 王身子高 (~30px), 让剑碰到身子就算命中 (不只认脚底中心一点)。
func melee_hit_radius() -> float:
	return 14.0


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	if players.is_empty():
		_cached_player = null
		return null
	_cached_player = players[0]
	return _cached_player


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		if not _is_dying:
			_check_player_contact()   # 远程王仍能打伤本地(client)玩家
		return
	if _is_dying:
		return
	_check_despawn(delta)
	if _is_dying:
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		if _hit_flash <= 0.0 and sprite != null:
			sprite.modulate = Color(1.15, 0.82, 0.82)
	_iframe_t = max(0.0, _iframe_t - delta)
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := _find_player()
	if player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * WALK_SPEED
		if sprite != null:
			sprite.flip_h = dir < 0
			if sprite.animation != "walk":
				sprite.play("walk")
	else:
		velocity.x = move_toward(velocity.x, 0.0, 150.0 * delta)
		if sprite != null and sprite.animation != "idle":
			sprite.play("idle")
	move_and_slide()
	# 撞墙落地 → 跳 (爬台阶过坎); 玩家在下方时不跳 (防砸头顶躲)
	if is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		if player == null or player.global_position.y - global_position.y <= float(TILE_SIZE) * 1.5:
			velocity.y = JUMP_VY
			_jump_cooldown = 0.8
	_check_player_contact()


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = player.global_position.y - global_position.y
	if dx > 14.0 or dy < -34.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	hp.take_damage(CONTACT_DAMAGE, global_position, 140.0)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0 or _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	if sprite != null:
		sprite.modulate = Color(1.8, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -20), actual_loss)
	# Boss 抗击退 (体重): 只受很小位移
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var d: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity += d * knockback * 0.08
	if current_health == 0:
		_die()
	return true


# 远离消失: 玩家不存在 (死/离场) 或太远 → 累计计时, 超时直接消失 (不掉落)
func _check_despawn(delta: float) -> void:
	var player := _find_player()
	var far: bool = player == null or global_position.distance_to(player.global_position) > DESPAWN_DISTANCE_PX
	if far:
		_far_timer += delta
		if _far_timer >= DESPAWN_AFTER_SEC:
			_is_dying = true
			queue_free()
	else:
		_far_timer = 0.0


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-10.0, 10.0), -10.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 必掉: 一大堆骨头 + 骨剑 (阔剑). 几率盔甲/法杖在 Phase 2/3 加。
	var n := BONE_DROP_MIN + (randi() % (BONE_DROP_MAX - BONE_DROP_MIN + 1))
	for i in n:
		_spawn_drop("bone")
	_spawn_drop("bone_sword")
	queue_free()
