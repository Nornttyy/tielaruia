# 起床战争横幅 (CanvasLayer): 床破/出局/胜利提示。听 bedwars_manager 的信号。
extends CanvasLayer

var _banner: Label
var _flash: Label
var _flash_t: float = 0.0


func _ready() -> void:
	layer = 49
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 中央大横幅 (持续, 胜利/出局用)
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.offset_left = -300.0
	_banner.offset_right = 300.0
	_banner.offset_top = -40.0
	_banner.offset_bottom = 40.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 48)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.visible = false
	add_child(_banner)
	# 顶部一闪而过的小提示 (床破/有人出局)
	_flash = Label.new()
	_flash.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_flash.anchor_left = 0.5
	_flash.anchor_right = 0.5
	_flash.offset_left = -250.0
	_flash.offset_right = 250.0
	_flash.offset_top = 60.0
	_flash.offset_bottom = 96.0
	_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_flash.add_theme_font_size_override("font_size", 22)
	_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_flash.add_theme_constant_override("outline_size", 4)
	_flash.visible = false
	add_child(_flash)
	var mgr: Node = get_tree().get_first_node_in_group("bedwars_manager")
	if mgr != null:
		mgr.bed_broken_sig.connect(_on_bed_broken)
		mgr.player_out_sig.connect(_on_out)
		mgr.game_over_sig.connect(_on_game_over)


func _process(delta: float) -> void:
	if _flash_t > 0.0:
		_flash_t -= delta
		if _flash_t <= 0.0:
			_flash.visible = false


func _show_flash(text: String) -> void:
	_flash.text = text
	_flash.visible = true
	_flash_t = 2.5


func _on_bed_broken(_slot: int) -> void:
	_show_flash("💥 一张床被砸了!")


func _on_out(pid: String) -> void:
	var me: bool = NetworkManager != null and pid == NetworkManager.my_peer_id()
	if me:
		_banner.text = "你出局了"
		_banner.add_theme_color_override("font_color", Color(0.9, 0.4, 0.4))
		_banner.visible = true
	else:
		_show_flash("有人出局了")


func _on_game_over(winner_pid: String) -> void:
	var me: bool = NetworkManager != null and winner_pid == NetworkManager.my_peer_id()
	if me:
		_banner.text = "胜 利!"
		_banner.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	else:
		_banner.text = "游戏结束"
		_banner.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	_banner.visible = true
