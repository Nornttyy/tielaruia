# 无害小动物；每一种使用自己的原始切帧，不借用家畜或敌怪外观。
extends "res://scripts/entities/animal_base.gd"

const Pack = preload("res://scripts/art/terraria_sprite_pack.gd")
const Metrics = preload("res://scripts/art/world_metrics.gd")
@export_enum("bunny", "penguin", "frog") var species: String = "bunny"
@export_range(0, 1) var variant: int = 0
static var _frames: Dictionary = {}
var _hop_wait := 0.0

static func frames_for(kind: String, color_variant := 0) -> SpriteFrames:
	var key := "%s:%d" % [kind, color_variant]
	if _frames.has(key): return _frames[key]
	var frames: SpriteFrames
	match kind:
		"penguin":
			frames = Pack.enemy_frames("NPC_%d.png" % (148 + color_variant), Vector2i(28, 42), Vector2i(28, 42), {"idle": [0], "walk": range(6)})
		"frog":
			frames = Pack.enemy_frames("NPC_361.png", Vector2i(26, 22), Vector2i(26, 22), {"idle": [0], "walk": [6, 7, 8], "hop": [6, 7, 8], "swim": [9, 10, 11, 12]})
		_:
			frames = Pack.enemy_frames("NPC_46.png", Vector2i(48, 40), Vector2i(48, 40), {"idle": [0], "walk": range(1, 7)})
	frames.set_meta("source_species", kind)
	_frames[key] = frames
	return frames

func _ready() -> void:
	max_health = 5
	walk_speed = 22.5 if species == "penguin" else 30.0
	drop_table = []
	sprite_frames = frames_for(species, variant)
	sprite.centered = true
	sprite.offset = Vector2.ZERO
	sprite.scale = Vector2.ONE * Metrics.PIXEL_SCALE
	super._ready()
	Metrics.align_feet(sprite, Metrics.PIXEL_SCALE)
	add_to_group("critters")
	_hop_wait = randf_range(0.3, 1.2)

func _physics_process(delta: float) -> void:
	if species != "frog":
		super._physics_process(delta)
		return
	if has_meta("is_remote") or _is_dying: return
	_iframe_t = maxf(0.0, _iframe_t - delta)
	_hit_flash = maxf(0.0, _hit_flash - delta)
	sprite.modulate = Color(1.6, 1.0, 1.0) if _hit_flash > 0.0 else Color.WHITE
	_wander_timer -= delta
	if _wander_timer <= 0.0: _pick_new_wander()
	if _flee_timer > 0.0:
		_flee_timer -= delta
		_wander_dir = -1.0 if _flee_from.x > global_position.x else 1.0
	var submerged := _is_in_water()
	if submerged:
		# 朝水面上浮，离开水面立即恢复重力。
		velocity.y = move_toward(velocity.y, -24.0, 160.0 * delta)
		velocity.x = _wander_dir * 24.0
		_play_anim("swim")
	elif is_on_floor():
		_hop_wait -= delta
		velocity.x = 0.0
		_play_anim("idle")
		if _hop_wait <= 0.0 and not is_zero_approx(_wander_dir):
			velocity = Vector2(_wander_dir * 48.0, -150.0)
			_hop_wait = randf_range(0.7, 1.5)
			_play_anim("hop")
	else:
		velocity.y += GRAVITY * delta
	if absf(velocity.x) > 0.1: sprite.flip_h = velocity.x < 0.0
	move_and_slide()
	if is_on_wall(): _wander_dir = -_wander_dir
