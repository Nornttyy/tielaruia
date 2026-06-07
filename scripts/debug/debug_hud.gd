# F3 切换显示；显示 FPS、玩家世界坐标、玩家所在 tile 坐标、tile 上的暗格状态。
extends CanvasLayer

const TILE_SIZE := 12

@onready var label: Label = $Panel/Label
var _player: Node2D
var _visible: bool = false  # 默认隐藏, 按 F3 (toggle_debug action) 显示


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
	var hp: Node = _player.get_node_or_null("PlayerHealth")
	var hp_txt: String = "n/a"
	if hp != null:
		hp_txt = "%d / %d" % [hp.current_health, hp.MAX_HEALTH]
	label.text = "FPS: %d\nPos: (%.1f, %.1f)\nTile: (%d, %d)\nDark: %s\nHP: %s\nFrames: %d" % [
		Engine.get_frames_per_second(),
		pos.x, pos.y,
		tile_x, tile_y,
		"YES" if dark else "no",
		hp_txt,
		Engine.get_frames_drawn(),
	]
