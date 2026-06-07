# 骷髅王 Boss (Phase 1: 本体). 骷髅骑士, 体型 ≈ 玩家身高再高一点 (放大 2x 的骷髅 + 王冠)。
# 走向玩家 + 接触伤害; 4 招 (扔骨头/冲刺/横扫/召唤小骷髅) 在 T5 加。
# HP 1200。死: 掉 bone ×15-25 + bone_sword。玩家死/远离 → despawn (不掉)。
# 照搬 king_slime.gd 模式: group boss + take_damage + boss_display_name + 不与玩家物理碰撞。
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")
const SkeletonKingArt = preload("res://scripts/art/skeleton_king_art.gd")
const BoneProj = preload("res://scripts/entities/bone_projectile.gd")
const SkeletonScene = preload("res://scenes/entities/skeleton.tscn")

const BASE_MAX_HEALTH := 1200
const CONTACT_DAMAGE := 15      # 摸到身子
const GRAVITY := 337.5
const TILE_SIZE := ChunkConstants.TILE_SIZE
const WALK_SPEED := 21.0        # 骑士慢走 (比小骷髅 35 稍快, 有压迫感)
const AGGRO_RANGE_PX := 300.0
const HIT_FLASH_SEC := 0.1
const ENEMY_IFRAME_SEC := 0.12
const JUMP_VY := -120.0
const DESPAWN_DISTANCE_PX := 550.0
const DESPAWN_AFTER_SEC := 5.0
const BONE_DROP_MIN := 15
const BONE_DROP_MAX := 25
const ARMOR_DROP_CHANCE := 0.40   # 每件骷髅盔甲掉落几率 (多打几次凑齐一套)
const STAFF_DROP_CHANCE := 0.25   # 骷髅法杖掉落几率 (稀有奖励)
const BODY_SCALE := 0.65         # 专属骑士帧 24×30 → ~35px ≈ 玩家(30px)高一点

# === 4 招 (按距离选: 远扔骨头 / 中冲刺 / 近横扫; 血<50% 周期召唤小骷髅) ===
const ATTACK_COOLDOWN_FULL := 2.2    # 满血出招间隔
const ATTACK_COOLDOWN_LOW := 1.2     # 残血更频 (压迫感)
const RANGE_CLOSE_PX := 3.0 * TILE_SIZE   # < 这个 → 横扫
const RANGE_FAR_PX := 7.0 * TILE_SIZE     # > 这个 → 扔骨头; 中间 → 冲刺
const THROW_DAMAGE := 12
const THROW_WINDUP := 0.35           # 前摇 (举手, 给玩家反应时间)
const THROW_COUNT := 2               # 一次扔几根
const DASH_DAMAGE := 18
const DASH_WINDUP := 0.35            # 前摇 (蹲一下蓄力)
const DASH_DURATION := 0.35
const DASH_SPEED := 120.0
const SWEEP_DAMAGE := 22
const SWEEP_WINDUP := 0.25           # 举刀前摇
const SWEEP_ACTIVE := 0.22           # 打击窗口
const SWEEP_RANGE_PX := 13.0
const MINION_INTERVAL := 5.0
const MINION_PER_WAVE := 2
const MINION_CAP := 6

var max_health: int = BASE_MAX_HEALTH
var current_health: int = BASE_MAX_HEALTH
var _cached_player: Node2D = null
var _hit_flash: float = 0.0
var _iframe_t: float = 0.0
var _is_dying: bool = false
var _far_timer: float = 0.0
var _jump_cooldown: float = 0.0
# 攻击状态机
var _attack_timer: float = ATTACK_COOLDOWN_FULL
var _state: String = ""        # "" 平时 / "throw" / "dash" / "sweep"
var _state_t: float = 0.0
var _state_done: bool = false  # 这次攻击是否已结算伤害 (防一招多次)
var _dash_dir: float = 1.0
var _minion_timer: float = MINION_INTERVAL

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _crown: Sprite2D = $Crown


