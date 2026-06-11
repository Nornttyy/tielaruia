# PvP 击杀榜 (CanvasLayer, 纯代码)。只在对战房显示, 右上角列 "名字 ×击杀数"。
# 监听 NetworkManager.kill_scored 累加 (各端独立统计, 靠 pkill 广播保持一致)。
extends CanvasLayer

const PvpArena = preload("res://scripts/world/pvp_arena.gd")
const WIN_SCORE := 20        # 积分到 20 = 胜利 (用户要求)
const RESET_DELAY := 4.0     # 胜利后多久重置地图 (给玩家看胜利横幅)

var _vbox: VBoxContainer
var _kills: Dictionary = {}   # peer_id(String) → 击杀数(int)
var _match_over: bool = false   # 已有人到 20 → 等重置 (防重复触发)
var _banner: Label = null       # "X 胜利!" 横幅


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
	_build_banner()
	_refresh()
	if NetworkManager != null and NetworkManager.has_signal("kill_scored"):
		NetworkManager.kill_scored.connect(_on_kill_scored)


func _process(_delta: float) -> void:
	# 只在对战房露脸. 用 room_mode=="pvp" 而非 combat_enabled(): 切模式转房断开重连期间
	# connected()=false 但 room_mode 仍 pvp → 击杀榜不会消失一阵 (用户反馈)。
	visible = NetworkManager != null and NetworkManager.room_mode == "pvp"


func _on_kill_scored(killer_pid: String, _victim_pid: String) -> void:
	if killer_pid == "":
		return   # 没凶手 (掉虚空/自杀) 不计
	_kills[killer_pid] = int(_kills.get(killer_pid, 0)) + 1
	_refresh()
	# 到 20 → 胜利 (各端击杀数同步, 所以各端同时判出同一个赢家, 各自本地重置 → 一致)
	if not _match_over and int(_kills[killer_pid]) >= WIN_SCORE:
		_trigger_win(killer_pid)


# 顶部居中胜利横幅 (常驻隐藏)。
func _build_banner() -> void:
	_banner = Label.new()
	_banner.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_banner.offset_top = 70.0
	_banner.offset_bottom = 150.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 40)
	_banner.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_banner.add_theme_constant_override("outline_size", 6)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.visible = false
	add_child(_banner)


func _trigger_win(winner_pid: String) -> void:
	_match_over = true
	if _banner != null:
		_banner.text = "%s 胜利!  地图重置中…" % _name_for(winner_pid)
		_banner.visible = true
	get_tree().create_timer(RESET_DELAY).timeout.connect(_reset_match)


# 重置: 清积分 + 重建竞技场 (清玩家搭的方块) + 本地玩家随机出生 + 满血。各端独立跑, 结果一致。
func _reset_match() -> void:
	_kills.clear()
	_match_over = false
	_refresh()
	if _banner != null:
		_banner.visible = false
	var w: Node = get_tree().get_first_node_in_group("world")
	if w != null and w.has_method("_set_tile"):
		PvpArena.build(w)
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		(player as Node2D).global_position = PvpArena.random_spawn()
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and hp.has_method("revive_full"):
			hp.revive_full()


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
