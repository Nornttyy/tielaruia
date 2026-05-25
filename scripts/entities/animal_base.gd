# 中立动物基类: 闲逛 + 被击后短时间逃跑 + HP / drop.
# 子类只需在 _ready 前 (或 _init) 设 max_health / walk_speed / drop_table / sprite_frames.
extends CharacterBody2D

const ItemDropScene = preload("res://scenes/items/item_drop.tscn")

const GRAVITY := 900.0
const SWIM_GRAVITY := 200.0     # 水里重力 (慢慢沉)
const SWIM_MAX_SINK := 80.0     # 水里最大下沉速度
const WATER_SPEED_MUL := 0.5    # 水里横向速度系数
const FLEE_DURATION := 4.0
const FLEE_SPEED_MULT := 1.8
const WANDER_SWITCH_MIN := 2.0
const WANDER_SWITCH_MAX := 5.0
const HIT_FLASH_SEC := 0.1
const TILE_SIZE := 16
# Auto-step: 撞 1 格台阶时自动抬上去 (避免动物在山坡/小台阶前来回踱步).
# 抬 17 = TILE_SIZE+1: Godot test_move 有 0.08 px safe_margin, 多抬 1 px 避免误判碰撞.
const AUTO_STEP_LIFT := TILE_SIZE + 1
const AUTO_STEP_DURATION := 0.12  # tween 时长 (秒). 太短像瞬移, 太长像漂浮.

# 子类覆盖
var max_health: int = 10
var walk_speed: float = 50.0
var drop_table: Array = []   # [item_id, weight%, count_min, count_max]
var sprite_frames: SpriteFrames = null

var current_health: int = 10
var _flee_timer: float = 0.0
var _flee_from: Vector2 = Vector2.ZERO
var _wander_dir: float = 0.0
var _wander_timer: float = 0.0
var _hit_flash: float = 0.0
var _is_dying: bool = false
var _stepping: bool = false   # auto-step tween 进行中, 物理暂停

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	current_health = max_health
	if sprite_frames != null:
		sprite.sprite_frames = sprite_frames
	sprite.play("idle")
	add_to_group("animals")
	_pick_new_wander()
	# 动物完全不跟玩家物理交互 (避免动物 move_and_slide 撞玩家 → 动物 sliding 改方向 → "被顶走" 错觉).
	# 玩家也碰不到动物 (collision_layer=0 在 .tscn 已设). 这里加 exception 确保动物自身 move_and_slide 也忽略玩家.
	call_deferred("_add_player_exception")


func _add_player_exception() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player != null:
		add_collision_exception_with(player)


# 动物身体在水里吗 (腰部 tile 是 WATER)
func _is_in_water() -> bool:
	var terrain: Node = get_tree().get_first_node_in_group("terrain_layer")
	if terrain == null:
		return false
	var world: Node = terrain.get_parent()
	if world == null:
		return false
	var cm = world.get("chunk_manager")
	if cm == null:
		return false
	var tx: int = int(floor(global_position.x / 16.0))
	var ty: int = int(floor((global_position.y - 6.0) / 16.0))  # 腰部 (高度比玩家小)
	return cm.get_tile(tx, ty) == Tiles.WATER


func _physics_process(delta: float) -> void:
	if has_meta("is_remote"):
		return
	if _is_dying:
		return
	# auto-step tween 期间停物理 (let tween 接管 position, 不被重力/move_and_slide 干扰)
	if _stepping:
		return
	if _hit_flash > 0.0:
		_hit_flash = max(0.0, _hit_flash - delta)
		sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE

	# 动物不会游泳: 正常重力 (碰水继续下沉)
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# desired_dir = 本帧想去的方向
	var speed_mul: float = 1.0
	var desired_dir: float = 0.0
	if _flee_timer > 0.0:
		_flee_timer -= delta
		var dir: float = signf(global_position.x - _flee_from.x)
		if abs(dir) < 0.1:
			dir = 1.0 if randf() < 0.5 else -1.0
		desired_dir = dir
		velocity.x = dir * walk_speed * FLEE_SPEED_MULT * speed_mul
		sprite.flip_h = dir < 0
		_play_anim("walk")
	else:
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_pick_new_wander()
		desired_dir = _wander_dir
		velocity.x = _wander_dir * walk_speed * speed_mul
		if _wander_dir != 0.0:
			sprite.flip_h = _wander_dir < 0
			_play_anim("walk")
		else:
			_play_anim("idle")

	move_and_slide()

	# 撞墙: 先试 auto-step 爬 1 格台阶, 没爬上去再反向
	if is_on_wall() and is_on_floor() and abs(desired_dir) > 0.1:
		if not _try_auto_step(desired_dir):
			if _flee_timer > 0.0:
				_flee_from = Vector2(-_flee_from.x + 2 * global_position.x, _flee_from.y)
			else:
				_wander_dir = -_wander_dir


