# 起床战争管理器 (Node, 只在起床战争房存在, main 建)。
# Phase 2a: 分岛 (slot, host 权威) + owns_bed_col (拦砸自己床)。
# Phase 2b: 床状态 (host 轮询) + 出局 (床破再死) + 胜负 (剩 1 人)。
# 显示交给 bedwars_hud (听本管理器的信号)。
extends Node

const BedwarsArena = preload("res://scripts/world/bedwars_arena.gd")

signal bed_broken_sig(slot: int)        # 某岛床破 (HUD 提示)
signal player_out_sig(peer_id: String)  # 某人出局
signal game_over_sig(winner_pid: String)

var _world: Node = null
var spawns: Array = []          # 各岛出生世界坐标
var _my_slot: int = 0
var _assigned: Dictionary = {}   # host 记: pid → slot
var _bed_alive: Array = []        # 每岛床还在没 (index = slot)
var _eliminated: Dictionary = {}  # host 记: 已出局 pid
var _bed_poll_t: float = 0.0
var _over: bool = false           # 已分胜负 (防重复)


func setup(world: Node, spawns_arr: Array) -> void:
	_world = world
	spawns = spawns_arr
	add_to_group("bedwars_manager")
	_bed_alive.resize(BedwarsArena.N_ISLANDS)
	_bed_alive.fill(true)
	if NetworkManager == null:
		return
	if not NetworkManager.bw_slot_received.is_connected(_on_slot):
		NetworkManager.bw_slot_received.connect(_on_slot)
	if not NetworkManager.peer_joined.is_connected(_on_peer_joined):
		NetworkManager.peer_joined.connect(_on_peer_joined)
	if not NetworkManager.peer_left.is_connected(_on_peer_left):
		NetworkManager.peer_left.connect(_on_peer_left)
	if not NetworkManager.bw_bed_broken.is_connected(_recv_bed):
		NetworkManager.bw_bed_broken.connect(_recv_bed)
	if not NetworkManager.bw_out.is_connected(_recv_out):
		NetworkManager.bw_out.connect(_recv_out)
	if not NetworkManager.bw_win.is_connected(_recv_win):
		NetworkManager.bw_win.connect(_recv_win)
	if NetworkManager.is_host:
		_assigned[NetworkManager.my_peer_id()] = 0
		_my_slot = 0


func my_slot() -> int:
	return _my_slot


func my_spawn() -> Vector2:
	if _my_slot >= 0 and _my_slot < spawns.size():
		return spawns[_my_slot]
	return spawns[0] if spawns.size() > 0 else Vector2.ZERO


func owns_bed_col(col: int) -> bool:
	return BedwarsArena.island_of_col(col) == _my_slot


func local_bed_alive() -> bool:
	return _my_slot >= 0 and _my_slot < _bed_alive.size() and bool(_bed_alive[_my_slot])


# ---- 分岛 (Phase 2a) ----
func _on_peer_joined(pid: String) -> void:
	if NetworkManager == null or not NetworkManager.is_host:
		return
	var slot: int = _next_free_slot()
	_assigned[pid] = slot
	NetworkManager.send_bw_slot(pid, slot)


func _on_peer_left(pid: String) -> void:
	# 离开的人释放岛 + 当出局处理 (host 重算胜负)
	if NetworkManager != null and NetworkManager.is_host:
		_assigned.erase(pid)
		_recv_out(pid)


func _next_free_slot() -> int:
	var used: Dictionary = {}
	for s in _assigned.values():
		used[int(s)] = true
	var i: int = 0
	while used.has(i):
		i += 1
	return i


func _on_slot(pid: String, slot: int) -> void:
	if NetworkManager != null and pid == NetworkManager.my_peer_id():
		_my_slot = slot
		_teleport_to_own_island()


func _teleport_to_own_island() -> void:
	if _world == null or not is_instance_valid(_world) or not _world.has_method("get_player"):
		return
	var p = _world.get_player()
	if p != null and _my_slot >= 0 and _my_slot < spawns.size():
		p.global_position = spawns[_my_slot]


# ---- 床状态 (Phase 2b, host 轮询) ----
func _process(delta: float) -> void:
	if NetworkManager == null or not NetworkManager.is_host or _world == null:
		return
	_bed_poll_t -= delta
	if _bed_poll_t > 0.0:
		return
	_bed_poll_t = 1.0
	var cm = _world.get("chunk_manager")
	if cm == null:
		return
	for i in BedwarsArena.N_ISLANDS:
		if not bool(_bed_alive[i]):
			continue
		var col: int = BedwarsArena.island_center_col(i)
		if cm.get_tile(col, BedwarsArena.FLOOR_Y - 1) != Tiles.BED:
			_bed_alive[i] = false
			NetworkManager.send_bw_bed_broken(i)   # 告诉客户端
			bed_broken_sig.emit(i)                  # host 自己的 HUD


# client 收 host 广播的床破
func _recv_bed(slot: int) -> void:
	if slot >= 0 and slot < _bed_alive.size():
		_bed_alive[slot] = false
		bed_broken_sig.emit(slot)


# 本端玩家"床破后又死" → 出局: 广播 + 本端提示; host 还要算胜负
func declare_out() -> void:
	if NetworkManager == null:
		return
	NetworkManager.send_bw_out(NetworkManager.my_peer_id())
	player_out_sig.emit(NetworkManager.my_peer_id())   # 自己的"出局"横幅
	if NetworkManager.is_host:
		_eliminated[NetworkManager.my_peer_id()] = true
		_check_win()


# 收到某人出局 (host 端算胜负; 各端弹提示)
func _recv_out(pid: String) -> void:
	player_out_sig.emit(pid)
	if NetworkManager != null and NetworkManager.is_host:
		_eliminated[pid] = true
		_check_win()


func _check_win() -> void:
	if _over:
		return
	var alive: Array = []
	for pid in _assigned.keys():
		if not _eliminated.has(pid):
			alive.append(pid)
	if alive.size() <= 1 and _assigned.size() >= 2:   # ≥2 人开局才算胜负
		_over = true
		var winner: String = alive[0] if alive.size() == 1 else ""
		NetworkManager.send_bw_win(winner)
		_recv_win(winner)


func _recv_win(winner_pid: String) -> void:
	_over = true
	game_over_sig.emit(winner_pid)