func _ready() -> void:
	# 难度缩放最前 (测试 .new() 时无 sprite 子节点, max_health 仍要对)
	max_health = max(1, int(round(BASE_MAX_HEALTH * GameSettings.enemy_hp_multiplier())))
	current_health = max_health
	if sprite != null:
		sprite.sprite_frames = SkeletonKingArt.build_frames()   # 专属骷髅骑士帧 (头骨+斗篷+骨刀)
		sprite.scale = Vector2(BODY_SCALE, BODY_SCALE)
		sprite.modulate = Color.WHITE                           # 专属帧已上好色, 不再染
		sprite.play("idle")
	if _crown != null:
		_crown.texture = SkeletonKingArt.build_crown()    # 头顶破铁王冠 (独立, 不被身体染红)
	add_to_group("skeleton_king")
	add_to_group("skeletons")
	add_to_group("boss")
	# 必须进 "slimes" 组: 玩家近战命中检测只扫 ["slimes","animals"], 不加这个剑打不到王!
	add_to_group("slimes")
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
	return 7.0


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
			sprite.modulate = Color.WHITE
	_iframe_t = max(0.0, _iframe_t - delta)
	if _jump_cooldown > 0.0:
		_jump_cooldown -= delta
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	var player := _find_player()
	var aggro: bool = player != null and global_position.distance_to(player.global_position) <= AGGRO_RANGE_PX
	# 血 < 50% 周期召唤小骷髅 (独立于出招)
	if current_health < max_health / 2 and player != null:
		_minion_timer -= delta
		if _minion_timer <= 0.0:
			_minion_timer = MINION_INTERVAL
			_spawn_minions()
	# 攻击状态机优先; 平时走向玩家攒招
	if _state != "":
		_run_attack(delta, player)
	elif aggro:
		var dir: float = signf(player.global_position.x - global_position.x)
		velocity.x = dir * WALK_SPEED
		_face(dir)
		_play("walk")
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_pick_attack(player)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 75.0 * delta)
		_play("idle")
	move_and_slide()
	# 撞墙落地 → 跳 (爬台阶过坎); 攻击中不跳; 玩家在下方时不跳 (防砸头顶躲)
	if _state == "" and is_on_wall() and is_on_floor() and _jump_cooldown <= 0.0:
		if player == null or player.global_position.y - global_position.y <= float(TILE_SIZE) * 1.5:
			velocity.y = JUMP_VY
			_jump_cooldown = 0.8
	_check_player_contact()


# === 4 招攻击 ===

func _attack_cooldown_now() -> float:
	var ratio: float = clamp(float(current_health) / float(max_health), 0.0, 1.0)
	return lerp(ATTACK_COOLDOWN_LOW, ATTACK_COOLDOWN_FULL, ratio)


# 按距离选招进入对应状态: 远扔骨头 / 中冲刺 / 近横扫
func _pick_attack(player: Node2D) -> void:
	if player == null:
		return
	var dist: float = global_position.distance_to(player.global_position)
	var dir: float = signf(player.global_position.x - global_position.x)
	_face(dir)
	if dist > RANGE_FAR_PX:
		_state = "throw"
	elif dist < RANGE_CLOSE_PX:
		_state = "sweep"
	else:
		_state = "dash"
		_dash_dir = dir if dir != 0.0 else 1.0
	_state_t = 0.0
	_state_done = false
	_play("attack")


func _run_attack(delta: float, player: Node2D) -> void:
	_state_t += delta
	match _state:
		"throw":
			velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)   # 站定扔
			if not _state_done and _state_t >= THROW_WINDUP:
				_state_done = true
				_throw_bones(player)
			if _state_t >= THROW_WINDUP + 0.25:
				_end_attack()
		"sweep":
			velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)
			if not _state_done and _state_t >= SWEEP_WINDUP and _state_t < SWEEP_WINDUP + SWEEP_ACTIVE:
				_do_sweep_hit(player)   # 打击窗口里结算一次
				_state_done = true
			if _state_t >= SWEEP_WINDUP + SWEEP_ACTIVE:
				_end_attack()
		"dash":
			if _state_t < DASH_WINDUP:
				velocity.x = move_toward(velocity.x, 0.0, 160.0 * delta)   # 前摇蓄力 (telegraph)
			elif _state_t < DASH_WINDUP + DASH_DURATION:
				velocity.x = _dash_dir * DASH_SPEED   # 冲!
			else:
				_end_attack()


