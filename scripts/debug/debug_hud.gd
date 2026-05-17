# F3 切换显示；显示 FPS、玩家世界坐标、玩家所在 tile 坐标、tile 上的暗格状态。
extends CanvasLayer

const TILE_SIZE := 16

@onready var label: Label = $Panel/Label
var _player: Node2D
var _visible: bool = true


func _ready() -> void:
	visible = _visible


func set_player(player: Node2D) -> void:
	_player = player


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("toggle_debug"):
		_visible = not _visible
		visible = _visible
	if not _visible or _player == null:
		return
	var pos := _player.global_position
	var tile_x := int(floor(pos.x / TILE_SIZE))
	var tile_y := int(floor(pos.y / TILE_SIZE))
	var dark := not SkyLightGrid.is_sky_exposed(tile_x, tile_y)
	label.text = "FPS: %d\nPos: (%.1f, %.1f)\nTile: (%d, %d)\nDark: %s" % [
		Engine.get_frames_per_second(),
		pos.x, pos.y,
		tile_x, tile_y,
		"YES" if dark else "no",
	]
