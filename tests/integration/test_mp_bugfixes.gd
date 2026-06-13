# 联机审计修复验收: A 名字按 peer 不串台 / B host 给晚进者补发 / C 对战房地形门控不依赖 connected()。
extends GutTest

const MainScene = preload("res://scenes/main.tscn")
const ChunkManagerClass = preload("res://scripts/world/chunk_manager.gd")


# ---- Fix A: 名字按 peer 分开存, 多人不串台 ----
func test_name_per_peer_no_collision() -> void:
	NetworkManager.remote_player_names.clear()
	NetworkManager._route_message('{"type":"name","n":"Alice"}', "PEER_A")
	NetworkManager._route_message('{"type":"name","n":"Bob"}', "PEER_B")
	assert_eq(NetworkManager.name_for_peer("PEER_A"), "Alice", "A 的名字按 A 存")
	assert_eq(NetworkManager.name_for_peer("PEER_B"), "Bob", "B 的名字按 B 存 (不被 A 覆盖)")
	assert_eq(NetworkManager.name_for_peer("PEER_X"), "", "没收到名字的 peer 返回空")
	NetworkManager.remote_player_names.clear()


func test_name_with_explicit_pid_field() -> void:
	# host 替别的 peer 转发名字时带 pid 字段, 接收端按 pid 存 (不是按 from_peer)
	NetworkManager.remote_player_names.clear()
	NetworkManager._route_message('{"type":"name","n":"Carol","pid":"PEER_C"}', "HOST")
	assert_eq(NetworkManager.name_for_peer("PEER_C"), "Carol", "带 pid 的名字按 pid 存")
	NetworkManager.remote_player_names.clear()


# ---- Fix B: host 在新 peer 进来时补发 (不崩 + spawn 远程玩家) ----
func test_host_peer_join_spawns_and_resends() -> void:
	var prev_host = NetworkManager.is_host
	var main = MainScene.instantiate()
	add_child_autofree(main)
	main.boot_to_game()
	await wait_frames(3)
	var w = main.get_node("World")
	NetworkManager.is_host = true
	NetworkManager.remote_player_names["OLD_PEER"] = "OldGuy"   # 房里已有一个人
	# 新人进来: 该 spawn 远程玩家 + host 补发逻辑跑通 (无 bridge → send 是 no-op, 不崩即可)
	w._on_peer_joined("NEW_PEER")
	assert_true(w._remote_players.has("NEW_PEER"), "新 peer 进来该 spawn 远程玩家")
	NetworkManager.is_host = prev_host
	NetworkManager.remote_player_names.clear()


# ---- Fix C: 对战房地形用 room_mode 而非 is_pvp() (断线重连窗口期也生成竞技场空气) ----
func test_pvp_chunk_empty_even_when_not_connected() -> void:
	var prev_s = NetworkManager.status
	var prev_m = NetworkManager.room_mode
	NetworkManager.status = "joining"     # connected()=false → 老代码 is_pvp() 会 false → 露真地形
	NetworkManager.room_mode = "pvp"
	var cm = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(42)
	cm.ensure_loaded(0)
	var solid: int = 0
	for y in range(0, 120):
		if cm.get_tile(0, y) != Tiles.AIR:
			solid += 1
	assert_eq(solid, 0, "对战房(room_mode=pvp)即使没 connected 也该全空气, 不露真地形")
	NetworkManager.status = prev_s
	NetworkManager.room_mode = prev_m


func test_survival_chunk_has_terrain() -> void:
	# 对照: 生存房该生成真地形
	var prev_m = NetworkManager.room_mode
	NetworkManager.room_mode = "survival"
	var cm = ChunkManagerClass.new()
	add_child_autofree(cm)
	cm.setup(42)
	cm.ensure_loaded(0)
	var solid: int = 0
	for y in range(0, 120):
		if cm.get_tile(0, y) != Tiles.AIR:
			solid += 1
	assert_gt(solid, 0, "生存房该有真地形")
	NetworkManager.room_mode = prev_m
