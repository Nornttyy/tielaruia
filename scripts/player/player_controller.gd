# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const SPEED := 140.0
const JUMP_VELOCITY := -320.0
const GRAVITY := 900.0
const COYOTE_TIME := 0.10
const LAND_VY_THRESHOLD := 200.0    # 落地时 vy 超此值才扬大灰
const WALK_PUFF_INTERVAL := 0.3     # 走路每 0.3s 一次 puff

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _player_aura: PointLight2D = $PlayerAura
@onready var _sun_aura: PointLight2D = $SunAura
@onready var _held_item: Sprite2D = $HeldItem

const HURT_DURATION := 0.4
const KNOCKBACK_VX := 90.0
const KNOCKBACK_VY := -180.0
const SHAKE_MAX_OFFSET := 4.0
const SHAKE_DECAY := 20.0

# Light2D 配置: PlayerAura 常亮小光圈, SunAura 头顶天空时大日光 (0.3s lerp)
const PLAYER_AURA_TEX_SIZE := 64
const SUN_AURA_TEX_SIZE := 400
const SUN_ENERGY_ON := 1.5
const SUN_ENERGY_OFF := 0.0
const SUN_FADE_TIME := 0.3
const TILE_SIZE := 16

var _coyote_timer: float = 0.0
var _facing_right: bool = true
var _was_on_floor: bool = true
var _previous_vy: float = 0.0
var _walk_step_timer: float = 0.0
var _hurt_timer: float = 0.0
var _shake_amount: float = 0.0


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")
	add_to_group("player")
	# 连受击信号
	var hp: Node = get_node_or_null("PlayerHealth")
	if hp != null and hp.has_signal("damaged"):
		hp.damaged.connect(_on_damaged)
	# 光源纹理: 两个尺寸 (玩家身光 + 大日光)
	_player_aura.texture = ArtCache.radial_gradient(PLAYER_AURA_TEX_SIZE)
	_sun_aura.texture = ArtCache.radial_gradient(SUN_AURA_TEX_SIZE)
	# 手持物品: 绑定 inventory, 之后 hotbar 切换会自动刷新 sprite
	var pinv: Node = get_node_or_null("PlayerInventory")
	if pinv != null and _held_item != null:
		_held_item.bind_inventory(pinv)


func _process(delta: float) -> void:
	_update_sun_aura(delta)


# SunAura 跟随 SkyLightGrid: 玩家头顶有天空 → 启用大日光; 钻进洞穴 → 关掉。0.3s lerp 避免硬切。
func _update_sun_aura(delta: float) -> void:
	var tile_x: int = int(floor(global_position.x / TILE_SIZE))
	var tile_y: int = int(floor(global_position.y / TILE_SIZE))
	var exposed: bool = SkyLightGrid.is_sky_exposed(tile_x, tile_y)
	var target: float = SUN_ENERGY_ON if exposed else SUN_ENERGY_OFF
	var t: float = clamp(delta / SUN_FADE_TIME, 0.0, 1.0)
	_sun_aura.energy = lerp(_sun_aura.energy, target, t)


# 公共接口: 朝向 (+1 右, -1 左)
func facing_dir() -> int:
	return 1 if _facing_right else -1


func _on_damaged(_amount: int, source_pos: Vector2) -> void:
	_hurt_timer = HURT_DURATION
	# 击退: 远离 source
	var dx: float = global_position.x - source_pos.x
	var kb_dir: float = signf(dx) if abs(dx) > 0.1 else 1.0
	velocity.x = kb_dir * KNOCKBACK_VX
	velocity.y = KNOCKBACK_VY


func _physics_process(delta: float) -> void:
	# 受击 lockout: 保留击退速度, 玩家暂失输入控制
	if _hurt_timer > 0.0:
		_hurt_timer = max(0.0, _hurt_timer - delta)
		if not is_on_floor():
			velocity.y += GRAVITY * delta
		else:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		move_and_slide()
		if sprite.animation != "hurt":
			sprite.play("hurt")
		_was_on_floor = is_on_floor()
		_previous_vy = velocity.y
		return

	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED

	var on_floor_now := is_on_floor()

	# 重力
	if not on_floor_now:
		velocity.y += GRAVITY * delta
		_coyote_timer = max(0.0, _coyote_timer - delta)
	else:
		_coyote_timer = COYOTE_TIME

	# 跳跃
	var did_jump := false
	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0
		did_jump = true

	# 记录跳前 vy 给落地用
	var pre_move_vy := velocity.y

	move_and_slide()

	var on_floor_after := is_on_floor()

	# 跳起瞬间扬灰
	if did_jump:
		Effects.spawn_jump_dust(global_position)

	# 落地瞬间扬灰：本帧由空中变地面 + 之前的 vy 够大
	if not _was_on_floor and on_floor_after and _previous_vy > LAND_VY_THRESHOLD:
		Effects.spawn_land_dust(global_position)

	# 走路 puff：在地 + 有移动
	if on_floor_after and abs(dir) > 0.01:
		_walk_step_timer -= delta
		if _walk_step_timer <= 0:
			var facing_sign := 1.0 if _facing_right else -1.0
			Effects.spawn_walk_puff(global_position + Vector2(-facing_sign * 4, 0))
			_walk_step_timer = WALK_PUFF_INTERVAL
	else:
		_walk_step_timer = 0.0

	_was_on_floor = on_floor_after
	_previous_vy = pre_move_vy

	# 相机震屏
	var camera: Camera2D = get_node_or_null("Camera2D")
	if camera != null:
		if _shake_amount > 0.01:
			camera.offset = Vector2(randf_range(-_shake_amount, _shake_amount), randf_range(-_shake_amount, _shake_amount))
			_shake_amount = max(0.0, _shake_amount - SHAKE_DECAY * delta)
		else:
			camera.offset = Vector2.ZERO

	# 朝向
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right
	if _held_item != null:
		_held_item.set_facing(_facing_right)

	# 动画状态机
	_update_animation(dir, on_floor_after)
	_update_workbench_prompt()


func _update_animation(dir: float, on_floor: bool) -> void:
	var next_anim: String
	if not on_floor:
		next_anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(dir) > 0.01:
		next_anim = "walk"
	else:
		next_anim = "idle"
	if sprite.animation != next_anim:
		sprite.play(next_anim)


func _update_workbench_prompt() -> void:
	var fp: CanvasLayer = get_tree().get_first_node_in_group("floating_prompt")
	if fp == null:
		return
	var terrain := get_tree().get_first_node_in_group("terrain_layer") as TileMapLayer
	if terrain == null:
		return
	var foot := global_position
	var pt := Vector2i(int(floor(foot.x / 16.0)), int(floor(foot.y / 16.0)))
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			var coord := pt + Vector2i(dx, dy)
			if terrain.get_cell_source_id(coord) == Tiles.WORKBENCH:
				fp.show_prompt(Vector2(coord.x * 16 + 8, coord.y * 16 - 4), "按 E")
				return
	# 没找到
	if fp.is_showing():
		fp.hide_prompt()


func shake(amount: float = 4.0) -> void:
	_shake_amount = clampf(amount, 0.0, SHAKE_MAX_OFFSET)
