# 玩家控制器：左右移动、跳跃、重力、AnimatedSprite2D 动画切换。
# 朝向通过 sprite.flip_h 处理；面向右默认。
extends CharacterBody2D

const SPEED := 140.0           # 像素/秒
const JUMP_VELOCITY := -320.0  # 负值 = 向上
const GRAVITY := 900.0         # 像素/秒²
const COYOTE_TIME := 0.10      # 离地后仍可跳的宽容窗口 (秒)

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

var _coyote_timer: float = 0.0
var _facing_right: bool = true


func _ready() -> void:
	sprite.sprite_frames = ArtCache.player_frames
	sprite.play("idle")


func _physics_process(delta: float) -> void:
	# --- 输入 ---
	var dir := Input.get_axis("move_left", "move_right")
	velocity.x = dir * SPEED

	# --- 重力 ---
	if not is_on_floor():
		velocity.y += GRAVITY * delta
		_coyote_timer = max(0.0, _coyote_timer - delta)
	else:
		_coyote_timer = COYOTE_TIME

	# --- 跳跃 ---
	if Input.is_action_just_pressed("jump") and _coyote_timer > 0.0:
		velocity.y = JUMP_VELOCITY
		_coyote_timer = 0.0

	move_and_slide()

	# --- 朝向 ---
	if dir > 0.01:
		_facing_right = true
	elif dir < -0.01:
		_facing_right = false
	sprite.flip_h = not _facing_right

	# --- 动画状态机 ---
	_update_animation(dir)


func _update_animation(dir: float) -> void:
	var on_floor := is_on_floor()
	var next_anim: String
	if not on_floor:
		next_anim = "jump" if velocity.y < 0.0 else "fall"
	elif abs(dir) > 0.01:
		next_anim = "walk"
	else:
		next_anim = "idle"
	if sprite.animation != next_anim:
		sprite.play(next_anim)
