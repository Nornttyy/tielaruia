# 起床战争管理器 (Node, 只在起床战争房存在, main 建)。
# Phase 2a: 给每个玩家分一座岛 (slot) — host 权威, 进房按顺序分; client 收到自己 slot → 传送到自己岛。
# 提供 owns_bed_col(col): 那张床是不是"我自己的" (用来拦"砸自己床")。
extends Node

const BedwarsArena = preload("res://scripts/world/bedwars_arena.gd")

var _world: Node = null
var spawns: Array = []         # 各岛出生世界坐标 (main 从 arena build 传入)
var _my_slot: int = 0
var _assigned: Dictionary = {}  # host 记: pid → slot


func setup(world: Node, spawns_arr: Array) -> void:
	_world = world
	spawns = spawns_arr
	add_to_group("bedwars_manager")
	if NetworkManager == null:
		return
	if NetworkManager.has_signal("bw_slot_received") and not NetworkManager.bw_slot_received.is_connected(_on_slot):
		NetworkManager.bw_slot_received.connect(_on_slot)
	if NetworkManager.has_signal("peer_joined") and not NetworkManager.peer_joined.is_connected(_on_peer_joined):
		NetworkManager.peer_joined.connect(_on_peer_joined)
	# host 自己 = 0 号岛 (已在那出生)
	if NetworkManager.is_host:
		_assigned[NetworkManager.my_peer_id()] = 0
		_my_slot = 0


func my_slot() -> int:
	return _my_slot


# 那张床 (世界列 col) 是不是我自己的 (= 我那座岛的)
func owns_bed_col(col: int) -> bool:
	return BedwarsArena.island_of_col(col) == _my_slot


# host: 有人进房 → 分下一个空岛 + 告诉他
func _on_peer_joined(pid: String) -> void:
	if NetworkManager == null or not NetworkManager.is_host:
		return
	var slot: int = _next_free_slot()
	_assigned[pid] = slot
	NetworkManager.send_bw_slot(pid, slot)


func _next_free_slot() -> int:
	var used: Dictionary = {}
	for s in _assigned.values():
		used[int(s)] = true
	var i: int = 0
	while used.has(i):
		i += 1
	return i


# 收到"你是 slot N" (pid==自己才认) → 记下 + 传送到自己岛
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