func _end_attack() -> void:
	_state = ""
	_state_t = 0.0
	_state_done = false
	_attack_timer = _attack_cooldown_now()


# 扔 THROW_COUNT 根飞骨头, 朝玩家身子中心 (略带散布)
func _throw_bones(player: Node2D) -> void:
	if player == null:
		return
	var hand: Vector2 = global_position + Vector2(0.0, -22.0)
	var target: Vector2 = player.global_position + Vector2(0.0, -14.0)
	var entities: Node = _entities_root()
	for i in THROW_COUNT:
		var b = BoneProj.new()
		entities.add_child(b)
		var spread: float = deg_to_rad((float(i) - float(THROW_COUNT - 1) / 2.0) * 12.0)
		var aimed: Vector2 = hand + (target - hand).rotated(spread)
		b.setup(hand, aimed, THROW_DAMAGE)
		# 联机 host: 广播让 client 重建这根骨头 (client 那根打 client 自己的玩家)
		if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
			NetworkManager.send_projectile("bone", hand.x, hand.y, aimed.x, aimed.y)


# 横扫: 玩家在面朝方向 + 范围内 + 高度合适 → 扣血
func _do_sweep_hit(player: Node2D) -> void:
	if player == null:
		return
	var dx: float = player.global_position.x - global_position.x
	var dy: float = player.global_position.y - global_position.y
	var facing: float = -1.0 if (sprite != null and sprite.flip_h) else 1.0
	# 玩家在背后且不贴脸 → 扫不到
	if signf(dx) != facing and absf(dx) > 5.0:
		return
	if absf(dx) > SWEEP_RANGE_PX or dy < -36.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp != null and hp.has_method("take_damage"):
		hp.take_damage(SWEEP_DAMAGE, global_position, 160.0)


# 召唤小骷髅 (复用普通骷髅). 只数普通骷髅小兵 (排除自己这个 boss)。
func _spawn_minions() -> void:
	var existing: int = 0
	for s in get_tree().get_nodes_in_group("skeletons"):
		if not s.is_in_group("boss"):
			existing += 1
	var entities: Node = _entities_root()
	for i in MINION_PER_WAVE:
		if existing >= MINION_CAP:
			break
		var m = SkeletonScene.instantiate()
		entities.add_child(m)
		m.global_position = global_position + Vector2(randf_range(-24.0, 24.0), -8.0)
		existing += 1


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
	var dy: float = player.global_position.y - global_position.y
	if dx > 14.0 or dy < -34.0 or dy > 22.0:
		return
	var hp: Node = player.get_node_or_null("PlayerHealth")
	if hp == null:
		return
	# 冲刺中撞到玩家 = 冲刺伤害 (18), 平时摸到 = 接触伤害 (15)
	var is_dashing: bool = _state == "dash" and _state_t >= DASH_WINDUP
	var dmg: int = DASH_DAMAGE if is_dashing else CONTACT_DAMAGE
	hp.take_damage(dmg, global_position, 160.0 if is_dashing else 140.0)


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
			# 联机: 通知 client 删它那只远程王 (照 _die; 漏发 = 客机看到王凭空卡住 + 血条空挂)
			if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
				NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
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
	# 必掉: 一大堆骨头 + 骨剑 (阔剑)
	var n := BONE_DROP_MIN + (randi() % (BONE_DROP_MAX - BONE_DROP_MIN + 1))
	for i in n:
		_spawn_drop("bone")
	_spawn_drop("bone_sword")
	# 几率掉骷髅盔甲 (各 40%, 多打几次凑齐一套)
	if randf() < ARMOR_DROP_CHANCE:
		_spawn_drop("skeleton_helmet")
	if randf() < ARMOR_DROP_CHANCE:
		_spawn_drop("skeleton_chest")
	if randf() < ARMOR_DROP_CHANCE:
		_spawn_drop("skeleton_pants")
	# 稀有: 25% 掉骷髅法杖 (召唤友方骷髅帮打)
	if randf() < STAFF_DROP_CHANCE:
		_spawn_drop("skull_staff")
	queue_free()
