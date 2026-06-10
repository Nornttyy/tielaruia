# PvP 击杀榜 (CanvasLayer, 纯代码)。只在对战房显示, 右上角列 "名字 ×击杀数"。
# 监听 NetworkManager.kill_scored 累加 (各端独立统计, 靠 pkill 广播保持一致)。
extends CanvasLayer

var _vbox: VBoxContainer
var _kills: Dictionary = {}   # peer_id(String) → 击杀数(int)


func _ready() -> void:
	layer = 48   # 世界之上、HUD(50) 之下
	process_mode = Node.PROCESS_MODE_ALWAYS
	var panel := PanelContainer.new()
	# 放小地图左边 (小地图右上角, 左缘约在 -448): 击杀榜紧贴它左侧
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -636.0
	panel.offset_right = -456.0
	panel.offset_top = 12.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_vbox = VBoxContainer.new()
	_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_vbox)
	_refresh()
	if NetworkManager != null and NetworkManager.has_signal("kill_scored"):
		NetworkManager.kill_scored.connect(_on_kill_scored)


func _process(_delta: float) -> void:
	# 只在对战房露脸
	visible = NetworkManager != null and NetworkManager.combat_enabled()


func _on_kill_scored(killer_pid: String, _victim_pid: String) -> void:
	if killer_pid == "":
		return   # 没凶手 (掉虚空/自杀) 不计
	_kills[killer_pid] = int(_kills.get(killer_pid, 0)) + 1
	_refresh()


func _name_for(pid: String) -> String:
	if NetworkManager != null and pid == NetworkManager.my_peer_id():
		return _local_name()
	# 远程: 暂用最近收到的对方名 (多人精确名是后续优化), 退回 pid
	if NetworkManager != null and NetworkManager.remote_player_name != "":
		return NetworkManager.remote_player_name
	return pid


func _local_name() -> String:
	if GameSettings != null and GameSettings.player_name != "":
		return GameSettings.player_name
	return "我"


func _refresh() -> void:
	for c in _vbox.get_children():
		c.free()   # 立即清 (非 queue_free, 防同帧重建数不对)
	var title := Label.new()
	title.text = "击杀榜"
	title.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 3)
	_vbox.add_child(title)
	var pids: Array = _kills.keys()
	pids.sort_custom(func(a, b): return int(_kills[a]) > int(_kills[b]))   # 击杀多的排前
	for pid in pids:
		var l := Label.new()
		l.text = "%s  ×%d" % [_name_for(pid), int(_kills[pid])]
		l.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		l.add_theme_constant_override("outline_size", 3)
		_vbox.add_child(l)
