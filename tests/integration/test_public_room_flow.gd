# 多人公共房: 多个远程玩家 spawn/移除 (直接驱动 world 的 peer 回调, 桌面无 bridge 也能测).
# 用 defer_init=true 让 world 跳过重的地形生成, 只建好 entities_root 等节点.
extends GutTest

const WorldScene = preload("res://scenes/world/world.tscn")
const MpRooms = preload("res://scripts/net/mp_rooms.gd")

var world


func before_each() -> void:
	world = WorldScene.instantiate()
	world.defer_init = true   # 跳过地形生成, 只要 entities_root / RemotePlayerScene 可用
	add_child_autofree(world)
	await wait_frames(2)   # 等 _ready 跑完


func test_peer_joined_spawns_distinct_remote_players() -> void:
	world._on_peer_joined("P2")
	world._on_peer_joined("P3")
	assert_eq(world._remote_players.size(), 2, "两个 peer → 两个远程玩家")
	assert_true(world._remote_players.has("P2") and world._remote_players.has("P3"))


func test_peer_left_removes_only_that_player() -> void:
	world._on_peer_joined("P2")
	world._on_peer_joined("P3")
	world._on_peer_left("P2")
	await wait_frames(1)
	assert_false(world._remote_players.has("P2"), "P2 走了被移除")
	assert_true(world._remote_players.has("P3"), "P3 还在")


func test_remote_pos_routes_to_correct_player() -> void:
	world._on_peer_joined("P2")
	world._on_remote_pos("P2", 100.0, 50.0, -1, "walk")
	var rp = world._remote_players["P2"]
	# apply_pos 存的是 lerp 目标 _target_pos (位置平滑追上去), 直接验证它收到了 P2 的坐标
	assert_almost_eq(rp._target_pos.x, 100.0, 0.5, "P2 的位置路由到 P2 自己的节点")
	assert_almost_eq(rp._target_pos.y, 50.0, 0.5, "y 也对")


func test_remote_pos_lazy_spawns_if_unknown() -> void:
	# 位置消息先于 join 到 → 懒创建, 不丢人
	world._on_remote_pos("P9", 10.0, 20.0, 1, "idle")
	assert_true(world._remote_players.has("P9"), "未知 peer 的 pos → 懒创建远程玩家")


func test_double_join_same_peer_no_duplicate() -> void:
	world._on_peer_joined("P2")
	world._on_peer_joined("P2")   # 重复进 (重连等) 不该建两个
	assert_eq(world._remote_players.size(), 1, "同一 peer 重复 join 只一个节点")


# 公共生存房常量稳定 (改了地图玩家会进到不同世界)
func test_public_survival_constants() -> void:
	assert_eq(MpRooms.PUBLIC_SV_SEED, 20260609, "公共生存房固定种子")
	assert_eq(MpRooms.MAX_PEERS, 8, "每房 8 人")


# 主菜单有公共生存房按钮 + 入口走 enter_public("SV", ...)
func test_main_menu_has_public_button() -> void:
	var MainMenuScene = load("res://scenes/ui/main_menu.tscn")
	var menu = MainMenuScene.instantiate()
	add_child_autofree(menu)
	await wait_frames(2)
	var btn = menu.get_node_or_null("MultiplayerPanel/VBox/PublicSurvivalButton")
	assert_not_null(btn, "多人面板该有公共生存房按钮")
	assert_true(menu.has_method("_on_public_survival_pressed"), "该有公共生存房按钮回调")
