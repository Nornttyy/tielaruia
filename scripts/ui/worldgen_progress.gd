# Original frame artwork; the two fills show completed work and the current pass.
extends Control

const FRAME = preload("res://assets/terraria_1449/ui/WorldGen/Outer_Corrupt.png")
const LOWER = preload("res://assets/terraria_1449/ui/WorldGen/Outer_Lower.png")
const FRAME_SIZE := Vector2(620, 106)
var overall: float = 0.0
var current_pass: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func _draw() -> void:
	draw_rect(Rect2(36, 41, 550, 15), Color8(22, 22, 28))
	var width := floorf(550.0 * clampf(overall, 0.0, 1.0))
	if width > 0.0:
		draw_rect(Rect2(36, 42, width, 13), Color8(182, 123, 30))
		draw_rect(Rect2(36, 43, width, 8), Color8(244, 199, 76))
		draw_rect(Rect2(36, 43, width, 2), Color8(255, 233, 133))
	draw_rect(Rect2(49, 62, 522, 7), Color8(18, 21, 34))
	var pass_width := floorf(522.0 * clampf(current_pass, 0.0, 1.0))
	if pass_width > 0.0:
		draw_rect(Rect2(49, 62, pass_width, 7), Color8(64, 103, 188))
		draw_rect(Rect2(49, 62, pass_width, 2), Color8(129, 167, 231))
	draw_texture(LOWER, Vector2(44, 60))
	draw_texture(FRAME, Vector2.ZERO)
