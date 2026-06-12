# 地狱恶魔领主 (Demon Lord) — 第 3 个 Boss, 飞行型。见 spec 2026-06-12。
# 悬浮在玩家上方盘旋, 三招: 火球弹幕 / 俯冲 / 召唤小兵; 残血(<40%)狂暴 (出招更快 + 火球更多)。
# 飞行用位置积分 (不走物理碰撞, 穿地形), 接触/招式伤害靠坐标判定。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const DemonLordArt = preload("res://scripts/art/demon_lord_art.gd")
const FireballScene = preload("res://scenes/entities/fireball.tscn")
const ImpScene = preload("res://scenes/entities/imp.tscn")
const HellWaspScene = preload("res://scenes/entities/hell_wasp.tscn")

const BASE_MAX_HEALTH := 1800
const CONTACT_DAMAGE := 18
const TILE_SIZE := 12
const BODY_SCALE := 1.35
const FLY_SPEED := 78.0           # 盘旋追击速度
const HOVER_HEIGHT := 64.0        # 悬停在玩家上方多高
const HOVER_SWAY := 42.0          # 左右摆幅 (别一直叠在玩家正上方)
const AGGRO_RANGE_PX := 720.0
const HIT_FLASH_SEC := 0.1
const ENEMY_IFRAME_SEC := 0.12
const DESPAWN_DISTANCE_PX := 1200.0
const DESPAWN_AFTER_SEC := 6.0
const ENRAGE_HP_FRAC := 0.4       # 血低于此 → 狂暴

# 出招
const ATTACK_COOLDOWN := 2.4
const RANGE_FAR_PX := 6.0 * TILE_SIZE
# 火球弹幕
const FB_WINDUP := 0.45           # 前摇 (张嘴, 给反应时间)
const FB_DAMAGE := 12
const FB_COUNT := 3               # 正常 3 颗扇形; 狂暴 5 颗
const FB_COUNT_ENRAGED := 5
const FB_SPREAD_DEG := 16.0
# 俯冲
const SWOOP_WINDUP := 0.45
const SWOOP_SPEED := 300.0
const SWOOP_DURATION := 0.45
const SWOOP_DAMAGE := 20
# 召唤
const MINION_INTERVAL := 6.0
const MINION_CAP := 5

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _is_dying: bool = false
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _far_timer: float = 0.0
var _bob_t: float = 0.0
var _attack_timer: float = ATTACK_COOLDOWN
var _minion_timer: float = MINION_INTERVAL
var _minions: Array = []
var _cached_player: Node2D = null

# 攻击状态机
var _state: String = ""
var _state_t: float = 0.0
var _state_done: bool = false
var _swoop_vel: Vector2 = Vector2.ZERO


func _ready() -> void:
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	if sprite != null:
		sprite.sprite_frames = DemonLordArt.build_frames()
		sprite.scale = Vector2(BODY_SCALE, BODY_SCALE)
		sprite.play("idle")
	add_to_group("demon_lord")
	add_to_group("boss")
	# 必须进 "slimes" 组: 玩家近战命中只扫 ["slimes","animals"], 不加这个剑/枪打不中王!
	add_to_group("slimes")
	collision_layer = 0   # 不跟玩家物理碰撞 (穿过, 伤害靠坐标判)
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


func boss_display_name() -> String:
	return "地狱恶魔领主"


# 大体型 → 近战命中半径放大 (否则剑只认脚底中心一点打不中, 见 reference_melee_hit_radius)
func melee_hit_radius() -> float:
	return 16.0


func _is_enraged() -> bool:
	return float(current_health) < float(max_health) * ENRAGE_HP_FRAC


func _find_player() -> Node2D:
	if _cached_player != null and is_instance_valid(_cached_player):
		return _cached_player
	var players := get_tree().get_nodes_in_group("player")
	_cached_player = players[0] if not players.is_empty() else null
	return _cached_player


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		if not _is_dying:
			_check_player_contact()
		return
	if _is_dying:
		return
	_check_despawn(delta)
	if _is_dying:
		return
	_bob_t += delta
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		if _hit_flash <= 0.0 and sprite != null:
			sprite.modulate = Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	var player := _find_player()
	var aggro: bool = player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX
	# 召唤小兵 (盯上玩家后周期召)
	if aggro:
		_minion_timer -= delta
		if _minion_timer <= 0.0:
			_minion_timer = MINION_INTERVAL * (0.6 if _is_enraged() else 1.0)
			_spawn_minions()
	# 攻击状态机优先; 平时盘旋攒招
	if _state != "":
		_run_attack(delta, player)
	elif aggro:
		_fly_hover(delta, player)
		_play("idle")
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_pick_attack(player)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, 120.0 * delta)
		_play("idle")
	global_position += velocity * delta   # 位置积分 (飞行, 穿地形)
	_check_player_contact()


# 盘旋: 飞向"玩家上方 + 左右摆动"的悬停点
func _fly_hover(delta: float, player: Node2D) -> void:
	if player == null:
		return
	var sway: float = sin(_bob_t * 1.3) * HOVER_SWAY
	var desired: Vector2 = player.global_position + Vector2(sway, -HOVER_HEIGHT)
	var to: Vector2 = desired - global_position
	if to.length() > 4.0:
		velocity = to.normalized() * FLY_SPEED
	else:
		velocity = Vector2.ZERO
	_face(signf(player.global_position.x - global_position.x))


func _attack_cooldown_now() -> float:
	return ATTACK_COOLDOWN * (0.5 if _is_enraged() else 1.0)