# 撞墙时: 若是 1 格台阶 (头顶空气 + 前下方有地) 则 teleport 上去, 返回 true. 否则不动返回 false.
func _try_auto_step(dir: float) -> bool:
	var step_x: float = signf(dir) * float(TILE_SIZE)
	var lift: float = float(AUTO_STEP_LIFT)
	var probe := global_transform.translated(Vector2(step_x, -lift))
	if test_move(probe, Vector2.ZERO):
		return false
	if not test_move(probe, Vector2(0, lift)):
		return false
	# 平滑 tween 移上去 (而不是瞬移), 期间 _stepping=true 阻挡物理.
	# 终点 y 用 -TILE_SIZE (不是 -lift), 落到台阶顶刚刚好 (lift 多了 1 px 防 safe_margin, 视觉用准的 16).
	var target := global_position + Vector2(step_x, -float(TILE_SIZE))
	_stepping = true
	velocity = Vector2.ZERO  # 清掉旧速度避免 tween 结束瞬间又有惯性
	var tw := create_tween()
	tw.set_trans(Tween.TRANS_QUAD)
	tw.set_ease(Tween.EASE_OUT)   # 上抬慢落快, 像跳到台阶上的弧线感
	tw.tween_property(self, "global_position", target, AUTO_STEP_DURATION)
	tw.tween_callback(_on_auto_step_done)
	return true


func _on_auto_step_done() -> void:
	_stepping = false


func _pick_new_wander() -> void:
	_wander_timer = randf_range(WANDER_SWITCH_MIN, WANDER_SWITCH_MAX)
	var r: float = randf()
	if r < 0.4:
		_wander_dir = 0.0   # 站着
	elif r < 0.7:
		_wander_dir = 1.0
	else:
		_wander_dir = -1.0


func _play_anim(anim_name: String) -> void:
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(anim_name):
		if sprite.animation != anim_name:
			sprite.play(anim_name)


# 受击: 掉血 + 启动逃跑. 返回是否造成有效伤害.
func take_damage(amount: int, source_pos: Vector2 = Vector2.ZERO) -> bool:
	if _is_dying or amount <= 0:
		return false
	current_health = max(0, current_health - amount)
	_hit_flash = HIT_FLASH_SEC
	sprite.modulate = Color(1.6, 1.0, 1.0)
	_flee_timer = FLEE_DURATION
	if source_pos != Vector2.ZERO:
		_flee_from = source_pos
	# 击退 + 弹动
	if source_pos != Vector2.ZERO:
		var dx: float = global_position.x - source_pos.x
		var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
		velocity.x = kb_dir * 120.0
		velocity.y = -100.0
	var tween := create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.15, 0.85), 0.06)
	tween.tween_property(sprite, "scale", Vector2.ONE, 0.12)
	if current_health == 0:
		_die()
	return true


func _die() -> void:
	_is_dying = true
	if NetworkManager != null and NetworkManager.connected() and NetworkManager.is_host:
		NetworkManager.send_entity_die(NetworkManager.entity_id_for(self))
	for entry in drop_table:
		var item_id: String = entry[0]
		var weight: int = entry[1]
		if randi() % 100 < weight:
			var n: int = randi_range(entry[2], entry[3])
			for i in n:
				_spawn_drop(item_id)
	queue_free()


func _spawn_drop(item_id: String) -> void:
	var drop = ItemDropScene.instantiate()
	drop.item_id = item_id
	drop.count = 1
	drop.global_position = global_position + Vector2(randf_range(-3.0, 3.0), -4.0)
	var entities: Node = get_tree().get_first_node_in_group("entities_root")
	if entities == null:
		entities = get_parent()
	entities.add_child(drop)
