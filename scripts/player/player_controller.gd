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

var _coyote_timer: float = 0.0
var _facing_right: bool = true
var _was_on_floor: bool = true
var _previous_vy: float = 0.0
var _walk_step_timer: float = 0.0


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")


func _physics_process(delta: float) -> void:
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

	# 朝向
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right

	# 动画状态机
	_update_animation(dir, on_floor_after)


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