# 远 → 火球弹幕; 近/中 → 俯冲
func _pick_attack(player: Node2D) -> void:
	if player == null:
		return
	_face(signf(player.global_position.x - global_position.x))
	var dist: float = global_position.distance_to(player.global_position)
	if dist > RANGE_FAR_PX:
		_state = "fireball"
	else:
		_state = "swoop"
		_swoop_vel = (player.global_position - global_position).normalized() * SWOOP_SPEED
	_state_t = 0.0
	_state_done = false
	_play("attack")


func _run_attack(delta: float, player: Node2D) -> void:
	_state_t += delta
	match _state:
		"fireball":
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)   # 站定喷
			if not _state_done and _state_t >= FB_WINDUP:
				_state_done = true
				_spit_fireballs(player)
			if _state_t >= FB_WINDUP + 0.25:
				_end_attack()
		"swoop":
			if _state_t < SWOOP_WINDUP:
				velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)   # 蓄力 telegraph
			elif _state_t < SWOOP_WINDUP + SWOOP_DURATION:
				velocity = _swoop_vel   # 俯冲!
			else:
				_end_attack()


func _end_attack() -> void:
	_state = ""
	_state_t = 0.0
	_state_done = false
	_attack_timer = _attack_cooldown_now()


# 朝玩家喷一串火球 (扇形, 狂暴时更多)
func _spit_fireballs(player: Node2D) -> void:
	if player == null:
		return
	var mouth: Vector2 = global_position + Vector2(0.0, 4.0)
	var target: Vector2 = player.global_position + Vector2(0.0, -8.0)
	var count: int = FB_COUNT_ENRAGED if _is_enraged() else FB_COUNT
	var entities: Node = _entities_root()
	for i in count:
		var fb = FireballScene.instantiate()
		entities.add_child(fb)
		var spread: float = deg_to_rad((float(i) - float(count - 1) / 2.0) * FB_SPREAD_DEG)
		var aimed: Vector2 = mouth + (target - mouth).rotated(spread)
		fb.setup(mouth, aimed, FB_DAMAGE)   # player_cast 默认 false → 打玩家
		if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
			NetworkManager.send_projectile("fireball", mouth.x, mouth.y, aimed.x, aimed.y)


# 召唤 1 小恶魔 + 1 地狱黄蜂 (场上小兵 cap MINION_CAP)
func _spawn_minions() -> void:
	_minions = _minions.filter(func(m): return m != null and is_instance_valid(m))
	if _minions.size() >= MINION_CAP:
		return
	var entities: Node = _entities_root()
	for scene in [ImpScene, HellWaspScene]:
		if _minions.size() >= MINION_CAP:
			break
		var m = scene.instantiate()
		entities.add_child(m)
		m.global_position = global_position + Vector2(randf_range(-20.0, 20.0), 10.0)
		_minions.append(m)


func _entities_root() -> Node:
	var e: Node = get_tree().get_first_node_in_group("entities_root")
	return e if e != null else get_parent()


func _face(dir: float) -> void:
	if sprite != null and dir != 0.0:
		sprite.flip_h = dir < 0


func _play(anim: String) -> void:
	if sprite != null and sprite.animation != anim:
		sprite.play(anim)


func _check_player_contact() -> void:
	var player := _find_player()
	if player == null:
		return
	var dx: float = abs(player.global_position.x - global_position.x)
	var dy: float = abs(player.global_position.y - global_position.y)
	if dx > 16.0 or dy > 18.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	var is_swooping: bool = _state == "swoop" and _state_t >= SWOOP_WINDUP
	var dmg: int = SWOOP_DAMAGE if is_swooping else CONTACT_DAMAGE
	hp.take_damage(dmg, global_position, 180.0 if is_swooping else 150.0)


func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO, knockback: float = 0.0) -> bool:
	if _is_dying or amount <= 0 or _iframe_t > 0.0:
		return false
	_iframe_t = ENEMY_IFRAME_SEC
	var actual_loss: int = min(amount, current_health)
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	if sprite != null:
		sprite.modulate = Color(1.8, 1.0, 1.0)
	Effects.spawn_damage_number(global_position + Vector2(0, -22), actual_loss)
	# Boss 抗击退: 只受很小位移
	if knockback > 0.0 and source_pos != Vector2.ZERO:
		var to_self: Vector2 = global_position - source_pos
		var d: Vector2 = Vector2.UP if to_self.length() < 0.1 else to_self.normalized()
		velocity += d * knockback * 0.05
	if current_health == 0:
		_die()
	return true


func _check_despawn(delta: float) -> void:
	var player := _find_player()
	var far: bool = player == null or global_position.distance_to(player.global_position) > DESPAWN_DISTANCE_PX
	if far:
		_far_timer += delta
		if _far_timer >= DESPAWN_AFTER_SEC:
			_is_dying = true
			if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
				NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
			queue_free()
	else:
		_far_timer = 0.0


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-12.0, 12.0), -6.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)


func _die() -> void:
	_is_dying = true
	if typeof(Achievements) != TYPE_NIL:
		Achievements.fire("boss_demon_lord")
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	# 保底: 3~6 地狱水晶
	var n := 3 + (randi() % 4)
	for i in n:
		_spawn_drop("hell_crystal")
	# 签名神装 (各自掷骰)
	if randf() < 0.35:
		_spawn_drop("demon_trident")
	if randf() < 0.30:
		_spawn_drop("inferno_staff")
	if randf() < 0.25:
		_spawn_drop("demon_wings")
	# 恶魔盔甲 (各 40%, 多打几次凑齐)
	if randf() < 0.40:
		_spawn_drop("demon_helmet")
	if randf() < 0.40:
		_spawn_drop("demon_chest")
	if randf() < 0.40:
		_spawn_drop("demon_pants")
	queue_free()
