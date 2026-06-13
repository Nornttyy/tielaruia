# PvP 击杀榜 (CanvasLayer, 纯代码)。只在对战房显示, 右上角列 "名字 ×击杀数"。
# 监听 NetworkManager.kill_scored 累加 (各端独立统计, 靠 pkill 广播保持一致)。
extends CanvasLayer

const PvpArena = preload("res://scripts/world/pvp_arena.gd")
const WIN_SCORE := 20        # 积分到 20 = 胜利 (用户要求)
const RESET_DELAY := 4.0     # 胜利后多久重置地图 (给玩家看胜利横幅)
const EMPTY_RESET_SEC := 60.0   # 房间没别人 + 搭过方块, 满这么久 → 自动清场 (用户要求)

var _vbox: VBoxContainer
var _kills: Dictionary = {}   # peer_id(String) → 击杀数(int)
var _match_over: bool = false   # 已有人到 20 → 等重置 (防重复触发)
var _banner: Label = null       # "X 胜利!" 横幅
var _empty_timer: float = 0.0   # 独自一人持续时长 (满 EMPTY_RESET_SEC 清场)


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


func _process(delta: float) -> void:
	# 只在对战房露脸. 用 room_mode=="pvp" 而非 combat_enabled(): 切模式转房断开重连期间
	# connected()=false 但 room_mode 仍 pvp → 击杀榜不会消失一阵 (用户反馈)。
	var in_pvp: bool = NetworkManager != null and NetworkManager.room_mode == "pvp"
	visible = in_pvp
	_tick_empty_reset(delta, in_pvp)


# 房间没别人 (只剩自己) 且搭过方块 → 持续满 1 分钟自动清场. 有别人/没搭过 → 计时清零。
# (用户要求: 切模式保留方块, 但空房放久了自动重置, 给后来的人干净竞技场。)
func _tick_empty_reset(delta: float, in_pvp: bool) -> void:
	if not in_pvp or _match_over:
		_empty_timer = 0.0
		return
	if _other_players_present() or not _has_placed_blocks():
		_empty_timer = 0.0
		return
	_empty_timer += delta
	if _empty_timer >= EMPTY_RESET_SEC:
		_empty_timer = 0.0
		_clean_arena()


func _other_players_present() -> bool:
	var w: Node = get_tree().get_first_node_in_group("world")
	if w != null and w.has_method("get_remote_player_list"):
		return not (w.get_remote_player_list() as Array).is_empty()
	return false


func _has_placed_blocks() -> bool:
	var w: Node = get_tree().get_first_node_in_group("world")
	if w == null:
		return false
	var cm = w.get("chunk_manager")
	return cm != null and "_pvp_placed" in cm and not (cm._pvp_placed as Dictionary).is_empty()


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


# 重置: 清积分 + 清场 (重建竞技场 + 清搭的方块 + 随机出生) + 满血。各端独立跑, 结果一致。
func _reset_match() -> void:
	_kills.clear()
	_match_over = false
	_empty_timer = 0.0
	_refresh()
	if _banner != null:
		_banner.visible = false
	_clean_arena()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null:
		var hp: Node = player.get_node_or_null("PlayerHealth")
		if hp != null and hp.has_method("revive_full"):
			hp.revive_full()


# 清场: 重建干净竞技场 (清玩家搭的方块) + 清放置记录 + 本地玩家挪回随机出生台。
# 赢了重开 / 空房满 1 分钟 都用它。
func _clean_arena() -> void:
	var w: Node = get_tree().get_first_node_in_group("world")
	if w == null or not w.has_method("_set_tile"):
		return
	PvpArena.build(w)
	var cm = w.get("chunk_manager")
	if cm != null and cm.has_method("clear_pvp_placed"):
		cm.clear_pvp_placed()
	var player: Node = get_tree().get_first_node_in_group("player")
	if player is Node2D:
		(player as Node2D).global_position = PvpArena.random_spawn()


func _name_for(pid: String) -> String:
	if NetworkManager != null and pid == NetworkManager.my_peer_id():
		return _local_name()
	# 远程: 按 peer 取各自名字 (多人不串台), 退回最近对方名, 再退 pid
	if NetworkManager != null:
		var by_peer: String = NetworkManager.name_for_peer(pid)
		if by_peer != "":
			return by_peer
		if NetworkManager.remote_player_name != "":
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
