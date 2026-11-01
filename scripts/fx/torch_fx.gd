# The handle is drawn by the tile map. This is only its original flame mask;
# no scaling animation or separate oversized particle sprite over the torch.
extends Node2D
const Sprites = preload("res://scripts/art/terraria_sprite_pack.gd")
const FLICKER_STEP := 0.09
var tile_id: int = Tiles.TORCH
var orientation := 0
var _elapsed := 0.0
var _phase := 0
static var _atlas: ImageTexture
@onready var flame: Sprite2D = $Flame
@onready var light: PointLight2D = $Light
@onready var spark_timer: Timer = $SparkTimer

func _ready() -> void:
	light.enabled = false # DarknessLayer supplies the actual tile lighting.
	spark_timer.stop()
	flame.visible = tile_id == Tiles.TORCH
	if not flame.visible:
		set_process(false)
		return
	if _atlas == null: _atlas = Sprites.torch_atlas(true)
	flame.texture = _atlas
	flame.hframes = 3
	flame.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	flame.scale = Vector2.ONE
	_phase = posmod(roundi(position.x * 7 + position.y * 11), 8)
	set_orientation(orientation)

func set_orientation(value: int) -> void:
	orientation = clampi(value, 0, 2)
	if flame != null: flame.frame = orientation

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed < FLICKER_STEP: return
	_elapsed = fmod(_elapsed, FLICKER_STEP)
	_phase = (_phase + 1) % 8
	# A single source-pixel of flame motion; the full handle never moves.
	var offsets := [Vector2.ZERO, Vector2(-0.75, 0), Vector2.ZERO,
		Vector2(0, -0.75), Vector2(0.75, 0), Vector2.ZERO,
		Vector2(0, -0.75), Vector2.ZERO]
	flame.position = offsets[_phase]
	flame.modulate.a = [0.65, 0.5, 0.8, 0.6, 0.7, 0.5, 0.75, 0.6][_phase]
